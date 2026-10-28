class_name PlayPitch
extends Control
## Boisko Edytora zagrań: siatka 5 stref × 3 korytarze, atak w górę ekranu (strefa 5 u góry).
## Pokazuje pola wyjścia karty, a dla aktywnego pola wyjścia: cele (strzałki), pola przelotu i wagi udziału
## zawodników (A = atak, O = obrona) – logika jak w PlayContest. Samo nie zmienia karty, tylko wysyła sygnały.

## Kliknięto pole boiska (button: MOUSE_BUTTON_LEFT / RIGHT, ctrl / shift: wciśnięte klawisze).
signal cell_clicked(cell: Vector2i, button: int, ctrl: bool, shift: bool)
## Kliknięto numer strefy w lewym marginesie (szybkie zaznaczenie całej strefy).
signal zone_clicked(zone: int)

const SHIRT_BASE: Texture2D = preload("res://assets/graphics/players/shirt_base.png")
const SHIRT_SHADOW: Texture2D = preload("res://assets/graphics/players/shirt_shadow.png")
## Podgląd ustawienia taktyki (półprzezroczyste koszulki).
const PREVIEW_SHIRT := Color(0.86, 0.92, 1.0, 0.5)
const PREVIEW_LABEL := Color(1.0, 1.0, 1.0, 0.75)
const HEADER_HEIGHT := 22.0
const GUTTER_WIDTH := 34.0
const NO_CELL := Vector2i(-1, -1)

const ORIGIN_FILL := Color(0.96, 0.84, 0.29, 0.22)
const ORIGIN_BORDER := Color(0.96, 0.84, 0.29, 0.85)
const ACTIVE_BORDER := Color(1.0, 0.95, 0.6, 1.0)
const TARGET_FILL := Color(0.44, 0.83, 1.0, 0.2)
const TARGET_BORDER := Color(0.55, 0.88, 1.0, 1.0)
const FOCUS_TARGET_BORDER := Color(1.0, 1.0, 1.0, 1.0)
const FLYOVER_FILL := Color(0.9, 0.38, 0.23, 0.28)
const ARROW_COLOR := Color(0.85, 0.95, 1.0, 0.95)
const ATTACK_TEXT := Color("#b8f08a")
const DEFENSE_TEXT := Color("#ffb070")
const LABEL_TEXT := Color("#f0e6a8")
const GRID_LINE := Color(1.0, 1.0, 1.0, 0.35)

var card: PlayCard
var active_origin := NO_CELL
## Tryb „cele”: kliknięcia przełączają cele aktywnego pola (tylko kierunek ręczny) – ramka pod kursorem w kolorze celu.
var target_mode := false
var rules := MatchRules.new()
## Taktyka, której ustawienie pokazujemy (najechanie na taktykę w panelu); null = brak podglądu.
var preview_tactic: TacticData

var _hover_cell := NO_CELL
var _hover_zone := 0
## Układ boiska z opcji: rysujemy pole gry i tyle trawy za liniami końcowymi, ile się zmieści.
var _layout := PitchLayout.get_default()


func _init() -> void:
	PixelArt.apply(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(GUTTER_WIDTH + _layout.field.size.x, HEADER_HEIGHT + _get_field_height())


func set_card(play_card: PlayCard, origin: Vector2i) -> void:
	card = play_card
	active_origin = origin
	queue_redraw()


func set_preview_tactic(tactic: TacticData) -> void:
	if tactic == preview_tactic:
		return
	preview_tactic = tactic
	queue_redraw()


# --- Geometria ---

func _get_field_height() -> float:
	return float(_layout.field.size.y)


## Ile pikseli murawy za linią końcową mieści się nad i pod polem gry.
func _get_visible_margin() -> float:
	var texture_margin := mini(_layout.field.position.y, _layout.size.y - _layout.field.end.y)
	return clampf(floorf((size.y - HEADER_HEIGHT - _get_field_height()) / 2.0), 0.0, texture_margin)


func get_field_rect() -> Rect2:
	var width := _layout.field.size.x
	var left := roundf((size.x - GUTTER_WIDTH - width) / 2.0) + GUTTER_WIDTH
	return Rect2(left, HEADER_HEIGHT + _get_visible_margin(), width, _get_field_height())


## Granice korytarzy w ułamkach szerokości (jak MatchRules.get_channel).
func _channel_bounds(channel: int) -> Vector2:
	var edges := [0.0, rules.channel_left_max, rules.channel_right_min, 1.0]
	return Vector2(edges[channel], edges[channel + 1])


func get_cell_rect(cell: Vector2i) -> Rect2:
	var field := get_field_rect()
	var lane_height := field.size.y / MatchRules.ZONE_COUNT
	var bounds := _channel_bounds(cell.y)
	var left := roundf(field.position.x + bounds.x * field.size.x)
	var right := roundf(field.position.x + bounds.y * field.size.x)
	var top := field.position.y + (MatchRules.ZONE_COUNT - cell.x) * lane_height
	return Rect2(left, top, right - left, lane_height)


func get_cell_at(point: Vector2) -> Vector2i:
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)
			if get_cell_rect(cell).has_point(point):
				return cell
	return NO_CELL


func get_zone_button_rect(zone: int) -> Rect2:
	var row := get_cell_rect(Vector2i(zone, 0))
	return Rect2(get_field_rect().position.x - GUTTER_WIDTH + 2.0, row.position.y + 3.0, GUTTER_WIDTH - 6.0,
			row.size.y - 6.0)


func _get_zone_button_at(point: Vector2) -> int:
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		if get_zone_button_rect(zone).has_point(point):
			return zone
	return 0


# --- Wejście ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(get_cell_at(event.position), _get_zone_button_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index != MOUSE_BUTTON_LEFT and event.button_index != MOUSE_BUTTON_RIGHT:
			return
		var zone := _get_zone_button_at(event.position)
		if zone != 0 and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			zone_clicked.emit(zone)
			return
		var cell := get_cell_at(event.position)
		if cell != NO_CELL:
			accept_event()
			cell_clicked.emit(cell, event.button_index, event.ctrl_pressed or event.meta_pressed, event.shift_pressed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover(NO_CELL, 0)


func _set_hover(cell: Vector2i, zone: int) -> void:
	if cell == _hover_cell and zone == _hover_zone:
		return
	_hover_cell = cell
	_hover_zone = zone
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if cell != NO_CELL or zone != 0 else Control.CURSOR_ARROW
	tooltip_text = tr("EDITOR_ZONE_TOGGLE_TOOLTIP") % zone if zone != 0 else ""
	queue_redraw()


## Cel, dla którego pokazujemy przelot i wagi: cel pod kursorem albo pierwszy cel aktywnego pola.
func get_focus_target() -> Vector2i:
	var targets := _get_active_targets()
	if targets.is_empty():
		return NO_CELL
	if _hover_cell in targets:
		return _hover_cell
	return targets[0]


func _get_active_targets() -> Array[Vector2i]:
	if card == null or not active_origin in card.origins:
		return []
	return card.get_targets(active_origin)


# --- Rysowanie ---

func _draw() -> void:
	var field := get_field_rect()
	var margin := _get_visible_margin()
	var texture_rect := Rect2(field.position - Vector2(0.0, margin), Vector2(field.size.x, field.size.y + margin * 2.0))
	draw_texture_rect_region(PitchDimmer.get_texture(PitchBuilder.get_texture(_layout), Settings.pitch_dim),
			texture_rect, Rect2(_layout.field.position.x, _layout.field.position.y - margin, field.size.x,
			texture_rect.size.y))
	_draw_grid(field)
	_draw_labels(field)
	if card == null:
		return
	for origin in card.origins:
		var rect := get_cell_rect(origin).grow(-3.0)
		draw_rect(rect, ORIGIN_FILL)
		draw_rect(rect, ORIGIN_BORDER, false, 2.0)
	var targets := _get_active_targets()
	var focus := get_focus_target()
	if focus != NO_CELL:
		for cell in PlayContest.get_flyover_cells(active_origin, focus):
			_draw_hatched(get_cell_rect(cell).grow(-3.0), FLYOVER_FILL)
	for target in targets:
		var rect := get_cell_rect(target).grow(-7.0)
		draw_rect(rect, TARGET_FILL)
		draw_rect(rect, FOCUS_TARGET_BORDER if target == focus and targets.size() > 1 else TARGET_BORDER, false, 3.0)
	if active_origin in card.origins:
		draw_rect(get_cell_rect(active_origin).grow(-3.0), ACTIVE_BORDER, false, 4.0)
	for target in targets:
		_draw_arrow(get_cell_rect(active_origin).get_center(), get_cell_rect(target).get_center(), target == focus)
	if active_origin in card.origins:
		_draw_ball(get_cell_rect(active_origin).get_center())
	if focus != NO_CELL:
		_draw_weights(focus)
	if preview_tactic != null:
		_draw_formation(preview_tactic, field)
	if _hover_cell != NO_CELL:
		var hover_color := TARGET_BORDER if target_mode else Color(1, 1, 1, 0.55)
		draw_rect(get_cell_rect(_hover_cell).grow(-1.0), hover_color, false, 2.0 if target_mode else 1.0)


func _draw_grid(field: Rect2) -> void:
	var separator := PitchOverlays.get_zone_separator(_layout.field.size.x)
	for zone in range(1, MatchRules.ZONE_COUNT):
		var top := get_cell_rect(Vector2i(zone, 0)).position.y
		draw_texture(separator, Vector2(field.position.x, top - floorf(separator.get_height() / 2.0)))
	for channel in range(1, MatchRules.CHANNEL_COUNT):
		var x := get_cell_rect(Vector2i(1, channel)).position.x
		_draw_dashed_vertical(x, field.position.y, field.end.y)


func _draw_dashed_vertical(x: float, top: float, bottom: float) -> void:
	var y := top
	while y < bottom:
		draw_line(Vector2(x, y), Vector2(x, minf(y + 6.0, bottom)), GRID_LINE, 2.0)
		y += 12.0


## Nazwy korytarzy nad boiskiem, przyciski stref po lewej i strzałka kierunku ataku.
func _draw_labels(field: Rect2) -> void:
	var font := get_theme_default_font()
	var keys: Array[String] = ["EDITOR_CHANNEL_LEFT", "EDITOR_CHANNEL_CENTER", "EDITOR_CHANNEL_RIGHT"]
	for channel in MatchRules.CHANNEL_COUNT:
		var rect := get_cell_rect(Vector2i(5, channel))
		draw_string(font, Vector2(rect.position.x, 16.0), tr(keys[channel]), HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x, 14, LABEL_TEXT)
	# Strzałka „atak” w lewym górnym rogu (nad przyciskami stref).
	var arrow_x := field.position.x - GUTTER_WIDTH / 2.0
	draw_colored_polygon(PackedVector2Array([Vector2(arrow_x, 3.0), Vector2(arrow_x - 7.0, 13.0),
			Vector2(arrow_x + 7.0, 13.0)]), LABEL_TEXT)
	draw_rect(Rect2(arrow_x - 2.5, 12.0, 5.0, 8.0), LABEL_TEXT)
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		var box := get_zone_button_rect(zone)
		var hovered := zone == _hover_zone
		draw_rect(box, Color(0.239, 0.42, 0.278, 1.0) if hovered else Color(0.149, 0.251, 0.184, 0.95))
		draw_rect(box, Color(0.651, 0.839, 0.447) if hovered else Color(0.353, 0.561, 0.373), false, 2.0)
		var baseline := box.get_center().y + (font.get_ascent(18) - font.get_descent(18)) / 2.0
		draw_string(font, Vector2(box.position.x, roundf(baseline)), str(zone), HORIZONTAL_ALIGNMENT_CENTER,
				box.size.x, 18, Color.WHITE)


func _draw_hatched(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)
	# Linie pod 45° (x + y = t) przycięte do prostokąta.
	var w := rect.size.x
	var h := rect.size.y
	var t := 10.0
	while t < w + h:
		var a := rect.position + Vector2(minf(t, w), maxf(0.0, t - w))
		var b := rect.position + Vector2(maxf(0.0, t - h), minf(t, h))
		draw_line(a, b, Color(color, 0.6), 1.0)
		t += 10.0


func _draw_arrow(from: Vector2, to: Vector2, focused: bool) -> void:
	var color := ARROW_COLOR if focused else Color(ARROW_COLOR, 0.6)
	if from.distance_to(to) < 1.0:
		# Cel = pole wyjścia (np. strzał): pierścień zamiast strzałki.
		draw_arc(from, 26.0, 0.0, TAU, 32, color, 3.0)
		return
	var direction := (to - from).normalized()
	var start := from + direction * 14.0
	var tip := to - direction * 10.0
	var head := 14.0
	var side := direction.orthogonal() * 8.0
	draw_line(start, tip - direction * head * 0.8, Color(0, 0, 0, 0.45), 7.0)
	draw_line(start, tip - direction * head * 0.8, color, 4.0)
	var points := PackedVector2Array([tip, tip - direction * head + side, tip - direction * head - side])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.45), 1.0)


func _draw_ball(center: Vector2) -> void:
	draw_circle(center, 9.0, Color(0.05, 0.05, 0.05, 0.8))
	draw_circle(center, 7.0, Color.WHITE)
	draw_circle(center, 2.5, Color(0.1, 0.1, 0.1))


## Wagi udziału zawodników przy danym celu: A (atak) i O (obrona) w każdym polu z wagą > 0.
func _draw_weights(target: Vector2i) -> void:
	var font := get_theme_default_font()
	var flyover := PlayContest.get_flyover_cells(active_origin, target)
	var attack_label := tr("EDITOR_WEIGHT_ATTACK_SHORT")
	var defense_label := tr("EDITOR_WEIGHT_DEFENSE_SHORT")
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)
			var attack := PlayContest.get_cell_weight(cell, true, active_origin, target, flyover, rules)
			var defense := PlayContest.get_cell_weight(cell, false, active_origin, target, flyover, rules)
			if attack <= 0.0 and defense <= 0.0:
				continue
			var rect := get_cell_rect(cell)
			var lines: Array = []
			if attack > 0.0:
				lines.append(["%s %s" % [attack_label, format_weight(attack)], ATTACK_TEXT])
			if defense > 0.0:
				lines.append(["%s %s" % [defense_label, format_weight(defense)], DEFENSE_TEXT])
			var line_height := 15.0
			var box_width := 52.0
			var box := Rect2(rect.end.x - box_width - 6.0, rect.end.y - lines.size() * line_height - 8.0,
					box_width, lines.size() * line_height + 4.0)
			draw_rect(box, Color(0.04, 0.07, 0.05, 0.78))
			for i in lines.size():
				draw_string(font, Vector2(box.position.x + 4.0, box.position.y + 13.0 + i * line_height), lines[i][0],
						HORIZONTAL_ALIGNMENT_LEFT, box_width - 6.0, 13, lines[i][1])
	if card.is_shot:
		# Bramkarz broniących przy strzale zawsze w pełni.
		var goal_rect := get_cell_rect(Vector2i(MatchRules.ZONE_COUNT, MatchRules.CHANNEL_CENTER))
		var text := tr("EDITOR_GOALKEEPER_WEIGHT") % format_weight(1.0)
		var box := Rect2(goal_rect.position.x + 6.0, goal_rect.position.y + 6.0, goal_rect.size.x - 12.0, 20.0)
		draw_rect(box, Color(0.04, 0.07, 0.05, 0.78))
		draw_string(font, Vector2(box.position.x, box.position.y + 15.0), text, HORIZONTAL_ALIGNMENT_CENTER,
				box.size.x, 13, DEFENSE_TEXT)


## Półprzezroczyste koszulki zawodników taktyki (atak w górę, jak w PitchView: pas strefy i głębokość w pasie)
## ze skrótem roli.
func _draw_formation(tactic: TacticData, field: Rect2) -> void:
	var font := get_theme_default_font()
	var lane_height := field.size.y / MatchRules.ZONE_COUNT
	for slot in tactic.slots:
		var lane_bottom := field.end.y - (slot.lane - 1) * lane_height
		var point := Vector2(field.position.x + slot.x * field.size.x, lane_bottom - slot.depth * lane_height)
		var shirt_position := (point - SHIRT_BASE.get_size() / 2.0).round()
		draw_texture(SHIRT_SHADOW, shirt_position + Vector2(1.0, 2.0), Color(1.0, 1.0, 1.0, 0.35))
		draw_texture(SHIRT_BASE, shirt_position, PREVIEW_SHIRT)
		var role := GameData.get_role(slot.role_id)
		var text := tr(role.short_key) if role != null else String(slot.role_id)
		draw_string_outline(font, Vector2(point.x - 30.0, point.y + 24.0), text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12,
				3, Color(0.0, 0.0, 0.0, 0.6))
		draw_string(font, Vector2(point.x - 30.0, point.y + 24.0), text, HORIZONTAL_ALIGNMENT_CENTER, 60.0, 12,
				PREVIEW_LABEL)


static func format_weight(value: float) -> String:
	var text := String.num(value, 1)
	if not "." in text:
		text += ".0"
	return text.replace(".", ",") if TranslationServer.get_locale().begins_with("pl") else text

class_name PitchView
extends Control
## Boisko podzielone na 5 pasów taktycznych (po 2 pasy murawy na każdy).
## Pas 1 gospodarzy (bramkarz + obrońcy) jest na dole, pas 1 gości – na górze (lustrzane odbicie).
## Pasy (strefy) są oddzielone delikatną przerywaną linią; gdy zones_interactive, kliknięcie zaznacza strefę.

signal slot_pressed(lineup: Lineup, slot_index: int)
## Przeciągnięty zawodnik został upuszczony na pozycję w formacji.
signal player_dropped(lineup: Lineup, slot_index: int, dragged: PlayerData)
## Kliknięto strefę boiska (numer pasa z perspektywy gospodarzy, 1–5).
signal zone_pressed(zone: int)

const LANE_COUNT := FormationSlot.LANE_COUNT
const LABEL_GUTTER := 26.0
## Przezroczystość podświetlenia strefy pod kursorem (niezaznaczonej).
const ZONE_HOVER_ALPHA := 0.4
## Głębokość w pasie w trybie split (widok meczu): pozostali, bramkarz, obrońcy w pasie 1.
const SPLIT_DEPTH := 0.25
const SPLIT_GOALKEEPER_DEPTH := 0.1
const SPLIT_DEFENDER_DEPTH := 0.35

@export var show_lane_labels := true
@export var interactive := true
## Widok meczu: każdy pas taktyczny dzielony na dwa pasy murawy – gospodarze stoją na dolnym, goście na górnym.
## Wyłączone: pozycja wewnątrz pasa wynika z FormationSlot.depth.
@export var split_lanes := false
## Kliknięcie w boisko (poza żetonem) zaznacza strefę.
@export var zones_interactive := false

## Zaznaczona pozycja w składzie gospodarzy (-1 = brak).
var selected_slot := -1
## Zaznaczona strefa (1–5, 0 = brak).
var selected_zone := 0:
	set(value):
		selected_zone = value
		queue_redraw()

var _hover_zone := 0
## Układ boiska (grafika i pole gry).
var _layout := PitchLayout.get_default()

var _home_lineup: Lineup
var _away_lineup: Lineup
var _tokens_root: Control
## Składy i taktyki, dla których zbudowano żetony – przy zmianie żetony są tworzone od nowa,
## w przeciwnym razie tylko aktualizowane (żeby nie usuwać żetonu, który gracz właśnie trzyma myszą).
var _built_signature: Array = []


func _ready() -> void:
	PixelArt.apply(self)
	_tokens_root = Control.new()
	_tokens_root.name = "Tokens"
	_tokens_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tokens_root.position = _get_pitch_origin()
	add_child(_tokens_root)
	# Wariant zaznaczenia strefy pochodzi z ustawień gry.
	Settings.settings_changed.connect(queue_redraw)
	refresh()


func _gui_input(event: InputEvent) -> void:
	if not zones_interactive:
		return
	if event is InputEventMouseMotion:
		_set_hover_zone(get_zone_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var zone := get_zone_at(event.position)
		if zone != 0:
			accept_event()
			zone_pressed.emit(zone)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover_zone(0)


## Strefa (1–5) pod punktem w pikselach kontrolki albo 0 poza polem gry.
func get_zone_at(point: Vector2) -> int:
	for zone in range(1, LANE_COUNT + 1):
		if get_zone_rect(zone).has_point(point):
			return zone
	return 0


## Prostokąt strefy w pikselach kontrolki (strefa 1 na dole).
func get_zone_rect(zone: int) -> Rect2:
	var rect := _layout.get_zone_rect(zone)
	rect.position += _get_pitch_origin()
	return rect


func _set_hover_zone(zone: int) -> void:
	if get_viewport().gui_is_dragging():
		zone = 0
	if zone != _hover_zone:
		_hover_zone = zone
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if zone != 0 else Control.CURSOR_ARROW
		queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(_layout.size) + Vector2(_get_pitch_origin().x, 0.0)


func set_lineups(home: Lineup, away: Lineup = null) -> void:
	_home_lineup = home
	_away_lineup = away
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	var signature := [_home_lineup, _home_lineup.tactic if _home_lineup != null else null,
			_away_lineup, _away_lineup.tactic if _away_lineup != null else null]
	if signature != _built_signature:
		_built_signature = signature
		for child in _tokens_root.get_children():
			_tokens_root.remove_child(child)
			child.queue_free()
		if _home_lineup != null:
			_add_tokens(_home_lineup, true)
		if _away_lineup != null:
			_add_tokens(_away_lineup, false)
	for token: PlayerToken in _tokens_root.get_children():
		_update_token(token)
	queue_redraw()


## Pozycja pozycji formacji w pikselach (względem lewego górnego rogu tekstury boiska).
func get_slot_point(slot: FormationSlot, is_home: bool) -> Vector2:
	var field_size := Vector2(_layout.field.size)
	var lane_height := _layout.get_zone_height()
	var lane_bottom := field_size.y - (slot.lane - 1) * lane_height
	# W trybie split zawodnik stoi na środku "swojego" (dolnego z perspektywy drużyny) pasa murawy.
	var depth := get_split_depth(slot) if split_lanes else slot.depth
	var point := Vector2(slot.x * field_size.x, lane_bottom - depth * lane_height)
	if not is_home:
		point = field_size - point
	return point + Vector2(_layout.field.position)


## Głębokość w pasie w trybie split: bramkarz bliżej bramki, obrońcy dalej od niego (bliżej środka pasa).
static func get_split_depth(slot: FormationSlot) -> float:
	if slot.role_id == PositionData.GOALKEEPER:
		return SPLIT_GOALKEEPER_DEPTH
	if slot.lane == 1:
		return SPLIT_DEFENDER_DEPTH
	return SPLIT_DEPTH


func _get_pitch_origin() -> Vector2:
	return Vector2(LABEL_GUTTER if show_lane_labels else 0.0, 0.0)


func _add_tokens(lineup: Lineup, is_home: bool) -> void:
	for slot in lineup.tactic.slots:
		var token := PlayerToken.new()
		token.interactive = interactive
		token.set_meta(&"lineup", lineup)
		token.set_meta(&"slot_index", slot.index)
		token.set_meta(&"is_home", is_home)
		token.position = (get_slot_point(slot, is_home) - token.get_anchor_offset()).round()
		token.pressed.connect(_on_token_pressed.bind(lineup, slot.index))
		token.player_dropped.connect(_on_token_player_dropped.bind(lineup, slot.index))
		_tokens_root.add_child(token)


func _update_token(token: PlayerToken) -> void:
	var lineup: Lineup = token.get_meta(&"lineup")
	var slot_index: int = token.get_meta(&"slot_index")
	var is_home: bool = token.get_meta(&"is_home")
	token.selected = is_home and slot_index == selected_slot
	var role_id := lineup.tactic.slots[slot_index].role_id
	var colors: Array[Color] = [lineup.team.primary_color, lineup.team.secondary_color]
	if role_id == PositionData.GOALKEEPER:
		colors = _get_goalkeeper_kit(is_home)
	token.setup(lineup.get_player_at(slot_index), role_id, colors[0], colors[1])


## Strój bramkarza (KitColors) – różny od koszulek obu drużyn na boisku.
func _get_goalkeeper_kit(is_home: bool) -> Array[Color]:
	if _home_lineup != null and _away_lineup != null:
		return KitColors.get_match_goalkeeper_kits(_home_lineup.team, _away_lineup.team)[0 if is_home else 1]
	var lineup := _home_lineup if is_home else _away_lineup
	return KitColors.get_goalkeeper_kit(lineup.team)


func _on_token_pressed(lineup: Lineup, slot_index: int) -> void:
	slot_pressed.emit(lineup, slot_index)


func _on_token_player_dropped(dragged: PlayerData, lineup: Lineup, slot_index: int) -> void:
	player_dropped.emit(lineup, slot_index, dragged)


func _draw() -> void:
	var origin := _get_pitch_origin()
	draw_texture(PitchDimmer.get_texture(PitchBuilder.get_texture(_layout), Settings.pitch_dim), origin)
	_draw_zones(origin)
	if not show_lane_labels:
		return
	# Numery pasów taktycznych (z perspektywy gospodarzy) po lewej stronie boiska.
	var font := get_theme_default_font()
	for lane in range(1, LANE_COUNT + 1):
		var zone := get_zone_rect(lane)
		var box := Rect2(2.0, zone.position.y + 2.0, LABEL_GUTTER - 6.0, zone.size.y - 4.0)
		var is_selected := lane == selected_zone
		draw_rect(box, Color("#f5d54a", 0.85) if is_selected else Color(0.0, 0.0, 0.0, 0.3))
		var baseline := box.get_center().y + (font.get_ascent(14) - font.get_descent(14)) / 2.0
		draw_string(font, Vector2(box.position.x, roundf(baseline)), str(lane), HORIZONTAL_ALIGNMENT_CENTER,
				box.size.x, 14, Color("#1d1a08") if is_selected else Color(1.0, 1.0, 1.0, 0.8))


## Linie między strefami (zawsze) i podświetlenie strefy zaznaczonej / pod kursorem.
func _draw_zones(origin: Vector2) -> void:
	var separator := PitchOverlays.get_zone_separator(_layout.field.size.x)
	for zone in range(1, LANE_COUNT):
		var top := get_zone_rect(zone).position.y
		draw_texture(separator, Vector2(origin.x + _layout.field.position.x, top - floorf(separator.get_height() / 2.0)))
	var highlight := PitchOverlays.get_zone_highlight(Settings.zone_highlight_style,
			Vector2i(get_zone_rect(1).size))
	if _hover_zone != 0 and _hover_zone != selected_zone:
		draw_texture_rect(highlight, get_zone_rect(_hover_zone), false, Color(1, 1, 1, ZONE_HOVER_ALPHA))
	if selected_zone != 0:
		draw_texture_rect(highlight, get_zone_rect(selected_zone), false)

class_name MatchPitch
extends Control
## Boisko ekranu meczu: oba składy (MatchPlayer) w aktualnych polach, nakładka zagrania (udział pól, cel,
## przelot, piłka), kości przy koszulkach, wybór pola docelowego i przesunięcia zawodnika.
## Po rzucie zawodnicy z kośćmi stają się plakietkami (DicePlate: kości zamiast koszulki), a reszta znacznikami.
## Gospodarze (drużyna 0) atakują w górę ekranu. Pola silnika są w perspektywie drużyny, a tu – „pola ekranu”:
## strefa 1 na dole, korytarz 0 po lewej (czyli perspektywa gospodarzy).

## Kliknięto pole (pole ekranu) – tylko pola z listy wyboru (cel zagrania, przesunięcie).
signal cell_clicked(screen_cell: Vector2i)
## Kliknięto zawodnika z listy wybieralnych (przesunięcie).
signal player_clicked(player: MatchPlayer)
signal die_clicked(match_die: MatchDie)
## Kość gracza przeciągnięta z miejsca w teście z powrotem na boisko.
signal die_returned(contest_die: PlayContest.ContestDie)
## Kliknięto nazwisko zawodnika – profil zawodnika.
signal player_profile_requested(player: MatchPlayer)

const NO_CELL := Vector2i(-1, -1)
## Rozsuwanie nachodzących plakietek: odstęp i liczba przebiegów.
const PLATE_GAP := 4.0
const PLATE_LAYOUT_ITERATIONS := 60
## Znacznik zawodnika bez udziału w akcji (w trakcie rzutu).
const MARKER_RADIUS := 5.0
const MARKER_OUTLINE := Color(0.06, 0.08, 0.07, 0.9)
const NON_PARTICIPANT_ALPHA := 0.45
const MOVE_TIME := 0.3

const HEAT_COLOR := Color(0.95, 0.81, 0.29)
const FLYOVER_COLOR := Color(0.95, 0.5, 0.25)
const TARGET_BORDER := Color("#f2cf4a")
const ORIGIN_BORDER := Color(0.91, 0.93, 0.87, 0.85)
const CHOICE_COLOR := Color(0.55, 0.88, 1.0)
const SHIFT_COLOR := Color(0.62, 0.88, 0.48)
const LABEL_COLOR := Color("#fff1b8")
const ARROW_OUTLINE := Color(0.063, 0.125, 0.102, 0.8)

var engine: MatchEngine
## Układ boiska (rozmiar grafiki, pole gry, wysokość strefy).
var layout := PitchLayout.get_default()
## Stroje: [drużyna][0 = pole, 1 = bramkarz] -> [kolor główny, dodatkowy].
var kits: Array = []

# --- Nakładka zagrania ---
var overlay_card: PlayCard
## Pola w perspektywie atakujących.
var overlay_origin := NO_CELL
var overlay_target := NO_CELL
## Indeks drużyny atakującej (perspektywa pól nakładki).
var overlay_team := 0
## Pola do kliknięcia (pola ekranu): wybór celu albo przesunięcia.
var choice_cells: Array[Vector2i] = []
var choice_color := CHOICE_COLOR
## Zawodnicy do kliknięcia (przesunięcie) i zawodnik wybrany.
var selectable_players: Array[MatchPlayer] = []
var selected_player: MatchPlayer
## Kości gracza można w tej fazie odkładać z powrotem na boisko.
var accepts_returned_dice := false

var _tokens: Dictionary = {}  # MatchPlayer -> PlayerToken
var _dice: Dictionary = {}  # PlayContest.ContestDie -> MatchDie
var _plates: Dictionary = {}  # MatchPlayer -> DicePlate
## Kości wylądowały: plakietki zamiast koszulek, znaczniki zamiast zawodników bez kości.
var _dice_phase := false
var _tokens_root: Control
var _dice_root: Control
var _fx_root: Control
var _hover_cell := NO_CELL
var _hover_name_player: MatchPlayer


func _init() -> void:
	PixelArt.apply(self)
	custom_minimum_size = layout.size
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false


func _ready() -> void:
	for layer_name in ["Tokens", "Dice", "Effects"]:
		var layer := Control.new()
		layer.name = layer_name
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer)
	_tokens_root = get_node("Tokens")
	_dice_root = get_node("Dice")
	_fx_root = get_node("Effects")
	_dice_root.mouse_filter = Control.MOUSE_FILTER_PASS
	Settings.settings_changed.connect(queue_redraw)


func setup(match_engine: MatchEngine) -> void:
	engine = match_engine
	var home := engine.teams[0].lineup.team
	var away := engine.teams[1].lineup.team
	var keepers := KitColors.get_match_goalkeeper_kits(home, away)
	kits = [
		[[home.primary_color, home.secondary_color], keepers[0]],
		[[away.primary_color, away.secondary_color], keepers[1]],
	]
	refresh(false)


# --- Geometria ---

## Pole ekranu <-> pole w perspektywie drużyny (to samo odbicie w obie strony).
static func to_screen(cell: Vector2i, team_index: int) -> Vector2i:
	if team_index == 0:
		return cell
	return Vector2i(MatchRules.ZONE_COUNT + 1 - cell.x, MatchRules.CHANNEL_COUNT - 1 - cell.y)


func _channel_edges() -> Array[float]:
	var left := float(layout.field.position.x)
	var width := float(layout.field.size.x)
	var rules := engine.rules if engine != null else MatchRules.new()
	return [left, left + roundf(rules.channel_left_max * width), left + roundf(rules.channel_right_min * width),
			left + width]


func get_cell_rect(screen_cell: Vector2i) -> Rect2:
	var edges := _channel_edges()
	var zone := layout.get_zone_rect(screen_cell.x)
	return Rect2(edges[screen_cell.y], zone.position.y, edges[screen_cell.y + 1] - edges[screen_cell.y], zone.size.y)


func get_cell_at(point: Vector2) -> Vector2i:
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)
			if get_cell_rect(cell).has_point(point):
				return cell
	return NO_CELL


## Punkt zawodnika na ekranie (środek koszulki): formacja jak na boisku przedmeczowym, a po przesunięciu
## albo przejściu na inne pole – w tym polu.
func get_player_point(player: MatchPlayer, team_index: int) -> Vector2:
	var slot := player.formation_slot
	var field := Vector2(layout.field.size)
	var lane_height := layout.get_zone_height()
	var depth := PitchView.get_split_depth(slot)
	var point := Vector2(slot.x * field.x, field.y - (slot.lane - 1) * lane_height - depth * lane_height)
	var formation_cell := Vector2i(slot.lane, engine.rules.get_channel(slot.x))
	var cell := player.get_base_cell() + player.shift
	if cell != formation_cell:
		point.y -= (cell.x - formation_cell.x) * lane_height
		if cell.y != formation_cell.y:
			var edges := _channel_edges()
			point.x = (edges[cell.y] + edges[cell.y + 1]) / 2.0 - layout.field.position.x
	if team_index == 1:
		point = field - point
	return point + Vector2(layout.field.position)


func get_team_index(player: MatchPlayer) -> int:
	return 0 if engine.teams[0].players.has(player) else 1


## Waga udziału zawodnika w nakładanym zagraniu (1 bez nakładki).
func get_player_weight(player: MatchPlayer) -> float:
	if overlay_card == null:
		return 1.0
	var attacking := get_team_index(player) == overlay_team
	if overlay_card.is_shot and not attacking and player.is_goalkeeper():
		return 1.0
	return PlayContest.get_cell_weight(player.get_cell(attacking), attacking, overlay_origin, overlay_target,
			PlayContest.get_flyover_cells(overlay_origin, overlay_target), engine.rules)


# --- Stan ---

func set_overlay(card: PlayCard, origin: Vector2i, target: Vector2i, attackers_index: int) -> void:
	overlay_card = card
	overlay_origin = origin
	overlay_target = target
	overlay_team = attackers_index
	refresh()


func clear_overlay() -> void:
	overlay_card = null
	overlay_origin = NO_CELL
	overlay_target = NO_CELL
	refresh()


func set_choice_cells(cells: Array[Vector2i], color: Color = CHOICE_COLOR) -> void:
	choice_cells = cells
	choice_color = color
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


## Żetony na pozycje (z animacją przesunięcia), energia, przyciemnienie zawodników bez udziału w akcji.
## Po rzucie zawodnicy z kośćmi są plakietkami (DicePlate), a pozostali – znacznikami w kolorze drużyny.
func refresh(animate := true) -> void:
	if engine == null or not is_node_ready():
		return
	for team_index in 2:
		for player in engine.teams[team_index].players:
			var token: PlayerToken = _tokens.get(player)
			if token == null:
				token = PlayerToken.new()
				token.interactive = false
				token.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_tokens_root.add_child(token)
				_tokens[player] = token
			var kit: Array = kits[team_index][1 if player.is_goalkeeper() else 0]
			token.setup(player.data, player.role_id, kit[0], kit[1])
			token.energy = player.energy
			token.max_energy = player.max_energy
			var dice_colors: Array[Color] = []
			for die in player.dice:
				dice_colors.append(DieGraphics.FACE_COLORS.get(die.type.id, die.type.color))
			token.dice_colors = dice_colors
			token.selected = player == selected_player
			token.highlighted = selectable_players.has(player)
			token.modulate.a = 1.0 if get_player_weight(player) > 0.0 else NON_PARTICIPANT_ALPHA
			token.visible = not _dice_phase
			token.queue_redraw()
			var target_position := (get_player_point(player, team_index) - token.get_anchor_offset()).round()
			if animate and token.position != target_position and token.position != Vector2.ZERO:
				create_tween().tween_property(token, "position", target_position, MOVE_TIME)
			else:
				token.position = target_position
	_layout_plates(animate)
	queue_redraw()


# --- Plakietki z kośćmi ---

## Tworzy plakietki zawodników z kośćmi akcji (ukryte do lądowania kości).
func create_dice(contest: PlayContest) -> void:
	clear_dice()
	for attacking: bool in [true, false]:
		for contest_die in contest.get_dice(attacking):
			var player := contest_die.player
			var plate: DicePlate = _plates.get(player)
			if plate == null:
				var team_index := get_team_index(player)
				var team := engine.teams[team_index].lineup.team
				plate = DicePlate.create(player, team.primary_color, team.secondary_color)
				plate.exhausted_efficiency = engine.rules.exhausted_efficiency
				plate.name_pressed.connect(func(p: MatchPlayer) -> void: player_profile_requested.emit(p))
				plate.visible = false
				_dice_root.add_child(plate)
				_plates[player] = plate
			var match_die := MatchDie.create_for(contest_die, MatchDie.DieSize.LARGE)
			match_die.visible = false
			match_die.pressed.connect(func(d: MatchDie) -> void: die_clicked.emit(d))
			plate.add_die(match_die)
			_dice[contest_die] = match_die


## Koniec akcji: plakietki znikają, wracają koszulki.
func clear_dice() -> void:
	for plate: DicePlate in _plates.values():
		plate.queue_free()
	_plates.clear()
	_dice.clear()
	_dice_phase = false
	refresh(false)


func get_die_view(contest_die: PlayContest.ContestDie) -> MatchDie:
	return _dice.get(contest_die)


func get_die_views() -> Array[MatchDie]:
	var result: Array[MatchDie] = []
	result.assign(_dice.values())
	return result


## Plakietki stają w miejscu koszulek zawodników (w polu, w którym zawodnik stoi teraz – także po
## przesunięciu), a nachodzące na siebie są rozsuwane.
func _layout_plates(animate: bool) -> void:
	if _plates.is_empty():
		return
	var players: Array = _plates.keys()
	var rects: Array[Rect2] = []
	for player: MatchPlayer in players:
		var plate: DicePlate = _plates[player]
		var point := get_player_point(player, get_team_index(player))
		rects.append(Rect2(point - plate.get_anchor_offset(), plate.size))
	_separate(rects)
	for i in players.size():
		var plate: DicePlate = _plates[players[i]]
		var target := rects[i].position.round()
		if animate and plate.visible and plate.position != target:
			create_tween().tween_property(plate, "position", target, MOVE_TIME)
		else:
			plate.position = target


## Rozsuwa nachodzące prostokąty (po osi mniejszego nałożenia), w granicach boiska.
func _separate(rects: Array[Rect2]) -> void:
	var bounds := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	for iteration in PLATE_LAYOUT_ITERATIONS:
		var moved := false
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				var a := rects[i].grow(PLATE_GAP / 2.0)
				var b := rects[j].grow(PLATE_GAP / 2.0)
				if not a.intersects(b):
					continue
				moved = true
				var overlap := Vector2(minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x),
						minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y))
				var direction := signf(b.get_center().x - a.get_center().x) if overlap.x < overlap.y \
						else signf(b.get_center().y - a.get_center().y)
				if direction == 0.0:
					direction = 1.0
				var push := Vector2(overlap.x / 2.0 * direction, 0.0) if overlap.x < overlap.y \
						else Vector2(0.0, overlap.y / 2.0 * direction)
				rects[i].position -= push
				rects[j].position += push
		for i in rects.size():
			rects[i].position = rects[i].position.clamp(bounds.position, bounds.end - rects[i].size)
		if not moved:
			break


## Kości wylądowały: zawodnicy z kośćmi zamieniają się w plakietki, pozostali w znaczniki.
func _show_plates() -> void:
	_dice_phase = true
	for plate: DicePlate in _plates.values():
		plate.visible = true
	refresh(false)


## Rzut: kości koziołkują po boisku wokół pola akcji, lądują, a potem lecą na plakietki zawodników.
func animate_roll(dice: Array[PlayContest.ContestDie], screen_cell: Vector2i) -> void:
	var center := get_cell_rect(screen_cell).get_center()
	var views: Array[DieRollView] = []
	var tween := create_tween().set_parallel(true)
	for contest_die in dice:
		var view := DieRollView.new()
		_fx_root.add_child(view)
		var start := center + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		var land := start + Vector2(randf_range(-90.0, 90.0), randf_range(-70.0, 70.0))
		land = land.clamp(Vector2(layout.field.position), Vector2(layout.field.end) - DieRollView.FRAME_SIZE)
		view.position = start - DieRollView.FRAME_SIZE / 2.0
		view.spin_time = randf_range(0.6, 0.9)
		view.roll(contest_die.die, contest_die.face)
		tween.tween_property(view, "position", land, view.spin_time + 0.15) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		views.append(view)
	await tween.finished
	await get_tree().create_timer(0.45).timeout
	_show_plates()
	var fly := create_tween().set_parallel(true)
	for i in dice.size():
		var match_die := get_die_view(dice[i])
		var target := match_die.get_global_rect().position - global_position - DieRollView.FACE_OFFSET
		fly.tween_property(views[i], "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await fly.finished
	for i in dice.size():
		views[i].queue_free()
		var match_die := get_die_view(dice[i])
		match_die.sync_face()
		match_die.visible = true
	for plate: DicePlate in _plates.values():
		plate.queue_redraw()


## Przerzut: kość koziołkuje w miejscu i pokazuje nową ściankę.
func animate_reroll(dice: Array[PlayContest.ContestDie]) -> void:
	if dice.is_empty():
		return
	var views: Array[DieRollView] = []
	for contest_die in dice:
		var match_die := get_die_view(contest_die)
		var view := DieRollView.new()
		view.position = match_die.get_global_rect().position - global_position - DieRollView.FACE_OFFSET
		view.spin_time = 0.5
		match_die.visible = false
		_fx_root.add_child(view)
		view.roll(contest_die.die, contest_die.face)
		views.append(view)
	await views.back().finished
	await get_tree().create_timer(0.2).timeout
	for i in dice.size():
		views[i].queue_free()
		var match_die := get_die_view(dice[i])
		match_die.sync_face()
		match_die.visible = true


# --- Wejście ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := get_cell_at(event.position)
		if not choice_cells.has(cell):
			cell = NO_CELL
		if cell != _hover_cell:
			_hover_cell = cell
			queue_redraw()
		var over_player := _get_selectable_player_at(event.position) != null
		_set_hover_name(_get_name_player_at(event.position))
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND \
				if over_player or cell != NO_CELL or _hover_name_player != null else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var player := _get_selectable_player_at(event.position)
		if player != null:
			accept_event()
			player_clicked.emit(player)
			return
		var cell := get_cell_at(event.position)
		if choice_cells.has(cell):
			accept_event()
			cell_clicked.emit(cell)
			return
		var named := _get_name_player_at(event.position)
		if named != null:
			accept_event()
			player_profile_requested.emit(named)


## Zawodnik, którego nazwisko jest pod kursorem (widoczne żetony).
func _get_name_player_at(point: Vector2) -> MatchPlayer:
	for player: MatchPlayer in _tokens:
		var token: PlayerToken = _tokens[player]
		if token.visible and token.get_name_rect().has_point(point - token.position):
			return player
	return null


func _set_hover_name(player: MatchPlayer) -> void:
	if player == _hover_name_player:
		return
	if _hover_name_player != null and _tokens.has(_hover_name_player):
		_tokens[_hover_name_player].name_hovered = false
	_hover_name_player = player
	if player != null:
		_tokens[player].name_hovered = true


## Podpowiedź części żetonu: koszulka – schematy kości zawodnika, pasek – wytrzymałość.
func _get_tooltip(at_position: Vector2) -> String:
	for player: MatchPlayer in _tokens:
		var token: PlayerToken = _tokens[player]
		if not token.visible:
			continue
		var local := at_position - token.position
		if token.get_shirt_rect().has_point(local):
			return "dice:%d" % player.get_instance_id()
		if token.get_energy_rect().grow(2.0).has_point(local):
			return EnergyBar.get_tooltip_text(player.energy, player.max_energy, engine.rules.exhausted_efficiency)
	return ""


func _make_custom_tooltip(for_text: String) -> Object:
	if not for_text.begins_with("dice:"):
		return null
	var player := instance_from_id(for_text.trim_prefix("dice:").to_int()) as MatchPlayer
	if player == null:
		return null
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	var title := Label.new()
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.text = "%d %s" % [player.data.number, player.data.get_full_name()]
	title.add_theme_font_size_override(&"font_size", 14)
	title.add_theme_color_override(&"font_color", UiFrames.get_text_color(Settings.tooltip_style as UiFrames.Style))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	box.add_child(row)
	for die in player.dice:
		row.add_child(DieNetView.make_tooltip(die, DieNetView.get_die_title(die)))
	return box


func _get_selectable_player_at(point: Vector2) -> MatchPlayer:
	for player in selectable_players:
		var token: PlayerToken = _tokens.get(player)
		if token != null and Rect2(token.position, PlayerToken.TOKEN_SIZE).has_point(point):
			return player
	return null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return accepts_returned_dice and data is Dictionary and data.has("contest_die") and data.get("from_slot", false)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	die_returned.emit(data["contest_die"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover_name(null)
		if _hover_cell != NO_CELL:
			_hover_cell = NO_CELL
			queue_redraw()


# --- Rysowanie ---

func _draw() -> void:
	draw_texture(PitchDimmer.get_texture(PitchBuilder.get_texture(layout), Settings.pitch_dim), Vector2.ZERO)
	var separator := PitchOverlays.get_zone_separator(layout.field.size.x)
	for zone in range(1, MatchRules.ZONE_COUNT):
		var top := get_cell_rect(Vector2i(zone, 0)).position.y
		draw_texture(separator, Vector2(layout.field.position.x, top - floorf(separator.get_height() / 2.0)))
	if engine == null:
		return
	if overlay_card != null:
		_draw_overlay()
	if _dice_phase:
		_draw_markers()
	for cell in choice_cells:
		var rect := get_cell_rect(cell).grow(-2.0)
		var fill := choice_color
		fill.a = 0.32 if cell == _hover_cell else 0.16
		draw_rect(rect, fill)
		draw_rect(rect, choice_color, false, 2.0)
	_draw_ball()


func _draw_overlay() -> void:
	var font := get_theme_default_font()
	var flyover := PlayContest.get_flyover_cells(overlay_origin, overlay_target)
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)  # perspektywa atakujących
			var rect := get_cell_rect(to_screen(cell, overlay_team))
			var weight := PlayContest.get_cell_weight(cell, true, overlay_origin, overlay_target, flyover, engine.rules)
			if cell in flyover:
				draw_rect(rect, Color(FLYOVER_COLOR, 0.18))
			elif weight > 0.0:
				draw_rect(rect, Color(HEAT_COLOR, 0.08 + 0.22 * weight))
			if weight > 0.0:
				draw_string(font, rect.position + Vector2(4.0, 14.0), "%d%%" % roundi(weight * 100.0),
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL_COLOR)
	var origin_rect := get_cell_rect(to_screen(overlay_origin, overlay_team)).grow(-1.0)
	_draw_dashed_rect(origin_rect, ORIGIN_BORDER)
	var target_rect := get_cell_rect(to_screen(overlay_target, overlay_team)).grow(-1.0)
	draw_rect(target_rect, TARGET_BORDER, false, 2.0)
	if overlay_origin != overlay_target:
		_draw_arrow(origin_rect.get_center(), target_rect.get_center())


func _draw_arrow(from: Vector2, to: Vector2) -> void:
	var direction := (to - from).normalized()
	var start := from + direction * 20.0
	var tip := to - direction * 24.0
	var normal := Vector2(-direction.y, direction.x)
	var head := PackedVector2Array([tip + direction * 14.0, tip + normal * 9.0, tip - normal * 9.0])
	draw_line(start, tip, ARROW_OUTLINE, 6.0)
	draw_dashed_line(start, tip, TARGET_BORDER, 3.0, 6.0)
	draw_colored_polygon(head, TARGET_BORDER)
	draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[0]]), ARROW_OUTLINE, 1.5)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], color, 2.0, 6.0)


## Zawodnicy bez kości w akcji: kropka w kolorze koszulki w miejscu zawodnika.
func _draw_markers() -> void:
	for team_index in 2:
		for player in engine.teams[team_index].players:
			if _plates.has(player):
				continue
			var kit: Array = kits[team_index][1 if player.is_goalkeeper() else 0]
			var point := get_player_point(player, team_index)
			draw_circle(point, MARKER_RADIUS + 1.0, MARKER_OUTLINE)
			draw_circle(point, MARKER_RADIUS, kit[0])


## Piłka w polu, w którym jest (w rogu pola, żeby nie zasłaniać zawodników).
func _draw_ball() -> void:
	var rect := get_cell_rect(to_screen(engine.ball, engine.possession))
	var center := rect.get_center() + Vector2(0.0, rect.size.y * 0.5 - 12.0)
	draw_circle(center + Vector2(1, 2), 5.0, Color(0, 0, 0, 0.35))
	draw_circle(center, 5.0, Color("#1b241e"))
	draw_circle(center, 4.0, Color.WHITE)

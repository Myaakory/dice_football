class_name SquadRow
extends Button
## Wiersz listy kadry: numer, pozycja, nazwisko, miejsce w składzie i sumy punktów kości.
## Kliknięcie = wybór zawodnika, przeciągnięcie na innego zawodnika = zamiana miejscami.
## Nazwisko działa jak link: podkreśla się pod kursorem, a kliknięcie w nie otwiera kartę zawodnika.
## Najechanie na sumę kości pokazuje tooltip z całą kością (siatka ścianek).

## Upuszczono na ten wiersz przeciąganego zawodnika (z listy lub z boiska).
signal player_dropped(dragged: PlayerData)
## Kliknięto bezpośrednio w nazwisko zawodnika.
signal name_pressed

const ROW_HEIGHT := 26.0
# Kolumny: [x, szerokość] – używane też przez SquadHeader, żeby nagłówki były nad kolumnami.
const COLUMN_NUMBER := Vector2(4.0, 26.0)
const COLUMN_POSITION := Vector2(38.0, 40.0)
const COLUMN_NAME := Vector2(80.0, 140.0)
const COLUMN_PITCH := Vector2(222.0, 42.0)
const COLUMN_DICE := Vector2(266.0, 84.0)
const DIE_CELL_WIDTH := 28.0
const PITCH_TEXT_COLOR := Color("#f0e6a8")
const FONT_SIZE := 14

var player: PlayerData
## Rola na boisku (skrót) albo oznaczenie rezerwowego (R1, R2...).
var pitch_label := ""
var is_starter := false
var active_dice: Array[int] = []
var team_color := Color.WHITE

var _drop_hover := false
var _name_hover := false
## Wciśnięto przycisk myszy nad nazwiskiem – zwolnienie nad nim (bez przeciągania) otwiera kartę.
var _name_press_armed := false


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_player: PlayerData, p_pitch_label: String, p_is_starter: bool, p_active_dice: Array[int], p_team_color: Color) -> void:
	player = p_player
	pitch_label = p_pitch_label
	is_starter = p_is_starter
	active_dice = p_active_dice
	team_color = p_team_color
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_name_hover(_is_over_name(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_over_name(event.position):
			# Przejmujemy kliknięcie w nazwisko (wiersz nie zmienia zaznaczenia), przeciąganie nadal działa.
			_name_press_armed = true
			accept_event()
		elif not event.pressed and _name_press_armed:
			_name_press_armed = false
			accept_event()
			if _is_over_name(event.position) and not get_viewport().gui_is_dragging():
				name_pressed.emit()


## Prostokąt faktycznie narysowanego nazwiska (nie całej kolumny).
func get_name_rect() -> Rect2:
	if player == null:
		return Rect2()
	var font := get_theme_font(&"font")
	var width := minf(font.get_string_size(player.get_short_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x,
			COLUMN_NAME.y)
	return Rect2(COLUMN_NAME.x, 0.0, width, size.y)


func _is_over_name(point: Vector2) -> bool:
	return get_name_rect().grow_individual(2.0, -4.0, 2.0, -4.0).has_point(point)


func _set_name_hover(value: bool) -> void:
	if _name_hover != value:
		_name_hover = value
		queue_redraw()


func _get_die_cell(die_index: int) -> Rect2:
	return Rect2(COLUMN_DICE.x + die_index * DIE_CELL_WIDTH, 4.0, DIE_CELL_WIDTH - 3.0, size.y - 8.0)


## Tekst tooltipa = indeks kości pod kursorem (zmiana kości odświeża tooltip).
func _get_tooltip(at_position: Vector2) -> String:
	if player == null:
		return ""
	for die_index in player.dice.size():
		if _get_die_cell(die_index).grow(1.0).has_point(at_position):
			return str(die_index)
	return ""


func _make_custom_tooltip(for_text: String) -> Object:
	if player == null or not for_text.is_valid_int() or for_text.to_int() >= player.dice.size():
		return null
	var die := player.dice[for_text.to_int()]
	return DieNetView.make_tooltip(die, DieNetView.get_die_title(die))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if player == null:
		return null
	var preview := Label.new()
	preview.text = "%d  %s" % [player.number, player.get_short_name()]
	preview.add_theme_color_override(&"font_shadow_color", Color.BLACK)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return PlayerDrag.create(player)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var dragged := PlayerDrag.get_player(data)
	var can_drop := dragged != null and dragged != player
	_set_drop_hover(can_drop)
	return can_drop


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_hover(false)
	player_dropped.emit(PlayerDrag.get_player(data))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT, NOTIFICATION_DRAG_END:
			_set_drop_hover(false)
			_set_name_hover(false)
			_name_press_armed = false


func _set_drop_hover(value: bool) -> void:
	if _drop_hover != value:
		_drop_hover = value
		queue_redraw()


func _draw() -> void:
	if player == null:
		return
	var font := get_theme_font(&"font")
	var font_size := FONT_SIZE
	var color := get_theme_color(&"font_color")
	var dim_color := Color(color, 0.55)
	var baseline := roundf((size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)

	if _drop_hover:
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), Color.WHITE, false, 2.0)
	if is_starter:
		draw_rect(Rect2(3.0, 3.0, 4.0, size.y - 6.0), team_color)

	_draw_cell(font, str(player.number), COLUMN_NUMBER, baseline, font_size, color, HORIZONTAL_ALIGNMENT_RIGHT)
	var player_position := GameData.get_position(player.position_id)
	if player_position != null:
		_draw_cell(font, tr(player_position.short_key), COLUMN_POSITION, baseline, font_size, dim_color)
	_draw_cell(font, player.get_short_name(), COLUMN_NAME, baseline, font_size, color)
	if _name_hover:
		var name_rect := get_name_rect()
		var underline_y := baseline + 2.0
		draw_line(Vector2(name_rect.position.x, underline_y), Vector2(name_rect.end.x, underline_y), color, 1.0)
	_draw_cell(font, pitch_label, COLUMN_PITCH, baseline, font_size, PITCH_TEXT_COLOR if is_starter else dim_color)

	# Suma punktów każdej kości w jej kolorze; aktywne jasne, nieaktywne wyblakłe.
	for die_index in player.dice.size():
		DieTotalBadge.draw_badge(self, _get_die_cell(die_index), player.dice[die_index], die_index in active_dice,
				font, font_size, baseline)


func _draw_cell(font: Font, text: String, column: Vector2, baseline: float, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, Vector2(column.x, baseline), text, align, column.y, font_size, color)

class_name SquadHeader
extends Control
## Nagłówki kolumn listy kadry – małe przyciski sortowania ustawione nad kolumnami SquadRow.
## Ponowne kliknięcie aktywnego nagłówka odwraca kolejność.

signal sort_requested(mode: SortMode)

enum SortMode { PITCH, NUMBER, POSITION, NAME }

const HEADER_HEIGHT := 22.0
const FONT_SIZE := 11
const ACTIVE_BORDER := Color("#e8d36a")

var _buttons: Dictionary[SortMode, Button] = {}
var _labels: Dictionary[SortMode, String] = {
	SortMode.NUMBER: "SORT_NUMBER",
	SortMode.POSITION: "SORT_POSITION",
	SortMode.NAME: "SORT_NAME",
	SortMode.PITCH: "SORT_PITCH",
}
var _active_mode := SortMode.PITCH
var _descending := false


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEADER_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_add_button(SortMode.NUMBER, SquadRow.COLUMN_NUMBER)
	_add_button(SortMode.POSITION, SquadRow.COLUMN_POSITION)
	_add_button(SortMode.NAME, SquadRow.COLUMN_NAME)
	_add_button(SortMode.PITCH, SquadRow.COLUMN_PITCH)
	var dice_label := Label.new()
	dice_label.text = "SETUP_DICE_HEADER"
	dice_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.modulate.a = 0.6
	dice_label.position = Vector2(SquadRow.COLUMN_DICE.x, 0.0)
	dice_label.size = Vector2(SquadRow.COLUMN_DICE.y, HEADER_HEIGHT)
	add_child(dice_label)
	set_active(_active_mode, _descending)


func set_active(mode: SortMode, descending: bool) -> void:
	_active_mode = mode
	_descending = descending
	if not is_node_ready():
		return
	for button_mode in _buttons:
		var button := _buttons[button_mode]
		var is_active := button_mode == mode
		button.set_pressed_no_signal(is_active)
		var suffix := (" ▼" if descending else " ▲") if is_active else ""
		button.text = tr(_labels[button_mode]) + suffix


func _add_button(mode: SortMode, column: Vector2) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.clip_text = true
	button.add_theme_font_size_override(&"font_size", FONT_SIZE)
	button.add_theme_stylebox_override(&"normal", _make_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.15)))
	button.add_theme_stylebox_override(&"hover", _make_style(Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.35)))
	button.add_theme_stylebox_override(&"pressed", _make_style(Color(0.239, 0.42, 0.278), ACTIVE_BORDER))
	button.add_theme_stylebox_override(&"hover_pressed", _make_style(Color(0.239, 0.42, 0.278), ACTIVE_BORDER))
	button.position = Vector2(column.x, 0.0)
	button.size = Vector2(column.y, HEADER_HEIGHT)
	button.pressed.connect(_on_button_pressed.bind(mode))
	add_child(button)
	_buttons[mode] = button


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(1.0)
	return style


func _on_button_pressed(mode: SortMode) -> void:
	# Stan przycisku ustawia set_active() – kliknięcie jedynie zgłasza prośbę o sortowanie.
	set_active(_active_mode, _descending)
	sort_requested.emit(mode)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		set_active(_active_mode, _descending)

class_name ModalDialog
extends Control
## Okno z pytaniem / komunikatem nad bieżącym ekranem (przyciemnione tło, ramka 9-slice).
## open() pokazuje tytuł, treść i przyciski (klucze tłumaczeń); wybór przychodzi sygnałem `closed`
## (indeks przycisku albo -1 przy Esc).

signal closed(choice: int)

const BODY_WIDTH := 520.0

var _title: Label
var _body: Label
var _buttons: HBoxContainer


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.PITCH, 22.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	panel.add_child(box)
	_title = Label.new()
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_title.add_theme_font_size_override(&"font_size", 22)
	_title.add_theme_color_override(&"font_color", Color("#f0e6a8"))
	box.add_child(_title)
	_body = Label.new()
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	box.add_child(_body)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override(&"separation", 10)
	box.add_child(_buttons)


## title i body to gotowe teksty, buttons – klucze tłumaczeń (pierwszy dostaje fokus).
func open(title: String, body: String, buttons: Array) -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_body.text = body
	_body.visible = not body.is_empty()
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	for i in buttons.size():
		var button := Button.new()
		button.text = buttons[i]
		button.custom_minimum_size = Vector2(120.0, 40.0)
		button.pressed.connect(_finish.bind(i))
		_buttons.add_child(button)
	show()
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(-1)


func _finish(choice: int) -> void:
	hide()
	closed.emit(choice)

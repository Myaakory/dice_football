class_name ToastMessage
extends PanelContainer
## Komunikat na środku ekranu, który sam znika po kilku sekundach (np. "nie można rozpocząć meczu").
## Nie blokuje kliknięć.

const FADE_TIME := 0.2
const DEFAULT_DURATION := 3.5

var _label: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_stylebox_override(&"panel", UiFrames.make_stylebox(UiFrames.Style.GOLD, 18.0))
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	# Zakotwiczony w środku rodzica i rośnie we wszystkie strony – rozmiar wynika z tekstu.
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH


func show_message(text: String, duration := DEFAULT_DURATION) -> void:
	_label.text = text
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	visible = true
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_callback(hide)


func dismiss() -> void:
	if _tween != null:
		_tween.kill()
	hide()

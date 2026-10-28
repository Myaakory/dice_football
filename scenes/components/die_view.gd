class_name DieView
extends Control
## Podgląd kości zawodnika: nazwa typu i 6 ścianek (symbole cechy ułożone jak oczka).
## Kliknięcie zgłasza chęć aktywowania kości. Najechanie na ściankę pokazuje jej opis.

signal pressed

const FACE_SIZE := DieGraphics.FACE_SIZE
const FACE_GAP := 6.0
## Przyciemnienie ścianek nieaktywnej kości.
const INACTIVE_FACE_MODULATE := Color(0.5, 0.52, 0.5)
const PADDING := 8.0
const HEADER_HEIGHT := 22.0
const INACTIVE_BG := Color(0.1, 0.12, 0.11)
const INACTIVE_BORDER := Color(0.3, 0.33, 0.31)

var die: DieData
var active := false


func _init() -> void:
	PixelArt.apply(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_die: DieData, p_active: bool) -> void:
	die = p_die
	active = p_active
	var face_count := die.get_face_count()
	custom_minimum_size = Vector2(
			PADDING * 2.0 + face_count * FACE_SIZE.x + (face_count - 1) * FACE_GAP,
			PADDING * 2.0 + HEADER_HEIGHT + FACE_SIZE.y)
	queue_redraw()


func _get_tooltip(at_position: Vector2) -> String:
	if die == null:
		return ""
	for i in die.get_face_count():
		if Rect2(_get_face_position(i), FACE_SIZE).has_point(at_position):
			return DieNetView.describe_face(die, i)
	return ""


func _get_face_position(face_index: int) -> Vector2:
	return Vector2(PADDING + face_index * (FACE_SIZE.x + FACE_GAP), PADDING + HEADER_HEIGHT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	if die == null:
		return
	var font := get_theme_default_font()
	var base := die.type.color
	var border := base if active else INACTIVE_BORDER

	draw_rect(Rect2(Vector2.ZERO, size), base.darkened(0.65) if active else INACTIVE_BG)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), border, false, 2.0)

	# "Checkbox" + nazwa typu kości
	var box := Rect2(PADDING, PADDING + 3.0, 12.0, 12.0)
	draw_rect(box, border, false, 2.0)
	if active:
		draw_rect(box.grow(-3.0), base.lightened(0.35))
	_draw_text(font, tr(die.type.name_key), Rect2(PADDING + 20.0, PADDING, size.x, 18.0), 14,
			Color.WHITE if active else Color(0.6, 0.63, 0.6), HORIZONTAL_ALIGNMENT_LEFT)

	var face_modulate := Color.WHITE if active else INACTIVE_FACE_MODULATE
	for i in die.get_face_count():
		DieGraphics.draw_face(self, _get_face_position(i), die.type.id, die.get_face_attribute(i), die.get_face_value(i), face_modulate)


func _draw_text(font: Font, text: String, rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var pos := Vector2(rect.position.x, roundf(baseline))
	draw_string(font, pos + Vector2.ONE, text, align, rect.size.x, font_size, Color(0.0, 0.0, 0.0, 0.6))
	draw_string(font, pos, text, align, rect.size.x, font_size, color)

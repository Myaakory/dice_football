class_name DieChip
extends Control
## Kompaktowe podsumowanie kości: dla każdej cechy ikonka + łączna liczba symboli na ściankach.
## Najechanie na wartość pokazuje tooltip z rozłożoną kością i podświetlonymi ściankami tej cechy.

const PADDING := 4.0
const CELL_WIDTH := 34.0
const HEIGHT := 22.0
const FONT_SIZE := 13
const INACTIVE_ALPHA := 0.4

var die: DieData
var active := true
## Cechy kości w kolejności ścianek (bez powtórzeń).
var _attributes: Array[StringName] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_die: DieData, p_active := true) -> void:
	die = p_die
	active = p_active
	_attributes.clear()
	for i in die.get_face_count():
		var attribute := die.get_face_attribute(i)
		if attribute not in _attributes:
			_attributes.append(attribute)
	custom_minimum_size = Vector2(PADDING * 2.0 + _attributes.size() * CELL_WIDTH, HEIGHT)
	queue_redraw()


## Tekst tooltipa = id cechy pod kursorem (zmiana cechy odświeża tooltip).
func _get_tooltip(at_position: Vector2) -> String:
	if die == null or _attributes.is_empty():
		return ""
	var index := clampi(int((at_position.x - PADDING) / CELL_WIDTH), 0, _attributes.size() - 1)
	return String(_attributes[index])


func _make_custom_tooltip(for_text: String) -> Object:
	if die == null:
		return null
	var attribute := GameData.get_attribute(StringName(for_text))
	var attribute_name := tr(attribute.name_key) if attribute != null else for_text
	var title := "%s  ·  %s %d" % [tr(die.type.name_key), attribute_name, die.get_attribute_total(StringName(for_text))]
	return DieNetView.make_tooltip(die, title, StringName(for_text))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	if die == null:
		return
	var base := die.type.color
	var alpha := 1.0 if active else INACTIVE_ALPHA
	draw_rect(Rect2(Vector2.ZERO, size), Color(base.darkened(0.6), alpha))
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color(base, alpha), false, 1.0)
	var font := get_theme_default_font()
	var baseline := roundf((size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2.0)
	var icon_y := roundf((size.y - DieGraphics.ICON_SIZE.y) / 2.0)
	for i in _attributes.size():
		var x := PADDING + i * CELL_WIDTH
		# kafelek w kolorze kości – ciemne ikonki znikałyby na przyciemnionym tle
		draw_rect(Rect2(x - 1.0, icon_y - 1.0, DieGraphics.ICON_CELL, DieGraphics.ICON_CELL), Color(base, alpha))
		DieGraphics.draw_attribute_icon(self, Vector2(x, icon_y), _attributes[i], Color(1, 1, 1, alpha))
		draw_string(font, Vector2(x + DieGraphics.ICON_SIZE.x + 2.0, baseline), str(die.get_attribute_total(_attributes[i])),
				HORIZONTAL_ALIGNMENT_LEFT, CELL_WIDTH - DieGraphics.ICON_SIZE.x - 2.0, FONT_SIZE,
				Color(base.lightened(0.6), alpha))

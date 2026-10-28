class_name DieNetView
extends Control
## Rozłożona kość (siatka w kształcie krzyża): wszystkie 6 ścianek naraz.
## Ścianki o tej samej cesze (1-2, 3-4, 5-6) leżą naprzeciw siebie, jak na prawdziwej kości po złożeniu.
## Opcjonalnie podświetla jedną cechę (pozostałe ścianki przyciemnione).
## Z face_tooltips najechanie na ściankę pokazuje jej opis (np. "2 × Podanie"); kliknięcia przechodzą do rodzica.

## Komórka siatki (kolumna, wiersz) dla ścianek 1..6.
const NET_CELLS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 1), Vector2i(3, 1)]
const NET_COLUMNS := 4
const NET_ROWS := 3
const DIM_MODULATE := Color(0.42, 0.44, 0.42)

var die: DieData
## Skala pikselowa (całkowita – grafiki są pixel-art).
var face_scale := 1
var gap := 2.0
var highlight_attribute: StringName = &""
var dimmed := false
var face_tooltips := false:
	set(value):
		face_tooltips = value
		mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Tooltip z całą kością: tytuł + siatka ścianek (używany w liście kadry, panelu strefy itd.).
static func make_tooltip(p_die: DieData, title: String, highlight: StringName = &"") -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = title
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", UiFrames.get_text_color(Settings.tooltip_style as UiFrames.Style))
	box.add_child(label)
	var net := DieNetView.new()
	net.setup(p_die, 1, highlight)
	box.add_child(net)
	return box


## Tytuł tooltipa całej kości: "Kość fizyczna · suma 9".
static func get_die_title(p_die: DieData) -> String:
	return TranslationServer.translate("DIE_TOOLTIP_TITLE") % [TranslationServer.translate(p_die.type.name_key),
			p_die.get_total()]


## Słowny opis ścianki, np. "2 × Podanie".
static func describe_face(p_die: DieData, face_index: int) -> String:
	var attribute := GameData.get_attribute(p_die.get_face_attribute(face_index))
	var attribute_name := String(p_die.get_face_attribute(face_index))
	if attribute != null:
		attribute_name = TranslationServer.translate(attribute.name_key)
	return TranslationServer.translate("DIE_FACE_DESCRIPTION") % [p_die.get_face_value(face_index), attribute_name]


func _get_tooltip(at_position: Vector2) -> String:
	if not face_tooltips or die == null:
		return ""
	var face_size := DieGraphics.FACE_SIZE * face_scale
	for i in mini(die.get_face_count(), NET_CELLS.size()):
		if Rect2(get_face_position(i), face_size).has_point(at_position):
			return describe_face(die, i)
	return ""


func setup(p_die: DieData, p_scale := 1, p_highlight: StringName = &"", p_dimmed := false) -> void:
	die = p_die
	face_scale = p_scale
	highlight_attribute = p_highlight
	dimmed = p_dimmed
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var cell := DieGraphics.FACE_SIZE * face_scale
	return Vector2(NET_COLUMNS * cell.x + (NET_COLUMNS - 1) * gap, NET_ROWS * cell.y + (NET_ROWS - 1) * gap)


## Lewy górny róg ścianki w pikselach kontrolki.
func get_face_position(face_index: int) -> Vector2:
	var cell := NET_CELLS[face_index]
	var face := DieGraphics.FACE_SIZE * face_scale
	return Vector2(cell.x * (face.x + gap), cell.y * (face.y + gap))


func _draw() -> void:
	if die == null:
		return
	for i in mini(die.get_face_count(), NET_CELLS.size()):
		var attribute := die.get_face_attribute(i)
		var modulate := Color.WHITE
		if dimmed or (highlight_attribute != &"" and attribute != highlight_attribute):
			modulate = DIM_MODULATE
		draw_set_transform(get_face_position(i), 0.0, Vector2.ONE * face_scale)
		DieGraphics.draw_face(self, Vector2.ZERO, die.type.id, attribute, die.get_face_value(i), modulate)
	draw_set_transform(Vector2.ZERO)

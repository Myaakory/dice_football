extends RefCounted
## Wspólne elementy makiet ekranu zawodnika (tylko dev): czcionki, etykiety, panele, pas kości, mini-boisko, flaga.
## Czcionki ładowane z systemu/dysku w czasie działania, nic nie trafia do repo – po wyborze wariantu trzeba wybrać
## czcionkę z licencją pozwalającą dołączyć ją do gry (Bahnschrift i Impact jej nie mają).

const BAHN := "C:/Windows/Fonts/bahnschrift.ttf"
const CARLITO := "C:/Windows/Fonts/Carlito-Regular.ttf"
const CARLITO_BOLD := "C:/Windows/Fonts/Carlito-Bold.ttf"
const LATO := "C:/Windows/Fonts/Lato-Regular.ttf"
const LATO_BOLD := "C:/Windows/Fonts/Lato-Bold.ttf"
const IMPACT := "C:/Windows/Fonts/impact.ttf"

const GREEN_DOT := Color("#3fa34d")
const YELLOW_DOT := Color("#d9a826")

static var _fonts: Dictionary = {}


static func font(path: String, weight := 0, width := 0) -> Font:
	var key := "%s|%d|%d" % [path, weight, width]
	if _fonts.has(key):
		return _fonts[key]
	var file := FontFile.new()
	file.load_dynamic_font(path)
	var result: Font = file
	if weight > 0:
		var server := TextServerManager.get_primary_interface()
		var variation := FontVariation.new()
		variation.base_font = file
		variation.variation_opentype = {server.name_to_tag("wght"): weight, server.name_to_tag("wdth"): width}
		result = variation
	_fonts[key] = result
	return result


## Pełnoekranowy korzeń wariantu (absolutny układ 1920×1080 – to makieta).
static func root(color: Color) -> Control:
	var control := Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill(control, Rect2(0, 0, 1920, 1080), color)
	return control


static func fill(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	node.color = color
	parent.add_child(node)
	return node


static func style(color: Color, border := Color.TRANSPARENT, border_width := 0, radius := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box


static func panel(parent: Node, rect: Rect2, box: StyleBox) -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override(&"panel", box)
	parent.add_child(node)
	return node


## Przycinający kontener (np. portret i wielki numer przycięte do bloku).
static func clip(parent: Node, rect: Rect2) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.clip_contents = true
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node


static func text(parent: Node, content: String, pos: Vector2, font_size: int, color: Color, used_font: Font = null,
		width := 0.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = content
	label.position = pos
	if width > 0.0:
		label.size.x = width
	label.horizontal_alignment = align
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	if used_font != null:
		label.add_theme_font_override(&"font", used_font)
	parent.add_child(label)
	return label


static func button(parent: Node, content: String, rect: Rect2, normal: StyleBox, hover: StyleBox, color: Color,
		used_font: Font, font_size: int, action: Callable) -> Button:
	var node := Button.new()
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	node.text = content
	node.position = rect.position
	node.size = rect.size
	for state: StringName in [&"normal", &"pressed", &"focus"]:
		node.add_theme_stylebox_override(state, normal)
	node.add_theme_stylebox_override(&"hover", hover)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		node.add_theme_color_override(state, color)
	node.add_theme_font_override(&"font", used_font)
	node.add_theme_font_size_override(&"font_size", font_size)
	node.pressed.connect(action)
	parent.add_child(node)
	return node


## Portret 64 px w całkowitym powiększeniu (przezroczyste tło, więc może stać na dowolnym bloku).
static func portrait(parent: Node, ctx: Dictionary, pos: Vector2, scale: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = PortraitComposer.get_player_texture(ctx.player, ctx.team, PortraitComposer.CARD_SIZE, scale)
	rect.position = pos
	rect.size = Vector2.ONE * PortraitComposer.CARD_SIZE * scale
	PixelArt.apply(rect)
	parent.add_child(rect)
	return rect


static func clickable(control: Control, ctx: Dictionary, die_index: int) -> void:
	if ctx.read_only:
		return
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			ctx.lineup.activate_die.call_deferred(ctx.player, die_index))


# --- Dane ---

static func position_name(ctx: Dictionary) -> String:
	var data := GameData.get_position(ctx.player.position_id)
	return tr_key(data.name_key) if data != null else String(ctx.player.position_id)


static func lineup_text(ctx: Dictionary) -> String:
	var slot_index: int = ctx.lineup.get_player_slot(ctx.player)
	if slot_index == -1:
		return tr_key("PLAYER_LINEUP_BENCH") % (ctx.lineup.get_bench_index(ctx.player) + 1)
	var slot: FormationSlot = ctx.lineup.tactic.slots[slot_index]
	var role := GameData.get_role(slot.role_id)
	return tr_key("PLAYER_LINEUP_STARTER") % [tr_key(role.name_key) if role != null else "?", slot.lane]


static func dice_power(ctx: Dictionary) -> int:
	var total := 0
	for die: DieData in ctx.lineup.get_active_dice(ctx.player):
		total += die.get_total()
	return total


## Cechy kości w kolejności ścianek: [{id, name, total}].
static func die_attributes(die: DieData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(0, die.get_face_count(), 2):
		var attribute_id := die.get_face_attribute(i)
		var attribute := GameData.get_attribute(attribute_id)
		result.append({"id": attribute_id, "name": tr_key(attribute.name_key) if attribute != null else String(attribute_id),
				"total": die.get_attribute_total(attribute_id)})
	return result


static func role_shorts(ctx: Dictionary, roles: Array[StringName]) -> PackedStringArray:
	var names := PackedStringArray()
	for role_id in roles:
		var role := GameData.get_role(role_id)
		names.append(tr_key(role.name_key) if role != null else String(role_id))
	return names


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


# --- Widżety ---

## Kość w jednym rzędzie: trzy pary ścianek tej samej cechy (czytelniej niż krzyż, gdy liczą się sumy cech).
class DieStrip extends Control:
	const FACE := 52

	var die: DieData
	var face_scale := 1
	var dimmed := false
	var face_gap := 2
	var pair_gap := 12

	func _init(p_die: DieData, p_scale := 1, p_dimmed := false, p_pair_gap := 12) -> void:
		die = p_die
		face_scale = p_scale
		dimmed = p_dimmed
		pair_gap = p_pair_gap
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelArt.apply(self)
		size = get_strip_size()

	func get_strip_size() -> Vector2:
		var cell := FACE * face_scale
		return Vector2(6 * cell + 3 * face_gap + 2 * pair_gap, cell)

	## Lewy brzeg pary cech (0–2) względem kontrolki.
	func get_pair_x(pair: int) -> int:
		return pair * (2 * FACE * face_scale + face_gap + pair_gap)

	func _get_minimum_size() -> Vector2:
		return get_strip_size()

	func _draw() -> void:
		var modulate_color := Color(0.42, 0.44, 0.42) if dimmed else Color.WHITE
		for i in die.get_face_count():
			var x := get_pair_x(i / 2) + (i % 2) * (FACE * face_scale + face_gap)
			draw_set_transform(Vector2(x, 0), 0.0, Vector2.ONE * face_scale)
			DieGraphics.draw_face(self, Vector2.ZERO, die.type.id, die.get_face_attribute(i), die.get_face_value(i),
					modulate_color)
		draw_set_transform(Vector2.ZERO)


## Boisko o dowolnym rozmiarze z plakietkami ról (poziomo: atak w prawo), z kolorami danego wariantu.
class MiniPitch extends Control:
	var player: PlayerData
	var horizontal := false
	var stripes: Array[Color] = [Color8(119, 145, 92), Color8(106, 117, 89)]
	var line := Color(1, 1, 1, 0.6)
	var empty_dot := Color(0.06, 0.09, 0.07, 0.75)
	var label_font: Font
	var font_size := 12

	func _init(p_player: PlayerData, rect: Rect2, p_horizontal := false) -> void:
		player = p_player
		horizontal = p_horizontal
		position = rect.position
		size = rect.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _role_point(role_id: StringName) -> Vector2:
		var point: Vector2 = PositionMap.get_role_points()[role_id]
		if horizontal:
			point = Vector2(1.0 - point.y, point.x)
		return (Vector2(10, 10) + point * (size - Vector2(20, 20))).round()

	func _draw() -> void:
		var count := 10
		for i in count:
			var rect := Rect2(i * size.x / count, 0, size.x / count, size.y) if horizontal \
					else Rect2(0, i * size.y / count, size.x, size.y / count)
			draw_rect(rect, stripes[i % 2])
		var field := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_rect(field, line, false, 1.0)
		var center := size / 2.0
		if horizontal:
			draw_line(Vector2(center.x, 4), Vector2(center.x, size.y - 4), line)
		else:
			draw_line(Vector2(4, center.y), Vector2(size.x - 4, center.y), line)
		draw_arc(center, minf(size.x, size.y) * 0.14, 0.0, TAU, 32, line)
		var box := Vector2(size.x * 0.14, size.y * 0.56) if horizontal else Vector2(size.x * 0.56, size.y * 0.14)
		for far: bool in [false, true]:
			var pos := Vector2(4, center.y - box.y / 2.0) if horizontal else Vector2(center.x - box.x / 2.0, 4)
			if far and horizontal:
				pos.x = size.x - 4 - box.x
			elif far:
				pos.y = size.y - 4 - box.y
			draw_rect(Rect2(pos, box), line, false, 1.0)
		var used_font := label_font if label_font != null else get_theme_default_font()
		for role_id in PositionMap.get_role_points():
			var fit := player.get_role_fit(role_id)
			var at := _role_point(role_id)
			if fit == PlayerData.RoleFit.NONE:
				draw_circle(at, 4.0, empty_dot)
				draw_circle(at, 4.0, Color(1, 1, 1, 0.25), false, 1.0)
				continue
			var color: Color = GREEN_DOT if fit == PlayerData.RoleFit.NATURAL else YELLOW_DOT
			var rect := Rect2(at - Vector2(17, 10), Vector2(34, 20))
			draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.4))
			draw_rect(rect, color)
			var role := GameData.get_role(role_id)
			var short: String = TranslationServer.translate(role.short_key) if role != null else ""
			var baseline := roundf(at.y + (used_font.get_ascent(font_size) - used_font.get_descent(font_size)) / 2.0)
			draw_string(used_font, Vector2(rect.position.x, baseline), short, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x,
					font_size, Color.WHITE if fit == PlayerData.RoleFit.NATURAL else Color("#3a2a05"))


## Flaga z pasów (tylko flagi zawodników z makiety; docelowo arkusz flag pixel art).
class FlagView extends Control:
	const WIDTH := 16
	const HEIGHT := 10
	## poziome = pasy od góry, pionowe = pasy od lewej.
	const FLAGS := {
		&"POL": [false, ["#f4f1ea", "#d0282e"]],
		&"GER": [false, ["#1b1b1f", "#c9242b", "#f2c230"]],
		&"NGA": [true, ["#1d8a4e", "#f4f1ea", "#1d8a4e"]],
		&"SWE": [false, ["#1f5fa8", "#f2c230", "#1f5fa8"]],
		&"ARG": [false, ["#74acdf", "#f4f1ea", "#74acdf"]],
	}

	var code: StringName
	var pixel := 2

	func _init(p_code: StringName, pos: Vector2, p_pixel := 2) -> void:
		code = p_code
		pixel = p_pixel
		position = pos
		size = Vector2(WIDTH, HEIGHT) * pixel
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var flag: Array = FLAGS.get(code, [false, ["#888888"]])
		var bands: Array = flag[1]
		for i in bands.size():
			var rect := Rect2(i * size.x / bands.size(), 0, size.x / bands.size(), size.y) if flag[0] \
					else Rect2(0, i * size.y / bands.size(), size.x, size.y / bands.size())
			draw_rect(rect, Color(bands[i]))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), false, 1.0)

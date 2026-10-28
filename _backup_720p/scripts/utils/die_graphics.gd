class_name DieGraphics
extends RefCounted
## Rysowanie ścianek kości z grafik (grafiki_brudnopis/dice*.aseprite → assets/graphics/dice).
## Ścianka 40x40: korpus w kolorze typu kości + symbole cech ułożone jak oczka (1..5).
## 6 = jedna ikonka powiększona x2 + złota obwódka (tylko ścianka z jedną cechą).
## Ikonki cech (die_icons.png + maski) składa grafiki_brudnopis/propozycje_ikon/system_jasnosci/build_final.py:
## w każdej kości jedna ikonka jasna, jedna ciemna i jedna w kolorze sygnaturowym kości. Poza ścianką
## (lista, podsumowanie) rysuj ikonkę na kafelku w kolorze kości, bo ciemna ikonka znika na ciemnym tle.

const FACE_SIZE := Vector2(40, 40)
const ICON_SIZE := Vector2(14, 14)
## Komórka w arkuszach ikon i masek (ikonka 14x14 w lewym górnym rogu, maska 16x16).
const ICON_CELL := 16
const MAX_VALUE := 6
const MAX_MIXED_VALUE := 5

const BODIES: Texture2D = preload("res://assets/graphics/dice/die_bodies.png")
const ICONS: Texture2D = preload("res://assets/graphics/dice/die_icons.png")
const ICON_MASKS: Texture2D = preload("res://assets/graphics/dice/die_icon_masks.png")
const MAX_RIM: Texture2D = preload("res://assets/graphics/dice/die_max_rim.png")

## Kolejność typów w die_bodies.png / die_roll_*.png i cech w die_icons.png.
const TYPE_ORDER: Array[StringName] = [&"physical", &"technical", &"defensive"]
const ATTRIBUTE_ORDER: Array[StringName] = [
	&"strength", &"speed", &"jump", &"pass", &"shot", &"control", &"tackle", &"pressing", &"reading"]
## Kolor ściany każdego typu – "wycięcie" wokół ikonek nachodzących na inne.
const FACE_COLORS := {
	&"physical": Color("#c8553d"),
	&"technical": Color("#3d7cc8"),
	&"defensive": Color("#c99a1e"),
}
const ICON_SHADOW := Color(0.08, 0.04, 0.08, 0.47)

## Pozycje ikonek (lewy górny róg) dla 1..5 symboli; kolejność = kolejność wypełniania.
const CENTER_5 := Vector2(13, 11)
const LAYOUTS := {
	1: [Vector2(13, 11)],
	2: [Vector2(4, 3), Vector2(22, 18)],
	3: [Vector2(5, 4), Vector2(20, 4), Vector2(12, 16)],
	4: [Vector2(5, 4), Vector2(20, 4), Vector2(5, 17), Vector2(20, 17)],
	5: [Vector2(3, 2), Vector2(22, 2), Vector2(3, 19), Vector2(22, 19), CENTER_5],
}
## 5 symboli bez pojedynczej grupy (np. 3+2): środek dostaje grupa większościowa.
const LAYOUT_5_PAIRED: Array[Vector2] = [Vector2(3, 2), Vector2(22, 2), CENTER_5, Vector2(3, 19), Vector2(22, 19)]
const SIX_POSITION := Vector2(6, 4)


## Rysuje ściankę z jedną cechą (attribute_id × value).
static func draw_face(canvas: CanvasItem, pos: Vector2, type_id: StringName, attribute_id: StringName,
		value: int, modulate := Color.WHITE) -> void:
	draw_mixed_face(canvas, pos, type_id, [[attribute_id, value]], modulate)


## Rysuje ściankę z kilkoma cechami jednej kategorii: groups = [[attribute_id, liczba], ...].
static func draw_mixed_face(canvas: CanvasItem, pos: Vector2, type_id: StringName, groups: Array,
		modulate := Color.WHITE) -> void:
	draw_body(canvas, pos, type_id, modulate)
	var total := 0
	for group: Array in groups:
		total += int(group[1])
	if total <= 0:
		return
	if groups.size() == 1 and total >= MAX_VALUE:
		_draw_six(canvas, pos, groups[0][0], modulate)
		return
	var face_color: Color = FACE_COLORS.get(type_id, Color.BLACK) * modulate
	var placed := _arrange(groups, mini(total, MAX_MIXED_VALUE))
	for item: Array in placed:
		var icon_pos: Vector2 = pos + item[1]
		var index: int = item[0]
		# "wycięcie" w kolorze ściany przy wielu symbolach (oddziela od wcześniej narysowanych), cień, ikonka.
		# Wycięcie musi być pod cieniem – inaczej zakrywa go i zamiast cienia zostaje obwódka w kolorze kości.
		if placed.size() > 1:
			canvas.draw_texture_rect_region(ICON_MASKS, Rect2(icon_pos - Vector2.ONE, Vector2(ICON_CELL, ICON_CELL)),
					_mask_region(index), face_color)
		canvas.draw_texture_rect_region(ICON_MASKS, Rect2(icon_pos, Vector2(ICON_CELL, ICON_CELL)),
				_mask_region(index), ICON_SHADOW * modulate)
		canvas.draw_texture_rect_region(ICONS, Rect2(icon_pos, ICON_SIZE), _icon_region(index), modulate)


## Sam korpus kości (pusta ścianka) – np. ostatnia klatka animacji rzutu.
static func draw_body(canvas: CanvasItem, pos: Vector2, type_id: StringName, modulate := Color.WHITE) -> void:
	var type_index := maxi(TYPE_ORDER.find(type_id), 0)
	canvas.draw_texture_rect_region(BODIES, Rect2(pos, FACE_SIZE),
			Rect2(Vector2(type_index * FACE_SIZE.x, 0.0), FACE_SIZE), modulate)


## Pojedyncza ikonka cechy 14x14 z cieniem (np. w podsumowaniach kości).
static func draw_attribute_icon(canvas: CanvasItem, pos: Vector2, attribute_id: StringName, modulate := Color.WHITE) -> void:
	var index := ATTRIBUTE_ORDER.find(attribute_id)
	if index == -1:
		return
	canvas.draw_texture_rect_region(ICON_MASKS, Rect2(pos, Vector2(ICON_CELL, ICON_CELL)), _mask_region(index),
			ICON_SHADOW * modulate)
	canvas.draw_texture_rect_region(ICONS, Rect2(pos, ICON_SIZE), _icon_region(index), modulate)


## Ikonka cechy na kafelku 16x16 w kolorze kości (np. do OptionButton / ItemList).
static func make_attribute_icon(attribute_id: StringName, type_id: StringName) -> Texture2D:
	var image := Image.create_empty(ICON_CELL, ICON_CELL, false, Image.FORMAT_RGBA8)
	image.fill(FACE_COLORS.get(type_id, Color.BLACK))
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(ICON_CELL - 1, 0), Vector2i(0, ICON_CELL - 1),
			Vector2i(ICON_CELL - 1, ICON_CELL - 1)]:
		image.set_pixelv(corner, Color.TRANSPARENT)
	var index := ATTRIBUTE_ORDER.find(attribute_id)
	if index != -1:
		var icons := ICONS.get_image()
		icons.convert(Image.FORMAT_RGBA8)
		image.blend_rect(icons, Rect2i(_icon_region(index)), Vector2i.ONE)
	return ImageTexture.create_from_image(image)


static func _draw_six(canvas: CanvasItem, pos: Vector2, attribute_id: StringName, modulate: Color) -> void:
	canvas.draw_texture(MAX_RIM, pos, modulate)
	var index := ATTRIBUTE_ORDER.find(attribute_id)
	if index == -1:
		return
	var rect := Rect2(pos + SIX_POSITION, ICON_SIZE * 2.0)
	canvas.draw_texture_rect_region(ICONS, Rect2(rect.position + Vector2(2, 2), rect.size), _icon_region(index),
			ICON_SHADOW * modulate)
	canvas.draw_texture_rect_region(ICONS, rect, _icon_region(index), modulate)


## Zwraca [[indeks_ikonki, pozycja], ...] w kolejności rysowania. Ta sama cecha trafia obok siebie,
## grupy od najliczniejszej; środek przy 5 symbolach rysowany na końcu (nachodzi na rogi).
static func _arrange(groups: Array, total: int) -> Array:
	var sorted := groups.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var positions: Array = LAYOUTS[total]
	if total == 5 and sorted.all(func(g: Array) -> bool: return int(g[1]) != 1):
		positions = LAYOUT_5_PAIRED
	var placed: Array = []
	for group: Array in sorted:
		var index := ATTRIBUTE_ORDER.find(StringName(group[0]))
		for i in int(group[1]):
			if placed.size() >= total:
				break
			placed.append([index, positions[placed.size()]])
	placed = placed.filter(func(item: Array) -> bool: return item[0] != -1)
	for i in placed.size():
		if placed[i][1] == CENTER_5:
			placed.append(placed.pop_at(i))
			break
	return placed


static func _icon_region(index: int) -> Rect2:
	return Rect2(Vector2(index * ICON_CELL, 0.0), ICON_SIZE)


static func _mask_region(index: int) -> Rect2:
	return Rect2(Vector2(index * ICON_CELL, 0.0), Vector2(ICON_CELL, ICON_CELL))

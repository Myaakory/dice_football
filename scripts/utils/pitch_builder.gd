class_name PitchBuilder
extends RefCounted
## Składa grafikę boiska dla układu PitchLayout:
## - murawa: jedna bezszwowa trawa 128 × 128 (parts/grass.png) kładziona na całą grafikę od lewego górnego rogu;
##   pasy to filtr – maska wzoru (GrassPattern) wybiera piksele, które dostają ciemniejszy kolor (DARK_GRASS),
##   więc kształt pasów nie zależy od kafelków (w grze: pasy pod strefy; gotowe też inne wzory),
## - linie: proste rysowane tutaj, krzywe (rogi, łuki pól karnych, koło środkowe, punkty karne) z elementów
##   w assets/graphics/pitch/parts (wycina je tools/cut_pitch_parts.py z grafiki_brudnopis/pitch.aseprite);
##   cała warstwa linii z kryciem LINE_OPACITY (jak warstwa Lines w Aseprite),
## - bramki z cieniem.
## Elementy mają kotwicę na polu gry i przesunięcie (pieces.json), więc pasują do każdego rozmiaru pola gry.
## Gotowe tekstury są trzymane w cache (jedna na układ i wzór pasów).

## Wzór pasów murawy (w grze ZONES; pozostałe na przyszłość, np. różne stadiony).
enum GrassPattern {
	## 2 pasy na strefę taktyczną; za liniami końcowymi kolor pasa przy linii końcowej.
	ZONES,
	## Granice pasów na liniach pól bramkowych, między nimi nieparzysta liczba równych pasów (symetrycznie
	## względem linii środkowej); od pola bramkowego do krawędzi grafiki jeden pas.
	GOAL_AREAS,
	## Pierścienie wokół środka boiska, szerokości pasa.
	RINGS,
}

const PARTS_DIR := "res://assets/graphics/pitch/parts/"
const PIECES_PATH := PARTS_DIR + "pieces.json"
## Ciemny pas: kolory jasnej trawy -> kolory ciemnego pasa z pitch.aseprite. Kolor spoza mapy dostaje te same
## średnie proporcje: jasność ×0,814, nasycenie ×0,67, odcień -0,013 (lekko w stronę żółci).
const DARK_GRASS := {
	Color8(131, 154, 94): Color8(115, 125, 92),
	Color8(119, 145, 92): Color8(106, 117, 89),
	Color8(150, 159, 100): Color8(128, 131, 98),
}
const DARK_VALUE := 0.814
const DARK_SATURATION := 0.67
const DARK_HUE_SHIFT := -0.013
const LINE_COLOR := Color8(245, 247, 250)
const LINE_OPACITY := 179
const LINE_WIDTH := 2
## Pole karne i pole bramkowe: szerokość × głębokość od linii końcowej (z liniami).
const PENALTY_BOX := Vector2i(254, 100)
const GOAL_BOX := Vector2i(104, 35)

static var _textures: Dictionary = {}  # [PitchLayout, GrassPattern] -> ImageTexture
static var _grass: Dictionary = {}  # false (jasna) / true (ciemna) -> Image 128 × 128
static var _pieces: Dictionary = {}  # nazwa -> {"image", "anchor", "offset", "layer"}


static func get_texture(layout: PitchLayout, pattern: GrassPattern = GrassPattern.ZONES) -> Texture2D:
	var key := [layout, pattern]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(build_image(layout, pattern))
	return _textures[key]


static func build_image(layout: PitchLayout, pattern: GrassPattern = GrassPattern.ZONES) -> Image:
	_load_parts()
	var image := _tile_grass(_grass[false], layout.size)
	var dark := _tile_grass(_grass[true], layout.size)
	var mask := _build_stripe_mask(layout, pattern)
	image.blit_rect_mask(dark, mask, Rect2i(Vector2i.ZERO, layout.size), Vector2i.ZERO)
	var lines := Image.create_empty(layout.size.x, layout.size.y, false, Image.FORMAT_RGBA8)
	_draw_lines(lines, layout)
	image.blend_rect(lines, Rect2i(Vector2i.ZERO, layout.size), Vector2i.ZERO)
	_draw_pieces(image, layout, "goals", false)
	return image


# --- Murawa ---

static func _tile_grass(tile: Image, image_size: Vector2i) -> Image:
	var image := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	var tile_size := tile.get_size()
	for y in range(0, image_size.y, tile_size.y):
		for x in range(0, image_size.x, tile_size.x):
			image.blit_rect(tile, Rect2i(Vector2i.ZERO, tile_size), Vector2i(x, y))
	return image


## Filtr ciemnego pasa dla trawy (piksel po pikselu – raz na całą teksturę 128 × 128).
static func _darken_grass(tile: Image) -> Image:
	var dark := tile.duplicate() as Image
	for y in dark.get_height():
		for x in dark.get_width():
			var color := dark.get_pixel(x, y)
			var opaque := Color(color, 1.0)
			if DARK_GRASS.has(opaque):
				dark.set_pixel(x, y, Color(DARK_GRASS[opaque], color.a))
			else:
				dark.set_pixel(x, y, Color.from_hsv(fposmod(color.h + DARK_HUE_SHIFT, 1.0), color.s * DARK_SATURATION,
						color.v * DARK_VALUE, color.a))
	return dark


## Maska ciemnych pasów (nieprzezroczysty piksel = ciemna trawa).
static func _build_stripe_mask(layout: PitchLayout, pattern: GrassPattern) -> Image:
	var mask := Image.create_empty(layout.size.x, layout.size.y, false, Image.FORMAT_RGBA8)
	match pattern:
		GrassPattern.GOAL_AREAS:
			var edges := _goal_area_stripe_edges(layout)
			# Pasy przy bramkach (od krawędzi grafiki do linii pola bramkowego) ciemne, dalej na przemian.
			for i in range(0, edges.size() - 1, 2):
				mask.fill_rect(Rect2i(0, edges[i], layout.size.x, edges[i + 1] - edges[i]), Color.WHITE)
		GrassPattern.RINGS:
			_fill_rings(mask, layout)
		_:
			var y := 0
			while y < layout.size.y:
				var stripe := layout.get_stripe_index(y)
				var band_end := layout.field.position.y + (stripe + 1) * layout.stripe_height
				if stripe == PitchLayout.STRIPE_COUNT - 1:
					band_end = layout.size.y
				if layout.is_dark_stripe(stripe):
					mask.fill_rect(Rect2i(0, y, layout.size.x, band_end - y), Color.WHITE)
				y = band_end
	return mask


## Granice pasów wzoru GOAL_AREAS: krawędź grafiki, linie pól bramkowych, a między nimi nieparzysta liczba pasów
## (najbliższa wysokości pasa układu), zaokrąglone lustrzanie względem linii środkowej.
static func _goal_area_stripe_edges(layout: PitchLayout) -> Array[int]:
	var top := layout.field.position.y + GOAL_BOX.y
	var bottom := layout.field.end.y - GOAL_BOX.y
	var span := float(bottom - top)
	var count := maxi(1, roundi(span / layout.stripe_height))
	if count % 2 == 0:
		count += 1 if span / layout.stripe_height > count else -1
	var edges: Array[int] = [0]
	for i in count + 1:
		if i * 2 <= count:
			edges.append(top + roundi(i * span / count))
		else:
			edges.append(bottom - roundi((count - i) * span / count))
	edges.append(layout.size.y)
	return edges


## Pierścienie wokół środka pola gry (szerokość = wysokość pasa), co drugi ciemny; wiersz po wierszu odcinkami.
static func _fill_rings(mask: Image, layout: PitchLayout) -> void:
	var center := Vector2(layout.field.get_center())
	var width := float(layout.stripe_height)
	var ring_count := ceili(Vector2(layout.size).length() / width)
	for y in layout.size.y:
		var dy := y + 0.5 - center.y
		for ring in range(1, ring_count, 2):
			var inner := ring * width
			var outer := (ring + 1) * width
			if absf(dy) >= outer:
				continue
			var outer_half := sqrt(outer * outer - dy * dy)
			var inner_half := sqrt(maxf(inner * inner - dy * dy, 0.0))
			for side: float in [-1.0, 1.0]:
				var a := center.x + side * inner_half
				var b := center.x + side * outer_half
				var x0 := clampi(roundi(minf(a, b)), 0, layout.size.x)
				var x1 := clampi(roundi(maxf(a, b)), 0, layout.size.x)
				if x1 > x0:
					mask.fill_rect(Rect2i(x0, y, x1 - x0, 1), Color.WHITE)


# --- Linie ---

## Warstwa linii: wszystkie piksele w jednym kolorze z kryciem LINE_OPACITY (kopiowane, nie mieszane, więc
## nakładające się elementy nie jaśnieją).
static func _draw_lines(lines: Image, layout: PitchLayout) -> void:
	var color := Color(LINE_COLOR, LINE_OPACITY / 255.0)
	var field := layout.field
	var w := LINE_WIDTH
	var rects: Array[Rect2i] = [
		Rect2i(field.position.x, field.position.y, field.size.x, w),
		Rect2i(field.position.x, field.end.y - w, field.size.x, w),
		Rect2i(field.position.x, field.position.y, w, field.size.y),
		Rect2i(field.end.x - w, field.position.y, w, field.size.y),
		Rect2i(field.position.x, field.position.y + field.size.y / 2 - w / 2, field.size.x, w),
	]
	var center_x := field.position.x + field.size.x / 2
	for box in [PENALTY_BOX, GOAL_BOX]:
		var left: int = center_x - box.x / 2
		for top: int in [field.position.y, field.end.y - box.y]:
			rects.append(Rect2i(left, top, w, box.y))
			rects.append(Rect2i(left + box.x - w, top, w, box.y))
		rects.append(Rect2i(left, field.position.y + box.y - w, box.x, w))
		rects.append(Rect2i(left, field.end.y - box.y, box.x, w))
	for rect in rects:
		lines.fill_rect(rect, color)
	_draw_pieces(lines, layout, "lines", true)


static func _draw_pieces(image: Image, layout: PitchLayout, layer: String, copy: bool) -> void:
	var field := layout.field
	for piece: Dictionary in _pieces.values():
		if piece["layer"] != layer:
			continue
		var piece_image: Image = piece["image"]
		var anchor: Vector2 = piece["anchor"]
		var position := field.position + Vector2i((anchor * Vector2(field.size)).round()) + Vector2i(piece["offset"])
		var source := Rect2i(Vector2i.ZERO, piece_image.get_size())
		if copy:
			image.blit_rect_mask(piece_image, piece_image, source, position)
		else:
			image.blend_rect(piece_image, source, position)


# --- Wczytanie elementów ---

static func _load_parts() -> void:
	if not _grass.is_empty():
		return
	var grass := _load_image("grass")
	_grass[false] = grass
	_grass[true] = _darken_grass(grass)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIECES_PATH))
	if not data is Dictionary:
		push_error("PitchBuilder: cannot read %s" % PIECES_PATH)
		return
	for piece_name: String in data:
		var entry: Dictionary = data[piece_name]
		var image := _load_image(piece_name)
		if entry["layer"] == "lines":
			image = _to_line_pixels(image)
		_pieces[piece_name] = {
			"image": image,
			"anchor": Vector2(entry["anchor"][0], entry["anchor"][1]),
			"offset": Vector2(entry["offset"][0], entry["offset"][1]),
			"layer": entry["layer"],
		}


static func _load_image(part_name: String) -> Image:
	var image := (load(PARTS_DIR + part_name + ".png") as Texture2D).get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Element linii w kolorze i kryciu warstwy linii (w pliku jest nieprzezroczysty).
static func _to_line_pixels(image: Image) -> Image:
	var color := Color(LINE_COLOR, LINE_OPACITY / 255.0)
	for y in image.get_height():
		for x in image.get_width():
			image.set_pixel(x, y, color if image.get_pixel(x, y).a > 0.0 else Color(0, 0, 0, 0))
	return image

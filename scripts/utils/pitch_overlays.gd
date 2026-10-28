class_name PitchOverlays
extends RefCounted
## Pikselowe nakładki na boisko liczone pod rozmiar strefy z PitchLayout (dlatego nie są plikami PNG):
## 3 warianty podświetlenia strefy taktycznej i przerywana linia między strefami. Tekstury w cache na rozmiar.

enum ZoneStyle { FRAME, BRACKETS, BAND }

const ZONE_STYLE_NAME_KEYS: Array[String] = ["STYLE_ZONE_FRAME", "STYLE_ZONE_BRACKETS", "STYLE_ZONE_BAND"]
## Wysokość linii między strefami (rysowana wyśrodkowana na granicy stref).
const SEPARATOR_HEIGHT := 3

static var _cache: Dictionary = {}


static func get_zone_highlight(style: int, zone_size: Vector2i) -> Texture2D:
	var key := [&"zone", clampi(style, 0, ZoneStyle.size() - 1), zone_size]
	if not _cache.has(key):
		var image := Image.create_empty(zone_size.x, zone_size.y, false, Image.FORMAT_RGBA8)
		match key[1]:
			ZoneStyle.FRAME:
				_draw_frame(image)
			ZoneStyle.BRACKETS:
				_draw_brackets(image)
			ZoneStyle.BAND:
				_draw_band(image)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## Delikatna przerywana kredowa linia (6 px kreska, 4 px przerwa) z ciemnym cieniem pod spodem.
static func get_zone_separator(width: int) -> Texture2D:
	var key := [&"separator", width]
	if not _cache.has(key):
		var image := Image.create_empty(width, SEPARATOR_HEIGHT, false, Image.FORMAT_RGBA8)
		for x in range(0, width, 10):
			var dash := mini(6, width - x)
			image.fill_rect(Rect2i(x, 0, dash, 1), Color8(255, 255, 255, 40))
			image.fill_rect(Rect2i(x, 1, dash, 1), Color8(255, 255, 255, 95))
			image.fill_rect(Rect2i(x, 2, dash, 1), Color8(0, 0, 0, 45))
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## Wypełnienie + pełna złota ramka 2 px z ciemną linią wewnątrz i kropkami co 8 px („taśma”).
static func _draw_frame(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var gold := Color8(245, 213, 74)
	image.fill(Color8(245, 213, 74, 46))
	_outline(image, Rect2i(0, 0, w, h), gold)
	_outline(image, Rect2i(1, 1, w - 2, h - 2), gold)
	_outline(image, Rect2i(2, 2, w - 4, h - 4), Color8(40, 30, 0, 110))
	for x in range(8, w - 8, 8):
		image.set_pixel(x, 4, Color8(255, 240, 160, 150))
		image.set_pixel(x, h - 5, Color8(255, 240, 160, 150))


## Kreskowanie ukośne + narożniki celownika i znaczniki środka na bocznych krawędziach.
static func _draw_brackets(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	# Wiersz wzoru z okresem 8 px; wiersz y to ten sam wzór przesunięty o y (linie x + y = const).
	var pattern := Image.create_empty(w + 8, 1, false, Image.FORMAT_RGBA8)
	for x in w + 8:
		pattern.set_pixel(x, 0, Color8(255, 255, 255, 34) if x % 8 < 2 else Color8(255, 255, 255, 12))
	for y in h:
		image.blit_rect(pattern, Rect2i(y % 8, 0, w, 1), Vector2i(0, y))
	var gold := Color8(255, 222, 92)
	var dark := Color8(30, 22, 0, 160)
	var arm := 22
	var thick := 3
	for corner: Array in [[0, 0, 1, 1], [w - 1, 0, -1, 1], [0, h - 1, 1, -1], [w - 1, h - 1, -1, -1]]:
		var cx: int = corner[0]
		var cy: int = corner[1]
		var sx: int = corner[2]
		var sy: int = corner[3]
		for i in arm:
			for t in thick:
				_put(image, cx + sx * i, cy + sy * t, gold)
				_put(image, cx + sx * t, cy + sy * i, gold)
			_put(image, cx + sx * i, cy + sy * thick, dark)
			_put(image, cx + sx * thick, cy + sy * i, dark)
	image.fill_rect(Rect2i(0, h / 2 - 6, thick, 13), gold)
	image.fill_rect(Rect2i(w - thick, h / 2 - 6, thick, 13), gold)


## Świecący pas: gradient od górnej i dolnej krawędzi, jasne krawędzie i strzałki ▶ ◀ po bokach.
static func _draw_band(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		var edge := mini(y, h - 1 - y)
		image.fill_rect(Rect2i(0, y, w, 1), Color8(200, 236, 255, maxi(18, 120 - edge * 4)))
	for y in [0, 1, h - 2, h - 1]:
		image.fill_rect(Rect2i(0, y, w, 1), Color8(240, 250, 255))
	image.fill_rect(Rect2i(0, 2, w, 1), Color8(20, 40, 60, 90))
	image.fill_rect(Rect2i(0, h - 3, w, 1), Color8(20, 40, 60, 90))
	var mid := h / 2
	for i in 8:
		var arrow := Rect2i(0, mid - 8 + i, 1, 16 - 2 * i)
		image.fill_rect(Rect2i(Vector2i(6 + i, arrow.position.y), arrow.size), Color8(240, 250, 255, 230))
		image.fill_rect(Rect2i(Vector2i(w - 7 - i, arrow.position.y), arrow.size), Color8(240, 250, 255, 230))


static func _outline(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, 1), color)
	image.fill_rect(Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, 1, rect.size.y), color)
	image.fill_rect(Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y), color)


static func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)

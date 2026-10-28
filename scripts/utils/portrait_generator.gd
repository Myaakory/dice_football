class_name PortraitGenerator
extends RefCounted
## Proceduralna pikselowa twarz zawodnika (32x32), deterministyczna z ID zawodnika.
## Generowana na żądanie tylko dla wyświetlanego zawodnika – nic nie jest zapisywane ani trzymane per gracz.

const SIZE := 32
const OUTLINE := Color("#1a1210")
const SKIN_TONES: Array[Color] = [
	Color("#f2d0b0"), Color("#e3b48e"), Color("#c99067"), Color("#9c6644"), Color("#6e4529")]
const HAIR_COLORS: Array[Color] = [
	Color("#1c1714"), Color("#3b2618"), Color("#6b4423"), Color("#d6b25e"), Color("#a8502a"), Color("#8f8a84")]
const EYE_COLOR := Color("#20181a")

enum Hair { SHORT, BUZZ, CURLY, LONG, BALD, MOHAWK }


static func make_texture(seed_text: String, shirt_color: Color, trim_color: Color) -> ImageTexture:
	return ImageTexture.create_from_image(make_image(seed_text, shirt_color, trim_color))


static func make_image(seed_text: String, shirt_color: Color, trim_color: Color) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	var skin := SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
	var hair_color := HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
	var hair: Hair = rng.randi_range(0, Hair.size() - 1) as Hair
	var has_beard := rng.randf() < 0.3
	var head_width := rng.randi_range(6, 7)  # połowa szerokości głowy

	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var skin_shadow := skin.darkened(0.18)

	# Koszulka (ramiona) z kołnierzykiem w kolorze dodatkowym.
	for y in range(25, SIZE):
		var half := 9 + (y - 25)
		for x in range(16 - half, 16 + half):
			_put(image, x, y, shirt_color.darkened(0.15) if x >= 16 + half - 3 else shirt_color)
	for x in range(12, 20):
		_put(image, x, 25, trim_color)
	_put(image, 12, 26, trim_color)
	_put(image, 19, 26, trim_color)

	# Szyja.
	for y in range(21, 26):
		for x in range(13, 19):
			_put(image, x, y, skin_shadow)

	# Głowa (zaokrąglony owal) + uszy, prawa strona lekko zacieniona.
	var top := 6
	var bottom := 22
	for y in range(top, bottom):
		var t := float(y - top) / float(bottom - top)
		var half := head_width
		if t < 0.12 or t > 0.85:
			half -= 2
		elif t < 0.25 or t > 0.72:
			half -= 1
		for x in range(16 - half, 16 + half):
			_put(image, x, y, skin_shadow if x >= 16 + half - 2 else skin)
	for y in range(13, 17):
		_put(image, 16 - head_width - 1, y, skin)
		_put(image, 16 + head_width, y, skin_shadow)

	# Oczy, brwi, nos, usta.
	_put(image, 13, 14, EYE_COLOR)
	_put(image, 18, 14, EYE_COLOR)
	_put(image, 13, 13, Color.WHITE.lerp(skin, 0.4))
	_put(image, 18, 13, Color.WHITE.lerp(skin, 0.4))
	var brow := hair_color if hair != Hair.BALD else skin.darkened(0.45)
	for x in [12, 13, 14, 17, 18, 19]:
		_put(image, x, 12, brow)
	_put(image, 16, 16, skin.darkened(0.3))
	_put(image, 16, 17, skin.darkened(0.3))
	for x in range(14, 18):
		_put(image, x, 19, skin.darkened(0.42))

	if has_beard:
		for y in range(18, 22):
			for x in range(16 - head_width + 1, 16 + head_width - 1):
				if y > 18 or x < 14 or x > 17:
					if image.get_pixel(x, y).a > 0.0:
						_put(image, x, y, hair_color.lerp(skin, 0.15))
		for x in range(14, 18):
			_put(image, x, 19, skin.darkened(0.5))

	_draw_hair(image, rng, hair, hair_color, head_width, top)
	_add_outline(image)
	return image


static func _draw_hair(image: Image, rng: RandomNumberGenerator, hair: Hair, color: Color, head_width: int, top: int) -> void:
	var left := 16 - head_width
	var right := 16 + head_width
	var shade := color.darkened(0.25)
	match hair:
		Hair.SHORT:
			for y in range(top - 1, top + 5):
				for x in range(left - (1 if y > top + 1 else 0), right + (1 if y > top + 1 else 0)):
					if y < top + 3 or x < left + 1 or x >= right - 1:
						_put(image, x, y, shade if x >= right - 2 else color)
			# grzywka z przedziałkiem
			for x in range(left + 1, left + 5):
				_put(image, x, top + 3, color)
		Hair.BUZZ:
			for y in range(top, top + 3):
				for x in range(left, right):
					if image.get_pixel(x, y).a > 0.0:
						_put(image, x, y, color.lerp(Color(0.5, 0.4, 0.35), 0.25))
		Hair.CURLY:
			for y in range(top - 3, top + 4):
				for x in range(left - 2, right + 2):
					var dist := Vector2(x - 15.5, (y - top - 1) * 1.4).length()
					if dist < head_width + 2.0 and (y < top + 2 or x < left or x >= right):
						var bump := (x + y) % 3 == 0
						_put(image, x, y, shade if bump else color)
		Hair.LONG:
			for y in range(top - 1, top + 13):
				for x in range(left - 1, right + 1):
					if y < top + 3 or x < left + 1 or x >= right - 1:
						_put(image, x, y, shade if (x >= right - 1 or y > top + 8) else color)
		Hair.MOHAWK:
			for y in range(top - 4, top + 3):
				for x in range(14, 18):
					_put(image, x, y, shade if x == 17 else color)
			for y in range(top + 2, top + 6):
				_put(image, left, y, color.lerp(Color.GRAY, 0.3))
				_put(image, right - 1, y, color.lerp(Color.GRAY, 0.3))
		Hair.BALD:
			_put(image, left + 2, top + 1, Color(1, 1, 1, 0.55))
			_put(image, left + 3, top + 1, Color(1, 1, 1, 0.55))
	# lekki losowy kosmyk, żeby fryzury tego samego typu się różniły
	if hair != Hair.BALD and hair != Hair.BUZZ and rng.randf() < 0.5:
		_put(image, right - 3, top + 3, color)


## Obrys 1 px wokół wszystkich nieprzezroczystych pikseli.
static func _add_outline(image: Image) -> void:
	var outline: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if image.get_pixel(x, y).a > 0.0:
				continue
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + offset
				if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and image.get_pixelv(n).a > 0.0:
					outline.append(Vector2i(x, y))
					break
	for point in outline:
		image.set_pixelv(point, OUTLINE)


static func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		image.set_pixel(x, y, color)

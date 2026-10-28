class_name PitchDimmer
extends RefCounted
## Przyciemnianie murawy (opcja "Przyciemnienie boiska"): zamiast czarnej warstwy obniża jasność,
## nasycenie i trochę kontrast samej tekstury boiska, więc żetony, zaznaczenia i napisy zostają jasne.
## Przyciemnione tekstury są liczone raz na wartość suwaka (natywne Image.adjust_bcs) i trzymane w cache.

const MAX_DIM := 0.8
## Jaka część przyciemnienia przechodzi na spadek nasycenia i kontrastu.
const SATURATION_FACTOR := 0.7
const CONTRAST_FACTOR := 0.25
## Krok cache (wartości suwaka są zaokrąglane do niego).
const STEP := 0.05

static var _cache: Dictionary = {}


## Tekstura przyciemniona o `dim` (0 = oryginał, MAX_DIM = najciemniej).
static func get_texture(base: Texture2D, dim: float) -> Texture2D:
	var level := snappedf(clampf(dim, 0.0, MAX_DIM), STEP)
	if level <= 0.0 or base == null:
		return base
	var key := [base.get_rid(), level]
	if not _cache.has(key):
		var image := base.get_image()
		image.adjust_bcs(1.0 - level, 1.0 - level * CONTRAST_FACTOR, 1.0 - level * SATURATION_FACTOR)
		_cache[key] = ImageTexture.create_from_image(image)
	return _cache[key]


## Ten sam efekt dla kolorów rysowanych w kodzie (np. miniatura boiska).
static func dim_color(color: Color, dim: float) -> Color:
	var level := clampf(dim, 0.0, MAX_DIM)
	var result := Color.from_hsv(color.h, color.s * (1.0 - level * SATURATION_FACTOR), color.v * (1.0 - level), color.a)
	return result

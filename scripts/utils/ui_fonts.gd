class_name UiFonts
extends RefCounted
## Czcionka gry: Roboto ze zmiennymi osiami. Motyw projektu używa jej w wersji domyślnej (grubość 400, szerokość 100),
## a tutaj są warianty do nagłówków i dużych liczb.

const ROBOTO: FontFile = preload("res://assets/fonts/Roboto-Variable.ttf")
const WEIGHT_AXIS := 2003265652  # "wght"
const WIDTH_AXIS := 2003072104  # "wdth"
const BOLD := 700

static var _variants: Dictionary[Vector2i, FontVariation] = {}


## width = szerokość w % (75 = wąska, 100 = normalna).
static func get_variant(weight: int, width := 100) -> FontVariation:
	var key := Vector2i(weight, width)
	if not _variants.has(key):
		var variant := FontVariation.new()
		variant.base_font = ROBOTO
		variant.variation_opentype = {WEIGHT_AXIS: weight, WIDTH_AXIS: width}
		_variants[key] = variant
	return _variants[key]

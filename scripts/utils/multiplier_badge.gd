class_name MultiplierBadge
extends RefCounted
## Plakietka mnożnika udziału (W14): „×2” na złotym tle (pole akcji), „×1” na jasnym (pole sąsiednie). Rysowana
## kodem przy kościach zawodnika (DicePlate) i na polach nakładki zagrania (MatchPitch); tekst też w Edytorze zagrań.

const FONT_SIZE := 13
const PADDING := Vector2(4.0, 1.0)
const ACTION_BG := Color("#f2cf4a")
const SUPPORT_BG := Color(0.91, 0.93, 0.87, 0.92)
const TEXT := Color("#2a2219")
const OUTLINE := Color(0.04, 0.07, 0.05, 0.85)


## Mnożnik jako tekst: „×2”, „×1” (ułamki – np. z parametrów symulacji – z jedną cyfrą, przecinek po polsku).
static func format(weight: float) -> String:
	if is_equal_approx(weight, roundf(weight)):
		return "×%d" % roundi(weight)
	var text := String.num(weight, 1)
	return "×" + (text.replace(".", ",") if TranslationServer.get_locale().begins_with("pl") else text)


static func get_size(canvas: Control, weight: float, font_size := FONT_SIZE) -> Vector2:
	var font := canvas.get_theme_default_font()
	var text_size := font.get_string_size(format(weight), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	return (Vector2(text_size.x, font.get_height(font_size)) + PADDING * 2.0).round()


## Rysuje plakietkę z lewym górnym rogiem w `position`; action_weight – mnożnik pola akcji (złote tło od niego w górę).
## Zwraca prostokąt plakietki (np. do podpowiedzi).
static func draw(canvas: Control, position: Vector2, weight: float, action_weight: float,
		font_size := FONT_SIZE) -> Rect2:
	var font := canvas.get_theme_default_font()
	var rect := Rect2(position.round(), get_size(canvas, weight, font_size))
	var strong := weight >= action_weight - 0.001
	var style := StyleBoxFlat.new()
	style.bg_color = ACTION_BG if strong else SUPPORT_BG
	style.set_corner_radius_all(4)
	style.set_border_width_all(1)
	style.border_color = OUTLINE
	canvas.draw_style_box(style, rect)
	var baseline := rect.position.y + PADDING.y + font.get_ascent(font_size)
	canvas.draw_string(font, Vector2(rect.position.x + PADDING.x, roundf(baseline)), format(weight),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT)
	return rect

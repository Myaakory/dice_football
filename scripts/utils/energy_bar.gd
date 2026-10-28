class_name EnergyBar
extends RefCounted
## Pasek energii meczowej zawodnika: segment na każdy punkt energii w ciemnej ramce. Szerokość segmentu zależy
## od maksimum (2 punkty – szerokie segmenty, 10 – wąskie), żeby pasek miał podobną długość. Kolor pełnych segmentów
## mówi o zapasie (zielony – dużo, złoty – mało, pomarańczowy – ostatni punkt); wyczerpany zawodnik
## (energia 0, kości liczą się słabiej) ma czerwoną ramkę.

## Docelowa długość wszystkich segmentów razem (px) i granice szerokości jednego segmentu.
const TARGET_WIDTH := 36.0
const MIN_SEGMENT_WIDTH := 3.0
const MAX_SEGMENT_WIDTH := 12.0
const SEGMENT_HEIGHT := 3.0
const FRAME_COLOR := Color(0.04, 0.08, 0.06, 0.9)
const EMPTY_COLOR := Color(1.0, 1.0, 1.0, 0.13)
const HIGH_COLOR := Color("#8fd16a")
const LOW_COLOR := Color("#f2cf4a")
const LAST_COLOR := Color("#e8743a")
const EXHAUSTED_COLOR := Color("#e04a3a")


static func get_segment_width(max_energy: int) -> float:
	var free_width := TARGET_WIDTH - maxi(max_energy - 1, 0)
	return clampf(floorf(free_width / maxi(max_energy, 1)), MIN_SEGMENT_WIDTH, MAX_SEGMENT_WIDTH)


static func get_size(max_energy: int) -> Vector2:
	return Vector2(max_energy * (get_segment_width(max_energy) + 1.0) + 1.0, SEGMENT_HEIGHT + 2.0)


static func get_fill_color(energy: int, max_energy: int) -> Color:
	if energy <= 1:
		return LAST_COLOR
	return HIGH_COLOR if energy * 2 > max_energy else LOW_COLOR


## Tekst podpowiedzi paska: „Wytrzymałość: 4 / 6” (+ informacja o wyczerpaniu).
static func get_tooltip_text(energy: int, max_energy: int, exhausted_efficiency: float) -> String:
	var text := TranslationServer.translate("MATCH_ENERGY") % [energy, max_energy]
	if energy <= 0:
		text += "\n" + TranslationServer.translate("MATCH_EXHAUSTED") % roundi(exhausted_efficiency * 100.0)
	return text


## Rysuje pasek z lewym górnym rogiem w `pos`.
static func draw(canvas: CanvasItem, pos: Vector2, energy: int, max_energy: int) -> void:
	var frame := Rect2(pos, get_size(max_energy))
	if energy <= 0:
		canvas.draw_rect(frame.grow(1.0), EXHAUSTED_COLOR)
	canvas.draw_rect(frame, FRAME_COLOR)
	var fill := get_fill_color(energy, max_energy)
	var segment_size := Vector2(get_segment_width(max_energy), SEGMENT_HEIGHT)
	for i in max_energy:
		var segment := Rect2(pos + Vector2(1.0 + i * (segment_size.x + 1.0), 1.0), segment_size)
		canvas.draw_rect(segment, fill if i < energy else EMPTY_COLOR)

class_name StadiumView
extends Control
## Stadion wokół boiska: trybuny wzdłuż linii bocznych i za bramkami, maszty oświetlenia. Kontrolka ma rozmiar
## największego stadionu (trybuny MAX_STAND_WIDTH / MAX_END_DEPTH), a obecne trybuny są mniejsze (stand_width,
## end_depth) – stadion może rosnąć bez przebudowy ekranu. Całość jest wyższa niż ekran: ekran meczu przesuwa
## widok w pionie (środkowy przycisk myszy, kółko), żeby zobaczyć trybuny za bramkami.
## PROTOTYP: kibice to proste piksele w kolorach drużyn (grafika do dopracowania).

const MAX_STAND_WIDTH := 128.0
const MAX_END_DEPTH := 96.0
const STAND_GAP := 8.0
const SEAT_COLOR := Color("#1a2620")
const ROW_LINE := Color(0, 0, 0, 0.35)
const EMPTY_SEAT := Color("#2c3b34")
const NEUTRAL_FANS: Array[Color] = [Color("#e9d7c0"), Color("#8a6a55"), Color("#f2efe6"), Color("#c9b49a")]
const FLOODLIGHT := Color("#fff7d0")
## Komórka kibica (piksele) – jeden kibic to kwadrat 2 × 2 w komórce 3 × 3.
const FAN_CELL := 3

## Rozmiar grafiki boiska (PitchLayout) – trybuny biegną wzdłuż całej grafiki, więc rosną razem z nią.
var pitch_size := Vector2(PitchLayout.get_default().size)
var stand_width := 64.0
var end_depth := 64.0
var conditions: MatchConditions
var home_color := Color.RED
var away_color := Color.BLUE


func _init() -> void:
	custom_minimum_size = get_full_size(pitch_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Rozmiar kontrolki: boisko i największe możliwe trybuny.
static func get_full_size(pitch: Vector2) -> Vector2:
	return pitch + Vector2(MAX_STAND_WIDTH + STAND_GAP, MAX_END_DEPTH + STAND_GAP) * 2.0


## Lewy górny róg boiska w tej kontrolce (boisko zawsze na środku).
func get_pitch_position() -> Vector2:
	return ((size - pitch_size) / 2.0).round()


## Obszar zajęty przez boisko i obecne trybuny (do ograniczenia przesuwania widoku).
func get_content_rect() -> Rect2:
	var pitch := Rect2(get_pitch_position(), pitch_size)
	return pitch.grow_individual(stand_width + STAND_GAP, end_depth + STAND_GAP, stand_width + STAND_GAP,
			end_depth + STAND_GAP)


func _draw() -> void:
	var pitch := Rect2(get_pitch_position(), pitch_size)
	var ratio := conditions.get_attendance_ratio() if conditions != null else 0.7
	var left := Rect2(pitch.position.x - STAND_GAP - stand_width, pitch.position.y, stand_width, pitch.size.y)
	var right := Rect2(pitch.end.x + STAND_GAP, pitch.position.y, stand_width, pitch.size.y)
	var top := Rect2(pitch.position.x, pitch.position.y - STAND_GAP - end_depth, pitch.size.x, end_depth)
	var bottom := Rect2(pitch.position.x, pitch.end.y + STAND_GAP, pitch.size.x, end_depth)
	_draw_stand(left, ratio, home_color, 0.0, false, 1)
	_draw_stand(right, ratio, home_color, 0.28, false, 2)
	# Za bramkami: goście za górną bramką (ich bramka), gospodarze za dolną.
	_draw_stand(top, ratio, away_color, 0.0, true, 3)
	_draw_stand(bottom, ratio, home_color, 0.0, true, 4)
	for corner in [Vector2(left.position.x, top.position.y), Vector2(right.end.x - 14.0, top.position.y),
			Vector2(left.position.x, bottom.end.y - 6.0), Vector2(right.end.x - 14.0, bottom.end.y - 6.0)]:
		draw_rect(Rect2(corner + Vector2(-4, -4), Vector2(22, 14)), Color(FLOODLIGHT, 0.12))
		draw_rect(Rect2(corner, Vector2(14, 6)), FLOODLIGHT)


## Trybuna: rzędy krzesełek (równoległe do linii boiska) i kibice. `away_share` – część trybuny (od góry) dla
## kibiców gości.
func _draw_stand(rect: Rect2, ratio: float, team_color: Color, away_share: float, horizontal: bool,
		seed_value: int) -> void:
	draw_rect(rect, SEAT_COLOR)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var columns := int(rect.size.x) / FAN_CELL
	var rows := int(rect.size.y) / FAN_CELL
	for column in columns:
		var x := rect.position.x + column * FAN_CELL
		if not horizontal and column % 3 == 2:
			draw_rect(Rect2(x, rect.position.y, 1, rect.size.y), ROW_LINE)
			continue
		for row in rows:
			var y := rect.position.y + row * FAN_CELL
			if horizontal and row % 3 == 2:
				draw_rect(Rect2(x, y, FAN_CELL, 1), ROW_LINE)
				continue
			var color := EMPTY_SEAT
			if rng.randf() < ratio:
				var away_block := float(row) / rows < away_share
				var own := away_color if away_block else team_color
				color = own if rng.randf() < 0.55 else NEUTRAL_FANS[rng.randi() % NEUTRAL_FANS.size()]
			draw_rect(Rect2(x, y, 2, 2), color)

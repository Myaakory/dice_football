class_name MatchTimeline
extends Control
## Oś meczu w jednym wierszu: obie połowy, kwadratowe kafelki tur, między połowami szersza, delikatnie podświetlona
## przerwa (znak pauzy). Kolor kafelka = drużyna z piłką, symbol = co się stało (gol, strzał, awans, stały fragment,
## strata); bieżąca tura w złotej ramce, przyszłe to puste miejsca. Najechanie na kafelek opisuje turę.

const CELL_GAP := 3.0
const HALF_GAP := 40.0
## Kafelek jest kwadratem dopasowanym do szerokości, ale nie większym niż MAX_CELL (oś jest wtedy wyśrodkowana).
const MAX_CELL := 34.0
const MIN_CELL := 8.0
const HALF_TIME_COLOR := Color(0.95, 0.81, 0.29, 0.10)
const HALF_TIME_BORDER := Color(0.95, 0.81, 0.29, 0.35)
const HALF_TIME_MARK := Color(0.95, 0.81, 0.29, 0.75)
const CURRENT_COLOR := Color("#f2cf4a")
const GOAL_COLOR := Color("#f2cf4a")
const MARK_COLOR := Color("#e9eedf")
const LOSS_COLOR := Color("#ff9a7a")
const EMPTY_COLOR := Color(0.91, 0.93, 0.87, 0.18)

var engine: MatchEngine
## Kolory tur drużyn (gospodarze, goście).
var team_colors: Array[Color] = [Color.DARK_RED, Color.DARK_BLUE]
## Indeks bieżącej tury (-1 = brak).
var current_index := -1


func _init() -> void:
	custom_minimum_size = Vector2(0.0, MAX_CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(match_engine: MatchEngine) -> void:
	engine = match_engine
	team_colors = [engine.teams[0].lineup.team.primary_color.darkened(0.4),
			engine.teams[1].lineup.team.primary_color.darkened(0.4)]
	queue_redraw()


func _notification(what: int) -> void:
	# Wysokość osi = bok kafelka, który zależy od szerokości.
	if what == NOTIFICATION_RESIZED and engine != null:
		var cell := _get_cell_size()
		if not is_equal_approx(custom_minimum_size.y, cell):
			custom_minimum_size.y = cell


func _get_cell_size() -> float:
	var total := engine.rules.get_total_turns()
	return clampf(floorf((size.x - HALF_GAP - CELL_GAP * (total - 2)) / total), MIN_CELL, MAX_CELL)


## Lewy brzeg osi (wyśrodkowanej, gdy kafelki osiągną MAX_CELL).
func _get_offset(cell: float) -> float:
	var total := engine.rules.get_total_turns()
	return maxf(floorf((size.x - (cell * total + CELL_GAP * (total - 2) + HALF_GAP)) / 2.0), 0.0)


func _get_cell_rect(index: int) -> Rect2:
	var cell := _get_cell_size()
	var x := _get_offset(cell) + index * (cell + CELL_GAP)
	if index >= engine.rules.turns_per_half:
		x += HALF_GAP - CELL_GAP
	return Rect2(roundf(x), 0.0, cell, cell)


## Przerwa: pas między ostatnim kafelkiem 1. połowy a pierwszym kafelkiem 2. połowy.
func _get_half_time_rect() -> Rect2:
	var per_half := engine.rules.turns_per_half
	var left := _get_cell_rect(per_half - 1).end.x + CELL_GAP
	var right := _get_cell_rect(per_half).position.x - CELL_GAP
	return Rect2(left, 0.0, right - left, _get_cell_size())


func _get_turn(index: int) -> MatchEngine.Turn:
	for turn in engine.history:
		if turn.index == index:
			return turn
	return null


func _get_tooltip(at_position: Vector2) -> String:
	if engine == null:
		return ""
	if _get_half_time_rect().has_point(at_position):
		return tr("MATCH_HALF_TIME_SHORT")
	for index in engine.rules.get_total_turns():
		if _get_cell_rect(index).grow(CELL_GAP / 2.0).has_point(at_position):
			var turn := _get_turn(index)
			if turn == null:
				return "%d'" % engine.get_minute(index)
			var team := turn.attackers.get_short_name()
			if turn.skipped:
				return "%d' %s" % [engine.get_minute(index), team]
			return "%d' %s: %s\n%s – %s" % [engine.get_minute(index), team, turn.card.get_display_name(),
					tr(PlayCardView.SLOT_KEYS.get(turn.slot, "PLAY_SLOT_" + String(turn.slot).to_upper())),
					PlayEvents.get_display_name(turn.event)]
	return ""


func _draw() -> void:
	if engine == null:
		return
	_draw_half_time()
	for index in engine.rules.get_total_turns():
		var rect := _get_cell_rect(index)
		var turn := _get_turn(index)
		if turn == null:
			if index == current_index:
				draw_rect(rect, team_colors[engine.possession])
				draw_rect(rect.grow(-1.0), CURRENT_COLOR, false, 2.0)
			else:
				_draw_dashed(rect.grow(-0.5))
			continue
		draw_rect(rect, team_colors[turn.possession])
		_draw_symbol(turn, rect.get_center())


## Symbol tury: gol (złota piłka), strzał (pierścień), stały fragment (kwadracik), strata (krzyżyk),
## awans (strzałka w stronę bramki rywala – gospodarze w górę, goście w dół).
func _draw_symbol(turn: MatchEngine.Turn, center: Vector2) -> void:
	if turn.event == PlayEvents.GOAL:
		draw_circle(center, 4.5, GOAL_COLOR)
		draw_arc(center, 4.5, 0.0, TAU, 12, Color(0, 0, 0, 0.5), 1.0)
	elif turn.card != null and turn.card.is_shot:
		draw_arc(center, 4.0, 0.0, TAU, 12, MARK_COLOR, 1.5)
	elif turn.skipped or PlayEvents.changes_possession(turn.event):
		draw_line(center + Vector2(-3, -3), center + Vector2(3, 3), LOSS_COLOR, 1.5)
		draw_line(center + Vector2(-3, 3), center + Vector2(3, -3), LOSS_COLOR, 1.5)
	elif PlayEvents.is_exclusive(turn.event):
		draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), MARK_COLOR, false, 1.5)
	elif turn.event == PlayEvents.ADVANCE:
		var up := -1.0 if turn.possession == 0 else 1.0
		draw_polyline(PackedVector2Array([center + Vector2(-3, -up * 1.5), center + Vector2(0, up * 1.5),
				center + Vector2(3, -up * 1.5)]), MARK_COLOR, 1.5)


func _draw_half_time() -> void:
	var rect := _get_half_time_rect()
	draw_rect(rect, HALF_TIME_COLOR)
	draw_rect(rect.grow(-0.5), HALF_TIME_BORDER, false, 1.0)
	# Znak pauzy: dwie pionowe kreski.
	var center := rect.get_center()
	var bar := Vector2(3.0, roundf(rect.size.y * 0.4))
	for dx: float in [-3.5, 3.5]:
		draw_rect(Rect2(center + Vector2(dx - bar.x / 2.0, -bar.y / 2.0), bar), HALF_TIME_MARK)


func _draw_dashed(rect: Rect2) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], EMPTY_COLOR, 1.0, 3.0)

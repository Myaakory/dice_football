class_name PlayDiagram
extends Control
## Schematyczny rysunek zagrania na karcie: całe boisko 3 × 5 ustawione jak boisko na ekranie (gospodarze grają
## w górę; gdy atakują goście – `flipped`, bramka rywala atakujących jest na dole),
## trawa w pasy, linie, piłka w polu wyjścia, łuk podania / strzału do celu, podświetlone pole akcji i pola
## wsparcia, przelot długiej piłki i zawodnicy obu drużyn jako kropki (biorący udział – wyraźni, z obwódką).
## Rysowany kodem (nie pixel art), skaluje się do szerokości karty.

const ZONE_HEIGHT := 38.0
const MARGIN := Vector2(10, 12)
const GRASS_LIGHT := Color("#4a7a3f")
const GRASS_DARK := Color("#416f37")
const LINE := Color(0.95, 0.97, 0.9, 0.7)
const GRID := Color(0.95, 0.97, 0.9, 0.16)
const TARGET_FILL := Color(0.95, 0.81, 0.29, 0.42)
const TARGET_BORDER := Color("#f2cf4a")
const SUPPORT_FILL := Color(0.95, 0.81, 0.29, 0.15)
const FLYOVER_FILL := Color(0.95, 0.5, 0.25, 0.28)
const ARROW := Color("#f2cf4a")
const ARROW_SHADOW := Color(0.06, 0.12, 0.08, 0.6)
const BALL := Color("#ffffff")
const PLAYER_OUTLINE := Color(1, 1, 1, 0.95)
const NO_TARGET := Vector2i(-1, -1)

var card: PlayCard
var origin := Vector2i.ZERO
var targets: Array[Vector2i] = []
## Cel pokazany wyraźnie (podgląd strony); NO_TARGET = wszystkie cele (przy kilku – przygaszone).
var focus_target := NO_TARGET:
	set(value):
		focus_target = value
		queue_redraw()
var attackers: MatchTeam
var defenders: MatchTeam
var rules: MatchRules
## Rysunek odwrócony (atakują goście) – tak samo jak boisko na ekranie.
var flipped := false
var attack_color := Color.RED
var defense_color := Color.BLUE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, ZONE_HEIGHT * MatchRules.ZONE_COUNT + MARGIN.y * 2)


func setup(p_card: PlayCard, p_origin: Vector2i, p_targets: Array[Vector2i], p_attackers: MatchTeam,
		p_defenders: MatchTeam, p_rules: MatchRules, p_flipped := false) -> void:
	flipped = p_flipped
	card = p_card
	origin = p_origin
	targets = p_targets
	attackers = p_attackers
	defenders = p_defenders
	rules = p_rules
	if attackers != null:
		attack_color = attackers.lineup.team.primary_color
		defense_color = defenders.lineup.team.primary_color
	queue_redraw()


func _get_field() -> Rect2:
	return Rect2(MARGIN, Vector2(size.x - MARGIN.x * 2, ZONE_HEIGHT * MatchRules.ZONE_COUNT))


## Prostokąt pola siatki (pole w perspektywie atakujących; bez odwrócenia strefa 5 u góry, korytarz 0 po lewej).
func _cell_rect(cell: Vector2i) -> Rect2:
	if flipped:
		cell = Vector2i(MatchRules.ZONE_COUNT + 1 - cell.x, MatchRules.CHANNEL_COUNT - 1 - cell.y)
	var field := _get_field()
	var width := field.size.x / MatchRules.CHANNEL_COUNT
	return Rect2(field.position.x + cell.y * width, field.position.y + (MatchRules.ZONE_COUNT - cell.x) * ZONE_HEIGHT,
			width, ZONE_HEIGHT)


func _shown_targets() -> Array[Vector2i]:
	if focus_target != NO_TARGET:
		var single: Array[Vector2i] = [focus_target]
		return single
	return targets


func _draw() -> void:
	if card == null:
		return
	_draw_pitch()
	var shown := _shown_targets()
	var dim := targets.size() > 1 and focus_target == NO_TARGET
	if not card.is_shot:
		for target in shown:
			_draw_action_cells(target, 0.55 if dim else 1.0)
	_draw_players(shown[0] if not shown.is_empty() else origin)
	for target in shown:
		_draw_arrow(target, 0.6 if dim else 1.0)
	var ball := _cell_rect(origin).get_center()
	draw_circle(ball, 4.5, BALL)
	draw_arc(ball, 4.5, 0.0, TAU, 16, Color(0, 0, 0, 0.6), 1.0)


func _draw_pitch() -> void:
	var field := _get_field()
	var outer := field.grow_individual(MARGIN.x, MARGIN.y, MARGIN.x, MARGIN.y)
	draw_rect(outer, GRASS_DARK)
	# Pasy: dwa na strefę, jak na boisku w grze.
	var stripe := ZONE_HEIGHT / 2.0
	for i in MatchRules.ZONE_COUNT * 2:
		if i % 2 == 0:
			draw_rect(Rect2(outer.position.x, field.position.y + i * stripe, outer.size.x, stripe), GRASS_LIGHT)
	# Siatka 3 × 5.
	for c in range(1, MatchRules.CHANNEL_COUNT):
		var x := field.position.x + c * field.size.x / MatchRules.CHANNEL_COUNT
		draw_dashed_line(Vector2(x, field.position.y), Vector2(x, field.end.y), GRID, 1.0, 3.0)
	for z in range(1, MatchRules.ZONE_COUNT):
		var y := field.position.y + z * ZONE_HEIGHT
		draw_dashed_line(Vector2(field.position.x, y), Vector2(field.end.x, y), GRID, 1.0, 3.0)
	# Linie boiska: obrys, połowa, koło, pola karne i bramki.
	draw_rect(field, LINE, false, 1.5)
	var mid := field.get_center()
	draw_line(Vector2(field.position.x, mid.y), Vector2(field.end.x, mid.y), LINE, 1.5)
	draw_arc(mid, ZONE_HEIGHT * 0.6, 0.0, TAU, 32, LINE, 1.5)
	var box := Vector2(field.size.x * 0.5, ZONE_HEIGHT * 0.75)
	draw_rect(Rect2(Vector2(mid.x - box.x / 2.0, field.position.y), box), LINE, false, 1.5)
	draw_rect(Rect2(Vector2(mid.x - box.x / 2.0, field.end.y - box.y), box), LINE, false, 1.5)
	var goal := Vector2(field.size.x * 0.16, 5.0)
	draw_rect(Rect2(Vector2(mid.x - goal.x / 2.0, field.position.y - goal.y), goal), LINE)
	draw_rect(Rect2(Vector2(mid.x - goal.x / 2.0, field.end.y), goal), LINE)


## Pole akcji (złote), pola wsparcia atakujących (jasne złoto), przelot długiej piłki (pomarańcz).
func _draw_action_cells(target: Vector2i, alpha: float) -> void:
	if rules == null:
		return
	var flyover := PlayContest.get_flyover_cells(origin, target)
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		for channel in MatchRules.CHANNEL_COUNT:
			var cell := Vector2i(zone, channel)
			if cell == target:
				continue
			if cell in flyover:
				draw_rect(_cell_rect(cell).grow(-1.0), Color(FLYOVER_FILL, FLYOVER_FILL.a * alpha))
			elif PlayContest.get_card_cell_weight(card, cell, true, origin, target, rules) > 0.0:
				draw_rect(_cell_rect(cell).grow(-1.0), Color(SUPPORT_FILL, SUPPORT_FILL.a * alpha))
	var rect := _cell_rect(target).grow(-1.0)
	draw_rect(rect, Color(TARGET_FILL, TARGET_FILL.a * alpha))
	draw_rect(rect, Color(TARGET_BORDER, alpha), false, 2.0)


## Zawodnicy jako kropki w polach: atakujący w dolnej części pola, broniący w górnej. Biorący udział w akcji
## (waga > 0) są więksi i z obwódką, pozostali mali i przezroczyści.
func _draw_players(target: Vector2i) -> void:
	if attackers == null or rules == null:
		return
	var flyover := PlayContest.get_flyover_cells(origin, target)
	for attacking: bool in [true, false]:
		var team := attackers if attacking else defenders
		var color := attack_color if attacking else defense_color
		var by_cell := {}
		for player in team.players:
			var cell := player.get_cell(attacking)
			if not by_cell.has(cell):
				by_cell[cell] = []
			by_cell[cell].append(player)
		for cell: Vector2i in by_cell:
			var players: Array = by_cell[cell]
			var rect := _cell_rect(cell)
			var y := rect.position.y + rect.size.y * (0.7 if attacking != flipped else 0.3)
			var step := minf(11.0, (rect.size.x - 12.0) / maxf(players.size(), 1))
			var x := rect.get_center().x - step * (players.size() - 1) / 2.0
			for player: MatchPlayer in players:
				var weight := PlayContest.get_card_cell_weight(card, cell, attacking, origin, target, rules)
				if card.is_shot and not attacking and player.is_goalkeeper():
					weight = 1.0
				var point := Vector2(x, y)
				if weight > 0.0:
					draw_circle(point, 4.5, color)
					draw_arc(point, 4.5, 0.0, TAU, 14, PLAYER_OUTLINE, 1.2)
				else:
					draw_circle(point, 2.5, Color(color, 0.4))
				x += step


## Łuk od piłki do celu (strzał – do bramki) z grotem.
func _draw_arrow(target: Vector2i, alpha: float) -> void:
	var from := _cell_rect(origin).get_center()
	var to := _cell_rect(target).get_center()
	if card.is_shot:
		var field := _get_field()
		to = Vector2(field.get_center().x, field.end.y + 2.0 if flipped else field.position.y - 2.0)
	var bend := Vector2(-(to - from).y, (to - from).x).normalized() * minf(from.distance_to(to) * 0.18, 14.0)
	if is_equal_approx(from.x, to.x):
		bend = Vector2(10.0, 0.0)
	var control := (from + to) / 2.0 + bend
	var points := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	# Grot kończy się na celu, linia kończy się przed grotem.
	var direction := (points[16] - points[14]).normalized()
	var head := 8.0
	var line_end := to - direction * head * 0.8
	points[16] = line_end
	draw_polyline(points, Color(ARROW_SHADOW, ARROW_SHADOW.a * alpha), 5.0, true)
	draw_polyline(points, Color(ARROW, alpha), 2.5, true)
	var side := Vector2(-direction.y, direction.x) * head * 0.55
	var tip := PackedVector2Array([to, to - direction * head + side, to - direction * head - side])
	draw_colored_polygon(tip, Color(ARROW, alpha))

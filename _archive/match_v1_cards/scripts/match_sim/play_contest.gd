class_name PlayContest
extends RefCounted
## Jedna rozgrywana karta: kto uczestniczy (z jaką wagą), wyniki rzutów i stan wymagań obu stron.
## Czyste dane – bez Node'ów, RNG podawany z zewnątrz (deterministyczna symulacja).


## Kość biorąca udział w akcji.
class ContestDie:
	var player: MatchPlayer
	var die: DieData
	## Waga udziału × skuteczność zawodnika – mnożnik punktów ze ścianki.
	var efficiency: float = 0.0
	var face: int = -1
	## Strona kości (true = atak).
	var attacking := true
	## Dla każdej ścianki: indeks testu karty, do którego trafia (-1 = nic nie wnosi), i waga składnika.
	## Liczone leniwie przy pierwszym użyciu (kontesty AI do szacowania szans ich nie potrzebują).
	var face_requirements := PackedInt32Array()
	var face_weights := PackedFloat64Array()


var card: PlayCard
var origin: Vector2i
var target: Vector2i
var flyover: Array[Vector2i] = []
var attack_dice: Array[ContestDie] = []
var defense_dice: Array[ContestDie] = []
## Nadpisanie limitu kości testów (MatchRules.max_dice_used): -1 = według testu, 0 = wszystkie, n = n.
var max_dice_override: int = -1
## Ręczne rozmieszczenie kości w testach (ekran meczu: gracz przeciąga kości, AI układa swoje).
## Indeks = int(attacking); słownik ContestDie -> indeks testu. Bez rozmieszczenia liczą się automatycznie
## najlepsze kości każdego testu (symulacja AI kontra AI).
var _placements: Array[Dictionary] = [{}, {}]
var _placed: Array[bool] = [false, false]


static func create(play_card: PlayCard, from_cell: Vector2i, to_cell: Vector2i,
		attackers: MatchTeam, defenders: MatchTeam, rules: MatchRules) -> PlayContest:
	var contest := PlayContest.new()
	contest.card = play_card
	contest.origin = from_cell
	contest.target = to_cell
	contest.flyover = get_flyover_cells(from_cell, to_cell)
	contest.max_dice_override = rules.max_dice_used
	contest._add_dice(attackers, true, rules)
	contest._add_dice(defenders, false, rules)
	return contest


## Pola między polem wyjściowym a docelowym (bez nich samych) – tam obrońcy mogą przeciąć podanie.
static func get_flyover_cells(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var delta := to_cell - from_cell
	var steps := maxi(absi(delta.x), absi(delta.y))
	for step in range(1, steps):
		var t := float(step) / steps
		result.append(Vector2i(from_cell.x + roundi(delta.x * t), from_cell.y + roundi(delta.y * t)))
	return result


## Waga udziału zawodnika w akcji (0 = nie uczestniczy). Zasady: docs/design/match_rules.md.
func get_participation_weight(player: MatchPlayer, attacking: bool, rules: MatchRules) -> float:
	if card.is_shot and not attacking and player.is_goalkeeper():
		return 1.0
	return get_cell_weight(player.get_cell(attacking), attacking, origin, target, flyover, rules)


## Waga udziału zawodnika stojącego w polu `cell` (bez bramkarza przy strzale) – też do podglądu w edytorze.
static func get_cell_weight(cell: Vector2i, attacking: bool, from_cell: Vector2i, to_cell: Vector2i,
		flyover_cells: Array[Vector2i], rules: MatchRules) -> float:
	var zone_distance := absi(cell.x - to_cell.x)
	var channel_distance := absi(cell.y - to_cell.y)
	var weight := 0.0
	if zone_distance == 0:
		weight = [1.0, rules.support_weight, rules.far_side_weight][channel_distance]
	elif zone_distance == 1:
		if channel_distance == 0:
			weight = rules.support_weight
		elif channel_distance == 1:
			weight = rules.diagonal_weight
	if attacking and cell == from_cell:
		weight = maxf(weight, rules.passer_weight)
	if not attacking and cell in flyover_cells:
		weight = maxf(weight, rules.flyover_weight)
	return weight


func get_dice(attacking: bool) -> Array[ContestDie]:
	return attack_dice if attacking else defense_dice


func roll_all(rng: RandomNumberGenerator) -> void:
	for contest_die in attack_dice + defense_dice:
		contest_die.face = contest_die.die.roll(rng)


## Punkty strony dla każdego wymagania karty (indeks = indeks wymagania), tylko z liczących się kości.
func get_points(attacking: bool) -> PackedFloat64Array:
	var points := PackedFloat64Array()
	points.resize(card.get_requirements(attacking).size())
	if _placed[int(attacking)]:
		var placement := _placements[int(attacking)]
		for contest_die: ContestDie in placement:
			points[placement[contest_die]] += get_die_points_in_test(contest_die, placement[contest_die])
		return points
	for contest_die in get_used_dice(attacking):
		points[get_requirement_index(contest_die, attacking)] += get_die_points(contest_die)
	return points


# --- Ręczne rozmieszczenie kości ---

## Ustala, które kości strony liczą się w których testach (ContestDie -> indeks testu). Zwraca false (i nic
## nie zmienia), jeśli rozmieszczenie łamie zasady: ścianka spoza testu, przekroczony limit, cudza kość.
func set_placement(attacking: bool, placement: Dictionary) -> bool:
	if not is_valid_placement(attacking, placement):
		return false
	_placements[int(attacking)] = placement.duplicate()
	_placed[int(attacking)] = true
	return true


func clear_placement(attacking: bool) -> void:
	_placements[int(attacking)] = {}
	_placed[int(attacking)] = false


func has_placement(attacking: bool) -> bool:
	return _placed[int(attacking)]


## Rozmieszczenie strony: ręczne albo (bez niego) automatyczne – najlepsze kości każdego testu.
func get_placement(attacking: bool) -> Dictionary:
	if _placed[int(attacking)]:
		return _placements[int(attacking)].duplicate()
	return get_auto_placement(attacking)


## Rozmieszczenie, jakie wybrałby automat (tak liczy symulacja): w każdym teście najlepsze kości do limitu.
func get_auto_placement(attacking: bool) -> Dictionary:
	var result := {}
	var by_requirement := _get_dice_by_requirement(attacking)
	for i in by_requirement.size():
		var list: Array = by_requirement[i]
		var cap := get_test_cap(attacking, i)
		for j in (list.size() if cap <= 0 else mini(cap, list.size())):
			result[list[j]] = i
	return result


## Czy wyrzucona ścianka kości pasuje do testu (cecha należy do testu).
func can_place(contest_die: ContestDie, test_index: int) -> bool:
	var requirements := card.get_requirements(contest_die.attacking)
	if test_index < 0 or test_index >= requirements.size():
		return false
	return requirements[test_index].accepts(contest_die.die.get_face_attribute(contest_die.face))


func is_valid_placement(attacking: bool, placement: Dictionary) -> bool:
	var counts := {}
	var own := get_dice(attacking)
	for contest_die: Variant in placement:
		if not contest_die is ContestDie or not own.has(contest_die):
			return false
		var index: int = placement[contest_die]
		if not can_place(contest_die, index):
			return false
		counts[index] = counts.get(index, 0) + 1
		var cap := get_test_cap(attacking, index)
		if cap > 0 and counts[index] > cap:
			return false
	return true


## Punkty kości w danym teście (waga składnika testu, w którym leży kość).
func get_die_points_in_test(contest_die: ContestDie, test_index: int) -> float:
	var requirement := card.get_requirements(contest_die.attacking)[test_index]
	return contest_die.die.get_face_value(contest_die.face) * contest_die.efficiency \
			* requirement.get_weight(contest_die.die.get_face_attribute(contest_die.face))


## Limit kości testu strony (0 = wszystkie).
func get_test_cap(attacking: bool, index: int) -> int:
	if max_dice_override >= 0:
		return max_dice_override
	return card.get_requirements(attacking)[index].max_dice


## Kości, które się liczą: w każdym teście najlepsze kości do jego limitu (PlayRequirement.max_dice).
## Ścianka trafia tylko do jednego testu, więc testy wybierają kości niezależnie.
func get_used_dice(attacking: bool) -> Array[ContestDie]:
	var result: Array[ContestDie] = []
	if _placed[int(attacking)]:
		result.assign(_placements[int(attacking)].keys())
		return result
	var by_requirement := _get_dice_by_requirement(attacking)
	for i in by_requirement.size():
		var list: Array = by_requirement[i]
		var cap := get_test_cap(attacking, i)
		for j in (list.size() if cap <= 0 else mini(cap, list.size())):
			result.append(list[j])
	return result


## Kości trafiające w każdy test, od najwyższych punktów.
func _get_dice_by_requirement(attacking: bool) -> Array[Array]:
	var by_requirement: Array[Array] = []
	for i in card.get_requirements(attacking).size():
		by_requirement.append([])
	for contest_die in get_dice(attacking):
		var index := get_requirement_index(contest_die, attacking)
		if index != -1:
			by_requirement[index].append(contest_die)
	for list in by_requirement:
		list.sort_custom(func(a: ContestDie, b: ContestDie) -> bool: return get_die_points(a) > get_die_points(b))
	return by_requirement


## Indeks wymagania, do którego trafia wyrzucona ścianka (-1 = nic nie wnosi).
## Ścianka trafia do pierwszego testu, który zawiera jej cechę.
func get_requirement_index(contest_die: ContestDie, _attacking: bool) -> int:
	if contest_die.face_requirements.is_empty():
		_index_faces(contest_die)
	return contest_die.face_requirements[contest_die.face]


## Punkty wyrzuconej ścianki: wartość × skuteczność × waga składnika testu.
func get_die_points(contest_die: ContestDie) -> float:
	if contest_die.face_weights.is_empty():
		_index_faces(contest_die)
	return contest_die.die.get_face_value(contest_die.face) * contest_die.efficiency * contest_die.face_weights[contest_die.face]


## Pierwszy test strony zawierający cechę (-1 = żaden).
func find_requirement_index(attribute_id: StringName, attacking: bool) -> int:
	var requirements := card.get_requirements(attacking)
	for i in requirements.size():
		if requirements[i].accepts(attribute_id):
			return i
	return -1


## Wymagania strony jeszcze niezapełnione (maska: true = brakuje punktów).
func get_unfilled_mask(attacking: bool) -> Array[bool]:
	var requirements := card.get_requirements(attacking)
	var points := get_points(attacking)
	var mask: Array[bool] = []
	for i in requirements.size():
		mask.append(points[i] < requirements[i].points)
	return mask


func is_filled(attacking: bool) -> bool:
	return not get_unfilled_mask(attacking).has(true)


## Brakujące punkty do zapełnienia wszystkich wymagań strony.
func get_deficit(attacking: bool) -> float:
	var requirements := card.get_requirements(attacking)
	var points := get_points(attacking)
	var deficit := 0.0
	for i in requirements.size():
		deficit += maxf(requirements[i].points - points[i], 0.0)
	return deficit


## Nadwyżka punktów ponad próg (ujemna = brakuje) – rozstrzyga pojedynki. Przy kilku testach („i”)
## liczy się test z największą nadwyżką.
func get_surplus(attacking: bool) -> float:
	var requirements := card.get_requirements(attacking)
	var points := get_points(attacking)
	var best := -INF
	for i in requirements.size():
		best = maxf(best, points[i] - requirements[i].points)
	return best


## Oczekiwana liczba punktów kości dla wymagań z maski (do decyzji o przerzucie).
func get_expected_die_points(contest_die: ContestDie, attacking: bool, mask: Array[bool]) -> float:
	var requirements := card.get_requirements(attacking)
	var total := 0.0
	var face_count := contest_die.die.get_face_count()
	for face in face_count:
		var attribute_id := contest_die.die.get_face_attribute(face)
		for i in requirements.size():
			if not mask[i]:
				continue
			var term := requirements[i].attributes.find(attribute_id)
			if term != -1:
				total += contest_die.die.get_face_value(face) * contest_die.efficiency * requirements[i].weights[term]
				break
	return total / face_count


## Obecny wkład kości do wymagań z maski (0, jeśli kość się nie liczy).
func get_current_die_points(contest_die: ContestDie, attacking: bool, mask: Array[bool],
		used: Array[ContestDie]) -> float:
	var index := get_requirement_index(contest_die, attacking)
	if index == -1 or not mask[index] or not used.has(contest_die):
		return 0.0
	return get_die_points(contest_die)


## Oczekiwany zysk z przerzutu kości. Kość spoza liczących się musi pobić najsłabszą liczącą się kość
## testu, do którego trafi (gdy ten test ma już komplet kości).
func get_reroll_gain(contest_die: ContestDie, attacking: bool, mask: Array[bool], used: Array[ContestDie]) -> float:
	if used.has(contest_die):
		return get_expected_die_points(contest_die, attacking, mask) \
				- get_current_die_points(contest_die, attacking, mask, used)
	var requirements := card.get_requirements(attacking)
	var floors := PackedFloat64Array()
	var counts := PackedInt32Array()
	floors.resize(requirements.size())
	counts.resize(requirements.size())
	floors.fill(INF)
	for used_die in used:
		var index := get_requirement_index(used_die, attacking)
		counts[index] += 1
		floors[index] = minf(floors[index], get_die_points(used_die))
	for i in requirements.size():
		var cap := get_test_cap(attacking, i)
		if cap <= 0 or counts[i] < cap:
			floors[i] = 0.0
	var total := 0.0
	var face_count := contest_die.die.get_face_count()
	for face in face_count:
		var attribute_id := contest_die.die.get_face_attribute(face)
		for i in requirements.size():
			if not mask[i]:
				continue
			var term := requirements[i].attributes.find(attribute_id)
			if term != -1:
				total += maxf(contest_die.die.get_face_value(face) * contest_die.efficiency
						* requirements[i].weights[term] - floors[i], 0.0)
				break
	return total / face_count


func _add_dice(team: MatchTeam, attacking: bool, rules: MatchRules) -> void:
	var dice := get_dice(attacking)
	for player in team.players:
		var weight := get_participation_weight(player, attacking, rules)
		if weight <= 0.0:
			continue
		for die in player.dice:
			if not card.uses_die_type(die.type, attacking):
				continue
			var contest_die := ContestDie.new()
			contest_die.player = player
			contest_die.die = die
			contest_die.efficiency = weight * player.get_die_efficiency(die, rules)
			contest_die.attacking = attacking
			dice.append(contest_die)


func _index_faces(contest_die: ContestDie) -> void:
	var attacking := contest_die.attacking
	var requirements := card.get_requirements(attacking)
	var face_count := contest_die.die.get_face_count()
	contest_die.face_requirements.resize(face_count)
	contest_die.face_weights.resize(face_count)
	for face in face_count:
		var attribute_id := contest_die.die.get_face_attribute(face)
		var index := find_requirement_index(attribute_id, attacking)
		contest_die.face_requirements[face] = index
		contest_die.face_weights[face] = requirements[index].get_weight(attribute_id) if index != -1 else 1.0

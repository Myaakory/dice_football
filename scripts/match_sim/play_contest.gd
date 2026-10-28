class_name PlayContest
extends RefCounted
## Jedna rozgrywana karta: kto uczestniczy (z jaką wagą), wyniki rzutów i stan wymagań obu stron.
## Czyste dane – bez Node'ów, RNG podawany z zewnątrz (deterministyczna symulacja).


## Kość biorąca udział w akcji.
class ContestDie:
	var player: MatchPlayer
	var die: DieData
	## Waga udziału × skuteczność zawodnika – mnożnik punktów ze ścianki w testach przy polu docelowym.
	var efficiency: float = 0.0
	## To samo dla testów przy polu startowym (0, gdy strona ich nie ma albo zawodnik stoi daleko).
	var origin_efficiency: float = 0.0
	## To samo dla testu interwencji bramkarza (tylko bramkarz broniących przy strzale).
	var keeper_efficiency: float = 0.0
	## Mnożniki udziału zawodnika (bez skuteczności) w testach celu, startu i bramkarza oraz największy z nich
	## (plakietka „×2” na ekranie).
	var target_weight: float = 0.0
	var origin_weight: float = 0.0
	var keeper_weight: float = 0.0
	var participation: float = 0.0
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
## Modyfikatory udziału stron (indeks = int(attacking)): zasady podstawowe i perki drużyny (MatchTeam).
var modifiers: Array = [[], []]
## Flagi karty liczone raz na kontest (udział liczy się dla każdego zawodnika): test startu strony
## (indeks = int(attacking)) i test bramkarza.
var _origin_tests: Array[bool] = [false, false]
var _keeper_test := false
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
	contest.modifiers = [defenders.get_participation_modifiers(rules), attackers.get_participation_modifiers(rules)]
	contest._origin_tests = [play_card.has_origin_tests(false), play_card.has_origin_tests(true)]
	contest._keeper_test = play_card.has_keeper_test()
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


## Waga udziału zawodnika w akcji (0 = nie uczestniczy) – największa z wag przy polu docelowym, startowym
## i w teście bramkarza. Zasady: docs/design/match_rules.md.
func get_participation_weight(player: MatchPlayer, attacking: bool, rules: MatchRules) -> float:
	return maxf(maxf(get_target_weight(player, attacking, rules), get_origin_weight(player, attacking, rules)),
			get_keeper_weight(player, attacking, rules))


## Waga udziału w teście interwencji bramkarza: bramkarz broniących jak w polu akcji, reszta 0.
func get_keeper_weight(player: MatchPlayer, attacking: bool, rules: MatchRules) -> float:
	return rules.action_weight if _keeper_test and not attacking and player.is_goalkeeper() else 0.0


## Waga udziału w testach przy polu docelowym. Gdy strona ma testy przy polu startowym, podający gra w nich,
## a nie dostaje premii podającego przy celu. Bramkarz przy strzale z testem interwencji gra tylko w nim.
func get_target_weight(player: MatchPlayer, attacking: bool, rules: MatchRules) -> float:
	if card.is_shot and not attacking and player.is_goalkeeper():
		return 0.0 if _keeper_test else rules.action_weight
	return _get_player_weight(player, attacking, target, flyover, not _origin_tests[int(attacking)])


## Waga udziału w testach przy polu startowym (0, gdy strona ich nie ma): jak przy celu, tylko liczona od startu.
func get_origin_weight(player: MatchPlayer, attacking: bool, rules: MatchRules) -> float:
	if not _origin_tests[int(attacking)] or get_keeper_weight(player, attacking, rules) > 0.0:
		return 0.0
	var no_flyover: Array[Vector2i] = []
	return _get_player_weight(player, attacking, origin, no_flyover, false)


## Mnożnik zawodnika przy teście w polu `test_cell` z modyfikatorów jego strony (ParticipationModifier).
func _get_player_weight(player: MatchPlayer, attacking: bool, test_cell: Vector2i, flyover_cells: Array[Vector2i],
		passer: bool) -> float:
	return ParticipationModifier.get_weight(modifiers[int(attacking)], player.get_cell(attacking), attacking, origin,
			test_cell, flyover_cells, passer, card.lane, player.role_id)


## Waga pola w podglądzie zagrania (boisko, rysunek karty, edytor): największa z wag przy celu i przy starcie.
## team / role_id: modyfikatory drużyny i rola zawodnika (bez nich – same zasady podstawowe).
static func get_card_cell_weight(play_card: PlayCard, cell: Vector2i, attacking: bool, from_cell: Vector2i,
		to_cell: Vector2i, rules: MatchRules, team: MatchTeam = null, role_id: StringName = &"") -> float:
	var list := team.get_participation_modifiers(rules) if team != null else rules.get_participation_modifiers()
	var has_origin := play_card.has_origin_tests(attacking)
	var weight := ParticipationModifier.get_weight(list, cell, attacking, from_cell, to_cell,
			get_flyover_cells(from_cell, to_cell), not has_origin, play_card.lane, role_id)
	if has_origin:
		var no_flyover: Array[Vector2i] = []
		weight = maxf(weight, ParticipationModifier.get_weight(list, cell, attacking, from_cell, from_cell, no_flyover,
				false, play_card.lane, role_id))
	return weight


func get_dice(attacking: bool) -> Array[ContestDie]:
	return attack_dice if attacking else defense_dice


func roll_all(rng: RandomNumberGenerator) -> void:
	for contest_die in attack_dice + defense_dice:
		contest_die.face = contest_die.die.roll(rng)


## Rzut kości jednej strony (tura etapami: najpierw atak, potem obrona).
func roll_side(attacking: bool, rng: RandomNumberGenerator) -> void:
	for contest_die in get_dice(attacking):
		contest_die.face = contest_die.die.roll(rng)


## Liczy od nowa kości strony z obecnych pól zawodników (obrońca przesuwa zawodnika dopiero po etapie ataku).
func rebuild_side(team: MatchTeam, attacking: bool, rules: MatchRules) -> void:
	modifiers[int(attacking)] = team.get_participation_modifiers(rules)
	get_dice(attacking).clear()
	clear_placement(attacking)
	_add_dice(team, attacking, rules)


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


## Czy wyrzucona ścianka kości pasuje do testu (cecha należy do testu, a zawodnik bierze udział przy jego polu).
func can_place(contest_die: ContestDie, test_index: int) -> bool:
	var requirements := card.get_requirements(contest_die.attacking)
	if test_index < 0 or test_index >= requirements.size():
		return false
	return get_test_efficiency(contest_die, test_index) > 0.0 \
			and requirements[test_index].accepts(contest_die.die.get_face_attribute(contest_die.face))


## Mnożnik punktów kości w teście: skuteczność przy polu, którego test dotyczy (start, cel albo bramka).
func get_test_efficiency(contest_die: ContestDie, test_index: int) -> float:
	var requirement := card.get_requirements(contest_die.attacking)[test_index]
	if requirement.is_at_origin():
		return contest_die.origin_efficiency
	if requirement.is_keeper():
		return contest_die.keeper_efficiency
	return contest_die.efficiency


## Mnożnik udziału kości w teście (bez skuteczności): ×2 / ×1 przy polu, którego test dotyczy.
func get_test_weight(contest_die: ContestDie, test_index: int) -> float:
	var requirement := card.get_requirements(contest_die.attacking)[test_index]
	if requirement.is_at_origin():
		return contest_die.origin_weight
	if requirement.is_keeper():
		return contest_die.keeper_weight
	return contest_die.target_weight


## Pole, którego dotyczy test strony (perspektywa atakujących); test bramkarza – środek strefy 5 (bramka broniących).
func get_test_cell(attacking: bool, test_index: int) -> Vector2i:
	var requirement := card.get_requirements(attacking)[test_index]
	if requirement.is_keeper():
		return Vector2i(MatchRules.ZONE_COUNT, MatchRules.CHANNEL_CENTER)
	return origin if requirement.is_at_origin() else target


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
	return contest_die.die.get_face_value(contest_die.face) * get_test_efficiency(contest_die, test_index) \
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


## Punkty wyrzuconej ścianki: wartość × skuteczność przy polu testu × waga składnika testu.
func get_die_points(contest_die: ContestDie) -> float:
	var index := get_requirement_index(contest_die, contest_die.attacking)
	if index == -1:
		return 0.0
	return contest_die.die.get_face_value(contest_die.face) * get_test_efficiency(contest_die, index) \
			* contest_die.face_weights[contest_die.face]


## Pierwszy test strony zawierający cechę, w którym kość bierze udział (-1 = żaden).
func find_requirement_index(contest_die: ContestDie, attribute_id: StringName) -> int:
	var requirements := card.get_requirements(contest_die.attacking)
	for i in requirements.size():
		if requirements[i].accepts(attribute_id) and get_test_efficiency(contest_die, i) > 0.0:
			return i
	return -1


## Wymagania strony jeszcze niezapełnione (maska: true = brakuje punktów). include_keeper = false pomija test
## bramkarza (zostaje false w masce).
func get_unfilled_mask(attacking: bool, include_keeper := true) -> Array[bool]:
	var requirements := card.get_requirements(attacking)
	var points := get_points(attacking)
	var mask: Array[bool] = []
	for i in requirements.size():
		mask.append(points[i] < requirements[i].points and (include_keeper or not requirements[i].is_keeper()))
	return mask


## Czy strona zapełniła swoje testy (bez testu bramkarza – ten rozstrzyga osobno, is_keeper_filled).
func is_filled(attacking: bool) -> bool:
	return not get_unfilled_mask(attacking, false).has(true)


## Czy bramkarz zapełnił test interwencji (false, gdy karta go nie ma).
func is_keeper_filled() -> bool:
	if not _keeper_test:
		return false
	var points := get_points(false)
	for i in card.defense.size():
		if card.defense[i].is_keeper() and points[i] < card.defense[i].points:
			return false
	return true


## Brakujące punkty do zapełnienia wymagań strony (domyślnie bez testu bramkarza).
func get_deficit(attacking: bool, include_keeper := false) -> float:
	var requirements := card.get_requirements(attacking)
	var points := get_points(attacking)
	var deficit := 0.0
	for i in requirements.size():
		if include_keeper or not requirements[i].is_keeper():
			deficit += maxf(requirements[i].points - points[i], 0.0)
	return deficit


## Nadwyżka punktów ponad próg (ujemna = brakuje) – rozstrzyga pojedynki. Przy kilku testach („i”)
## liczy się test z największą nadwyżką (bez testu bramkarza).
func get_surplus(attacking: bool) -> float:
	var requirements := card.get_requirements(attacking)
	var points := get_points(attacking)
	var best := -INF
	for i in requirements.size():
		if not requirements[i].is_keeper():
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
			if term != -1 and get_test_efficiency(contest_die, i) > 0.0:
				total += contest_die.die.get_face_value(face) * get_test_efficiency(contest_die, i) \
						* requirements[i].get_weight(attribute_id)
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
			if term != -1 and get_test_efficiency(contest_die, i) > 0.0:
				total += maxf(contest_die.die.get_face_value(face) * get_test_efficiency(contest_die, i)
						* requirements[i].get_weight(attribute_id) - floors[i], 0.0)
				break
	return total / face_count


func _add_dice(team: MatchTeam, attacking: bool, rules: MatchRules) -> void:
	var dice := get_dice(attacking)
	for player in team.players:
		var target_weight := get_target_weight(player, attacking, rules)
		var origin_weight := get_origin_weight(player, attacking, rules)
		var keeper_weight := get_keeper_weight(player, attacking, rules)
		if target_weight <= 0.0 and origin_weight <= 0.0 and keeper_weight <= 0.0:
			continue
		for die in player.dice:
			if not card.uses_die_type(die.type, attacking):
				continue
			var contest_die := ContestDie.new()
			contest_die.player = player
			contest_die.die = die
			var die_efficiency := player.get_die_efficiency(die, rules)
			contest_die.efficiency = target_weight * die_efficiency
			contest_die.origin_efficiency = origin_weight * die_efficiency
			contest_die.keeper_efficiency = keeper_weight * die_efficiency
			contest_die.target_weight = target_weight
			contest_die.origin_weight = origin_weight
			contest_die.keeper_weight = keeper_weight
			contest_die.participation = maxf(maxf(target_weight, origin_weight), keeper_weight)
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
		var index := find_requirement_index(contest_die, attribute_id)
		contest_die.face_requirements[face] = index
		contest_die.face_weights[face] = requirements[index].get_weight(attribute_id) if index != -1 else 1.0

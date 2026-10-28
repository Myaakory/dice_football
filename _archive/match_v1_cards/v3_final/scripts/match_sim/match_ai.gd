class_name MatchAI
extends RefCounted
## Decyzje drużyny w meczu: wybór karty i strony, przesunięcia i przerzuty za energię.
## Oparte na szansach z DiceOdds i prostej wartości stanu (MatchRules.possession_value).
## PROTOTYP – opis: res://docs/design/match_rules.md, sekcja „Przeciwnik komputerowy”.


class PlayChoice:
	var card: PlayCard
	var target: Vector2i
	var value: float = -INF
	var attack_chance: float = 0.0
	var defense_chance: float = 0.0


const SHIFT_DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Przerzut ma sens, jeśli oczekiwany zysk kości przekracza ten próg punktów.
const MIN_REROLL_GAIN := 0.05
## Miara odnogi wyniku (OutcomeBranch, np. niedobór obrony) przyjmowana przy ocenie kart – AI nie zna rzutu.
const BRANCH_ASSUMED_MEASURE := 1.0

## Mnożnik strat przy ocenie kart (>1 = ostrożny trener, <1 = ryzykant).
var risk_aversion: float = 1.0


static func create(risk: float = 1.0) -> MatchAI:
	var ai := MatchAI.new()
	ai.risk_aversion = risk
	return ai


## Skłonność do ryzyka w danej sytuacji meczowej (przegrywający w końcówce ryzykuje więcej).
func get_risk(score_difference: int, turns_left: int) -> float:
	var risk := risk_aversion
	if turns_left <= 8:
		if score_difference < 0:
			risk *= 0.5
		elif score_difference > 0:
			risk *= 1.5
	return risk


func choose_play(hand: Array[PlayCard], origin: Vector2i, attackers: MatchTeam, defenders: MatchTeam,
		rules: MatchRules, risk: float, rng: RandomNumberGenerator) -> PlayChoice:
	var best := PlayChoice.new()
	for card in hand:
		for target in card.get_targets(origin):
			var contest := PlayContest.create(card, origin, target, attackers, defenders, rules)
			var attack_chance := DiceOdds.fill_probability(contest, true)
			var defense_chance := DiceOdds.fill_probability(contest, false)
			var keeper_chance := DiceOdds.keeper_probability(contest)
			var value := evaluate(card, origin, target, attack_chance, defense_chance, rules, risk, keeper_chance)
			# Remis wartości rozstrzyga los, żeby AI nie było przewidywalne.
			if value > best.value + 0.0001 or (absf(value - best.value) <= 0.0001 and rng.randf() < 0.5):
				best.card = card
				best.target = target
				best.value = value
				best.attack_chance = attack_chance
				best.defense_chance = defense_chance
	return best


## Wartość zagrania z perspektywy atakujących (w „golach”): suma szans wyników × wartość efektu wyniku.
## keeper_chance: szansa interwencji bramkarza (gol zamienia się w obronę bramkarza).
static func evaluate(card: PlayCard, origin: Vector2i, target: Vector2i, attack_chance: float,
		defense_chance: float, rules: MatchRules, risk: float, keeper_chance := 0.0) -> float:
	var success := get_effect_value(card, &"success", origin, target, rules, risk, keeper_chance)
	var defense := get_effect_value(card, &"defense", origin, target, rules, risk, keeper_chance)
	# Pojedynki (obie strony zapełniły albo żadna): przyjmujemy 50% szans.
	var both := 0.5 * (get_effect_value(card, &"duel_won", origin, target, rules, risk, keeper_chance)
			+ get_effect_value(card, &"duel_lost", origin, target, rules, risk, keeper_chance))
	var neither := 0.5 * (get_effect_value(card, &"none_won", origin, target, rules, risk, keeper_chance)
			+ get_effect_value(card, &"none_lost", origin, target, rules, risk, keeper_chance))
	return (attack_chance * (1.0 - defense_chance) * success
			+ attack_chance * defense_chance * both
			+ (1.0 - attack_chance) * defense_chance * defense
			+ (1.0 - attack_chance) * (1.0 - defense_chance) * neither)


## Różnica między sukcesem a samą obroną – jak ważna jest akcja (steruje wydawaniem energii).
static func get_stake(card: PlayCard, origin: Vector2i, target: Vector2i, rules: MatchRules) -> float:
	return get_effect_value(card, &"success", origin, target, rules, 1.0) \
			- get_effect_value(card, &"defense", origin, target, rules, 1.0)


## Wartość stanu po slocie wyniku (MatchEngine._apply_effect) z odnogami: średnia ważona szansami odnóg.
## AI nie zna wyniku rzutu, więc miarę odnogi przyjmuje jako BRANCH_ASSUMED_MEASURE punktów.
## Straty mnożone przez `risk`.
static func get_effect_value(card: PlayCard, slot: StringName, origin: Vector2i, target: Vector2i,
		rules: MatchRules, risk: float, keeper_chance := 0.0) -> float:
	var cell := PlayCard.get_action_cell(slot, origin, target)
	var value := 0.0
	var total := 0.0
	for branch: OutcomeBranch in card.get_branches(slot):
		if not branch.applies_at(cell):
			continue
		var chance := minf(branch.get_chance(BRANCH_ASSUMED_MEASURE), 1.0 - total)
		if chance > 0.0:
			value += chance * get_event_value(branch.event, cell, origin, target, rules, risk, keeper_chance)
			total += chance
	return value + (1.0 - total) * get_event_value(card.get_outcome(slot), cell, origin, target, rules, risk,
			keeper_chance)


## Wartość stanu po zdarzeniu w miejscu akcji `cell`. Straty mnożone przez `risk`. Gol z szansą keeper_chance
## zamienia się w obronę bramkarza.
static func get_event_value(event: StringName, cell: Vector2i, origin: Vector2i, target: Vector2i,
		rules: MatchRules, risk: float, keeper_chance := 0.0) -> float:
	var chain := PlayEvents.get_chain_event(event)
	if chain != null:
		# Zdarzenie łańcucha: jak posiadanie (albo strata) w polu piłki – AI nie patrzy w głąb łańcucha.
		var chain_cell := chain.get_ball_cell(cell, origin, target)
		if chain.changes_possession:
			return get_turnover_value(chain_cell, rules) * risk
		return rules.get_possession_value(chain_cell.x)
	match event:
		PlayEvents.GOAL:
			return (1.0 - keeper_chance) * (1.0 - rules.get_possession_value(3)) \
					- keeper_chance * rules.get_possession_value(1) * risk
		PlayEvents.ADVANCE:
			return rules.get_possession_value(target.x)
		PlayEvents.TURNOVER, PlayEvents.OFFSIDE:
			return get_turnover_value(cell, rules) * risk
		PlayEvents.INTERCEPTION:
			var flyover := PlayContest.get_flyover_cells(origin, target)
			return get_turnover_value(flyover[0] if not flyover.is_empty() else cell, rules) * risk
		PlayEvents.CLEARANCE:
			var zone := mini(MatchRules.ZONE_COUNT + 1 - cell.x + rules.clearance_distance, MatchRules.ZONE_COUNT)
			return -rules.get_possession_value(zone) * risk
		PlayEvents.GOALKEEPER_SAVE:
			return -rules.get_possession_value(1) * risk
		PlayEvents.FOUL:
			return rules.get_possession_value(cell.x)
		PlayEvents.CORNER:
			return rules.get_possession_value(MatchRules.ZONE_COUNT)
		PlayEvents.PENALTY:
			return rules.penalty_value * (1.0 - rules.get_possession_value(3))
	return rules.get_possession_value(origin.x)


## Wartość utraty piłki w danym polu (rywal przejmuje ją w lustrzanej strefie).
static func get_turnover_value(cell: Vector2i, rules: MatchRules) -> float:
	return -rules.get_possession_value(MatchRules.ZONE_COUNT + 1 - cell.x)


## Przesunięcie jednego zawodnika o pole na tę turę. Zwraca {"player": MatchPlayer, "shift": Vector2i}
## albo pusty słownik, jeśli się nie opłaca.
func choose_shift(card: PlayCard, origin: Vector2i, target: Vector2i, attackers: MatchTeam,
		defenders: MatchTeam, attacking: bool, budget: int, rules: MatchRules) -> Dictionary:
	if budget < rules.shift_cost:
		return {}
	var own_team := attackers if attacking else defenders
	var base := PlayContest.create(card, origin, target, attackers, defenders, rules)
	var base_chance := DiceOdds.fill_probability(base, attacking)
	if base_chance > 0.9:
		return {}
	var best_gain := 0.0
	var best := {}
	for player in own_team.players:
		if player.is_goalkeeper() or player.energy < rules.shift_cost:
			continue
		var current_weight := base.get_participation_weight(player, attacking, rules)
		if current_weight >= 1.0:
			continue
		for direction in SHIFT_DIRECTIONS:
			var zone := player.get_base_cell().x + direction.x
			var channel := player.get_base_cell().y + direction.y
			if zone < 1 or zone > MatchRules.ZONE_COUNT or channel < 0 or channel >= MatchRules.CHANNEL_COUNT:
				continue
			player.shift = direction
			if base.get_participation_weight(player, attacking, rules) > current_weight:
				var contest := PlayContest.create(card, origin, target, attackers, defenders, rules)
				var gain := DiceOdds.fill_probability(contest, attacking) - base_chance
				if gain > best_gain:
					best_gain = gain
					best = {"player": player, "shift": direction}
			player.shift = Vector2i.ZERO
	if best_gain < rules.min_shift_gain:
		return {}
	return best


## Kości do przerzucenia: największy oczekiwany zysk, aż pokryje brakujące punkty albo skończy się budżet.
## Obrona przerzuca też kości bramkarza do testu interwencji – tylko gdy atak zapełnił testy (inaczej gola nie będzie).
func choose_rerolls(contest: PlayContest, attacking: bool, budget: int, rules: MatchRules) -> Array[PlayContest.ContestDie]:
	var chosen: Array[PlayContest.ContestDie] = []
	var keeper := not attacking and contest.is_filled(true)
	var mask := contest.get_unfilled_mask(attacking, keeper)
	if budget < rules.reroll_cost or not mask.has(true):
		return chosen
	var deficit := contest.get_deficit(attacking, keeper)
	var used := contest.get_used_dice(attacking)
	var candidates: Array[Array] = []  # [zysk, kość]
	for contest_die in contest.get_dice(attacking):
		var gain := contest.get_reroll_gain(contest_die, attacking, mask, used)
		if gain > MIN_REROLL_GAIN:
			candidates.append([gain, contest_die])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	# Brak szans na pokrycie nawet połowy braku – nie marnujemy energii.
	var possible_gain := 0.0
	for i in mini(candidates.size(), budget / rules.reroll_cost):
		possible_gain += candidates[i][0]
	if possible_gain < deficit * 0.5:
		return chosen
	var reserved := {}  # MatchPlayer -> energia już zarezerwowana w tej rundzie
	var expected_gain := 0.0
	var spent := 0
	for candidate in candidates:
		if expected_gain >= deficit or spent + rules.reroll_cost > budget:
			break
		var contest_die: PlayContest.ContestDie = candidate[1]
		var player := contest_die.player
		var player_reserved: int = reserved.get(player, 0)
		if player.energy - player_reserved < rules.reroll_cost:
			continue
		reserved[player] = player_reserved + rules.reroll_cost
		spent += rules.reroll_cost
		expected_gain += candidate[0]
		chosen.append(contest_die)
	return chosen

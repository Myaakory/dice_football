class_name MatchEngine
extends RefCounted
## Silnik meczu na czystych danych: tura = jedna karta zagrania. Symulacja (play_match) prowadzi obie drużyny
## przez MatchAI; ekran meczu wywołuje te same kroki tury po kolei (begin_turn … finish_turn) i za drużynę gracza
## podejmuje decyzje sam. PROTOTYP – zasady: res://docs/design/match_rules.md.

## Wynik rozstrzygnięcia wymagań (macierz: kto zapełnił swoje wymagania).
enum Outcome { SUCCESS, BOTH, DEFENSE, NONE }
## Skutek tury dla piłki.
enum Result { PROGRESS, GOAL, KEEP, TURNOVER }

const OUTCOME_NAMES: Array[String] = ["success", "both", "defense", "none"]
const RESULT_NAMES: Array[String] = ["progress", "goal", "keep", "turnover"]


## Jedna tura (karta): stan kolejnych kroków i wynik – ekran meczu pokazuje ją na bieżąco i w historii.
class Turn:
	var index: int = 0
	var attackers: MatchTeam
	var defenders: MatchTeam
	## Indeks drużyny z piłką (0 = gospodarze).
	var possession: int = 0
	## Strefa piłki na początku tury (perspektywa drużyny z piłką).
	var ball_zone: int = 3
	## Pole piłki w zagraniu (strefa piłki w kanale pola akcji – PlayCard.get_origin); znane po wyborze.
	var origin := Vector2i.ZERO
	var start_event: StringName = PlayEvents.POSSESSION
	var hand: Array[PlayCard] = []
	## Brak karty do zagrania – piłka od razu przechodzi do rywala.
	var skipped := false
	var choice: MatchAI.PlayChoice
	var card: PlayCard
	var target := Vector2i.ZERO
	var stake := 0.0
	## Energia, którą AI strony może wydać w tej akcji (indeks = int(attacking)).
	var budgets: Array[int] = [0, 0]
	## Czy strona już przesunęła zawodnika (indeks = int(attacking)).
	var shifted: Array[bool] = [false, false]
	var shifts: Array[Dictionary] = []
	var shift_notes := PackedStringArray()
	var contest: PlayContest
	var rerolls: Array[int] = [0, 0]
	var initial_attack := false
	var initial_defense := false
	var outcome: Outcome = Outcome.NONE
	## Wynik karty (PlayCard.OUTCOME_SLOTS) – przy „nikt nie zapełnił” też pojedynek.
	var slot: StringName
	## Zdarzenie efektu wyniku (PlayEvents).
	var event: StringName
	## Bramkarz zapełnił test interwencji i zamienił gola w obronę (event = goalkeeper_save).
	var keeper_save := false
	## Nadwyżka punktów ponad próg (indeks = int(attacking)) – rozstrzyga pojedynek.
	var surplus: Array[float] = [0.0, 0.0]
	var result: Result = Result.KEEP
	## Wynik meczu po turze.
	var score: Array[int] = [0, 0]

var rules: MatchRules
var teams: Array[MatchTeam] = []
var rng := RandomNumberGenerator.new()
## Opcjonalny zbiór statystyk wielu meczów.
var stats: MatchStats
## Zapis przebiegu tura po turze (tylko gdy verbose).
var verbose := false
var log_lines := PackedStringArray()

var score: Array[int] = [0, 0]
var shots: Array[int] = [0, 0]
var possession_turns: Array[int] = [0, 0]
var possession := 0
## Strefa piłki (1..5) w perspektywie drużyny z piłką – piłka nie ma kanału (B2, „Drabina”).
var ball_zone := 3
## Zdarzenie, po którym drużyna z piłką zaczyna turę (PlayEvents) – decyduje o dostępnych kartach.
var last_event: StringName = PlayEvents.POSSESSION
var turn := 0
## Najdalsza strefa bieżącego posiadania (raport „postęp posiadania”, MatchStats); 0 = brak posiadania.
var _possession_reach := 0
## Tura w trakcie rozgrywania (kroki begin_turn … finish_turn).
var current_turn: Turn
## Zapamiętywanie rozegranych tur (oś meczu na ekranie); symulacja wielu meczów tego nie potrzebuje.
var keep_history := false
var history: Array[Turn] = []


static func create(home: MatchTeam, away: MatchTeam, match_rules: MatchRules, seed_value: int) -> MatchEngine:
	var engine := MatchEngine.new()
	engine.teams = [home, away]
	engine.rules = match_rules
	engine.rng.seed = seed_value
	return engine


func play_match() -> void:
	start_match()
	while not is_finished():
		_play_turn()
	_end_possession()
	if stats != null:
		stats.record_match(self)


## Cała tura prowadzona przez AI obu drużyn – te same kroki, które ekran meczu wywołuje po kolei.
func _play_turn() -> void:
	var current := begin_turn()
	if current.skipped:
		return
	choose_ai_play()
	for attacking: bool in [true, false]:
		ai_shift(attacking)
		roll_side(attacking)
		for round_index in rules.reroll_rounds:
			if ai_rerolls(attacking).is_empty():
				break
	finish_turn()


# --- Tura krok po kroku (ekran meczu z graczem) ---
# Tura w dwóch etapach (od 2026-10-28, docs/design/match_v2_plan.md, W12):
# begin_turn → (choose_ai_play | set_play) →
# etap ataku: przesunięcie (ai_shift / apply_shift) → roll_side(true) → przerzuty (ai_rerolls / reroll)
#   → rozmieszczenie kości (place_auto / PlayContest.set_placement) →
# etap obrony: te same kroki dla obrony (obrońca widzi już wynik ataku) → finish_turn.

func start_match() -> void:
	turn = 0
	history.clear()
	_kickoff(0)


func is_finished() -> bool:
	return turn >= rules.get_total_turns()


func get_turns_left() -> int:
	return rules.get_total_turns() - turn


## Minuta na zegarze na początku tury o danym indeksie: połowa trwa od 0' (45') do 45' (90'), tury równo co
## 45 / (tury w połowie − 1) minut – przy 16 turach co 3 minuty.
func get_minute(turn_index: int) -> int:
	var per_half := rules.turns_per_half
	var half := mini(turn_index / per_half, 1)
	var within := turn_index - half * per_half
	return half * 45 + within * 45 / maxi(per_half - 1, 1)


func get_team_index(team: MatchTeam) -> int:
	return teams.find(team)


## Początek tury: przerwa (jeśli trzeba), losowanie ręki drużyny z piłką. Bez pasującej karty piłka
## przechodzi do rywala, a tura się kończy (skipped).
func begin_turn() -> Turn:
	if turn == rules.turns_per_half:
		_half_time()
	current_turn = Turn.new()
	current_turn.index = turn
	current_turn.attackers = teams[possession]
	current_turn.defenders = teams[1 - possession]
	current_turn.possession = possession
	current_turn.ball_zone = ball_zone
	_possession_reach = maxi(_possession_reach, ball_zone)
	current_turn.start_event = last_event
	possession_turns[possession] += 1
	current_turn.hand = _draw_hand(current_turn.attackers)
	if current_turn.hand.is_empty():
		push_warning("MatchEngine: no playable card in zone %d" % ball_zone)
		current_turn.skipped = true
		current_turn.result = _turnover(ball_zone)
		_end_turn()
	return current_turn


## Wybór karty i strony przez AI drużyny z piłką.
func choose_ai_play() -> void:
	var t := current_turn
	var risk := t.attackers.ai.get_risk(score[possession] - score[1 - possession], get_turns_left())
	t.choice = t.attackers.ai.choose_play(t.hand, ball_zone, t.attackers, t.defenders, rules, risk, rng)
	set_play(t.choice.card, t.choice.target)


## Zagrywana karta i pole docelowe (gracz wybiera sam; AI przez choose_ai_play).
func set_play(card: PlayCard, target: Vector2i) -> void:
	var t := current_turn
	t.card = card
	t.target = target
	t.origin = PlayCard.get_origin(ball_zone, target)
	if card.is_shot:
		_possession_reach = maxi(_possession_reach, target.x)
	if t.choice == null:
		# Gracz: szanse liczymy tak jak AI – do statystyk i podpowiedzi na ekranie.
		var odds := PlayContest.create(card, t.origin, target, t.attackers, t.defenders, rules)
		t.choice = MatchAI.PlayChoice.new()
		t.choice.card = card
		t.choice.target = target
		t.choice.attack_chance = DiceOdds.fill_probability(odds, true)
		t.choice.defense_chance = DiceOdds.fill_probability(odds, false)
	t.stake = MatchAI.get_stake(card, t.origin, target, rules)
	var turns_left := get_turns_left()
	t.budgets = [_get_energy_budget(t.defenders, t.stake, turns_left), _get_energy_budget(t.attackers, t.stake, turns_left)]


## Przesunięcie zawodnika strony przez AI (jeśli się opłaca). Obrońca zna już wynik ataku (etap obrony, W12).
## Zwraca {"player", "shift"} albo {}.
func ai_shift(attacking: bool) -> Dictionary:
	var t := current_turn
	var team := t.attackers if attacking else t.defenders
	var attack_surplus := t.contest.get_surplus(true) if not attacking and t.contest != null else NAN
	var shift := team.ai.choose_shift(t.card, t.origin, t.target, t.attackers, t.defenders, attacking,
			t.budgets[int(attacking)], rules, attack_surplus)
	if not shift.is_empty():
		apply_shift(shift["player"], shift["shift"], attacking)
	return shift


## Czy zawodnik może się przesunąć o pole (raz na stronę w turze, nie bramkarz, energia, w granicach boiska).
func can_shift(player: MatchPlayer, direction: Vector2i, attacking: bool) -> bool:
	if current_turn.shifted[int(attacking)] or player.is_goalkeeper() or player.energy < rules.shift_cost:
		return false
	if absi(direction.x) + absi(direction.y) != 1:
		return false
	var cell := player.get_base_cell() + direction
	return cell.x >= 1 and cell.x <= MatchRules.ZONE_COUNT and cell.y >= 0 and cell.y < MatchRules.CHANNEL_COUNT


func apply_shift(player: MatchPlayer, direction: Vector2i, attacking: bool) -> bool:
	if not can_shift(player, direction, attacking):
		return false
	var t := current_turn
	player.shift = direction
	player.spend_energy(rules.shift_cost)
	t.budgets[int(attacking)] -= rules.shift_cost
	t.shifted[int(attacking)] = true
	t.shifts.append({"player": player, "shift": direction, "attacking": attacking})
	if stats != null:
		stats.shifts += 1
	t.shift_notes.append("%s %s>%s" % ["A" if attacking else "D", player.role_id, direction])
	return true


## Rzut kości jednej strony. Kontest powstaje przy rzucie ataku; przy rzucie obrony jej kości liczą się od nowa,
## jeśli obrońca przesunął zawodnika (robi to dopiero po etapie ataku). Zwraca rzucone kości.
func roll_side(attacking: bool) -> Array[PlayContest.ContestDie]:
	var t := current_turn
	if attacking or t.contest == null:
		t.contest = PlayContest.create(t.card, t.origin, t.target, t.attackers, t.defenders, rules)
	if not attacking and t.shifted[0]:
		t.contest.rebuild_side(t.defenders, false, rules)
	t.contest.roll_side(attacking, rng)
	if attacking:
		t.initial_attack = t.contest.is_filled(true)
	else:
		t.initial_defense = t.contest.is_filled(false)
	return t.contest.get_dice(attacking)


## Przerzuty AI strony (jedna runda). Zwraca przerzucone kości.
func ai_rerolls(attacking: bool) -> Array[PlayContest.ContestDie]:
	var t := current_turn
	var team := t.attackers if attacking else t.defenders
	var chosen := team.ai.choose_rerolls(t.contest, attacking, t.budgets[int(attacking)], rules)
	reroll(chosen, attacking)
	return chosen


## Czy strona może przerzucić te kości (właściciel każdej kości ma energię na wszystkie swoje przerzuty).
func can_reroll(dice: Array[PlayContest.ContestDie]) -> bool:
	var cost := {}
	for contest_die in dice:
		cost[contest_die.player] = cost.get(contest_die.player, 0) + rules.reroll_cost
	for player: MatchPlayer in cost:
		if player.energy < cost[player]:
			return false
	return true


## Przerzut kości – płaci właściciel kości.
func reroll(dice: Array[PlayContest.ContestDie], attacking: bool) -> void:
	var t := current_turn
	for contest_die in dice:
		contest_die.player.spend_energy(rules.reroll_cost)
		contest_die.face = contest_die.die.roll(rng)
	t.budgets[int(attacking)] -= dice.size() * rules.reroll_cost
	t.rerolls[int(attacking)] += dice.size()


## Rozmieszczenie kości strony tak, jak liczy automat (najlepsze kości każdego testu) – ruch AI na ekranie.
func place_auto(attacking: bool) -> Dictionary:
	var contest := current_turn.contest
	var placement := contest.get_auto_placement(attacking)
	contest.set_placement(attacking, placement)
	return placement


## Rozstrzygnięcie tury: macierz wyników, pojedynek, efekt karty.
func finish_turn() -> Turn:
	var t := current_turn
	var contest := t.contest
	var card := t.card
	var attack_filled := contest.is_filled(true)
	var defense_filled := contest.is_filled(false)
	var outcome := Outcome.NONE
	if attack_filled and not defense_filled:
		outcome = Outcome.SUCCESS
	elif attack_filled and defense_filled:
		outcome = Outcome.BOTH
	elif defense_filled:
		outcome = Outcome.DEFENSE
	_record_points(contest)
	if card.is_shot:
		shots[possession] += 1

	var team_short := t.attackers.get_short_name()
	var slot := _get_slot(contest, outcome)
	t.outcome = outcome
	t.slot = slot
	t.event = card.get_outcome(slot)
	# Interwencja bramkarza: zaliczony test bramkarza zamienia gola w obronę (piłka u bramkarza).
	if t.event == PlayEvents.GOAL and contest.is_keeper_filled():
		t.event = PlayEvents.GOALKEEPER_SAVE
		t.keeper_save = true
	t.surplus = [contest.get_surplus(false), contest.get_surplus(true)]
	t.result = _apply_effect(contest, t.event)
	if verbose:
		log_lines.append("%02d' %s %s %s%-15s -> %s  A %.1f/%s%s  D %.1f/%s%s  rr %d/%d %s => %s %s%s  [%d:%d]" % [
				get_minute(turn), team_short, _cell_text(t.origin),
				"" if t.start_event == PlayEvents.POSSESSION else "(%s) " % t.start_event, card.id,
				_cell_text(t.target), _sum(contest.get_points(true)), _required_text(card.attack),
				"*" if attack_filled else "", _sum(contest.get_points(false)), _required_text(card.defense),
				"*" if defense_filled else "", t.rerolls[1], t.rerolls[0], " ".join(t.shift_notes),
				slot, t.event, " (GK)" if t.keeper_save else "", score[0], score[1]])
	if stats != null:
		stats.record_play(card, outcome, t.result, t.initial_attack, t.initial_defense, attack_filled, defense_filled,
				t.choice.attack_chance, t.choice.defense_chance)
		stats.rerolls += t.rerolls[0] + t.rerolls[1]
	t.attackers.clear_shifts()
	t.defenders.clear_shifts()
	_end_turn()
	return t


func _end_turn() -> void:
	current_turn.score = score.duplicate()
	if keep_history:
		history.append(current_turn)
	turn += 1


## Wynik karty (PlayCard.OUTCOME_SLOTS): gdy obie strony zapełniły testy albo żadna, rozstrzyga pojedynek.
func _get_slot(contest: PlayContest, outcome: Outcome) -> StringName:
	match outcome:
		Outcome.SUCCESS:
			return &"success"
		Outcome.BOTH:
			return &"duel_won" if _attacker_wins_duel(contest) else &"duel_lost"
		Outcome.DEFENSE:
			return &"defense"
		_:
			return &"duel_won" if _attacker_wins_duel(contest) else &"duel_lost"


## Wykonuje efekt wyniku (zdarzenie PlayEvents) w strefie pola akcji. Piłka ma tylko strefę; po stracie rywal
## zaczyna w lustrzanej strefie. Zasady: docs/design/match_rules.md, „Efekty wyników”.
func _apply_effect(contest: PlayContest, event: StringName) -> Result:
	var zone := contest.target.x
	if stats != null:
		stats.record_event(event)
	match event:
		PlayEvents.GOAL:
			score[possession] += 1
			_kickoff(1 - possession)
			return Result.GOAL
		PlayEvents.ADVANCE:
			ball_zone = zone
			_possession_reach = maxi(_possession_reach, zone)
			last_event = PlayEvents.ADVANCE
			return Result.PROGRESS
		PlayEvents.TURNOVER, PlayEvents.OFFSIDE:
			return _turnover(zone, event)
		PlayEvents.INTERCEPTION:
			return _turnover(contest.flyover[0].x if not contest.flyover.is_empty() else zone, event)
		PlayEvents.CLEARANCE:
			# Broniący wybijają piłkę o clearance_distance stref do przodu (ze swojej perspektywy).
			return _give_ball(mini(_mirror_zone(zone) + rules.clearance_distance, MatchRules.ZONE_COUNT), event)
		PlayEvents.GOALKEEPER_SAVE:
			return _give_ball(1, event)
		PlayEvents.FOUL:
			ball_zone = zone
		PlayEvents.CORNER, PlayEvents.PENALTY:
			ball_zone = MatchRules.ZONE_COUNT
		_:
			# KEEP i POSSESSION: piłka zostaje w swojej strefie.
			event = PlayEvents.KEEP
	last_event = event
	return Result.KEEP


func _attacker_wins_duel(contest: PlayContest) -> bool:
	var attack_surplus := contest.get_surplus(true)
	var defense_surplus := contest.get_surplus(false)
	if is_equal_approx(attack_surplus, defense_surplus):
		return rng.randf() < 0.5
	return attack_surplus > defense_surplus


## Piłkę przejmują broniący w strefie podanej w perspektywie tracących piłkę (lustrzana strefa).
func _turnover(zone: int, event: StringName = PlayEvents.TURNOVER) -> Result:
	return _give_ball(_mirror_zone(zone), event)


## Piłka dla rywala w strefie podanej już w jego perspektywie.
func _give_ball(zone: int, event: StringName) -> Result:
	_end_possession()
	possession = 1 - possession
	ball_zone = zone
	last_event = event
	return Result.TURNOVER


## Koniec posiadania (strata, gol, przerwa, koniec meczu): do statystyk najdalsza strefa, do której doszło.
func _end_possession() -> void:
	if stats != null and _possession_reach > 0:
		stats.record_possession(_possession_reach)
	_possession_reach = 0


static func _mirror_zone(zone: int) -> int:
	return MatchRules.ZONE_COUNT + 1 - zone


func _kickoff(team_index: int) -> void:
	_end_possession()
	possession = team_index
	ball_zone = 3
	last_event = PlayEvents.POSSESSION


func _half_time() -> void:
	for team in teams:
		for player in team.players:
			player.restore_energy(rules.halftime_energy)
	_kickoff(1)
	if verbose:
		log_lines.append("--- przerwa ---")


func _draw_hand(team: MatchTeam) -> Array[PlayCard]:
	var playable := team.get_playable_cards(ball_zone, last_event)
	# Tasowanie Fisher–Yates na RNG meczu (deterministyczne).
	for i in range(playable.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := playable[i]
		playable[i] = playable[j]
		playable[j] = temp
	return playable.slice(0, rules.hand_size)


## Ile energii drużyna może wydać w tej akcji: równe tempo na pozostałe tury × waga akcji.
func _get_energy_budget(team: MatchTeam, stake: float, turns_left: int) -> int:
	var per_turn := float(team.get_total_energy()) / maxi(turns_left, 1)
	var importance := clampf(stake / rules.reference_stake, 0.5, 3.0)
	return roundi(per_turn * rules.reroll_pacing * importance)


func _record_points(contest: PlayContest) -> void:
	for attacking: bool in [true, false]:
		var used := contest.get_used_dice(attacking)
		var placement := contest.get_placement(attacking) if contest.has_placement(attacking) else {}
		for contest_die in contest.get_dice(attacking):
			if contest.get_requirement_index(contest_die, attacking) == -1 and not placement.has(contest_die):
				continue
			var points := contest.get_die_points(contest_die)
			if placement.has(contest_die):
				points = contest.get_die_points_in_test(contest_die, placement[contest_die])
			var player := contest_die.player
			if used.has(contest_die):
				if attacking:
					player.points_attack += points
				else:
					player.points_defense += points
			elif attacking:
				player.points_attack_cut += points
			else:
				player.points_defense_cut += points
	if stats != null:
		stats.record_target(contest.target)


static func _cell_text(cell: Vector2i) -> String:
	return "%d%s" % [cell.x, MatchRules.channel_letter(cell.y)]


static func _sum(values: PackedFloat64Array) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total


static func _required_text(requirements: Array[PlayRequirement]) -> String:
	var total := 0.0
	for requirement in requirements:
		total += requirement.points
	return str(total)

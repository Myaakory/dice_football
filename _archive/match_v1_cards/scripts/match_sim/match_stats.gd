class_name MatchStats
extends RefCounted
## Statystyki zebrane z wielu symulowanych meczów – raport do strojenia zasad (PROTOTYP).

enum CardStat { PLAYS, ATTACK_FIRST_ROLL, DEFENSE_FIRST_ROLL, ATTACK_FILLED, DEFENSE_FILLED,
		SUCCESS, BOTH, DEFENSE, NONE, PROGRESS, GOAL, KEEP, TURNOVER, COUNT }

var matches := 0
var goals: Array[int] = [0, 0]
var shots: Array[int] = [0, 0]
var possession_turns: Array[int] = [0, 0]
var wins: Array[int] = [0, 0]
var draws := 0
## Liczba goli w meczu -> liczba meczów.
var goal_histogram: Dictionary[int, int] = {}
var rerolls := 0
var shifts := 0
var energy_spent := 0
var exhausted_players := 0
var player_appearances := 0
var elapsed_usec := 0
## id karty -> liczniki CardStat.
var cards: Dictionary[StringName, PackedInt32Array] = {}
## id karty -> [suma przewidywanej szansy ataku, suma przewidywanej szansy obrony].
var card_predictions: Dictionary[StringName, PackedFloat64Array] = {}
## rola -> [punkty w ataku, punkty w obronie, liczba występów, odcięte w ataku, odcięte w obronie].
var roles: Dictionary[StringName, PackedFloat64Array] = {}
## Pole docelowe akcji (perspektywa atakującego): strefa 1..5 -> liczba, korytarz L/C/R -> liczba.
var target_zones := PackedInt32Array([0, 0, 0, 0, 0])
var target_channels := PackedInt32Array([0, 0, 0])
## Efekt wyniku (PlayEvents) -> liczba.
var events: Dictionary[StringName, int] = {}
var role_order: Array[StringName] = []


func record_play(card: PlayCard, outcome: MatchEngine.Outcome, result: MatchEngine.Result,
		attack_first_roll: bool, defense_first_roll: bool, attack_filled: bool, defense_filled: bool,
		predicted_attack: float, predicted_defense: float) -> void:
	if not cards.has(card.id):
		var counters := PackedInt32Array()
		counters.resize(CardStat.COUNT)
		cards[card.id] = counters
		card_predictions[card.id] = PackedFloat64Array([0.0, 0.0])
	var stat := cards[card.id]
	stat[CardStat.PLAYS] += 1
	stat[CardStat.ATTACK_FIRST_ROLL] += int(attack_first_roll)
	stat[CardStat.DEFENSE_FIRST_ROLL] += int(defense_first_roll)
	stat[CardStat.ATTACK_FILLED] += int(attack_filled)
	stat[CardStat.DEFENSE_FILLED] += int(defense_filled)
	stat[CardStat.SUCCESS + outcome] += 1
	stat[CardStat.PROGRESS + result] += 1
	var prediction := card_predictions[card.id]
	prediction[0] += predicted_attack
	prediction[1] += predicted_defense
	# Packed*Array w słowniku może być kopią – zapisujemy z powrotem.
	cards[card.id] = stat
	card_predictions[card.id] = prediction


func record_event(event: StringName) -> void:
	events[event] = events.get(event, 0) + 1


func record_target(target: Vector2i) -> void:
	target_zones[target.x - 1] += 1
	target_channels[target.y] += 1


func record_match(engine: MatchEngine) -> void:
	matches += 1
	for i in 2:
		goals[i] += engine.score[i]
		shots[i] += engine.shots[i]
		possession_turns[i] += engine.possession_turns[i]
	if engine.score[0] > engine.score[1]:
		wins[0] += 1
	elif engine.score[1] > engine.score[0]:
		wins[1] += 1
	else:
		draws += 1
	var total_goals := engine.score[0] + engine.score[1]
	goal_histogram[total_goals] = goal_histogram.get(total_goals, 0) + 1
	for team in engine.teams:
		for player in team.players:
			player_appearances += 1
			energy_spent += player.energy_spent
			if player.energy <= 0:
				exhausted_players += 1
			if not roles.has(player.role_id):
				roles[player.role_id] = PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
				role_order.append(player.role_id)
			var role := roles[player.role_id]
			role[0] += player.points_attack
			role[1] += player.points_defense
			role[2] += 1.0
			role[3] += player.points_attack_cut
			role[4] += player.points_defense_cut
			roles[player.role_id] = role


func build_report(home_name: String, away_name: String) -> String:
	var lines := PackedStringArray()
	var n := maxi(matches, 1)
	lines.append("=== Symulacja: %d meczów, %s vs %s ===" % [matches, home_name, away_name])
	lines.append("Czas: %.2f ms / mecz" % (elapsed_usec / 1000.0 / n))
	lines.append("Gole / mecz: %.2f (%s %.2f, %s %.2f)" % [
			float(goals[0] + goals[1]) / n, home_name, float(goals[0]) / n, away_name, float(goals[1]) / n])
	lines.append("Strzały / mecz: %s %.2f, %s %.2f | skuteczność %.0f%%" % [
			home_name, float(shots[0]) / n, away_name, float(shots[1]) / n,
			100.0 * (goals[0] + goals[1]) / maxi(shots[0] + shots[1], 1)])
	lines.append("Wyniki: %s %d, remisy %d, %s %d" % [home_name, wins[0], draws, away_name, wins[1]])
	var turns_total := maxi(possession_turns[0] + possession_turns[1], 1)
	lines.append("Posiadanie (tury): %s %.0f%%, %s %.0f%%" % [
			home_name, 100.0 * possession_turns[0] / turns_total, away_name, 100.0 * possession_turns[1] / turns_total])
	var histogram := PackedStringArray()
	var keys := goal_histogram.keys()
	keys.sort()
	for total in keys:
		histogram.append("%d:%.0f%%" % [total, 100.0 * goal_histogram[total] / n])
	lines.append("Rozkład goli w meczu: %s" % " ".join(histogram))
	var zone_total := 0
	for count in target_zones:
		zone_total += count
	zone_total = maxi(zone_total, 1)
	var zone_parts := PackedStringArray()
	for i in target_zones.size():
		zone_parts.append("%d:%.0f%%" % [i + 1, 100.0 * target_zones[i] / zone_total])
	lines.append("Pole akcji (strefa celu z perspektywy atakującego): %s | korytarz L %.0f%% C %.0f%% R %.0f%%" % [
			" ".join(zone_parts), 100.0 * target_channels[0] / zone_total, 100.0 * target_channels[1] / zone_total,
			100.0 * target_channels[2] / zone_total])
	var event_parts := PackedStringArray()
	for event_id in PlayEvents.IDS:
		if events.has(event_id):
			event_parts.append("%s %.1f" % [event_id, float(events[event_id]) / n])
	lines.append("Efekty wyników / mecz: %s" % ", ".join(event_parts))
	lines.append("Energia: wydana %.1f / zawodnika / mecz, wyczerpani na koniec %.0f%% | przerzuty %.1f / mecz, przesunięcia %.1f / mecz" % [
			float(energy_spent) / maxi(player_appearances, 1), 100.0 * exhausted_players / maxi(player_appearances, 1),
			float(rerolls) / n, float(shifts) / n])

	lines.append("")
	lines.append("Karty (%% z zagrań; P = przewidziana szansa AI, 1. = po pierwszym rzucie, kon. = po przerzutach):")
	lines.append("%-15s %6s | %-15s | %-15s | %4s %4s %4s %4s | %5s %4s %4s %5s" % [
			"karta", "zagr/m", "atak P/1./kon.", "obr. P/1./kon.", "SUK", "OBA", "ODB", "NIC",
			"post", "gol", "trzy", "strata"])
	var card_ids := cards.keys()
	card_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return cards[a][CardStat.PLAYS] > cards[b][CardStat.PLAYS])
	for card_id: StringName in card_ids:
		var stat := cards[card_id]
		var plays := maxf(stat[CardStat.PLAYS], 1.0)
		var prediction := card_predictions[card_id]
		lines.append("%-15s %6.2f | %3.0f %3.0f %3.0f     | %3.0f %3.0f %3.0f     | %4.0f %4.0f %4.0f %4.0f | %5.0f %4.0f %4.0f %5.0f" % [
				card_id, stat[CardStat.PLAYS] / float(n),
				100.0 * prediction[0] / plays, 100.0 * stat[CardStat.ATTACK_FIRST_ROLL] / plays,
				100.0 * stat[CardStat.ATTACK_FILLED] / plays,
				100.0 * prediction[1] / plays, 100.0 * stat[CardStat.DEFENSE_FIRST_ROLL] / plays,
				100.0 * stat[CardStat.DEFENSE_FILLED] / plays,
				100.0 * stat[CardStat.SUCCESS] / plays, 100.0 * stat[CardStat.BOTH] / plays,
				100.0 * stat[CardStat.DEFENSE] / plays, 100.0 * stat[CardStat.NONE] / plays,
				100.0 * stat[CardStat.PROGRESS] / plays, 100.0 * stat[CardStat.GOAL] / plays,
				100.0 * stat[CardStat.KEEP] / plays, 100.0 * stat[CardStat.TURNOVER] / plays])

	lines.append("")
	lines.append("Wkład ról (liczone punkty z kości trafiające w wymagania, średnio na występ w meczu; odc. = rzucone, ale poza limitem kości):")
	lines.append("%-5s %6s %6s %6s %7s %7s %6s" % ["rola", "atak", "obrona", "razem", "odc.at", "odc.ob", "występy"])
	for role_id in role_order:
		var role := roles[role_id]
		var appearances := maxf(role[2], 1.0)
		lines.append("%-5s %6.1f %6.1f %6.1f %7.1f %7.1f %6d" % [role_id, role[0] / appearances, role[1] / appearances,
				(role[0] + role[1]) / appearances, role[3] / appearances, role[4] / appearances, int(role[2])])
	return "\n".join(lines)

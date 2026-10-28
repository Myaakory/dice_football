class_name MatchTeam
extends RefCounted
## Drużyna w trakcie meczu: jedenastka jako MatchPlayer, talia kart, profil AI i modyfikatory udziału (perki trenera).

var lineup: Lineup
var players: Array[MatchPlayer] = []
var deck: Array[PlayCard] = []
var ai: MatchAI
## Modyfikatory udziału drużyny ponad zasady podstawowe – perki trenera (CoachData.perks).
var participation_modifiers: Array[ParticipationModifier] = []


## team_ai: null = AI z profilem ryzyka trenera drużyny (bez trenera – neutralne).
static func create(team_lineup: Lineup, team_deck: Array[PlayCard], rules: MatchRules, team_ai: MatchAI = null) -> MatchTeam:
	var team := MatchTeam.new()
	team.lineup = team_lineup
	team.deck = team_deck
	var coach := team_lineup.team.coach
	team.ai = team_ai if team_ai != null else MatchAI.create(coach.risk_aversion if coach != null else 1.0)
	if coach != null:
		for perk in coach.perks:
			team.participation_modifiers.append(perk.modifier)
	for slot in team_lineup.tactic.slots:
		var player := team_lineup.get_player_at(slot.index)
		if player != null:
			team.players.append(MatchPlayer.create(player, slot, team_lineup.get_active_dice(player), rules))
	return team


func get_short_name() -> String:
	return lineup.team.short_name


func get_total_energy() -> int:
	var total := 0
	for player in players:
		total += maxi(player.energy, 0)
	return total


func clear_shifts() -> void:
	for player in players:
		player.shift = Vector2i.ZERO


## Modyfikatory udziału zawodników drużyny: zasady podstawowe i własne (perki).
func get_participation_modifiers(rules: MatchRules) -> Array[ParticipationModifier]:
	if participation_modifiers.is_empty():
		return rules.get_participation_modifiers()
	var result := rules.get_participation_modifiers().duplicate()
	result.append_array(participation_modifiers)
	return result


## Karty, które można zagrać z piłką w danej strefie po zdarzeniu `event` (PlayEvents): karty zwykłego posiadania
## i karty z tym zdarzeniem w warunkach. Po stałym fragmencie (PlayEvents.is_exclusive) tylko karty z tym
## zdarzeniem – jeśli żadnej nie ma, gra toczy się dalej kartami zwykłego posiadania.
func get_playable_cards(zone: int, event: StringName = PlayEvents.POSSESSION) -> Array[PlayCard]:
	var result: Array[PlayCard] = []
	if PlayEvents.is_exclusive(event):
		for card in deck:
			if card.can_play_zone(zone) and card.is_triggered_by(event):
				result.append(card)
		if not result.is_empty():
			return result
		event = PlayEvents.POSSESSION
	for card in deck:
		if card.can_play_zone(zone) and (card.is_triggered_by(PlayEvents.POSSESSION) or card.is_triggered_by(event)):
			result.append(card)
	return result

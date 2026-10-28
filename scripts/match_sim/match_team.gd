class_name MatchTeam
extends RefCounted
## Drużyna w trakcie meczu: jedenastka jako MatchPlayer, talia kart, profil AI i modyfikatory udziału.

var lineup: Lineup
var players: Array[MatchPlayer] = []
var deck: Array[PlayCard] = []
var ai: MatchAI
## Modyfikatory udziału drużyny ponad zasady podstawowe (perki trenera – B5a; na razie puste).
var participation_modifiers: Array[ParticipationModifier] = []


static func create(team_lineup: Lineup, team_deck: Array[PlayCard], rules: MatchRules, team_ai: MatchAI) -> MatchTeam:
	var team := MatchTeam.new()
	team.lineup = team_lineup
	team.deck = team_deck
	team.ai = team_ai
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

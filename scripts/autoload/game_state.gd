extends Node
## Stan bieżącej rozgrywki przekazywany między scenami (wybrane składy itp.).

## Drużyna prowadzona przez gracza w prototypie; pozostałe drużyny prowadzi komputer.
const PLAYER_TEAM_ID: StringName = &"red"

var player_lineup: Lineup
var opponent_lineup: Lineup


func get_player_team() -> TeamData:
	var team := GameData.get_team(PLAYER_TEAM_ID)
	return team if team != null else GameData.get_team_list().front()


## Zapisuje skład gracza i przygotowuje domyślny skład rywala.
func start_match(lineup: Lineup) -> void:
	player_lineup = lineup
	opponent_lineup = Lineup.create_default(get_opponent_team(lineup.team))


func get_opponent_team(team: TeamData) -> TeamData:
	for other in GameData.get_team_list():
		if other != team:
			return other
	return team


## Mecz z domyślnymi składami – używane przy uruchamianiu scen bezpośrednio (F6) do testów.
func setup_quick_match() -> void:
	start_match(Lineup.create_default(get_player_team()))

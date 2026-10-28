class_name Lineup
extends RefCounted
## Skład meczowy drużyny: taktyka, przypisanie zawodników do pozycji i wybór aktywnych kości.

signal changed

## Ile kości z posiadanych zawodnik może używać w meczu.
const ACTIVE_DICE_COUNT := 2

var team: TeamData
var tactic: TacticData
## Zawodnik na każdej pozycji formacji (indeks = FormationSlot.index). null = pusta pozycja.
var slot_players: Array[PlayerData] = []
## Rezerwowi w ustalonej kolejności (indeks 0 = R1).
var bench_players: Array[PlayerData] = []
## player_id -> indeksy aktywnych kości (w kolejności wyboru; najstarszy wybór wypada pierwszy).
var active_dice: Dictionary[StringName, Array] = {}
## player_id zawodników, którym aktywne kości narzuciła rola (RoleData.preferred_dice) – po zejściu z roli
## wracają do kości swojej pozycji.
var _role_dice_players: Dictionary[StringName, bool] = {}


## Tworzy skład z domyślną taktyką drużyny i automatycznie wybraną jedenastką.
static func create_default(team_data: TeamData, tactic_data: TacticData = null) -> Lineup:
	var lineup := Lineup.new()
	lineup.team = team_data
	lineup.tactic = tactic_data if tactic_data != null else GameData.get_default_tactic(team_data)
	for player in team_data.players:
		lineup.active_dice[player.id] = _default_active_dice(player)
	lineup._assign_players(team_data.players, [])
	lineup._sort_bench_by_position()
	lineup._refresh_role_dice()
	return lineup


# --- Odczyt ---

func get_player_at(slot_index: int) -> PlayerData:
	return slot_players[slot_index]


## Indeks pozycji zawodnika w formacji albo -1, jeśli siedzi na ławce.
func get_player_slot(player: PlayerData) -> int:
	return slot_players.find(player)


func is_starter(player: PlayerData) -> bool:
	return get_player_slot(player) != -1


func get_starters() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player in slot_players:
		if player != null:
			result.append(player)
	return result


func get_bench() -> Array[PlayerData]:
	return bench_players.duplicate()


## Indeks zawodnika na ławce (0 = R1) albo -1, jeśli gra na boisku.
func get_bench_index(player: PlayerData) -> int:
	return bench_players.find(player)


func get_active_dice_indices(player: PlayerData) -> Array[int]:
	var result: Array[int] = []
	result.assign(active_dice.get(player.id, []))
	return result


func get_active_dice(player: PlayerData) -> Array[DieData]:
	var result: Array[DieData] = []
	for die_index in get_active_dice_indices(player):
		result.append(player.dice[die_index])
	return result


func is_die_active(player: PlayerData, die_index: int) -> bool:
	return die_index in active_dice.get(player.id, [])


## Zwraca listę kluczy tłumaczeń opisujących problemy ze składem (pusta = skład poprawny).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if slot_players.has(null):
		errors.append("ERROR_INCOMPLETE_LINEUP")
	for slot in tactic.slots:
		if slot.role_id == PositionData.GOALKEEPER:
			var keeper := slot_players[slot.index]
			if keeper == null or not keeper.is_goalkeeper():
				errors.append("ERROR_NEED_GOALKEEPER")
	return errors


func is_valid() -> bool:
	return validate().is_empty()


# --- Zmiany ---

## Zmienia taktykę, zachowując obecną jedenastkę (zawodnicy rozstawiani są wg pasujących pozycji).
func set_tactic(new_tactic: TacticData) -> void:
	if new_tactic == tactic:
		return
	var starters := get_starters()
	var bench := get_bench()
	tactic = new_tactic
	_assign_players(starters, bench)
	_refresh_role_dice()
	changed.emit()


## Automatycznie wybiera najlepiej pasujących zawodników z całej kadry.
func auto_pick() -> void:
	_assign_players(team.players, [])
	_sort_bench_by_position()
	_refresh_role_dice()
	changed.emit()


## Zamienia miejscami dwóch zawodników (pozycja na boisku ↔ pozycja na boisku / miejsce na ławce).
func swap_players(player_a: PlayerData, player_b: PlayerData) -> void:
	if player_a == player_b:
		return
	var slot_a := get_player_slot(player_a)
	var bench_a := get_bench_index(player_a)
	var slot_b := get_player_slot(player_b)
	var bench_b := get_bench_index(player_b)
	_place(player_a, slot_b, bench_b)
	_place(player_b, slot_a, bench_a)
	_refresh_role_dice()
	changed.emit()


## Przenosi zawodnika na pozycję w formacji. Zajęta pozycja = zamiana z obecnym zawodnikiem.
func move_player_to_slot(slot_index: int, player: PlayerData) -> void:
	var occupant := slot_players[slot_index]
	if occupant != null:
		swap_players(player, occupant)
		return
	var previous_slot := get_player_slot(player)
	if previous_slot != -1:
		slot_players[previous_slot] = null
	bench_players.erase(player)
	slot_players[slot_index] = player
	_refresh_role_dice()
	changed.emit()


## Aktywuje kość zawodnika. Gdy aktywnych jest już ACTIVE_DICE_COUNT, wypada najdawniej wybrana.
func activate_die(player: PlayerData, die_index: int) -> void:
	var selected: Array = active_dice.get(player.id, [])
	if die_index in selected:
		return
	selected.append(die_index)
	while selected.size() > ACTIVE_DICE_COUNT:
		selected.pop_front()
	active_dice[player.id] = selected
	changed.emit()


# --- Wewnętrzne ---

## Rozstawia zawodników na pozycjach: najpierw z listy `primary`, braki uzupełnia z `reserve`.
## Niewykorzystani zawodnicy trafiają na ławkę w kolejności z list.
func _assign_players(primary: Array[PlayerData], reserve: Array[PlayerData]) -> void:
	slot_players.clear()
	slot_players.resize(tactic.get_slot_count())
	var pools := [primary.duplicate(), reserve.duplicate()]
	for candidates: Array in pools:
		# 1. Zawodnicy na swoich nominalnych pozycjach.
		for slot in tactic.slots:
			if slot_players[slot.index] == null:
				var wanted_position := GameData.get_role_position_id(slot.role_id)
				slot_players[slot.index] = _take_player(candidates,
						func(p: PlayerData) -> bool: return p.position_id == wanted_position)
		# 2. Pozostałe pozycje – dowolny zawodnik z pola (bramkarz tylko w ostateczności).
		for slot in tactic.slots:
			if slot_players[slot.index] == null:
				slot_players[slot.index] = _take_player(candidates,
						func(p: PlayerData) -> bool: return not p.is_goalkeeper())
		for slot in tactic.slots:
			if slot_players[slot.index] == null:
				slot_players[slot.index] = _take_player(candidates, func(_p: PlayerData) -> bool: return true)
	bench_players.clear()
	for candidates: Array in pools:
		bench_players.append_array(candidates)


## Kolejność rezerwowych wg pozycji: bramkarze, obrońcy, pomocnicy, napastnicy (stabilnie wg kadry).
func _sort_bench_by_position() -> void:
	var team_order := team.players
	bench_players.sort_custom(func(a: PlayerData, b: PlayerData) -> bool:
		var order_a := GameData.get_position_order(a.position_id)
		var order_b := GameData.get_position_order(b.position_id)
		if order_a != order_b:
			return order_a < order_b
		return team_order.find(a) < team_order.find(b))


func _place(player: PlayerData, slot_index: int, bench_index: int) -> void:
	if slot_index != -1:
		slot_players[slot_index] = player
	elif bench_index != -1:
		bench_players[bench_index] = player


static func _take_player(pool: Array, predicate: Callable) -> PlayerData:
	for i in pool.size():
		if predicate.call(pool[i]):
			var player: PlayerData = pool[i]
			pool.remove_at(i)
			return player
	return null


## Zawodnicy na rolach z własnymi kośćmi (np. DM) dostają je jako aktywne; po zejściu z takiej roli
## wracają do kości swojej pozycji. Ręcznie wybrane kości pozostałych zawodników się nie zmieniają.
func _refresh_role_dice() -> void:
	for player in team.players:
		var slot_index := get_player_slot(player)
		var role := GameData.get_role(tactic.slots[slot_index].role_id) if slot_index != -1 else null
		if role != null and not role.preferred_dice.is_empty():
			active_dice[player.id] = _default_active_dice(player, role.preferred_dice)
			_role_dice_players[player.id] = true
		elif _role_dice_players.has(player.id):
			active_dice[player.id] = _default_active_dice(player)
			_role_dice_players.erase(player.id)


## Domyślne aktywne kości: wg podanych typów (np. z roli) albo preferencji pozycji zawodnika,
## uzupełnione kolejnymi kośćmi.
static func _default_active_dice(player: PlayerData, preferred: Array[StringName] = []) -> Array[int]:
	var result: Array[int] = []
	if preferred.is_empty():
		var position := GameData.get_position(player.position_id)
		if position != null:
			preferred = position.preferred_dice
	for die_type_id in preferred:
		for i in player.dice.size():
			if result.size() < ACTIVE_DICE_COUNT and player.dice[i].type.id == die_type_id and i not in result:
				result.append(i)
				break
	for i in player.dice.size():
		if result.size() >= ACTIVE_DICE_COUNT:
			break
		if i not in result:
			result.append(i)
	return result

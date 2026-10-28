extends Node
## Dane gry wczytywane z plików CSV w res://data/.
## Każdy plik CSV to eksport jednej zakładki arkusza Google Sheets (nazwa pliku = nazwa zakładki).
## Opis kolumn: res://data/README.md

const DATA_DIR := "res://data/"

var attributes: Dictionary[StringName, AttributeData] = {}
var die_types: Dictionary[StringName, DieTypeData] = {}
var positions: Dictionary[StringName, PositionData] = {}
var roles: Dictionary[StringName, RoleData] = {}
var tactics: Dictionary[StringName, TacticData] = {}
var teams: Dictionary[StringName, TeamData] = {}
var players: Dictionary[StringName, PlayerData] = {}
var perks: Dictionary[StringName, PerkData] = {}
var coaches: Dictionary[StringName, CoachData] = {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	for table: Dictionary in [attributes, die_types, positions, roles, tactics, teams, players, perks, coaches]:
		table.clear()
	_load_attributes()
	_load_die_types()
	_load_positions()
	_load_roles()
	_load_perks()
	_load_tactics()
	_load_tactic_slots()
	_load_teams()
	_load_coaches()
	_load_players()
	_load_player_dice()
	print_verbose("GameData: %d teams, %d players, %d tactics" % [teams.size(), players.size(), tactics.size()])


# --- Dostęp ---

func get_attribute(id: StringName) -> AttributeData:
	return attributes.get(id)


func get_die_type(id: StringName) -> DieTypeData:
	return die_types.get(id)


func get_position(id: StringName) -> PositionData:
	return positions.get(id)


## Kolejność pozycji z positions.csv (GK, DF, MF, FW) – do sortowania.
func get_position_order(id: StringName) -> int:
	var index := positions.keys().find(id)
	return index if index != -1 else positions.size()


func get_role(id: StringName) -> RoleData:
	return roles.get(id)


func get_role_position_id(role_id: StringName) -> StringName:
	var role := get_role(role_id)
	return role.position_id if role != null else &""


func get_tactic(id: StringName) -> TacticData:
	return tactics.get(id)


func get_team(id: StringName) -> TeamData:
	return teams.get(id)


func get_player(id: StringName) -> PlayerData:
	return players.get(id)


func get_team_list() -> Array[TeamData]:
	var result: Array[TeamData] = []
	result.assign(teams.values())
	return result


func get_tactic_list() -> Array[TacticData]:
	var result: Array[TacticData] = []
	result.assign(tactics.values())
	return result


func get_default_tactic(team: TeamData) -> TacticData:
	var tactic := get_tactic(team.default_tactic_id)
	return tactic if tactic != null else get_tactic_list().front()


# --- Wczytywanie ---

func _read(file_name: String) -> Array[Dictionary]:
	return CsvLoader.load_table(DATA_DIR + file_name)


func _load_attributes() -> void:
	for row in _read("attributes.csv"):
		var attribute := AttributeData.new()
		attribute.id = StringName(row["id"])
		attribute.die_type_id = StringName(row["die_type"])
		attribute.name_key = row["name_key"]
		attribute.short_key = row["short_key"]
		attributes[attribute.id] = attribute


func _load_die_types() -> void:
	for row in _read("die_types.csv"):
		var die_type := DieTypeData.new()
		die_type.id = StringName(row["id"])
		die_type.name_key = row["name_key"]
		die_type.color = Color.from_string(row["color"], Color.WHITE)
		var face := 1
		while row.has("face_%d" % face) and not row["face_%d" % face].is_empty():
			var attribute_id := StringName(row["face_%d" % face])
			if not attributes.has(attribute_id):
				push_warning("GameData: die type '%s' uses unknown attribute '%s'" % [die_type.id, attribute_id])
			die_type.face_attributes.append(attribute_id)
			face += 1
		die_types[die_type.id] = die_type


func _load_positions() -> void:
	for row in _read("positions.csv"):
		var position := PositionData.new()
		position.id = StringName(row["id"])
		position.name_key = row["name_key"]
		position.short_key = row["short_key"]
		position.preferred_dice = CsvLoader.split_list(row["preferred_dice"])
		positions[position.id] = position


func _load_roles() -> void:
	for row in _read("roles.csv"):
		var role := RoleData.new()
		role.id = StringName(row["id"])
		role.name_key = row["name_key"]
		role.short_key = row["short_key"]
		role.position_id = StringName(row["position"])
		role.preferred_dice = CsvLoader.split_list(row.get("preferred_dice", ""))
		if not positions.has(role.position_id):
			push_warning("GameData: role '%s' has unknown position '%s'" % [role.id, role.position_id])
		roles[role.id] = role


func _load_tactics() -> void:
	for row in _read("tactics.csv"):
		var tactic := TacticData.new()
		tactic.id = StringName(row["id"])
		tactic.name = row["name"]
		tactic.description_key = row["description_key"]
		tactics[tactic.id] = tactic


func _load_tactic_slots() -> void:
	var order := {}  # FormationSlot -> numer z kolumny "slot" (do sortowania)
	for row in _read("tactic_slots.csv"):
		var tactic := get_tactic(StringName(row["tactic_id"]))
		if tactic == null:
			push_warning("GameData: tactic slot for unknown tactic '%s'" % row["tactic_id"])
			continue
		var slot := FormationSlot.new()
		slot.role_id = StringName(row["role"])
		slot.lane = clampi(row["lane"].to_int(), 1, FormationSlot.LANE_COUNT)
		slot.x = clampf(row["x"].to_float() / 100.0, 0.0, 1.0)
		slot.depth = clampf(row["depth"].to_float() / 100.0, 0.0, 1.0)
		if not roles.has(slot.role_id):
			push_warning("GameData: tactic '%s' uses unknown role '%s'" % [tactic.id, slot.role_id])
		order[slot] = row["slot"].to_int()
		tactic.slots.append(slot)
	for tactic in tactics.values():
		tactic.slots.sort_custom(func(a: FormationSlot, b: FormationSlot) -> bool: return order[a] < order[b])
		for i in tactic.slots.size():
			tactic.slots[i].index = i
		if tactic.slots.size() != 11:
			push_warning("GameData: tactic '%s' has %d slots (expected 11)" % [tactic.id, tactic.slots.size()])


func _load_teams() -> void:
	for row in _read("teams.csv"):
		var team := TeamData.new()
		team.id = StringName(row["id"])
		team.name = row["name"]
		team.short_name = row["short_name"]
		team.primary_color = Color.from_string(row["primary_color"], Color.WHITE)
		team.secondary_color = Color.from_string(row["secondary_color"], Color.BLACK)
		team.default_tactic_id = StringName(row["default_tactic"])
		if not tactics.has(team.default_tactic_id):
			push_warning("GameData: team '%s' has unknown default tactic '%s'" % [team.id, team.default_tactic_id])
		teams[team.id] = team


## Perki trenerów: relacja (action / support / passer / flyover), strona (attack / defense / puste = obie), role
## i strefy (lista „|”, puste = wszystkie), kanał (center / wing / puste = każdy), mnożnik.
func _load_perks() -> void:
	const RELATIONS: Array[String] = ["action", "support", "passer", "flyover"]
	const SIDES: Array[String] = ["", "attack", "defense"]
	const LANES: Array[String] = ["", "center", "wing"]
	for row in _read("perks.csv"):
		var perk := PerkData.new()
		perk.id = StringName(row["id"])
		perk.name_key = row["name_key"]
		perk.description_key = row["description_key"]
		var relation := RELATIONS.find(row["relation"])
		var side := SIDES.find(row.get("side", ""))
		var lane := LANES.find(row.get("lane", ""))
		if relation == -1 or side == -1 or lane == -1:
			push_warning("GameData: perk '%s' has unknown relation, side or lane" % perk.id)
			continue
		var modifier := ParticipationModifier.create(relation as ParticipationModifier.Relation,
				float(row["weight"]), side as ParticipationModifier.SideFilter)
		modifier.roles = CsvLoader.split_list(row.get("roles", ""))
		for role_id in modifier.roles:
			if not roles.has(role_id):
				push_warning("GameData: perk '%s' has unknown role '%s'" % [perk.id, role_id])
		for zone in CsvLoader.split_list(row.get("zones", "")):
			modifier.zones.append(int(String(zone)))
		modifier.lane = lane as ParticipationModifier.LaneFilter
		perk.modifier = modifier
		perks[perk.id] = perk


## Trenerzy drużyn (jeden na drużynę): profil ryzyka w procentach (100 = neutralny) i perki (lista „|”).
func _load_coaches() -> void:
	for row in _read("coaches.csv"):
		var coach := CoachData.new()
		coach.id = StringName(row["id"])
		coach.team_id = StringName(row["team_id"])
		coach.first_name = row["first_name"]
		coach.last_name = row["last_name"]
		coach.risk_aversion = row.get("risk_percent", "100").to_float() / 100.0
		for perk_id in CsvLoader.split_list(row.get("perks", "")):
			if perks.has(perk_id):
				coach.perks.append(perks[perk_id])
			else:
				push_warning("GameData: coach '%s' has unknown perk '%s'" % [coach.id, perk_id])
		var team: TeamData = teams.get(coach.team_id)
		if team == null:
			push_warning("GameData: coach '%s' has unknown team '%s'" % [coach.id, coach.team_id])
		else:
			team.coach = coach
		coaches[coach.id] = coach


func _load_players() -> void:
	for row in _read("players.csv"):
		var player := PlayerData.new()
		player.id = StringName(row["id"])
		player.team_id = StringName(row["team_id"])
		player.number = row["number"].to_int()
		player.first_name = row["first_name"]
		player.last_name = row["last_name"]
		player.position_id = StringName(row["position"])
		player.age = row.get("age", "0").to_int()
		player.natural_roles = CsvLoader.split_list(row.get("natural_roles", ""))
		player.secondary_roles = CsvLoader.split_list(row.get("secondary_roles", ""))
		if player.natural_roles.is_empty():
			for role: RoleData in roles.values():
				if role.position_id == player.position_id:
					player.natural_roles.append(role.id)
		if not positions.has(player.position_id):
			push_warning("GameData: player '%s' has unknown position '%s'" % [player.id, player.position_id])
		var team := get_team(player.team_id)
		if team == null:
			push_warning("GameData: player '%s' belongs to unknown team '%s'" % [player.id, player.team_id])
			continue
		team.players.append(player)
		players[player.id] = player


func _load_player_dice() -> void:
	for row in _read("player_dice.csv"):
		var player := get_player(StringName(row["player_id"]))
		var die_type := get_die_type(StringName(row["die_type"]))
		if player == null or die_type == null:
			push_warning("GameData: invalid player die row %s" % row)
			continue
		var die := DieData.new()
		die.slot = row["slot"].to_int()
		die.type = die_type
		for face in die_type.face_attributes.size():
			die.face_values.append(row.get("face_%d" % (face + 1), "0").to_int())
		player.dice.append(die)
	for player in players.values():
		player.dice.sort_custom(func(a: DieData, b: DieData) -> bool: return a.slot < b.slot)
		if player.dice.size() < Lineup.ACTIVE_DICE_COUNT:
			push_warning("GameData: player '%s' has only %d dice" % [player.id, player.dice.size()])

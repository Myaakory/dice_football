class_name PlayCard
extends RefCounted
## Karta zagrania taktycznego. PROTOTYP – zasady: res://docs/design/match_rules.md.
## Pola boiska podawane są jako Vector2i(strefa 1..5, kanał 0..2) w perspektywie drużyny z piłką.
## Karty żyją w res://data/plays/plays.json (PlayLibrary) i edytuje się je w grze (Edytor zagrań).

## Kierunek ruchu piłki: przed siebie (ten sam korytarz), na boki (lewy albo prawy do wyboru atakującego),
## do środka, ręcznie (manual_targets dla każdego pola wyjścia).
enum Direction { FORWARD, SIDES, CENTER, MANUAL }

const DIRECTION_IDS: Array[StringName] = [&"forward", &"sides", &"center", &"manual"]
const DIRECTION_NAME_KEYS: Array[String] = [
	"PLAY_DIRECTION_FORWARD", "PLAY_DIRECTION_SIDES", "PLAY_DIRECTION_CENTER", "PLAY_DIRECTION_MANUAL"]
const MIN_ADVANCE := -1
const MAX_ADVANCE := 4
## Sloty wyniku akcji: tylko atak zapełnił / obie strony zapełniły i atak wygrał pojedynek / … przegrał /
## tylko obrona zapełniła / nikt nie zapełnił i atak wygrał pojedynek / … przegrał.
const OUTCOME_SLOTS: Array[StringName] = [&"success", &"duel_won", &"duel_lost", &"defense", &"none_won", &"none_lost"]

var id: StringName
## Nazwa wyświetlana (na razie zwykły tekst – narzędzie deweloperskie).
var name: String = ""
var description: String = ""
## Taktyki, które mają kartę w talii (id z GameData.tactics).
var tactics: Array[StringName] = []
## Zdarzenia (PlayEvents, łączone przez „lub”), po których karta trafia do puli losowania.
var triggers: Array[StringName] = [PlayEvents.POSSESSION]
## Pola, z których można zagrać kartę.
var origins: Array[Vector2i] = []
## O ile stref do przodu idzie piłka (wynik przycinany do 1..5). Przy MANUAL tylko pomoc w edytorze.
var advance: int = 1
var direction: Direction = Direction.FORWARD
## Pole wyjścia -> lista pól docelowych (tylko Direction.MANUAL).
var manual_targets: Dictionary[Vector2i, Array] = {}
## Sukces = gol. Bramkarz broniących gra w teście interwencji (test obrony z miejscem keeper), a bez takiego
## testu – w zwykłych testach obrony z pełną wagą.
var is_shot: bool = false
var attack: Array[PlayRequirement] = []
var defense: Array[PlayRequirement] = []
## Slot wyniku (OUTCOME_SLOTS) -> id zdarzenia (PlayEvents).
var outcomes: Dictionary[StringName, StringName] = {}
## Slot wyniku -> czy po nim jeden zawodnik atakujących przechodzi z pola wyjścia na pole docelowe
## (zostaje tam, dopóki drużyna ma piłkę). Brak wpisu = false.
var outcome_moves: Dictionary[StringName, bool] = {}
## Slot wyniku -> odnogi (Array[OutcomeBranch]): zdarzenia, które z pewną szansą zastępują efekt slotu.
## Brak wpisu = brak odnóg.
var outcome_branches: Dictionary[StringName, Array] = {}


static func create_default(card_id: StringName, tactic_ids: Array[StringName]) -> PlayCard:
	var card := PlayCard.new()
	card.id = card_id
	card.tactics = tactic_ids.duplicate()
	card.attack.append(PlayRequirement.create([&"pass"], 1.0))
	card.defense.append(PlayRequirement.create([&"tackle"], 1.0))
	card.reset_outcomes()
	return card


## Domyślne efekty wyników (zależne od is_shot).
func reset_outcomes() -> void:
	var success := PlayEvents.GOAL if is_shot else PlayEvents.ADVANCE
	outcomes = {
		&"success": success,
		&"duel_won": success,
		&"duel_lost": PlayEvents.KEEP,
		&"defense": PlayEvents.TURNOVER,
		&"none_won": PlayEvents.KEEP,
		&"none_lost": PlayEvents.TURNOVER,
	}
	outcome_moves.clear()
	outcome_branches.clear()


func get_outcome(slot: StringName) -> StringName:
	return outcomes.get(slot, PlayEvents.TURNOVER)


func get_branches(slot: StringName) -> Array:
	return outcome_branches.get(slot, [])


## Miejsce akcji slotu: pole docelowe, a przy bezpańskiej piłce (nikt nie zapełnił) pole wyjścia.
static func get_action_cell(slot: StringName, origin: Vector2i, target: Vector2i) -> Vector2i:
	return origin if slot == &"none_won" or slot == &"none_lost" else target


## Wszystkie zdarzenia, które karta może wywołać (efekty slotów i odnóg).
func get_emitted_events() -> Array[StringName]:
	var result: Array[StringName] = []
	for slot in OUTCOME_SLOTS:
		if not get_outcome(slot) in result:
			result.append(get_outcome(slot))
		for branch: OutcomeBranch in get_branches(slot):
			if not branch.event in result:
				result.append(branch.event)
	return result


func get_outcome_move(slot: StringName) -> bool:
	return outcome_moves.get(slot, false)


## Czy karta może trafić do puli po danym zdarzeniu (zwykłe posiadanie albo jedno z warunków).
func is_triggered_by(event: StringName) -> bool:
	return event in triggers


func can_play(cell: Vector2i) -> bool:
	if not cell in origins:
		return false
	return direction != Direction.MANUAL or not manual_targets.get(cell, []).is_empty()


## Możliwe pola docelowe z danego pola (więcej niż jedno = atakujący wybiera stronę).
func get_targets(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if direction == Direction.MANUAL:
		result.assign(manual_targets.get(origin, []))
		return result
	var zone := clampi(origin.x + advance, 1, MatchRules.ZONE_COUNT)
	match direction:
		Direction.FORWARD:
			result.append(Vector2i(zone, origin.y))
		Direction.CENTER:
			result.append(Vector2i(zone, MatchRules.CHANNEL_CENTER))
		Direction.SIDES:
			result.append(Vector2i(zone, MatchRules.CHANNEL_LEFT))
			result.append(Vector2i(zone, MatchRules.CHANNEL_RIGHT))
	return result


## Strefa celu wynikająca z advance (przy MANUAL tylko pomoc dla ręcznego ustawiania celów).
func get_advance_zone(origin: Vector2i) -> int:
	return clampi(origin.x + advance, 1, MatchRules.ZONE_COUNT)


func get_requirements(attacking: bool) -> Array[PlayRequirement]:
	return attack if attacking else defense


## Czy kość danego typu może cokolwiek wnieść do wymagań strony.
## Czy strona ma test przy polu startowym (np. zagranie długiej piłki).
func has_origin_tests(attacking: bool) -> bool:
	for requirement in get_requirements(attacking):
		if requirement.is_at_origin():
			return true
	return false


## Czy karta ma test interwencji bramkarza (tylko strzały; test obrony z miejscem keeper).
func has_keeper_test() -> bool:
	if not is_shot:
		return false
	for requirement in defense:
		if requirement.is_keeper():
			return true
	return false


func uses_die_type(die_type: DieTypeData, attacking: bool) -> bool:
	for requirement in get_requirements(attacking):
		for attribute_id in die_type.face_attributes:
			if requirement.accepts(attribute_id):
				return true
	return false


func is_in_tactic(tactic_id: StringName) -> bool:
	return tactic_id in tactics


func describe() -> String:
	var attack_text: Array[String] = []
	for requirement in attack:
		attack_text.append(requirement.describe())
	var defense_text: Array[String] = []
	for requirement in defense:
		defense_text.append(requirement.describe())
	return "%s [A: %s | D: %s]" % [id, ", ".join(attack_text), ", ".join(defense_text)]


# --- Serializacja (format pliku: PlayLibrary) ---

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func parse_cell_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(-1, -1)
	return Vector2i(parts[0].to_int(), parts[1].to_int())


## Stabilna kolejność pól. Ręczne cele zapisywane tylko dla bieżących pól wyjścia.
func to_dict() -> Dictionary:
	var movement := {"advance": advance, "direction": String(DIRECTION_IDS[direction])}
	if direction == Direction.MANUAL:
		var targets := {}
		for origin in origins:
			var list: Array = []
			for target: Vector2i in manual_targets.get(origin, []):
				list.append([target.x, target.y])
			targets[cell_key(origin)] = list
		movement["manual_targets"] = targets
	var origin_list: Array = []
	for origin in origins:
		origin_list.append([origin.x, origin.y])
	var outcome_dict := {}
	for slot in OUTCOME_SLOTS:
		var entry := {"event": String(get_outcome(slot)), "move_player": get_outcome_move(slot)}
		var branches := get_branches(slot)
		if not branches.is_empty():
			var branch_list: Array = []
			for branch: OutcomeBranch in branches:
				branch_list.append(branch.to_dict())
			entry["branches"] = branch_list
		outcome_dict[String(slot)] = entry
	return {
		"id": String(id),
		"name": name,
		"description": description,
		"tactics": _strings(tactics),
		"triggers": _strings(triggers),
		"origins": origin_list,
		"movement": movement,
		"is_shot": is_shot,
		"attack": _requirements_to_list(attack),
		"defense": _requirements_to_list(defense),
		"outcomes": outcome_dict,
	}


static func from_dict(data: Dictionary) -> PlayCard:
	var card := PlayCard.new()
	card.id = StringName(str(data.get("id", "")))
	card.name = str(data.get("name", ""))
	card.description = str(data.get("description", ""))
	card.tactics.assign(_string_names(data.get("tactics", [])))
	card.triggers.assign(_string_names(data.get("triggers", [PlayEvents.POSSESSION])))
	for cell: Variant in data.get("origins", []):
		card.origins.append(_to_cell(cell))
	var movement: Dictionary = data.get("movement", {})
	card.advance = int(movement.get("advance", 1))
	card.direction = maxi(DIRECTION_IDS.find(StringName(str(movement.get("direction", "forward")))), 0) as Direction
	var manual: Dictionary = movement.get("manual_targets", {})
	for key: Variant in manual:
		var targets: Array = []
		for cell: Variant in manual[key]:
			targets.append(_to_cell(cell))
		card.manual_targets[parse_cell_key(str(key))] = targets
	card.is_shot = bool(data.get("is_shot", false))
	for test: Variant in data.get("attack", []):
		if test is Dictionary:
			card.attack.append(PlayRequirement.from_dict(test))
	for test: Variant in data.get("defense", []):
		if test is Dictionary:
			card.defense.append(PlayRequirement.from_dict(test))
	card.reset_outcomes()
	var outcome_data: Dictionary = data.get("outcomes", {})
	for slot in OUTCOME_SLOTS:
		var entry: Variant = outcome_data.get(String(slot))
		if entry is Dictionary:
			card.outcomes[slot] = StringName(str(entry.get("event", "")))
			if bool(entry.get("move_player", false)):
				card.outcome_moves[slot] = true
			var branches: Array = []
			for branch_data: Variant in entry.get("branches", []):
				if branch_data is Dictionary:
					branches.append(OutcomeBranch.from_dict(branch_data))
			if not branches.is_empty():
				card.outcome_branches[slot] = branches
		elif entry != null:
			# Format 1: sam id zdarzenia.
			card.outcomes[slot] = StringName(str(entry))
	return card


func duplicate_card(new_id: StringName) -> PlayCard:
	var copy := PlayCard.from_dict(to_dict())
	copy.id = new_id
	# Ręczne cele pól, które nie są polami wyjścia, też kopiujemy (to_dict je pomija).
	for origin in manual_targets:
		if not copy.manual_targets.has(origin):
			copy.manual_targets[origin] = manual_targets[origin].duplicate()
	return copy


static func _to_cell(value: Variant) -> Vector2i:
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


static func _strings(values: Array[StringName]) -> Array:
	var result: Array = []
	for value in values:
		result.append(String(value))
	return result


static func _string_names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value: Variant in values:
			result.append(StringName(str(value)))
	return result


static func _requirements_to_list(requirements: Array[PlayRequirement]) -> Array:
	var result: Array = []
	for requirement in requirements:
		result.append(requirement.to_dict())
	return result

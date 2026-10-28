class_name PlayCard
extends RefCounted
## Karta zagrania (model v4, „Drabina” – docs/design/match_v2_plan.md, ścieżka B). PROTOTYP – zasady:
## res://docs/design/match_rules.md. Karty żyją w res://data/plays/plays.json (PlayLibrary) i edytuje się je w grze
## (Edytor zagrań).
## Zagranie ma strefy, z których można je zagrać (`zones`), kanał (`lane`: środek albo skrzydło – na skrzydle
## atakujący wybiera stronę) i awans (`advance`, 0–2 stref). Pole akcji = strefa piłki + awans, w kanale zagrania.
## Pola boiska podawane są jako Vector2i(strefa 1..5, kanał 0..2) w perspektywie drużyny z piłką. Piłka ma tylko
## strefę (B2) – pole piłki w zagraniu to strefa piłki w kanale pola akcji (get_origin).
## Wyniki: sukces (zapełnił tylko atak), pojedynek wygrany / przegrany (obie strony albo żadna – rozstrzyga
## nadwyżka), odbiór (zapełniła tylko obrona). Model v3 (pola wyjścia, kierunki, odnogi, łańcuchy) jest
## w _archive/match_v1_cards/v3_final/.

## Kanał pola akcji: środek albo skrzydło (lewe lub prawe – do wyboru atakującego).
enum Lane { CENTER, WING }

const LANE_IDS: Array[StringName] = [&"center", &"wing"]
const LANE_NAME_KEYS: Array[String] = ["PLAY_LANE_CENTER", "PLAY_LANE_WING"]
const MIN_ADVANCE := 0
const MAX_ADVANCE := 2
## Wyniki akcji: tylko atak zapełnił / pojedynek wygrany / pojedynek przegrany / tylko obrona zapełniła.
const OUTCOME_SLOTS: Array[StringName] = [&"success", &"duel_won", &"duel_lost", &"defense"]

var id: StringName
## Nazwa wyświetlana (na razie zwykły tekst – narzędzie deweloperskie).
var name: String = ""
var description: String = ""
## Taktyki, które mają kartę w talii (id z GameData.tactics).
var tactics: Array[StringName] = []
## Zdarzenia (PlayEvents, łączone przez „lub”), po których karta trafia do puli losowania.
var triggers: Array[StringName] = [PlayEvents.POSSESSION]
## Strefy piłki (1..5), z których można zagrać kartę.
var zones: Array[int] = []
var lane: Lane = Lane.CENTER
## O ile stref do przodu idzie akcja (strefa pola akcji przycinana do 1..5).
var advance: int = 1
## Sukces = gol. Bramkarz broniących gra w teście interwencji (test obrony z miejscem keeper), a bez takiego
## testu – w zwykłych testach obrony z pełną wagą.
var is_shot: bool = false
var attack: Array[PlayRequirement] = []
var defense: Array[PlayRequirement] = []
## Wynik (OUTCOME_SLOTS) -> id zdarzenia (PlayEvents).
var outcomes: Dictionary[StringName, StringName] = {}


static func create_default(card_id: StringName, tactic_ids: Array[StringName]) -> PlayCard:
	var card := PlayCard.new()
	card.id = card_id
	card.tactics = tactic_ids.duplicate()
	card.zones.assign([3])
	card.attack.append(PlayRequirement.create([&"pass"], 2.0))
	card.defense.append(PlayRequirement.create([&"tackle"], 2.0))
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
	}


func get_outcome(slot: StringName) -> StringName:
	return outcomes.get(slot, PlayEvents.TURNOVER)


## Czy karta może trafić do puli po danym zdarzeniu (zwykłe posiadanie albo jedno z warunków).
func is_triggered_by(event: StringName) -> bool:
	return event in triggers


func can_play_zone(zone: int) -> bool:
	return zone in zones


## Strefa pola akcji przy piłce w danej strefie.
func get_action_zone(ball_zone: int) -> int:
	return clampi(ball_zone + advance, 1, MatchRules.ZONE_COUNT)


## Możliwe pola akcji (cele) przy piłce w strefie: środek – jedno pole, skrzydło – lewe i prawe (wybiera atakujący).
func get_targets(ball_zone: int) -> Array[Vector2i]:
	var zone := get_action_zone(ball_zone)
	var result: Array[Vector2i] = []
	if lane == Lane.WING:
		result.append(Vector2i(zone, MatchRules.CHANNEL_LEFT))
		result.append(Vector2i(zone, MatchRules.CHANNEL_RIGHT))
	else:
		result.append(Vector2i(zone, MatchRules.CHANNEL_CENTER))
	return result


## Pole piłki przy zagraniu do celu: piłka ma tylko strefę, więc zagrywa się z kanału pola akcji (start testów
## przy polu startowym, podający, początek przelotu).
static func get_origin(ball_zone: int, target: Vector2i) -> Vector2i:
	return Vector2i(ball_zone, target.y)


func get_requirements(attacking: bool) -> Array[PlayRequirement]:
	return attack if attacking else defense


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


## Czy kość danego typu może cokolwiek wnieść do wymagań strony.
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
	var zone_text := ""
	for zone in zones:
		zone_text += str(zone)
	return "%s z%s %s +%d [A: %s | D: %s]" % [id, zone_text, LANE_IDS[lane], advance, ", ".join(attack_text),
			", ".join(defense_text)]


# --- Serializacja (format pliku: PlayLibrary) ---

func to_dict() -> Dictionary:
	var outcome_dict := {}
	for slot in OUTCOME_SLOTS:
		outcome_dict[String(slot)] = String(get_outcome(slot))
	var zone_list: Array = []
	for zone in zones:
		zone_list.append(zone)
	return {
		"id": String(id),
		"name": name,
		"description": description,
		"tactics": _strings(tactics),
		"triggers": _strings(triggers),
		"zones": zone_list,
		"lane": String(LANE_IDS[lane]),
		"advance": advance,
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
	for zone: Variant in data.get("zones", []):
		card.zones.append(int(zone))
	card.lane = maxi(LANE_IDS.find(StringName(str(data.get("lane", "center")))), 0) as Lane
	card.advance = int(data.get("advance", 1))
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
		if outcome_data.has(String(slot)):
			card.outcomes[slot] = StringName(str(outcome_data[String(slot)]))
	return card


func duplicate_card(new_id: StringName) -> PlayCard:
	var copy := PlayCard.from_dict(to_dict())
	copy.id = new_id
	return copy


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

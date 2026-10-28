class_name PlayRequirement
extends RefCounted
## Jeden test karty zagrania: próg punktów i składniki połączone przez „lub” (np. „podanie lub kontrola: 3”).
## Każdy składnik to cecha z wagą – punkty kości trafiającej w cechę są mnożone przez jej wagę.
## Testy jednej strony karty łączy „i” (każdy musi zostać zapełniony).
## max_dice: ile najlepszych kości liczy się w teście (0 = wszystkie) – narzędzie balansu.
## location: pole, którego dotyczy test – docelowe (domyślnie, np. przyjęcie piłki) albo startowe (np. zagranie
## długiej piłki); udział zawodników w teście liczy się od tego pola (PlayContest). Przy strzale test obrony może
## być interwencją bramkarza (keeper): liczą się w nim tylko kości bramkarza broniących, a zaliczony zamienia gola
## w obronę bramkarza (MatchEngine.finish_turn).

const POINTS_STEP := 0.5
const DEFAULT_WEIGHT := 1.0
const DEFAULT_MAX_DICE := 3
const MAX_DICE_LIMIT := 11
const LOCATION_TARGET := &"target"
const LOCATION_ORIGIN := &"origin"
const LOCATION_KEEPER := &"keeper"
const LOCATIONS: Array[StringName] = [LOCATION_TARGET, LOCATION_ORIGIN, LOCATION_KEEPER]

## Cechy składników (indeks = indeks wagi).
var attributes: Array[StringName] = []
var weights := PackedFloat64Array()
var points: float = 0.0
var max_dice: int = DEFAULT_MAX_DICE
var location: StringName = LOCATION_TARGET


static func create(attribute_ids: Array, required_points: float, term_weights: Array = []) -> PlayRequirement:
	var requirement := PlayRequirement.new()
	for i in attribute_ids.size():
		requirement.add_term(StringName(attribute_ids[i]),
				float(term_weights[i]) if i < term_weights.size() else DEFAULT_WEIGHT)
	requirement.points = required_points
	return requirement


func add_term(attribute_id: StringName, weight: float = DEFAULT_WEIGHT) -> void:
	attributes.append(attribute_id)
	weights.append(weight)


func remove_term(index: int) -> void:
	attributes.remove_at(index)
	weights.remove_at(index)


func get_term_count() -> int:
	return attributes.size()


func accepts(attribute_id: StringName) -> bool:
	return attribute_id in attributes


## Mnożnik punktów kości dla cechy (0 = cecha nie należy do testu).
func get_weight(attribute_id: StringName) -> float:
	var index := attributes.find(attribute_id)
	return weights[index] if index != -1 else 0.0


func describe() -> String:
	var parts: Array[String] = []
	for i in attributes.size():
		parts.append(String(attributes[i]) if is_equal_approx(weights[i], 1.0)
				else "%s×%s" % [attributes[i], str(weights[i])])
	var cap := "" if max_dice == DEFAULT_MAX_DICE else " (max %d)" % max_dice
	var place := " @start" if is_at_origin() else (" @gk" if is_keeper() else "")
	return "%s %s%s%s" % ["|".join(parts), str(points), cap, place]


func is_at_origin() -> bool:
	return location == LOCATION_ORIGIN


## Interwencja bramkarza (tylko obrona przy strzale).
func is_keeper() -> bool:
	return location == LOCATION_KEEPER


func to_dict() -> Dictionary:
	var terms: Array = []
	for i in attributes.size():
		terms.append({"attribute": String(attributes[i]), "weight": weights[i]})
	var data := {"points": points, "max_dice": max_dice, "terms": terms}
	if location != LOCATION_TARGET:
		data["location"] = String(location)
	return data


static func from_dict(data: Dictionary) -> PlayRequirement:
	var requirement := PlayRequirement.new()
	requirement.points = float(data.get("points", 0.0))
	requirement.max_dice = int(data.get("max_dice", DEFAULT_MAX_DICE))
	var location_id := StringName(str(data.get("location", "")))
	requirement.location = location_id if location_id in LOCATIONS else LOCATION_TARGET
	for term: Variant in data.get("terms", []):
		if term is Dictionary:
			requirement.add_term(StringName(str(term.get("attribute", ""))), float(term.get("weight", DEFAULT_WEIGHT)))
	return requirement

class_name PlayRequirement
extends RefCounted
## Jeden test karty zagrania (model v4): próg punktów (liczba całkowita, w skali udziału ×2 / ×1) i cechy połączone
## przez „lub” (np. „podanie lub kontrola: 4”). Każda kość trafiająca w cechę testu wnosi swoje punkty – bez wag.
## Testy jednej strony karty łączy „i” (każdy musi zostać zapełniony).
## max_dice: ile najlepszych kości liczy się w teście (0 = wszystkie) – narzędzie balansu.
## location: pole, którego dotyczy test – docelowe (domyślnie, np. przyjęcie piłki) albo startowe (np. zagranie
## długiej piłki); udział zawodników w teście liczy się od tego pola (PlayContest). Przy strzale test obrony może
## być interwencją bramkarza (keeper): liczą się w nim tylko kości bramkarza broniących, a zaliczony zamienia gola
## w obronę bramkarza (MatchEngine.finish_turn).

const POINTS_STEP := 1.0
const MAX_POINTS := 30
const DEFAULT_MAX_DICE := 3
const MAX_DICE_LIMIT := 11
const LOCATION_TARGET := &"target"
const LOCATION_ORIGIN := &"origin"
const LOCATION_KEEPER := &"keeper"
const LOCATIONS: Array[StringName] = [LOCATION_TARGET, LOCATION_ORIGIN, LOCATION_KEEPER]

## Cechy testu (łączone przez „lub”).
var attributes: Array[StringName] = []
## Próg; w pliku liczba całkowita (symulacja może go skalować, np. defense_scale).
var points: float = 0.0
var max_dice: int = DEFAULT_MAX_DICE
var location: StringName = LOCATION_TARGET


static func create(attribute_ids: Array, required_points: float, test_location: StringName = LOCATION_TARGET,
		dice_limit: int = DEFAULT_MAX_DICE) -> PlayRequirement:
	var requirement := PlayRequirement.new()
	for attribute_id: Variant in attribute_ids:
		requirement.add_term(StringName(attribute_id))
	requirement.points = required_points
	requirement.location = test_location
	requirement.max_dice = dice_limit
	return requirement


func add_term(attribute_id: StringName) -> void:
	attributes.append(attribute_id)


func remove_term(index: int) -> void:
	attributes.remove_at(index)


func get_term_count() -> int:
	return attributes.size()


func accepts(attribute_id: StringName) -> bool:
	return attribute_id in attributes


## Mnożnik punktów kości dla cechy: 1, gdy cecha należy do testu, inaczej 0 (model v4 nie ma wag).
func get_weight(attribute_id: StringName) -> float:
	return 1.0 if accepts(attribute_id) else 0.0


func describe() -> String:
	var cap := "" if max_dice == DEFAULT_MAX_DICE else " (max %d)" % max_dice
	var place := " @start" if is_at_origin() else (" @gk" if is_keeper() else "")
	return "%s %s%s%s" % ["|".join(attributes), str(points), cap, place]


func is_at_origin() -> bool:
	return location == LOCATION_ORIGIN


## Interwencja bramkarza (tylko obrona przy strzale).
func is_keeper() -> bool:
	return location == LOCATION_KEEPER


func to_dict() -> Dictionary:
	var names: Array = []
	for attribute_id in attributes:
		names.append(String(attribute_id))
	var data := {"points": roundi(points) if is_equal_approx(points, roundf(points)) else points,
			"attributes": names, "max_dice": max_dice}
	if location != LOCATION_TARGET:
		data["location"] = String(location)
	return data


static func from_dict(data: Dictionary) -> PlayRequirement:
	var requirement := PlayRequirement.new()
	requirement.points = float(data.get("points", 0.0))
	requirement.max_dice = int(data.get("max_dice", DEFAULT_MAX_DICE))
	var location_id := StringName(str(data.get("location", "")))
	requirement.location = location_id if location_id in LOCATIONS else LOCATION_TARGET
	for attribute_id: Variant in data.get("attributes", []):
		requirement.add_term(StringName(str(attribute_id)))
	return requirement

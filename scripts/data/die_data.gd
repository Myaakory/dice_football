class_name DieData
extends RefCounted
## Konkretna kość zawodnika: typ kości + liczba punktów na każdej ściance (zależna od jakości zawodnika).

var slot: int = 0
var type: DieTypeData
var face_values: Array[int] = []


func get_face_count() -> int:
	return face_values.size()


func get_face_attribute(face_index: int) -> StringName:
	return type.face_attributes[face_index]


func get_face_value(face_index: int) -> int:
	return face_values[face_index]


## Rzut kością – zwraca indeks wylosowanej ścianki.
func roll(rng: RandomNumberGenerator = null) -> int:
	if rng != null:
		return rng.randi_range(0, get_face_count() - 1)
	return randi_range(0, get_face_count() - 1)


## Suma punktów na wszystkich ściankach – ogólna siła kości.
func get_total() -> int:
	var total := 0
	for value in face_values:
		total += value
	return total


## Suma punktów danej cechy na wszystkich ściankach – przydatne do oceny siły zawodnika.
func get_attribute_total(attribute_id: StringName) -> int:
	var total := 0
	for i in get_face_count():
		if get_face_attribute(i) == attribute_id:
			total += face_values[i]
	return total

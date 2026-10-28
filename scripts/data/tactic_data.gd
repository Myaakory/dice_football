class_name TacticData
extends RefCounted
## Taktyka (ustawienie) – lista 11 pozycji rozmieszczonych w 5 pasach boiska.

var id: StringName
var name: String
var description_key: String
var slots: Array[FormationSlot] = []


func get_slot_count() -> int:
	return slots.size()

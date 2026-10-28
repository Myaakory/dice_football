class_name RoleData
extends RefCounted
## Rola na boisku w ramach taktyki (np. lewy obrońca, defensywny pomocnik, skrzydłowy).

var id: StringName
var name_key: String
var short_key: String
## Pozycja kadrowa (PositionData.id), która naturalnie pasuje do tej roli.
var position_id: StringName
## Aktywne kości zawodnika na tej roli (DieTypeData.id); puste = według pozycji zawodnika.
var preferred_dice: Array[StringName] = []

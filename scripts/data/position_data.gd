class_name PositionData
extends RefCounted
## Nominalna pozycja zawodnika w kadrze (bramkarz, obrońca, pomocnik, napastnik).

const GOALKEEPER: StringName = &"GK"

var id: StringName
var name_key: String
var short_key: String
## Typy kości domyślnie wybierane jako aktywne dla tej pozycji.
var preferred_dice: Array[StringName] = []

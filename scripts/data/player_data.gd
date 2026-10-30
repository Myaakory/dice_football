class_name PlayerData
extends RefCounted
## Zawodnik z kadry drużyny wraz z jego kośćmi (zwykle 3, w meczu korzysta z 2 wybranych).

var id: StringName
var team_id: StringName
var number: int = 0
var first_name: String
var last_name: String
var position_id: StringName
## Narodowość: id z nationalities.csv (GameData.get_nationality), puste = nieznana.
var nationality: StringName = &""
## Wiek w latach (0 = nieznany – kolumna "age" w players.csv jest opcjonalna).
var age: int = 0
## Role (id z roles.csv), na których zawodnik gra naturalnie / umie zagrać, ale czuje się gorzej.
## Brak danych w arkuszu = naturalne są wszystkie role jego pozycji kadrowej (GameData).
var natural_roles: Array[StringName] = []
var secondary_roles: Array[StringName] = []
var dice: Array[DieData] = []
## Wygląd portretu {pula: wariant} (PortraitLooks). Pusty = wyliczany z id i narodowości przy pierwszym
## wyświetleniu (deterministycznie); generator świata może go ustawić sam.
var portrait_look: Dictionary = {}


func get_full_name() -> String:
	return "%s %s" % [first_name, last_name]


func get_short_name() -> String:
	return "%s. %s" % [first_name.left(1), last_name]


enum RoleFit { NONE, SECONDARY, NATURAL }


func get_role_fit(role_id: StringName) -> RoleFit:
	if role_id in natural_roles:
		return RoleFit.NATURAL
	if role_id in secondary_roles:
		return RoleFit.SECONDARY
	return RoleFit.NONE


func is_goalkeeper() -> bool:
	return position_id == PositionData.GOALKEEPER


func get_portrait_look() -> Dictionary:
	if portrait_look.is_empty():
		portrait_look = PortraitLooks.generate(String(id), nationality)
	return portrait_look

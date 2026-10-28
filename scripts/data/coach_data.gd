class_name CoachData
extends RefCounted
## Trener drużyny: perki (modyfikatory udziału w meczu) i profil ryzyka AI. Dane: zakładka coaches (data/coaches.csv).

var id: StringName
var team_id: StringName
var first_name: String
var last_name: String
## Skłonność do ryzyka AI (MatchAI.risk_aversion): 1 = neutralny, >1 = ostrożny, <1 = ryzykant.
var risk_aversion: float = 1.0
var perks: Array[PerkData] = []


func get_full_name() -> String:
	return "%s %s" % [first_name, last_name]

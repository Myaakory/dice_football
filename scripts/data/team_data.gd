class_name TeamData
extends RefCounted
## Drużyna i jej kadra.

var id: StringName
var name: String
var short_name: String
var primary_color: Color = Color.WHITE
var secondary_color: Color = Color.BLACK
var default_tactic_id: StringName
var players: Array[PlayerData] = []
## Trener (perki, profil ryzyka AI); null = bez trenera.
var coach: CoachData

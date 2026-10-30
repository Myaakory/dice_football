class_name TeamData
extends RefCounted
## Drużyna i jej kadra.

var id: StringName
var name: String
var short_name: String
var primary_color: Color = Color.WHITE
var secondary_color: Color = Color.BLACK
## Strój bramkarza (koszulka bramkarska na portrecie); domyślnie zielony z czarnym.
var gk_primary_color: Color = Color("#3fae49")
var gk_secondary_color: Color = Color("#1c1c1c")
var default_tactic_id: StringName
var players: Array[PlayerData] = []
## Trener (perki, profil ryzyka AI); null = bez trenera.
var coach: CoachData

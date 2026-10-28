class_name PlayerDrag
extends RefCounted
## Dane przeciągania zawodnika (drag & drop) między boiskiem a listą kadry.

const KIND: StringName = &"lineup_player"


static func create(player: PlayerData) -> Dictionary:
	return {"kind": KIND, "player": player}


## Zawodnik z danych przeciągania albo null, jeśli przeciągane jest coś innego.
static func get_player(data: Variant) -> PlayerData:
	if data is Dictionary and data.get("kind") == KIND:
		return data.get("player") as PlayerData
	return null

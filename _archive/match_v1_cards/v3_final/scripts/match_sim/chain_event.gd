class_name ChainEvent
extends RefCounted
## Zdarzenie łańcucha (własne zdarzenie z Edytora zagrań): efekt wyniku albo odnogi jednej karty, na który
## inne karty mogą mieć warunek dobierania (PlayCard.triggers). Działa jak stały fragment: po nim losują się
## tylko karty z tym zdarzeniem w warunkach (jeśli żadnej nie ma – karty zwykłego posiadania).
## Przykład: dobitka po strzale (odnoga obrony bramkarza) albo dośrodkowanie w pole karne → strzał głową.
## Żyje w res://data/plays/plays.json („events”), rejestr dla silnika: PlayEvents.set_chain_events.

## Gdzie leży piłka po zdarzeniu: w miejscu akcji (jak faul), w polu wyjścia albo w polu docelowym.
enum Ball { ACTION, ORIGIN, TARGET }

const BALL_IDS: Array[StringName] = [&"action", &"origin", &"target"]
const BALL_NAME_KEYS: Array[String] = ["CHAIN_BALL_ACTION", "CHAIN_BALL_ORIGIN", "CHAIN_BALL_TARGET"]

var id: StringName
## Nazwa wyświetlana (zwykły tekst – narzędzie deweloperskie, jak nazwy kart).
var name: String = ""
var ball: Ball = Ball.ACTION
## Piłkę przejmują broniący (np. kontra po odbiorze); domyślnie zostaje u atakujących.
var changes_possession := false
## Edytor: po dodaniu warunku na to zdarzenie do jednej karty znika z list warunków innych kart.
var hide_after_use := false


static func create(event_id: StringName, event_name: String) -> ChainEvent:
	var chain := ChainEvent.new()
	chain.id = event_id
	chain.name = event_name
	return chain


## Pole piłki po zdarzeniu (perspektywa atakujących karty).
func get_ball_cell(action_cell: Vector2i, origin: Vector2i, target: Vector2i) -> Vector2i:
	match ball:
		Ball.ORIGIN:
			return origin
		Ball.TARGET:
			return target
	return action_cell


func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": name,
		"ball": String(BALL_IDS[ball]),
		"changes_possession": changes_possession,
		"hide_after_use": hide_after_use,
	}


static func from_dict(data: Dictionary) -> ChainEvent:
	var chain := ChainEvent.new()
	chain.id = StringName(str(data.get("id", "")))
	chain.name = str(data.get("name", ""))
	chain.ball = maxi(BALL_IDS.find(StringName(str(data.get("ball", "action")))), 0) as Ball
	chain.changes_possession = bool(data.get("changes_possession", false))
	chain.hide_after_use = bool(data.get("hide_after_use", false))
	return chain

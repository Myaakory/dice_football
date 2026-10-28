class_name PlayEvents
extends RefCounted
## Zdarzenia zagrań: wspólna lista dla efektów wyników karty (PlayCard.outcomes) i warunków dobierania
## (PlayCard.triggers). Nazwy przez klucze tłumaczeń PLAY_EVENT_<ID>. Skutki efektów: MatchEngine._apply_effect,
## opis: docs/design/match_rules.md („Efekty wyników”).
## Oprócz stałej listy są zdarzenia łańcuchów (ChainEvent) z pliku kart – rejestruje je PlayLibrary.

const POSSESSION := &"possession"
const ADVANCE := &"advance"
const GOAL := &"goal"
const KEEP := &"keep"
const TURNOVER := &"turnover"
const CLEARANCE := &"clearance"
const INTERCEPTION := &"interception"
const GOALKEEPER_SAVE := &"goalkeeper_save"
const FOUL := &"foul"
const CORNER := &"corner"
const PENALTY := &"penalty"
const OFFSIDE := &"offside"

## Kolejność = kolejność na listach rozwijanych edytora.
const IDS: Array[StringName] = [
	&"possession",       ## zwykłe posiadanie piłki
	&"advance",          ## awans na pole docelowe
	&"goal",             ## gol
	&"keep",             ## utrzymanie piłki w polu wyjścia
	&"turnover",         ## odbiór: rywal przejmuje piłkę i zaczyna akcję w miejscu odbioru
	&"clearance",        ## obronny wykop
	&"interception",     ## przechwyt podania w polu przelotu
	&"goalkeeper_save",  ## obrona bramkarza
	&"foul",             ## faul / rzut wolny
	&"corner",           ## rzut rożny
	&"penalty",          ## rzut karny
	&"offside",          ## spalony
]

## Stałe fragmenty: po nich losuje się tylko karty z tym zdarzeniem w warunkach (jeśli są).
const SET_PIECES: Array[StringName] = [&"foul", &"corner", &"penalty", &"offside"]
## Efekty, po których piłkę ma rywal.
const POSSESSION_CHANGES: Array[StringName] = [&"turnover", &"clearance", &"interception", &"goalkeeper_save", &"offside"]


## Zdarzenia łańcuchów: id -> ChainEvent (PlayLibrary po wczytaniu, Edytor zagrań po zmianach).
static var _chain_events: Dictionary[StringName, ChainEvent] = {}


static func set_chain_events(events: Array[ChainEvent]) -> void:
	_chain_events.clear()
	for chain in events:
		_chain_events[chain.id] = chain


static func get_chain_event(id: StringName) -> ChainEvent:
	return _chain_events.get(id)


static func is_chain(id: StringName) -> bool:
	return _chain_events.has(id)


static func is_valid(id: StringName) -> bool:
	return id in IDS or _chain_events.has(id)


static func is_set_piece(id: StringName) -> bool:
	return id in SET_PIECES


## Po zdarzeniu losują się tylko karty z nim w warunkach (stały fragment albo zdarzenie łańcucha).
static func is_exclusive(id: StringName) -> bool:
	return id in SET_PIECES or _chain_events.has(id)


static func changes_possession(id: StringName) -> bool:
	if _chain_events.has(id):
		return _chain_events[id].changes_possession
	return id in POSSESSION_CHANGES


static func get_name_key(id: StringName) -> String:
	return "PLAY_EVENT_" + String(id).to_upper()


## Nazwa do pokazania: zdarzenie łańcucha ma własną nazwę, reszta przez klucz tłumaczenia.
static func get_display_name(id: StringName) -> String:
	var chain: ChainEvent = _chain_events.get(id)
	if chain != null:
		return chain.name if not chain.name.strip_edges().is_empty() else String(id)
	return TranslationServer.translate(get_name_key(id))

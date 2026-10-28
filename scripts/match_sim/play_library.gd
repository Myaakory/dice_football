class_name PlayLibrary
extends RefCounted
## Biblioteka kart zagrań: wczytanie i zapis res://data/plays/plays.json, walidacja i talie taktyk.
## Czyste dane (bez Node'ów) – używa jej silnik, symulacja (scenes/dev/match_sim.gd) i Edytor zagrań.
## Wyjątek od zasady „arkusz Google = źródło prawdy”: karty edytuje się w grze, plik jest źródłem prawdy.
##
## Format: {"version": 4, "plays": [<PlayCard.to_dict()>, ...]} – model v4 („Drabina”), opis pól
## w docs/design/match_rules.md. Starsze formaty (v1–v3: pola wyjścia, kierunki, odnogi, łańcuchy) się nie wczytują –
## ostatni plik v3 i kod do niego są w _archive/match_v1_cards/v3_final/.

const DEFAULT_PATH := "res://data/plays/plays.json"
const FORMAT_VERSION := 4
## Krótkie listy i słowniki z samymi wartościami prostymi zapisujemy w jednej linii (czytelniejszy plik).
const INLINE_LIMIT := 100
const ID_PATTERN := "^[a-z][a-z0-9_]*$"

var plays: Array[PlayCard] = []
## Błąd wczytania pliku (pusty = OK).
var load_error: String = ""


static func load_default() -> PlayLibrary:
	return load_file(DEFAULT_PATH)


static func load_file(path: String) -> PlayLibrary:
	var library := PlayLibrary.new()
	if not FileAccess.file_exists(path):
		library.load_error = "file not found: %s" % path
		return library
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		library.load_error = "%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()]
		return library
	library.load_error = library.load_data(json.data)
	return library


## Wczytuje dane z drzewa słowników (wynik JSON.parse). Zwraca opis błędu albo pusty tekst.
func load_data(data: Variant) -> String:
	plays.clear()
	if not data is Dictionary:
		return "root is not an object"
	var version := int(data.get("version", 0))
	if version != FORMAT_VERSION:
		return "unsupported version %d (expected %d; v3 is archived in _archive/match_v1_cards/v3_final)" \
				% [version, FORMAT_VERSION]
	var list: Variant = data.get("plays", [])
	if not list is Array:
		return "'plays' is not a list"
	for entry: Variant in list:
		if entry is Dictionary:
			plays.append(PlayCard.from_dict(entry))
	return ""


func to_dict() -> Dictionary:
	var list: Array = []
	for card in plays:
		list.append(card.to_dict())
	return {"version": FORMAT_VERSION, "plays": list}


func to_json_text() -> String:
	return stringify(to_dict()) + "\n"


## Zapis przez plik tymczasowy – przy błędzie stary plik zostaje nietknięty.
func save_file(path: String = DEFAULT_PATH) -> Error:
	var text := to_json_text()
	# Kontrola: tekst musi dać się wczytać z powrotem do identycznych danych.
	var check := PlayLibrary.new()
	var json := JSON.new()
	if json.parse(text) != OK or check.load_data(json.data) != "" or check.to_json_text() != text:
		push_error("PlayLibrary: serialization round-trip failed, not saving")
		return ERR_INVALID_DATA
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_path)
			return remove_error
	return DirAccess.rename_absolute(temp_path, path)


## Karty w talii taktyki (kolejność jak w pliku).
func get_deck(tactic_id: StringName) -> Array[PlayCard]:
	var deck: Array[PlayCard] = []
	for card in plays:
		if card.is_in_tactic(tactic_id):
			deck.append(card)
	return deck


func find_index(card_id: StringName) -> int:
	for i in plays.size():
		if plays[i].id == card_id:
			return i
	return -1


## Wolne id na bazie podanego (base, base_2, base_3…).
func make_unique_id(base: String) -> StringName:
	var candidate := base
	var counter := 2
	while find_index(StringName(candidate)) != -1:
		candidate = "%s_%d" % [base, counter]
		counter += 1
	return StringName(candidate)


# --- Walidacja ---

## Błędy danych: lista {"play": indeks karty, "key": klucz tłumaczenia, "args": [...]}.
## attribute_ids / tactic_ids: znane cechy i taktyki (GameData), puste = bez sprawdzania.
func validate(attribute_ids: Array = [], tactic_ids: Array = []) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var regex := RegEx.create_from_string(ID_PATTERN)
	var seen := {}
	for i in plays.size():
		var card := plays[i]
		if String(card.id).is_empty():
			errors.append(_error(i, "EDITOR_ERROR_ID_EMPTY"))
		elif regex.search(String(card.id)) == null:
			errors.append(_error(i, "EDITOR_ERROR_ID_FORMAT", [card.id]))
		elif seen.has(card.id):
			errors.append(_error(i, "EDITOR_ERROR_ID_DUPLICATE", [card.id]))
		seen[card.id] = true
		if card.name.strip_edges().is_empty():
			errors.append(_error(i, "EDITOR_ERROR_NAME_EMPTY"))
		for tactic_id in card.tactics:
			if not tactic_ids.is_empty() and not tactic_id in tactic_ids:
				errors.append(_error(i, "EDITOR_ERROR_TACTIC_UNKNOWN", [tactic_id]))
		if card.triggers.is_empty():
			errors.append(_error(i, "EDITOR_ERROR_NO_TRIGGER"))
		for trigger in card.triggers:
			if not PlayEvents.is_valid(trigger):
				errors.append(_error(i, "EDITOR_ERROR_EVENT_UNKNOWN", [trigger]))
		_validate_movement(i, card, errors)
		for attacking: bool in [true, false]:
			_validate_tests(i, card, attacking, attribute_ids, errors)
		for slot in PlayCard.OUTCOME_SLOTS:
			if not PlayEvents.is_valid(card.get_outcome(slot)):
				errors.append(_error(i, "EDITOR_ERROR_EVENT_UNKNOWN", [card.get_outcome(slot)]))
	return errors


func _validate_movement(index: int, card: PlayCard, errors: Array[Dictionary]) -> void:
	if card.zones.is_empty():
		errors.append(_error(index, "EDITOR_ERROR_NO_ZONES"))
	var seen := {}
	for zone in card.zones:
		if zone < 1 or zone > MatchRules.ZONE_COUNT or seen.has(zone):
			errors.append(_error(index, "EDITOR_ERROR_BAD_ZONE", [zone]))
		seen[zone] = true
	if card.advance < PlayCard.MIN_ADVANCE or card.advance > PlayCard.MAX_ADVANCE:
		errors.append(_error(index, "EDITOR_ERROR_ADVANCE", [card.advance]))


func _validate_tests(index: int, card: PlayCard, attacking: bool, attribute_ids: Array,
		errors: Array[Dictionary]) -> void:
	var side_key := "EDITOR_SIDE_ATTACK" if attacking else "EDITOR_SIDE_DEFENSE"
	var tests := card.get_requirements(attacking)
	var field_tests := 0
	for t in tests.size():
		var test := tests[t]
		if not test.is_keeper():
			field_tests += 1
		if test.points < 1.0 or not is_equal_approx(test.points, roundf(test.points)):
			errors.append(_error(index, "EDITOR_ERROR_POINTS", [side_key, t + 1]))
		if test.is_keeper() and (attacking or not card.is_shot):
			errors.append(_error(index, "EDITOR_ERROR_KEEPER_TEST", [side_key, t + 1]))
		if test.max_dice < 0 or test.max_dice > PlayRequirement.MAX_DICE_LIMIT:
			errors.append(_error(index, "EDITOR_ERROR_MAX_DICE", [side_key, t + 1]))
		if test.get_term_count() == 0:
			errors.append(_error(index, "EDITOR_ERROR_NO_TERMS", [side_key, t + 1]))
		var seen := {}
		for attribute_id in test.attributes:
			if not attribute_ids.is_empty() and not attribute_id in attribute_ids:
				errors.append(_error(index, "EDITOR_ERROR_ATTRIBUTE_UNKNOWN", [side_key, t + 1, attribute_id]))
			elif seen.has(attribute_id):
				errors.append(_error(index, "EDITOR_ERROR_ATTRIBUTE_DUPLICATE", [side_key, t + 1, attribute_id]))
			seen[attribute_id] = true
	if field_tests == 0:
		errors.append(_error(index, "EDITOR_ERROR_NO_TESTS", [side_key]))


static func _error(play_index: int, key: String, args: Array = []) -> Dictionary:
	return {"play": play_index, "key": key, "args": args}


## Tekst błędu walidacji. Argumenty zaczynające się od „EDITOR_” albo „PLAY_SLOT_” też są tłumaczone.
static func format_error(error: Dictionary) -> String:
	var args: Array = []
	for arg: Variant in error["args"]:
		var text := str(arg)
		var translated := text.begins_with("EDITOR_") or text.begins_with("PLAY_SLOT_")
		args.append(TranslationServer.translate(text) if translated else text)
	var template := TranslationServer.translate(error["key"])
	return template % args if not args.is_empty() else template


# --- Zapis JSON w stabilnym, czytelnym układzie ---

static func stringify(value: Variant, indent: String = "") -> String:
	var compact := _compact(value)
	if (not value is Dictionary and not value is Array) or (compact.length() <= INLINE_LIMIT and _is_inlinable(value)):
		return compact
	var inner := indent + "\t"
	var parts: Array[String] = []
	if value is Dictionary:
		if value.is_empty():
			return "{}"
		for key: Variant in value:
			parts.append(inner + JSON.stringify(str(key)) + ": " + stringify(value[key], inner))
		return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
	if value.is_empty():
		return "[]"
	for item: Variant in value:
		parts.append(inner + stringify(item, inner))
	return "[\n" + ",\n".join(parts) + "\n" + indent + "]"


static func _compact(value: Variant) -> String:
	if value is Dictionary:
		var parts: Array[String] = []
		for key: Variant in value:
			parts.append(JSON.stringify(str(key)) + ": " + _compact(value[key]))
		return "{" + ", ".join(parts) + "}"
	if value is Array:
		var parts: Array[String] = []
		for item: Variant in value:
			parts.append(_compact(item))
		return "[" + ", ".join(parts) + "]"
	return JSON.stringify(value)


## W jednej linii: lista bez słowników albo słownik z wartościami prostymi i płaskimi listami (np. test karty).
static func _is_inlinable(value: Variant) -> bool:
	if value is Array:
		for item: Variant in value:
			if item is Dictionary or (item is Array and not _is_inlinable(item)):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			var item: Variant = value[key]
			if item is Dictionary:
				return false
			if item is Array:
				for element: Variant in item:
					if element is Array or element is Dictionary:
						return false
		return true
	return true

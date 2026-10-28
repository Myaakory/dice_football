class_name OutcomeBranch
extends RefCounted
## Odnoga wyniku karty: z pewną szansą zamienia efekt slotu wyniku (PlayCard.outcomes) na inne zdarzenie.
## Szansa = base + per_step × (miara / step), przycięta do 0..max_chance (w %). Miara to liczba punktów z rzutu
## (np. niedobór obrony do progu), więc „10% za każde 0,5 niedoboru” = per_step 10, step 0,5, miara
## defense_deficit. Warunek: pola akcji (cells; puste = wszędzie).
## Odnogi slotu losuje się jednym rzutem po kolei (szanse się sumują, łącznie maks. 100%); gdy żadna nie
## wypadnie, działa zwykły efekt slotu. Zasady: docs/design/match_rules.md („Odnogi wyników”).

## Miary z rzutu (PlayContest): brak = stała szansa, niedobór / nadwyżka strony do progu, różnica nadwyżek
## (o ile rozstrzygnął się pojedynek).
enum Measure { NONE, DEFENSE_DEFICIT, ATTACK_DEFICIT, DEFENSE_SURPLUS, ATTACK_SURPLUS, DUEL_MARGIN }

const MEASURE_IDS: Array[StringName] = [&"none", &"defense_deficit", &"attack_deficit", &"defense_surplus",
		&"attack_surplus", &"duel_margin"]
const MEASURE_NAME_KEYS: Array[String] = ["BRANCH_MEASURE_NONE", "BRANCH_MEASURE_DEFENSE_DEFICIT",
		"BRANCH_MEASURE_ATTACK_DEFICIT", "BRANCH_MEASURE_DEFENSE_SURPLUS", "BRANCH_MEASURE_ATTACK_SURPLUS",
		"BRANCH_MEASURE_DUEL_MARGIN"]
const DEFAULT_STEP := 0.5

var event: StringName = PlayEvents.FOUL
var move_player := false
## Szanse w procentach.
var base_chance := 0.0
var per_step := 10.0
var step := DEFAULT_STEP
var max_chance := 100.0
var measure: Measure = Measure.DEFENSE_DEFICIT
## Pola akcji (perspektywa atakujących), w których odnoga działa; puste = wszędzie.
var cells: Array[Vector2i] = []


static func create(event_id: StringName) -> OutcomeBranch:
	var branch := OutcomeBranch.new()
	branch.event = event_id
	return branch


func applies_at(cell: Vector2i) -> bool:
	return cells.is_empty() or cell in cells


## Szansa (0..1) przy danej wartości miary.
func get_chance(measure_value: float) -> float:
	var percent := base_chance
	if measure != Measure.NONE and step > 0.0:
		percent += per_step * maxf(measure_value, 0.0) / step
	return clampf(percent, 0.0, max_chance) / 100.0


## Wartość miary z rozstrzygniętej akcji.
static func get_measure_value(contest: PlayContest, measure_type: Measure) -> float:
	match measure_type:
		Measure.DEFENSE_DEFICIT:
			return contest.get_deficit(false)
		Measure.ATTACK_DEFICIT:
			return contest.get_deficit(true)
		Measure.DEFENSE_SURPLUS:
			return maxf(contest.get_surplus(false), 0.0)
		Measure.ATTACK_SURPLUS:
			return maxf(contest.get_surplus(true), 0.0)
		Measure.DUEL_MARGIN:
			return absf(contest.get_surplus(true) - contest.get_surplus(false))
	return 0.0


func to_dict() -> Dictionary:
	var cell_list: Array = []
	for cell in cells:
		cell_list.append([cell.x, cell.y])
	return {
		"event": String(event),
		"move_player": move_player,
		"measure": String(MEASURE_IDS[measure]),
		"base": base_chance,
		"per_step": per_step,
		"step": step,
		"max": max_chance,
		"cells": cell_list,
	}


static func from_dict(data: Dictionary) -> OutcomeBranch:
	var branch := OutcomeBranch.new()
	branch.event = StringName(str(data.get("event", PlayEvents.FOUL)))
	branch.move_player = bool(data.get("move_player", false))
	branch.measure = maxi(MEASURE_IDS.find(StringName(str(data.get("measure", "none")))), 0) as Measure
	branch.base_chance = float(data.get("base", 0.0))
	branch.per_step = float(data.get("per_step", 0.0))
	branch.step = float(data.get("step", DEFAULT_STEP))
	branch.max_chance = float(data.get("max", 100.0))
	for cell: Variant in data.get("cells", []):
		if cell is Array and cell.size() >= 2:
			branch.cells.append(Vector2i(int(cell[0]), int(cell[1])))
	return branch

extends SceneTree
## Zrzut ekranu meczu po kilku turach rozegranych automatycznie za gracza (pierwsze zagranie i pierwszy cel, bez
## przesunięć i przerzutów, kości ułożone przyciskiem „Ułóż najlepiej”, zatwierdzenie).
## Uruchomienie (okno, nie --headless – potrzebny render):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/match_screenshot.gd -- --windowed turns=6 stage=roll out=C:/tmp/x.png
## Argumenty: turns = od której tury (indeks) szukać chwili zrzutu, stage = chwila tury:
##   choose (gracz wybiera zagranie), roll (gracz układa kości – dowolny etap), attack / defense (gracz układa
##   kości w etapie ataku / obrony), result (rozstrzygnięcie, podświetlony wynik na karcie);
##   seed = ziarno meczu (domyślnie 1), card = id zagrania wybieranego zamiast pierwszego, gdy jest w ręce (wtedy
##   chwila zrzutu musi też dotyczyć tury z tym zagraniem; przy stage=choose – ręki z tym zagraniem). Bez statycznych typów klas projektu (autoloady nie są gotowe przy kompilacji).

const PLACE_MODE := 2  # match.gd DiceMode.PLACE

var _args := {}
var _frame := 0
var _scene: Node
var _done := false
var _auto_placed := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			_args[parts[0]] = parts[1]


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		seed(int(_args.get("seed", "1")))
		Engine.time_scale = 25.0
		_scene = load("res://scenes/match/match.tscn").instantiate()
		root.add_child(_scene)
	if _frame < 10 or _done:
		return false
	var turns := int(_args.get("turns", "0"))
	var stage: String = _args.get("stage", "choose")
	var turn = _scene._turn
	var wanted: String = _args.get("card", "")
	var card_ok: bool = wanted.is_empty() or (turn != null and turn.card != null and String(turn.card.id) == wanted) \
			or (stage == "choose" and turn != null and _hand_has(turn, wanted))
	if turn != null and turn.index >= turns and card_ok and _at_stage(turn, stage):
		Engine.time_scale = 1.0
		_done = true
		_shoot.call_deferred()
		return false
	if _frame % 3 == 0:
		_drive(turn)
	return false


func _hand_has(turn, card_id: String) -> bool:
	for card in turn.hand:
		if String(card.id) == card_id:
			return true
	return false


func _at_stage(turn, stage: String) -> bool:
	var placing: bool = turn.contest != null and _scene._dice_mode == PLACE_MODE
	match stage:
		"roll":
			return placing
		"attack":
			return placing and _scene._active_side == 1
		"defense":
			return placing and _scene._active_side == 0
		"result":
			return _scene._card_view != null and _scene.engine.turn == turn.index + 1
		_:
			return turn.card == null and not turn.hand.is_empty() and turn.index == _scene.engine.turn \
					and _scene.engine.get_team_index(turn.attackers) == _scene.human_index


## Jedno „kliknięcie” gracza: zagranie z celem, „Ułóż najlepiej” przy układaniu, potem dowolna akcja
## (pomiń / zatwierdź / dalej).
func _drive(turn) -> void:
	if turn != null and turn.card == null and not turn.hand.is_empty():
		var chosen = turn.hand[0]
		for card in turn.hand:
			if String(card.id) == _args.get("card", ""):
				chosen = card
		var targets = chosen.get_targets(turn.ball_zone)
		_scene._emit_input({"type": &"play", "card": chosen, "target": targets[0]})
		return
	if _scene._dice_mode == PLACE_MODE and not _auto_placed:
		_auto_placed = true
		_scene._emit_input({"type": &"action", "id": &"auto"})
		return
	_auto_placed = false
	_scene._emit_input({"type": &"action", "id": &"confirm"})


func _shoot() -> void:
	for i in 20:
		await process_frame
	var out: String = _args.get("out", OS.get_user_data_dir() + "/match_screenshot.png")
	root.get_texture().get_image().save_png(out)
	print("Saved ", out)
	quit()

extends Control
## Ekran meczu: gracz (gospodarze) kontra komputer, tura po turze (2 × 15 tur, 3 minuty na turę).
## Po lewej stadion z boiskiem, po prawej: wynik, oś meczu, karty i testy z miejscami na kości, decyzje
## i warunki meczu. Silnik: MatchEngine krok po kroku – te same kroki co symulacja AI kontra AI, tylko za
## drużynę gracza decyduje gracz. Zasady: res://docs/design/match_rules.md.

## Wejście gracza: {"type": &"action" | &"card" | &"play" | &"cell" | &"player", ...}
## (&"play" = potwierdzone zagranie z celem: {"card", "target"}).
signal _input_received(data: Dictionary)

## Panel po prawej: od PANEL_GAP za widokiem stadionu do prawego marginesu ekranu.
const PANEL_TOP := 16.0
const PANEL_GAP := 24.0
const SCREEN_MARGIN := 16.0
## Odstęp między kartami w ręce.
const HAND_GAP := 12
## Widoczny fragment stadionu (lewa część ekranu): szerokość stadionu z największymi trybunami (zależy od układu
## boiska), wysokość ekranu. Gdy stadion się mieści, jest wyśrodkowany w pionie; gdy jest wyższy, widok się
## przesuwa, a boisko jest domyślnie z marginesem PITCH_TOP od góry.
const PITCH_TOP := 8.0
const SCROLL_STEP := 48.0
const SCROLL_HINT_COLOR := Color(0.91, 0.93, 0.87, 0.55)
## Pauza po ruchu komputera (sekundy), żeby gracz widział, co się stało.
const AI_DELAY := 1.0

const BG := Color("#10201a")
const PANEL_BG := Color("#182d23")
const PANEL_BORDER := Color("#2d4a39")
const TEXT := Color("#e9eedf")
const MUTED := Color("#a9b7a4")
const GOLD := Color("#f2cf4a")
const ATTACK_COLOR := Color("#9fe07a")
const DEFENSE_COLOR := Color("#ffb070")

enum DiceMode { NONE, REROLL, PLACE }

var engine: MatchEngine
var conditions: MatchConditions
## Drużyna gracza (indeks w engine.teams).
var human_index := 0

var _stadium: StadiumView
var _pitch: MatchPitch
var _timeline: MatchTimeline
var _score_label: Label
var _minute_label: Label
var _main: VBoxContainer
var _status: Label
var _buttons: HBoxContainer
var _button_by_id: Dictionary = {}
var _fx: Control
var _tests: TestsPanel
var _turn: MatchEngine.Turn
var _card_view: PlayCardView
## Etap tury w pasku decyzji („Atak – Redwood:”), pusty poza etapami.
var _phase_text := ""
var _dice_mode: DiceMode = DiceMode.NONE
## Strona gracza w bieżącej decyzji o kościach: int(attacking), -1 = brak.
var _active_side := -1
var _reroll_selection: Array[PlayContest.ContestDie] = []
var _profile: PlayerDetailsScreen
var _stadium_view: Control
var _stadium_view_size := Vector2.ZERO
var _stadium_world: Control
var _scroll_hints: Control
## Przesunięcie widoku stadionu w pionie (px od góry stadionu) i przeciąganie środkowym przyciskiem.
var _stadium_scroll := 0.0
var _stadium_dragging := false
var _scroll_tween: Tween


func _ready() -> void:
	# Uruchomienie sceny bezpośrednio (F6) – tworzymy domyślne składy.
	if GameState.player_lineup == null:
		GameState.setup_quick_match()
	conditions = MatchConditions.create_default()
	var rules := MatchRules.new()
	conditions.apply_to(rules)
	var library := PlayLibrary.load_default()
	if not library.load_error.is_empty():
		push_error("Match: cannot load plays: %s" % library.load_error)
	var home_lineup := GameState.player_lineup
	var away_lineup := GameState.opponent_lineup
	var home := MatchTeam.create(home_lineup, library.get_deck(home_lineup.tactic.id), rules, MatchAI.create())
	var away := MatchTeam.create(away_lineup, library.get_deck(away_lineup.tactic.id), rules, MatchAI.create())
	engine = MatchEngine.create(home, away, rules, randi())
	engine.keep_history = true
	engine.start_match()
	_build()
	_run_match()


# --- Przebieg meczu ---

func _run_match() -> void:
	_refresh_header()
	while not engine.is_finished():
		if engine.turn == engine.rules.turns_per_half:
			await _wait_action(tr("MATCH_HALF_TIME") % engine.rules.halftime_energy,
					[[&"continue", tr("MATCH_CONTINUE"), true]])
		await _play_turn()
	_timeline.current_index = -1
	_refresh_header()
	var home := engine.teams[0].lineup.team
	var away := engine.teams[1].lineup.team
	await _wait_action(tr("MATCH_FULL_TIME") % [home.short_name, engine.score[0], engine.score[1], away.short_name],
			[[&"menu", tr("MATCH_BACK_TO_MENU"), true]])
	SceneManager.change_scene(SceneManager.MAIN_MENU)


func _play_turn() -> void:
	_turn = engine.begin_turn()
	var t := _turn
	_timeline.current_index = t.index
	_refresh_header()
	_pitch.refresh()
	if t.skipped:
		await _wait_action(tr("MATCH_NO_CARD") % t.attackers.get_short_name(), [[&"continue", tr("MATCH_CONTINUE"), true]])
		_refresh_header()
		return
	var attackers_index := engine.get_team_index(t.attackers)
	if attackers_index == human_index:
		await _human_choose_play(t)
	else:
		engine.choose_ai_play()
	_show_play(t)
	if attackers_index != human_index:
		_set_prompt(tr("MATCH_AI_PLAYS") % [t.attackers.get_short_name(), t.card.name])
		await _pause()

	# Etap ataku, potem etap obrony (W12): na boisku leżą naraz kości tylko strony, która gra etap.
	for attacking: bool in [true, false]:
		await _play_side(attacking)

	engine.finish_turn()
	_card_view.highlight_outcome(t.slot, t.event)
	_refresh_header()
	_pitch.refresh()
	await _wait_action(_describe_result(t), [[&"continue", tr("MATCH_CONTINUE"), true]])
	_pitch.clear_dice()
	_pitch.clear_overlay()
	_clear_main()
	_tests = null
	_card_view = null


## Etap jednej strony: przesunięcie → rzut → przerzuty → ułożenie kości (zatwierdzenie). Kości poprzedniego
## etapu znikają z boiska (zostają w miejscach testów).
func _play_side(attacking: bool) -> void:
	var t := _turn
	var attackers_index := engine.get_team_index(t.attackers)
	_pitch.clear_dice()
	var team := _side_team(attacking)
	_phase_text = (tr("MATCH_PHASE_ATTACK") if attacking else tr("MATCH_PHASE_DEFENSE")) % team.get_short_name()
	# Strzał: obrona to też interwencja bramkarza – jego ramka pojawia się w środku (karta zsuwa się, gdy trzeba).
	if not attacking and t.card.has_keeper_test():
		await _tests.show_keeper()
	if _is_human(attacking):
		await _human_shift(attacking)
	else:
		await _ai_shift(attacking)
	_card_view.refresh_diagram()
	_set_prompt(tr("MATCH_ROLLING"))
	var dice := engine.roll_side(attacking)
	if attacking:
		_tests.set_contest(t.contest)
	else:
		_tests.refresh()
	_pitch.create_dice(t.contest, attacking)
	await _pitch.animate_roll(dice, MatchPitch.to_screen(t.target, attackers_index))
	_update_dice()
	for round_index in engine.rules.reroll_rounds:
		var rerolled: int = await _human_reroll(attacking) if _is_human(attacking) else await _ai_reroll(attacking)
		if rerolled == 0:
			break
	if _is_human(attacking):
		await _human_place(attacking)
	else:
		await _ai_place(attacking)
	_phase_text = ""


func _is_human(attacking: bool) -> bool:
	return engine.get_team_index(_turn.attackers if attacking else _turn.defenders) == human_index


func _side_team(attacking: bool) -> MatchTeam:
	return _turn.attackers if attacking else _turn.defenders


# --- Decyzje gracza ---

## Wybór zagrania tylko na kartach (boisko nic tu nie wybiera): najechanie bez zaznaczenia = podgląd,
## klik = zaznaczenie i podgląd, drugi klik albo „Zagraj” = potwierdzenie. Karta z kilkoma celami (np. strona
## skrzydła) potwierdza się przyciskiem celu na karcie; najechanie na przycisk pokazuje ten cel na boisku.
func _human_choose_play(t: MatchEngine.Turn) -> void:
	var attackers_index := engine.get_team_index(t.attackers)
	_clear_main()
	var views := {}  # PlayCard -> PlayCardView
	var selected: PlayCardView = null
	# Trzy pionowe karty obok siebie (K4), równej wysokości.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", HAND_GAP)
	_main.add_child(row)
	var context := {"attackers": t.attackers, "defenders": t.defenders, "rules": engine.rules,
			"owners": [_owner_name(false), _owner_name(true)], "flipped": attackers_index != 0}
	for card in t.hand:
		var targets := card.get_targets(t.ball_zone)
		var odds := PlayContest.create(card, PlayCard.get_origin(t.ball_zone, targets[0]), targets[0], t.attackers,
				t.defenders, engine.rules)
		var view := PlayCardView.create(card, PlayCardView.Mode.PORTRAIT, t.ball_zone, targets,
				Vector2(DiceOdds.fill_probability(odds, true), DiceOdds.fill_probability(odds, false)) * 100.0, context)
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_stretch_ratio = 1.0
		view.clickable = true
		view.pressed.connect(func(chosen: PlayCard) -> void: _emit_input({"type": &"card", "card": chosen}))
		view.target_chosen.connect(func(chosen: PlayCard, target: Vector2i) -> void:
			_emit_input({"type": &"play", "card": chosen, "target": target}))
		view.target_hovered.connect(func(hovered: PlayCard, target: Vector2i, entered: bool) -> void:
			if entered:
				var single: Array[Vector2i] = [target]
				_preview_play(hovered, single, attackers_index)
			else:
				_preview_play(hovered, hovered.get_targets(t.ball_zone), attackers_index))
		view.mouse_entered.connect(func() -> void:
			if not _has_selected_card():
				_preview_play(card, targets, attackers_index))
		view.mouse_exited.connect(func() -> void:
			if not _has_selected_card():
				_pitch.set_choice_cells([])
				_pitch.clear_overlay())
		row.add_child(view)
		views[card] = view
	# Gdy kart jest mniej niż 3, zostają puste miejsca – karty mają zawsze tę samą szerokość.
	for i in range(t.hand.size(), engine.rules.hand_size):
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gap)
	_set_prompt(tr("MATCH_CHOOSE_PLAY"))
	while true:
		var data := await _next_input()
		if data["type"] == &"play":
			engine.set_play(data["card"], data["target"])
			break
		if data["type"] != &"card":
			continue
		var card: PlayCard = data["card"]
		var view: PlayCardView = views[card]
		var targets := card.get_targets(t.ball_zone)
		if view == selected:
			# Drugi klik w zaznaczoną kartę potwierdza ją – tylko gdy cel jest jeden (inaczej przycisk strony).
			if targets.size() == 1:
				engine.set_play(card, targets[0])
				break
			continue
		if selected != null:
			selected.selected = false
			selected.show_choice(false)
		selected = view
		view.selected = true
		view.show_choice(true)
		_preview_play(card, targets, attackers_index)
		_set_prompt((tr("MATCH_CONFIRM_PLAY") if targets.size() == 1 else tr("MATCH_CHOOSE_SIDE")) % card.name)
	_pitch.set_choice_cells([])


func _has_selected_card() -> bool:
	for view in _main.find_children("*", "PlayCardView", true, false):
		if view.selected:
			return true
	return false


## Podpis strony na karcie: „Ty” albo „Komputer”.
func _owner_name(attacking: bool) -> String:
	return tr("MATCH_YOU") if _is_human(attacking) else tr("MATCH_COMPUTER")


## Podgląd zagrania na boisku: nakładka dla pierwszego celu, a przy kilku celach – także podświetlone
## (nieklikalne) pola wszystkich celów.
func _preview_play(card: PlayCard, targets: Array[Vector2i], attackers_index: int) -> void:
	_pitch.set_overlay(card, PlayCard.get_origin(_turn.ball_zone, targets[0]), targets[0], attackers_index)
	var cells: Array[Vector2i] = []
	if targets.size() > 1:
		for cell in targets:
			cells.append(MatchPitch.to_screen(cell, attackers_index))
	_pitch.set_choice_cells(cells, MatchPitch.CHOICE_COLOR, false)


func _human_shift(attacking: bool) -> void:
	var team := _side_team(attacking)
	var team_index := engine.get_team_index(team)
	var candidates: Array[MatchPlayer] = []
	for player in team.players:
		if not player.is_goalkeeper() and player.energy >= engine.rules.shift_cost:
			candidates.append(player)
	if candidates.is_empty():
		return
	_pitch.selectable_players = candidates
	_pitch.selected_player = null
	_pitch.refresh(false)
	_set_prompt(tr("MATCH_SHIFT_PROMPT"), [[&"skip", tr("MATCH_NO_SHIFT_BUTTON")]])
	var selected: MatchPlayer = null
	while true:
		var data := await _next_input()
		if data["type"] == &"action":
			break
		if data["type"] == &"player":
			selected = data["player"]
			_pitch.selected_player = selected
			var cells: Array[Vector2i] = []
			for direction in MatchAI.SHIFT_DIRECTIONS:
				if engine.can_shift(selected, direction, attacking):
					cells.append(MatchPitch.to_screen(selected.get_base_cell() + direction, team_index))
			_pitch.set_choice_cells(cells, MatchPitch.SHIFT_COLOR)
			_pitch.refresh(false)
		elif data["type"] == &"cell" and selected != null:
			var own_cell := MatchPitch.to_screen(data["cell"], team_index)
			engine.apply_shift(selected, own_cell - selected.get_base_cell(), attacking)
			break
	_pitch.selectable_players = []
	_pitch.selected_player = null
	_pitch.set_choice_cells([])
	_pitch.refresh()


func _human_reroll(attacking: bool) -> int:
	_reroll_selection.clear()
	_dice_mode = DiceMode.REROLL
	_active_side = int(attacking)
	_update_dice()
	_set_prompt(tr("MATCH_REROLL_PROMPT"),
			[[&"skip", tr("MATCH_NO_REROLL_BUTTON")], [&"reroll", tr("MATCH_REROLL_BUTTON") % 0, true]])
	_update_reroll_button()
	var count := 0
	while true:
		var data := await _next_input()
		if data["type"] != &"action":
			continue
		if data["id"] == &"reroll":
			if _reroll_selection.is_empty() or not engine.can_reroll(_reroll_selection):
				continue
			var dice := _reroll_selection.duplicate()
			_reroll_selection.clear()
			_dice_mode = DiceMode.NONE
			_update_dice()
			_set_prompt(tr("MATCH_ROLLING"))
			engine.reroll(dice, attacking)
			await _pitch.animate_reroll(dice)
			_pitch.refresh()
			count = dice.size()
		break
	_dice_mode = DiceMode.NONE
	_active_side = -1
	_update_dice()
	return count


func _human_place(attacking: bool) -> void:
	_dice_mode = DiceMode.PLACE
	_active_side = int(attacking)
	_tests.editable_side = int(attacking)
	_pitch.accepts_returned_dice = true
	_tests.refresh()
	_update_dice()
	_set_prompt(tr("MATCH_PLACE_PROMPT"), [[&"auto", tr("MATCH_PLACE_AUTO")], [&"confirm", tr("MATCH_CONFIRM"), true]])
	while true:
		var data := await _next_input()
		if data["type"] != &"action":
			continue
		if data["id"] == &"auto":
			_tests.auto_place(attacking)
		elif data["id"] == &"confirm":
			break
	_turn.contest.set_placement(attacking, _tests.get_placement(attacking))
	_tests.editable_side = -1
	_pitch.accepts_returned_dice = false
	_dice_mode = DiceMode.NONE
	_active_side = -1
	_tests.refresh()
	_update_dice()


# --- Ruchy komputera ---

func _ai_shift(attacking: bool) -> void:
	var shift := engine.ai_shift(attacking)
	if shift.is_empty():
		return
	var player: MatchPlayer = shift["player"]
	_pitch.refresh()
	_set_prompt(tr("MATCH_AI_SHIFT") % [_side_team(attacking).get_short_name(), player.data.last_name])
	await _pause()


func _ai_reroll(attacking: bool) -> int:
	var chosen := engine.ai_rerolls(attacking)
	if chosen.is_empty():
		return 0
	_set_prompt(tr("MATCH_AI_REROLLS") % [_side_team(attacking).get_short_name(), chosen.size()])
	await _pitch.animate_reroll(chosen)
	_pitch.refresh()
	_update_dice()
	await _pause(0.6)
	return chosen.size()


func _ai_place(attacking: bool) -> void:
	var placement := engine.place_auto(attacking)
	_set_prompt(tr("MATCH_AI_PLACES") % _side_team(attacking).get_short_name())
	_tests.show_placement(attacking, placement)
	await get_tree().process_frame
	var tween: Tween
	for contest_die: PlayContest.ContestDie in placement:
		var slot_view := _tests.get_slot_view(contest_die)
		var chip := _pitch.get_die_view(contest_die)
		if slot_view == null or chip == null:
			continue
		slot_view.modulate.a = 0.0
		var flying := MatchDie.create_for(contest_die, MatchDie.DieSize.LARGE)
		flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fx.add_child(flying)
		flying.global_position = chip.global_position
		if tween == null:
			tween = create_tween().set_parallel(true)
		tween.tween_property(flying, "global_position", slot_view.global_position, 0.45) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.chain().tween_callback(func() -> void:
			flying.queue_free()
			slot_view.modulate.a = 1.0)
		tween.set_parallel(true)
	_update_dice()
	if tween != null:
		await tween.finished
	await _pause(0.6)


# --- Kości przy zawodnikach ---

func _on_die_clicked(match_die: MatchDie) -> void:
	var contest_die := match_die.contest_die
	if contest_die == null or int(contest_die.attacking) != _active_side:
		return
	match _dice_mode:
		DiceMode.REROLL:
			if _reroll_selection.has(contest_die):
				_reroll_selection.erase(contest_die)
			else:
				_reroll_selection.append(contest_die)
			_update_dice()
			_update_reroll_button()
		DiceMode.PLACE:
			if _tests.is_placed(contest_die):
				_tests.remove(contest_die)
			else:
				_tests.place(contest_die)


## Stan małych kości przy koszulkach: zaznaczone do przerzutu, w miejscu testu, bezużyteczne; plakietka punktów.
func _update_dice() -> void:
	if _turn == null or _turn.contest == null:
		return
	var contest := _turn.contest
	for view in _pitch.get_die_views():
		var contest_die := view.contest_die
		view.sync_face()
		var usable := contest.get_requirement_index(contest_die, contest_die.attacking) != -1
		var placed := _tests != null and _tests.is_placed(contest_die)
		if _reroll_selection.has(contest_die):
			view.state = MatchDie.State.SELECTED
		elif placed:
			view.state = MatchDie.State.PLACED
		else:
			view.state = MatchDie.State.NORMAL if usable else MatchDie.State.USELESS
		if contest_die.attacking:
			view.points_color = ATTACK_COLOR
		else:
			view.points_color = TestsPanel.KEEPER_COLOR if contest_die.keeper_efficiency > 0.0 else DEFENSE_COLOR
		view.points_text = MatchDie.format_points(contest.get_die_points(contest_die)) if usable else ""
		var own := int(contest_die.attacking) == _active_side
		view.clickable = own and (_dice_mode == DiceMode.REROLL or (_dice_mode == DiceMode.PLACE and usable))
		view.draggable = own and _dice_mode == DiceMode.PLACE and usable
		view.tooltip_text = "%s (%s)" % [contest_die.player.data.get_full_name(),
				tr(GameData.get_attribute(view.attribute_id).name_key) if GameData.get_attribute(view.attribute_id) else ""]


func _update_reroll_button() -> void:
	var button: Button = _button_by_id.get(&"reroll")
	if button == null:
		return
	button.text = tr("MATCH_REROLL_BUTTON") % _reroll_selection.size()
	button.disabled = _reroll_selection.is_empty() or not engine.can_reroll(_reroll_selection)


# --- Panel ---

func _show_play(t: MatchEngine.Turn) -> void:
	var attackers_index := engine.get_team_index(t.attackers)
	_clear_main()
	# Rozwinięte zagranie (W16): kości gracza z lewej, karta w środku, kości komputera z prawej.
	_tests = TestsPanel.new()
	_tests.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(_tests)
	var owners: Array[String] = [_owner_name(false), _owner_name(true)]
	_tests.setup(t.card, t.attackers.get_short_name(), t.defenders.get_short_name(), _is_human(true), owners,
			t.origin, t.target, attackers_index)
	_update_test_rows()
	_tests.placement_changed.connect(_update_dice)
	var context := {"attackers": t.attackers, "defenders": t.defenders, "rules": engine.rules,
			"flipped": attackers_index != 0}
	var card_view := PlayCardView.create(t.card, PlayCardView.Mode.FULL, t.ball_zone, [t.target], Vector2(-1, -1),
			context)
	card_view.selected = true
	_tests.center.add_child(card_view)
	_card_view = card_view
	_pitch.set_overlay(t.card, t.origin, t.target, attackers_index)


## Pasy stref boiska na ekranie (strefa ekranu 1..5: góra i dół w globalnych y) – testy stoją na ich wysokości
## (W17); wywoływane też przy przesuwaniu stadionu.
func _update_test_rows() -> void:
	if _tests == null or not is_instance_valid(_tests):
		return
	var rows: Array[Vector2] = []
	var pitch_transform := _pitch.get_global_transform()
	for zone in range(1, MatchRules.ZONE_COUNT + 1):
		var rect := _pitch.get_cell_rect(Vector2i(zone, 0))
		rows.append(Vector2((pitch_transform * rect.position).y, (pitch_transform * rect.end).y))
	_tests.set_zone_rows(rows)


func _clear_main() -> void:
	for child in _main.get_children():
		child.queue_free()


func _describe_result(t: MatchEngine.Turn) -> String:
	var attack := MatchDie.format_points(t.surplus[1])
	var defense := MatchDie.format_points(t.surplus[0])
	var outcome_text := ""
	var won := t.slot == &"duel_won"
	match t.outcome:
		MatchEngine.Outcome.SUCCESS:
			outcome_text = tr("MATCH_RESULT_SUCCESS")
		MatchEngine.Outcome.DEFENSE:
			outcome_text = tr("MATCH_RESULT_DEFENSE")
		MatchEngine.Outcome.BOTH:
			outcome_text = tr("MATCH_RESULT_DUEL_WON" if won else "MATCH_RESULT_DUEL_LOST") % [attack, defense]
		_:
			# Nikt nie zapełnił testów: pojedynek wygrywa strona, której mniej brakowało.
			outcome_text = tr("MATCH_RESULT_NONE_WON" if won else "MATCH_RESULT_NONE_LOST") % [attack, defense]
	if t.event == PlayEvents.GOAL:
		return "%s %s" % [outcome_text, tr("MATCH_GOAL") % t.attackers.lineup.team.name]
	if t.keeper_save:
		return "%s %s" % [outcome_text, tr("MATCH_KEEPER_SAVED") % t.defenders.lineup.team.name]
	return "%s %s" % [outcome_text, tr("MATCH_RESULT_EVENT") % PlayEvents.get_display_name(t.event)]


func _refresh_header() -> void:
	_score_label.text = "%d : %d" % [engine.score[0], engine.score[1]]
	var index := _timeline.current_index if _timeline.current_index >= 0 else engine.rules.get_total_turns() - 1
	_minute_label.text = "%d'" % engine.get_minute(index)
	_timeline.queue_redraw()


# --- Wejście i przyciski ---

func _emit_input(data: Dictionary) -> void:
	_input_received.emit(data)


func _next_input() -> Dictionary:
	return await _input_received


func _wait_action(text: String, buttons: Array) -> StringName:
	_set_prompt(text, buttons)
	while true:
		var data := await _next_input()
		if data["type"] == &"action":
			return data["id"]
	return &""


## Tekst w pasku decyzji i przyciski [[id, tekst, główny?], ...].
func _set_prompt(text: String, buttons: Array = []) -> void:
	_status.text = text if _phase_text.is_empty() else "%s %s" % [_phase_text, text]
	_button_by_id.clear()
	for child in _buttons.get_children():
		child.queue_free()
	for spec: Array in buttons:
		var button := Button.new()
		button.text = spec[1]
		if spec.size() > 2 and spec[2]:
			button.add_theme_color_override(&"font_color", GOLD)
		button.pressed.connect(_emit_input.bind({"type": &"action", "id": spec[0]}))
		_buttons.add_child(button)
		_button_by_id[spec[0]] = button
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(_buttons.get_child_count() - 1) as Button).grab_focus.call_deferred()


# --- Widok stadionu ---

## Przesuwanie stadionu w pionie: środkowy przycisk myszy (przeciąganie, dwuklik = powrót), kółko myszy.
func _input(event: InputEvent) -> void:
	if _profile != null or _stadium_view == null:
		return
	if event is InputEventMouseMotion and _stadium_dragging:
		_set_stadium_scroll(_stadium_scroll - event.relative.y, false)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
		_stadium_dragging = false
		return
	if not _stadium_view.get_global_rect().has_point(event.position) or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			if event.double_click:
				_set_stadium_scroll(_get_default_scroll(), true)
			else:
				_stadium_dragging = true
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_UP:
			_set_stadium_scroll(_stadium_scroll - SCROLL_STEP, true)
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_WHEEL_DOWN:
			_set_stadium_scroll(_stadium_scroll + SCROLL_STEP, true)
			get_viewport().set_input_as_handled()


func _get_default_scroll() -> float:
	return _stadium.get_pitch_position().y - PITCH_TOP


func _get_scroll_range() -> Vector2:
	var content := _stadium.get_content_rect()
	if content.size.y <= _stadium_view_size.y:
		var centered := roundf(content.get_center().y - _stadium_view_size.y / 2.0)
		return Vector2(centered, centered)
	return Vector2(content.position.y, maxf(content.end.y - _stadium_view_size.y, content.position.y))


func _set_stadium_scroll(value: float, animate: bool) -> void:
	var limits := _get_scroll_range()
	_stadium_scroll = clampf(value, limits.x, limits.y)
	if _scroll_tween != null:
		_scroll_tween.kill()
	if animate:
		_scroll_tween = create_tween()
		_scroll_tween.tween_property(_stadium_world, "position:y", -_stadium_scroll, 0.2) 				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_stadium_world.position.y = -_stadium_scroll
	_scroll_hints.queue_redraw()


## Strzałki na górze / dole widoku, gdy stadion da się tam przesunąć.
func _draw_scroll_hints() -> void:
	var limits := _get_scroll_range()
	var center := _stadium_view_size.x / 2.0
	if _stadium_scroll > limits.x + 1.0:
		_scroll_hints.draw_colored_polygon(PackedVector2Array([Vector2(center - 8, 9), Vector2(center, 3),
				Vector2(center + 8, 9)]), SCROLL_HINT_COLOR)
	if _stadium_scroll < limits.y - 1.0:
		var bottom := _stadium_view_size.y
		_scroll_hints.draw_colored_polygon(PackedVector2Array([Vector2(center - 8, bottom - 9),
				Vector2(center, bottom - 3), Vector2(center + 8, bottom - 9)]), SCROLL_HINT_COLOR)


## Profil zawodnika jako nakładka (tylko podgląd – mecz czeka pod spodem).
func _open_profile(player: MatchPlayer) -> void:
	if _profile != null:
		return
	var team := engine.teams[_pitch.get_team_index(player)]
	_profile = PlayerDetailsScreen.create(team.lineup, player.data, true)
	_profile.back_requested.connect(func() -> void:
		_profile.queue_free()
		_profile = null)
	add_child(_profile)


func _pause(seconds := AI_DELAY) -> void:
	await get_tree().create_timer(seconds).timeout


# --- Budowa ekranu ---

func _build() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Stadion jest wyższy niż ekran (trybuny za bramkami) – widok przesuwamy w pionie (_input).
	var screen := get_viewport_rect().size
	_stadium_view_size = Vector2(StadiumView.get_full_size(PitchLayout.get_default().size).x, screen.y)
	_stadium_view = Control.new()
	_stadium_view.size = _stadium_view_size
	_stadium_view.clip_contents = true
	_stadium_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stadium_view)
	_stadium_world = Control.new()
	_stadium_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stadium_view.add_child(_stadium_world)
	_stadium = StadiumView.new()
	_stadium.conditions = conditions
	_stadium.home_color = engine.teams[0].lineup.team.primary_color
	_stadium.away_color = engine.teams[1].lineup.team.primary_color
	_stadium.size = _stadium.custom_minimum_size
	_stadium_world.add_child(_stadium)

	_pitch = MatchPitch.new()
	_pitch.position = _stadium.get_pitch_position()
	_stadium_world.add_child(_pitch)
	_scroll_hints = Control.new()
	_scroll_hints.size = _stadium_view_size
	_scroll_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll_hints.draw.connect(_draw_scroll_hints)
	_stadium_view.add_child(_scroll_hints)
	_set_stadium_scroll(_get_default_scroll(), false)
	_stadium_world.item_rect_changed.connect(_update_test_rows)
	_pitch.setup(engine)
	_pitch.player_clicked.connect(func(player: MatchPlayer) -> void: _emit_input({"type": &"player", "player": player}))
	_pitch.cell_clicked.connect(func(cell: Vector2i) -> void: _emit_input({"type": &"cell", "cell": cell}))
	_pitch.die_clicked.connect(_on_die_clicked)
	_pitch.player_profile_requested.connect(_open_profile)
	_pitch.die_returned.connect(func(contest_die: PlayContest.ContestDie) -> void:
		if _tests != null:
			_tests.remove(contest_die))

	var panel := VBoxContainer.new()
	panel.position = Vector2(_stadium_view_size.x + PANEL_GAP, PANEL_TOP)
	panel.size = Vector2(screen.x - SCREEN_MARGIN, screen.y - PANEL_TOP) - panel.position
	panel.clip_contents = true
	panel.add_theme_constant_override(&"separation", 10)
	add_child(panel)
	panel.add_child(_build_scoreboard())
	_timeline = MatchTimeline.new()
	panel.add_child(_timeline)
	_timeline.setup(engine)
	_main = VBoxContainer.new()
	_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_theme_constant_override(&"separation", 8)
	panel.add_child(_main)
	panel.add_child(_build_action_bar())
	panel.add_child(_build_conditions())

	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)


func _build_scoreboard() -> Control:
	var frame := _panel_container()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	frame.add_child(row)
	for team_index in 2:
		var team := engine.teams[team_index].lineup.team
		var block := HBoxContainer.new()
		block.add_theme_constant_override(&"separation", 8)
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if team_index == 1:
			block.alignment = BoxContainer.ALIGNMENT_END
		var crest := ColorRect.new()
		crest.color = team.primary_color
		crest.custom_minimum_size = Vector2(12, 18)
		crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var names := VBoxContainer.new()
		names.add_theme_constant_override(&"separation", -2)
		var name_label := _label(team.name, 15, TEXT)
		var who := _label(tr("MATCH_YOU") if team_index == human_index else tr("MATCH_COMPUTER"), 11, MUTED)
		if team_index == 1:
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		names.add_child(name_label)
		names.add_child(who)
		if team_index == 0:
			block.add_child(crest)
			block.add_child(names)
		else:
			block.add_child(names)
			block.add_child(crest)
		row.add_child(block)
		if team_index == 0:
			_score_label = _label("0 : 0", 30, TEXT)
			row.add_child(_score_label)
	var separator := VSeparator.new()
	row.add_child(separator)
	_minute_label = _label("0'", 26, GOLD)
	_minute_label.custom_minimum_size.x = 52
	_minute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_minute_label)
	return frame


func _build_action_bar() -> Control:
	var frame := _panel_container(GOLD)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	frame.add_child(row)
	_status = _label("", 13, TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.custom_minimum_size = Vector2(0, 40)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override(&"separation", 6)
	_buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_buttons)
	return frame


func _build_conditions() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var items := [
		[tr("MATCH_PITCH"), tr(MatchConditions.PITCH_NAME_KEYS[conditions.pitch_quality])],
		[tr("MATCH_WEATHER"), tr(MatchConditions.WEATHER_NAME_KEYS.get(conditions.weather, "MATCH_WEATHER_CLOUDY"))
				% conditions.temperature],
		[tr("MATCH_CROWD"), tr("MATCH_CROWD_VALUE") % [_format_thousands(conditions.attendance),
				_format_thousands(conditions.capacity)]],
	]
	for item: Array in items:
		var frame := _panel_container()
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", -2)
		box.add_child(_label(item[0], 11, MUTED))
		box.add_child(_label(item[1], 13, TEXT))
		frame.add_child(box)
		row.add_child(frame)
	var menu := Button.new()
	menu.text = tr("MATCH_BACK_TO_MENU")
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.pressed.connect(func() -> void: SceneManager.change_scene(SceneManager.MAIN_MENU))
	row.add_child(menu)
	return row


func _panel_container(border := PANEL_BORDER) -> PanelContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	frame.add_theme_stylebox_override(&"panel", style)
	return frame


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


static func _format_thousands(value: int) -> String:
	var text := str(value)
	var result := ""
	while text.length() > 3:
		result = " " + text.right(3) + result
		text = text.left(text.length() - 3)
	return text + result

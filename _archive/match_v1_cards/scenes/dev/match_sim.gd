extends Node
## Symulacja meczów AI vs AI bez interfejsu – raport do strojenia zasad (PROTOTYP silnika).
## Zasady: res://docs/design/match_rules.md. Karty: res://data/plays/plays.json (PlayLibrary). Uruchomienie:
##   Godot --headless --path . res://scenes/dev/match_sim.tscn -- matches=500 seed=1
## Argumenty: matches, seed, home, away, home_tactic, away_tactic (np. t_352), home_risk, away_risk, random_dice=1, log=1, cards=1,
## attack_scale / defense_scale (mnożnik progów wszystkich kart),
## role_dice (aktywne kości według roli zamiast pozycji, np. role_dice=DM:physical+defensive;AM:physical+technical),
## calibrate=1 (średnie punkty i szanse każdej karty z każdego pola, bez przesunięć i przerzutów)
## oraz dowolny parametr MatchRules (np. support_weight=0.7).

const RUNNER_ARGS: Array[String] = ["matches", "seed", "home", "away", "home_tactic", "away_tactic", "home_risk", "away_risk",
		"random_dice", "log", "cards", "calibrate", "attack_scale", "defense_scale", "role_dice"]


func _ready() -> void:
	var args := _parse_args()
	var rules := MatchRules.new()
	var overrides := {}
	for key: String in args:
		if key not in RUNNER_ARGS:
			overrides[key] = args[key]
	for key in rules.apply_overrides(overrides):
		push_warning("match_sim: unknown argument '%s'" % key)

	var match_count: int = args.get("matches", "200").to_int()
	var seed_value: int = args.get("seed", "1").to_int()
	var home_team := GameData.get_team(StringName(args.get("home", "red")))
	var away_team := GameData.get_team(StringName(args.get("away", "blue")))
	if home_team == null or away_team == null:
		push_error("match_sim: unknown team")
		get_tree().quit(1)
		return
	if args.get("random_dice", "0") == "1":
		_randomize_dice(seed_value)
	var home_lineup := Lineup.create_default(home_team, GameData.get_tactic(StringName(args.get("home_tactic", ""))))
	var away_lineup := Lineup.create_default(away_team, GameData.get_tactic(StringName(args.get("away_tactic", ""))))
	_apply_role_dice(home_lineup, args.get("role_dice", ""))
	_apply_role_dice(away_lineup, args.get("role_dice", ""))
	var home_risk: float = args.get("home_risk", "1.0").to_float()
	var away_risk: float = args.get("away_risk", "1.0").to_float()
	# Karty z res://data/plays/plays.json (Edytor zagrań); talia drużyny = karty jej taktyki.
	var library := PlayLibrary.load_default()
	if not library.load_error.is_empty():
		push_error("match_sim: cannot load plays: %s" % library.load_error)
		get_tree().quit(1)
		return
	var deck := library.plays
	var home_deck := library.get_deck(home_lineup.tactic.id)
	var away_deck := library.get_deck(away_lineup.tactic.id)
	# Mnożniki progów wszystkich kart (eksperymenty balansu, np. defense_scale=0.8).
	var attack_scale: float = args.get("attack_scale", "1.0").to_float()
	var defense_scale: float = args.get("defense_scale", "1.0").to_float()
	for card in deck:
		for requirement in card.attack:
			requirement.points *= attack_scale
		for requirement in card.defense:
			requirement.points *= defense_scale

	print("%s (%s) vs %s (%s), overrides: %s" % [home_team.name, home_lineup.tactic.name,
			away_team.name, away_lineup.tactic.name, overrides])
	if args.get("cards", "0") == "1":
		for card in deck:
			print("  " + card.describe())

	if args.get("calibrate", "0") == "1":
		_print_calibration(home_deck, away_deck, home_lineup, away_lineup, rules)

	var stats := MatchStats.new()
	var start := Time.get_ticks_usec()
	for i in match_count:
		var home := MatchTeam.create(home_lineup, home_deck, rules, MatchAI.create(home_risk))
		var away := MatchTeam.create(away_lineup, away_deck, rules, MatchAI.create(away_risk))
		var engine := MatchEngine.create(home, away, rules, seed_value * 100003 + i)
		engine.stats = stats
		engine.verbose = args.get("log", "0") == "1" and i == 0
		engine.play_match()
		if engine.verbose:
			print("\n".join(engine.log_lines))
			print("")
	stats.elapsed_usec = Time.get_ticks_usec() - start
	print(stats.build_report(home_team.short_name, away_team.short_name))
	get_tree().quit()


func _parse_args() -> Dictionary:
	var result := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else "1"
	return result


## Aktywne kości zawodników na wskazanych rolach, np. "DM:physical+defensive;AM:physical+technical".
func _apply_role_dice(lineup: Lineup, spec: String) -> void:
	if spec.is_empty():
		return
	for part in spec.split(";"):
		var pieces := part.split(":")
		var role_id := StringName(pieces[0])
		for slot in lineup.tactic.slots:
			if slot.role_id != role_id:
				continue
			var player := lineup.get_player_at(slot.index)
			var indices: Array[int] = []
			for type_id in pieces[1].split("+"):
				for i in player.dice.size():
					if player.dice[i].type.id == StringName(type_id) and i not in indices:
						indices.append(i)
						break
			lineup.active_dice[player.id] = indices


## Losowe punkty na ściankach (1–3), żeby zawodnicy się różnili. Zmienia tylko dane w pamięci.
func _randomize_dice(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for player: PlayerData in GameData.players.values():
		for die in player.dice:
			for face in die.face_values.size():
				die.face_values[face] = rng.randi_range(1, 3)


## Dla każdej karty i pola: średnie punkty ataku/obrony (próg) i szanse zapełnienia jednym rzutem.
## Każda drużyna tylko z kartami swojej talii.
func _print_calibration(home_deck: Array[PlayCard], away_deck: Array[PlayCard], home_lineup: Lineup,
		away_lineup: Lineup, rules: MatchRules) -> void:
	var home := MatchTeam.create(home_lineup, home_deck, rules, MatchAI.create())
	var away := MatchTeam.create(away_lineup, away_deck, rules, MatchAI.create())
	var cards: Array[PlayCard] = home_deck.duplicate()
	for card in away_deck:
		if not card in cards:
			cards.append(card)
	for card in cards:
		print(card.describe())
		for attacking_team: MatchTeam in [home, away]:
			if not card in attacking_team.deck:
				continue
			var defending_team: MatchTeam = away if attacking_team == home else home
			var cells := PackedStringArray()
			for zone in range(1, MatchRules.ZONE_COUNT + 1):
				for channel in MatchRules.CHANNEL_COUNT:
					var origin := Vector2i(zone, channel)
					if not card.can_play(origin):
						continue
					for target in card.get_targets(origin):
						var contest := PlayContest.create(card, origin, target, attacking_team, defending_team, rules)
						cells.append("%d%s>%d%s A%.1f/%.0f%% D%.1f/%.0f%%" % [zone, MatchRules.channel_letter(channel),
								target.x, MatchRules.channel_letter(target.y),
								DiceOdds.expected_points(contest, true), 100.0 * DiceOdds.fill_probability(contest, true),
								DiceOdds.expected_points(contest, false), 100.0 * DiceOdds.fill_probability(contest, false)])
			print("  %s: %s" % [attacking_team.get_short_name(), " | ".join(cells)])

extends Control
## Makiety ekranu szczegółów zawodnika do porównania (tylko dev, nie jest podpięte do gry).
## Klawisze: 1–4 wariant, ←/→ zawodnik. Kliknięcie kości przełącza ją w składzie.
## Argumenty po "--": variant=1..4 player=red_16 shot=ścieżka.png (zapisuje zrzut i kończy).
## Dane demo: arkusz nie ma jeszcze narodowości ani wieku, a wszystkie kości mają ścianki 1,2,1,2,1,2, więc tutaj
## zawodnicy dostają przykładowe wartości – inaczej każda cecha wyglądałaby tak samo.

const VARIANTS: Array[GDScript] = [
	preload("res://scenes/dev/player_mockups/variant_stand.gd"),
	preload("res://scenes/dev/player_mockups/variant_night.gd"),
	preload("res://scenes/dev/player_mockups/variant_wheel.gd"),
	preload("res://scenes/dev/player_mockups/variant_album.gd"),
]
const DEMO := [
	{"id": &"red_16", "nation": &"POL", "age": 24, "natural": [&"ST"], "secondary": [&"LW", &"RW"],
		"dice": [[2, 3, 3, 4, 1, 2], [1, 2, 4, 4, 1, 3], [1, 1, 2, 1, 1, 2]]},
	{"id": &"red_11", "nation": &"GER", "age": 29, "natural": [&"CM", &"AM"], "secondary": [&"DM", &"RM"],
		"dice": [[1, 2, 2, 2, 1, 1], [3, 4, 2, 3, 3, 4], [2, 2, 2, 3, 3, 3]]},
	{"id": &"red_05", "nation": &"SWE", "age": 27, "natural": [&"CB"], "secondary": [&"RB", &"DM"],
		"dice": [[3, 4, 2, 2, 3, 4], [1, 2, 1, 1, 1, 2], [3, 3, 2, 3, 4, 3]]},
	{"id": &"red_18", "nation": &"NGA", "age": 21, "natural": [&"LW", &"RW"], "secondary": [&"ST", &"RM"],
		"dice": [[2, 2, 4, 5, 2, 3], [2, 3, 3, 2, 3, 3], [1, 2, 1, 2, 1, 1]]},
	{"id": &"red_01", "nation": &"POL", "age": 31, "natural": [&"GK"], "secondary": [] as Array[StringName],
		"dice": [[2, 3, 2, 2, 3, 3], [3, 4, 2, 3, 4, 4]]},
]

var _variant := 0
var _demo_index := 0
var _lineup: Lineup
var _view: Control
var _shot_path := ""
var _frames_left := -1


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	TranslationServer.set_locale("pl")
	_lineup = Lineup.create_default(GameState.get_player_team())
	_lineup.changed.connect(_rebuild)
	for demo: Dictionary in DEMO:
		_apply_demo(demo)
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() != 2:
			continue
		match parts[0]:
			"variant":
				_variant = clampi(int(parts[1]) - 1, 0, VARIANTS.size() - 1)
			"player":
				for i in DEMO.size():
					if String(DEMO[i].id) == parts[1]:
						_demo_index = i
			"shot":
				_shot_path = parts[1]
				_frames_left = 6
	_rebuild()


func _process(_delta: float) -> void:
	if _frames_left < 0:
		return
	_frames_left -= 1
	if _frames_left == 0:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_1 and key < KEY_1 + VARIANTS.size():
		_variant = key - KEY_1
		_rebuild()
	elif key == KEY_RIGHT or key == KEY_LEFT:
		_demo_index = posmod(_demo_index + (1 if key == KEY_RIGHT else -1), DEMO.size())
		_rebuild()


func _rebuild() -> void:
	if _view != null:
		remove_child(_view)
		_view.queue_free()
	var demo: Dictionary = DEMO[_demo_index]
	var ctx := {
		"player": _find_player(demo.id),
		"lineup": _lineup,
		"team": _lineup.team,
		"nation": demo.nation,
		"nation_name": TranslationServer.translate("NATION_%s" % demo.nation),
		"age": demo.age,
		"read_only": false,
		"back": func() -> void: pass,
	}
	_view = VARIANTS[_variant].build(ctx)
	add_child(_view)


func _find_player(id: StringName) -> PlayerData:
	for player in _lineup.team.players:
		if player.id == id:
			return player
	push_error("Mockup: no player %s" % id)
	return _lineup.team.players[0]


func _apply_demo(demo: Dictionary) -> void:
	var player := _find_player(demo.id)
	player.age = demo.age
	player.natural_roles.assign(demo.natural)
	player.secondary_roles.assign(demo.secondary)
	player.portrait_look = PortraitLooks.generate(String(player.id), demo.nation)
	for i in mini(player.dice.size(), demo.dice.size()):
		player.dice[i].face_values.assign(demo.dice[i])

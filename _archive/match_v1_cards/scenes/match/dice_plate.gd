class_name DicePlate
extends Control
## Zawodnik biorący udział w akcji, po rzucie: zamiast koszulki jego kości (pełne ścianki 52 px) w ramce
## w kolorze drużyny, pod kośćmi numer i nazwisko, pod nimi pasek energii. Wokół kości poświata w kolorze
## koszulek (siła w ustawieniach: Settings.dice_glow) – od razu widać, czyje to kości.
## Nazwisko jest klikalne (profil zawodnika), pasek energii ma podpowiedź z wytrzymałością.

signal name_pressed(player: MatchPlayer)

const PADDING := 4.0
const DIE_GAP := 4.0
const NAME_HEIGHT := 13.0
const NAME_FONT_SIZE := 11
const MIN_WIDTH := 48.0
const BG := Color(0.04, 0.08, 0.06, 0.84)
const NAME_COLOR := Color.WHITE
## Poświata przy sile 1: promień (px) i krycie.
const GLOW_MAX_SIZE := 14.0
const GLOW_MIN_SIZE := 3.0
const GLOW_MAX_ALPHA := 0.95

var player: MatchPlayer
var team_color := Color.WHITE
var number_color := Color.WHITE
var dice: Array[MatchDie] = []
## Skuteczność wyczerpanego zawodnika (do podpowiedzi paska energii).
var exhausted_efficiency := 0.7

var _name_rect := Rect2()
var _energy_rect := Rect2()
var _name_hovered := false


func _init() -> void:
	PixelArt.apply(self)
	mouse_filter = Control.MOUSE_FILTER_PASS


func _ready() -> void:
	Settings.settings_changed.connect(queue_redraw)


static func create(p_player: MatchPlayer, p_team_color: Color, p_number_color: Color) -> DicePlate:
	var plate := DicePlate.new()
	plate.player = p_player
	plate.team_color = p_team_color
	plate.number_color = p_number_color
	return plate


func _get_tooltip(at_position: Vector2) -> String:
	if _energy_rect.grow(2.0).has_point(at_position):
		return EnergyBar.get_tooltip_text(player.energy, player.max_energy, exhausted_efficiency)
	return player.data.get_full_name()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _name_rect.has_point(event.position)
		if hovered != _name_hovered:
			_name_hovered = hovered
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and _name_rect.has_point(event.position):
		accept_event()
		name_pressed.emit(player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _name_hovered:
		_name_hovered = false
		queue_redraw()


func add_die(match_die: MatchDie) -> void:
	dice.append(match_die)
	add_child(match_die)
	# Poświata rysuje się tylko pod widocznymi kośćmi (po wylądowaniu, nie w trakcie przerzutu).
	match_die.visibility_changed.connect(queue_redraw)
	_update_layout()


## Środek pierwszego wiersza (kości) – plakietka ustawia się tak, żeby kości były w miejscu koszulki.
func get_anchor_offset() -> Vector2:
	return Vector2(size.x / 2.0, PADDING + DieGraphics.FACE_SIZE.y / 2.0)


func _update_layout() -> void:
	var dice_width := dice.size() * DieGraphics.FACE_SIZE.x + maxf(dice.size() - 1, 0) * DIE_GAP
	var font := get_theme_default_font()
	var name_width := font.get_string_size(_get_name_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x + 6.0
	var width := maxf(maxf(dice_width, name_width), maxf(MIN_WIDTH, EnergyBar.get_size(player.max_energy).x)) + PADDING * 2.0
	var height := PADDING + DieGraphics.FACE_SIZE.y + 3.0 + NAME_HEIGHT + 2.0 + EnergyBar.get_size(player.max_energy).y + PADDING
	custom_minimum_size = Vector2(roundf(width), height)
	size = custom_minimum_size
	var x := roundf((size.x - dice_width) / 2.0)
	for match_die in dice:
		match_die.position = Vector2(x, PADDING)
		x += DieGraphics.FACE_SIZE.x + DIE_GAP
	queue_redraw()


func _get_name_text() -> String:
	return "%d %s" % [player.data.number, player.data.last_name]


func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.set_corner_radius_all(5)
	panel.set_border_width_all(1)
	panel.border_color = team_color.lightened(0.25)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	_draw_glow()
	var font := get_theme_default_font()
	var top := PADDING + DieGraphics.FACE_SIZE.y + 3.0
	var number := str(player.data.number)
	var number_width := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
	var name_width := font.get_string_size(" " + player.data.last_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
	var x := roundf((size.x - number_width - name_width - 4.0) / 2.0)
	var baseline := roundf(top + (NAME_HEIGHT + font.get_ascent(NAME_FONT_SIZE) - font.get_descent(NAME_FONT_SIZE)) / 2.0)
	# Numer na tle w kolorze drużyny, nazwisko na biało.
	draw_rect(Rect2(x - 1.0, top, number_width + 4.0, NAME_HEIGHT), team_color)
	draw_string(font, Vector2(x + 1.0, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, number_color)
	draw_string(font, Vector2(x + number_width + 4.0, baseline), " " + player.data.last_name, HORIZONTAL_ALIGNMENT_LEFT,
			-1, NAME_FONT_SIZE, NAME_COLOR)
	_name_rect = Rect2(x - 1.0, top, number_width + name_width + 5.0, NAME_HEIGHT)
	if _name_hovered:
		draw_line(Vector2(x + number_width + 4.0 + 3.0, _name_rect.end.y), Vector2(_name_rect.end.x, _name_rect.end.y),
				NAME_COLOR, 1.0)
	var bar_size := EnergyBar.get_size(player.max_energy)
	_energy_rect = Rect2(Vector2(roundf((size.x - bar_size.x) / 2.0), top + NAME_HEIGHT + 2.0), bar_size)
	EnergyBar.draw(self, _energy_rect.position, player.energy, player.max_energy)


## Poświata w kolorze drużyny pod kośćmi: warstwy zaokrąglonych prostokątów coraz szersze i bledsze
## (nakładają się, więc przy kości jest najjaśniej).
func _draw_glow() -> void:
	var strength := Settings.dice_glow
	if strength <= 0.0:
		return
	var radius := roundi(lerpf(GLOW_MIN_SIZE, GLOW_MAX_SIZE, strength))
	var color := team_color.lightened(0.2)
	var layer := StyleBoxFlat.new()
	for match_die in dice:
		if not match_die.visible:
			continue
		var rect := Rect2(match_die.position, DieGraphics.FACE_SIZE)
		for i in range(radius, 0, -1):
			var falloff := 1.0 - float(i) / (radius + 1)
			layer.bg_color = Color(color, GLOW_MAX_ALPHA * strength * falloff * falloff / radius * 3.0)
			layer.set_corner_radius_all(6 + i)
			draw_style_box(layer, rect.grow(i))

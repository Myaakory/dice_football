class_name PlayerToken
extends Control
## Żeton zawodnika na boisku: koszulka z numerem, skrót roli obok i nazwisko pod spodem.
## Gdy jest interaktywny: kliknięcie = wybór, przeciągnięcie na innego zawodnika = zamiana miejscami.

signal pressed
## Upuszczono na ten żeton przeciąganego zawodnika (z boiska lub z listy kadry).
signal player_dropped(dragged: PlayerData)

const TOKEN_SIZE := Vector2(96, 40)
const SHIRT_SIZE := Vector2(32, 25)
## Warstwy koszulki: base barwiony kolorem głównym, trim dodatkowym, overlay (kontur + cienie) bez barwienia.
const SHIRT_BASE: Texture2D = preload("res://assets/graphics/players/shirt_base.png")
const SHIRT_TRIM: Texture2D = preload("res://assets/graphics/players/shirt_trim.png")
const SHIRT_OVERLAY: Texture2D = preload("res://assets/graphics/players/shirt_overlay.png")
const SHIRT_SHADOW: Texture2D = preload("res://assets/graphics/players/shirt_shadow.png")
const SHIRT_EMPTY: Texture2D = preload("res://assets/graphics/players/shirt_empty.png")
const SHIRT_MASK: Texture2D = preload("res://assets/graphics/players/shirt_mask.png")
## Koszulka bramkarza (tools/gen_ui_graphics.py): długi rękaw, rękawice – te same warstwy co zwykła.
const GK_SHIRT_BASE: Texture2D = preload("res://assets/graphics/players/gk_shirt_base.png")
const GK_SHIRT_TRIM: Texture2D = preload("res://assets/graphics/players/gk_shirt_trim.png")
const GK_SHIRT_OVERLAY: Texture2D = preload("res://assets/graphics/players/gk_shirt_overlay.png")
const GK_SHIRT_SHADOW: Texture2D = preload("res://assets/graphics/players/gk_shirt_shadow.png")
const GK_SHIRT_MASK: Texture2D = preload("res://assets/graphics/players/gk_shirt_mask.png")
## Obszar tułowia (bez rękawów i kołnierzyka), w którym wyśrodkowany jest numer.
const SHIRT_NUMBER_RECT := Rect2(6, 5, 20, 19)
const SELECTED_COLOR := Color("#f5d54a")
const DROP_COLOR := Color("#ffffff")
const ROLE_COLOR := Color("#f0e6a8")
## Kropki kolorów aktywnych kości pod koszulką (ekran meczu): promień, odstęp między kropkami, odstęp od
## koszulki i całe miejsce zajmowane w pionie.
const DICE_DOT_SPACING := 8.0
const DICE_DOTS_GAP := 2.0
const DICE_DOTS_HEIGHT := 8.0
const NAME_FONT_SIZE := 12
const NAME_HEIGHT := 14.0
const DICE_DOT_OUTLINE := Color(0.06, 0.08, 0.07, 0.9)

var player: PlayerData
var role_id: StringName
var primary_color := Color.WHITE
var secondary_color := Color.BLACK
var selected := false
var interactive := true
## Energia meczowa (pasek pod nazwiskiem, EnergyBar); -1 = nie pokazujemy.
var energy := -1
var max_energy := 0
## Kolory aktywnych kości zawodnika (kropki pod koszulką); pusta lista = bez kropek.
var dice_colors: Array[Color] = []
## Skrót roli obok koszulki (ekran meczu może go schować).
var show_role := true
## Biała obwódka – zawodnik do wybrania (np. przesunięcie na ekranie meczu).
var highlighted := false
## Kursor nad nazwiskiem (ekran meczu: podkreślenie, kliknięcie otwiera profil).
var name_hovered := false:
	set(value):
		if name_hovered != value:
			name_hovered = value
			queue_redraw()

var _drop_hover := false


func _init() -> void:
	custom_minimum_size = TOKEN_SIZE
	size = TOKEN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(p_player: PlayerData, p_role_id: StringName, p_primary: Color, p_secondary: Color) -> void:
	player = p_player
	role_id = p_role_id
	primary_color = p_primary
	secondary_color = p_secondary
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	tooltip_text = player.get_full_name() if player != null else ""
	queue_redraw()


## Punkt żetonu, który ma się pokrywać z pozycją na boisku (środek koszulki).
func get_anchor_offset() -> Vector2:
	return Vector2(TOKEN_SIZE.x / 2.0, SHIRT_SIZE.y / 2.0)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not interactive or player == null:
		return null
	set_drag_preview(_create_drag_preview())
	return PlayerDrag.create(player)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var dragged := PlayerDrag.get_player(data)
	var can_drop := interactive and dragged != null and dragged != player
	_set_drop_hover(can_drop)
	return can_drop


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_hover(false)
	player_dropped.emit(PlayerDrag.get_player(data))


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			queue_redraw()
		NOTIFICATION_MOUSE_EXIT, NOTIFICATION_DRAG_END:
			_set_drop_hover(false)


func _set_drop_hover(value: bool) -> void:
	if _drop_hover != value:
		_drop_hover = value
		queue_redraw()


## Półprzezroczysta kopia żetonu wyśrodkowana pod kursorem.
func _create_drag_preview() -> Control:
	var preview := Control.new()
	var copy := PlayerToken.new()
	copy.interactive = false
	copy.setup(player, role_id, primary_color, secondary_color)
	copy.modulate.a = 0.8
	copy.position = -copy.get_anchor_offset()
	preview.add_child(copy)
	return preview


# --- Części żetonu (podpowiedzi i kliknięcia na ekranie meczu) ---

func get_shirt_rect() -> Rect2:
	return Rect2(Vector2(roundf((size.x - SHIRT_SIZE.x) / 2.0), 0.0), SHIRT_SIZE)


## Prostokąt samego tekstu nazwiska (wyśrodkowany pod koszulką).
func get_name_rect() -> Rect2:
	var top := get_shirt_rect().end.y + 1.0 + (DICE_DOTS_HEIGHT if not dice_colors.is_empty() else 0.0)
	var width := 0.0
	if player != null:
		width = get_theme_default_font().get_string_size(player.last_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
	return Rect2(roundf((size.x - width) / 2.0), top, width, NAME_HEIGHT)


func get_energy_rect() -> Rect2:
	if energy < 0:
		return Rect2()
	var bar_size := EnergyBar.get_size(max_energy)
	return Rect2(Vector2(roundf((size.x - bar_size.x) / 2.0), get_name_rect().end.y), bar_size)


func _draw() -> void:
	var font := get_theme_default_font()
	var shirt := get_shirt_rect()

	if _drop_hover or (highlighted and not selected):
		_draw_shirt_glow(shirt.position, DROP_COLOR, 1 if highlighted and not _drop_hover else 2)
	if selected:
		_draw_shirt_glow(shirt.position, SELECTED_COLOR, 2)
	if player != null:
		var goalkeeper := is_goalkeeper()
		draw_texture(GK_SHIRT_SHADOW if goalkeeper else SHIRT_SHADOW, shirt.position)
		draw_texture(GK_SHIRT_BASE if goalkeeper else SHIRT_BASE, shirt.position, primary_color)
		draw_texture(GK_SHIRT_TRIM if goalkeeper else SHIRT_TRIM, shirt.position, secondary_color)
		draw_texture(GK_SHIRT_OVERLAY if goalkeeper else SHIRT_OVERLAY, shirt.position)
		var number_rect := Rect2(shirt.position + SHIRT_NUMBER_RECT.position, SHIRT_NUMBER_RECT.size)
		_draw_text(font, str(player.number), number_rect, 14, secondary_color, HORIZONTAL_ALIGNMENT_CENTER)
		var name_rect := get_name_rect()
		if not dice_colors.is_empty():
			# Kropki wyśrodkowane względem nazwiska, z małym odstępem od koszulki.
			_draw_dice_dots(Vector2(roundf(name_rect.get_center().x), shirt.end.y + DICE_DOTS_GAP))
		_draw_text(font, player.last_name, Rect2(0.0, name_rect.position.y, size.x, NAME_HEIGHT), NAME_FONT_SIZE,
				Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		if name_hovered:
			draw_line(Vector2(name_rect.position.x, name_rect.end.y - 1.0), Vector2(name_rect.end.x, name_rect.end.y - 1.0),
					Color.WHITE, 1.0)
		if energy >= 0:
			EnergyBar.draw(self, get_energy_rect().position, energy, max_energy)
	else:
		draw_texture(SHIRT_EMPTY, shirt.position)

	var role := GameData.get_role(role_id)
	if role != null and show_role:
		var role_rect := Rect2(0.0, shirt.position.y, shirt.position.x - 4.0, shirt.size.y)
		_draw_text(font, tr(role.short_key), role_rect, 11, ROLE_COLOR, HORIZONTAL_ALIGNMENT_RIGHT)


func is_goalkeeper() -> bool:
	return role_id == PositionData.GOALKEEPER


## Kropki kolorów kości wyśrodkowane w poziomie na `center`, pod koszulką. Pikselowe kółka 5 × 5 (z prostokątów,
## bo małe draw_circle przy przyciąganiu do pikseli wychodzą krzywe) z ciemną obwódką.
func _draw_dice_dots(center: Vector2) -> void:
	var start := roundf(center.x - (dice_colors.size() - 1) * DICE_DOT_SPACING / 2.0)
	for i in dice_colors.size():
		var dot := Vector2(start + i * DICE_DOT_SPACING, center.y + 3.0)
		_draw_pixel_dot(dot, 3, DICE_DOT_OUTLINE)
		_draw_pixel_dot(dot, 2, dice_colors[i])


## Pikselowe kółko o „promieniu” r wokół piksela `center` (lewy górny róg piksela środka).
func _draw_pixel_dot(center: Vector2, r: int, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-r + 1, -r), Vector2(r * 2 - 1, r * 2 + 1)), color)
	draw_rect(Rect2(center + Vector2(-r, -r + 1), Vector2(r * 2 + 1, r * 2 - 1)), color)


## Obwódka w kształcie koszulki: biała sylwetka przesunięta dookoła i zabarwiona.
func _draw_shirt_glow(pos: Vector2, color: Color, width: int) -> void:
	var mask := GK_SHIRT_MASK if is_goalkeeper() else SHIRT_MASK
	for dy in range(-width, width + 1):
		for dx in range(-width, width + 1):
			if dx != 0 or dy != 0:
				draw_texture(mask, pos + Vector2(dx, dy), color)


## Rysuje tekst z cieniem, wyśrodkowany w pionie w podanym prostokącie.
func _draw_text(font: Font, text: String, rect: Rect2, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	var baseline := rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
	var pos := Vector2(rect.position.x, roundf(baseline))
	draw_string(font, pos + Vector2.ONE, text, align, rect.size.x, font_size, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(font, pos, text, align, rect.size.x, font_size, color)

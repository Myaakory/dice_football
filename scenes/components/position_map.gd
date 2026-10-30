class_name PositionMap
extends Control
## Miniatura boiska z jedną kropką na każdą rolę z roles.csv (nawet jeśli taktyka ma kilku CM – tu jest jeden).
## Zielona = zawodnik gra tam naturalnie, żółta = umie zagrać, ciemna = nie gra. Styl kropek z ustawień gry.
## Położenie roli = średnia ze wszystkich pozycji tej roli w taktykach (tactic_slots.csv).

enum DotStyle {
	GEM,    ## cieniowane kropki z odblaskiem
	BADGE,  ## plakietki ze skrótem roli
	RING,   ## świecące pierścienie wokół ciemnej kropki
	ROLE_BADGE,  ## duże plakietki tylko na rolach zawodnika, reszta to małe kropki (poza wyborem w opcjach)
}

const DOT_STYLE_NAME_KEYS: Dictionary[DotStyle, String] = {
	DotStyle.GEM: "STYLE_DOTS_GEM",
	DotStyle.BADGE: "STYLE_DOTS_BADGE",
	DotStyle.RING: "STYLE_DOTS_RING",
}
const FIELD_SIZE := Vector2(200, 300)
## Pas za linią końcową (bramki) i odstęp boiska od krawędzi kontrolki.
const GOAL_MARGIN := 10.0
const SIDE_MARGIN := 10.0
const LEGEND_HEIGHT := 44.0
## Role nieużywane w żadnej taktyce: (x 0–1 od lewej, y 0–1 od bramki rywala).
## Docelowo położenie ról na mapie może trafić do arkusza (roles.csv).
const FALLBACK_POINTS: Dictionary[StringName, Vector2] = {&"AM": Vector2(0.5, 0.3)}

const STRIPE_COLORS: Array[Color] = [Color8(119, 145, 92), Color8(106, 117, 89)]
const LINE_COLOR := Color(1, 1, 1, 0.6)
const EMPTY_DOT := Color(0.06, 0.09, 0.07, 0.8)
## Paleta kropek: [ciemny obrys, kolor, jasny, odblask].
const GREEN: Array[Color] = [Color("#143a18"), Color("#3fa34d"), Color("#86dd78"), Color("#ecffe0")]
const YELLOW: Array[Color] = [Color("#4f3a06"), Color("#d9a826"), Color("#ffe07a"), Color("#fffbe6")]
const BADGE_SIZE := Vector2(28, 14)
const ROLE_BADGE_SIZE := Vector2(38, 20)
const ROLE_BADGE_FONT_SIZE := 14
const HOVER_RADIUS := 9.0

var player: PlayerData
var field_size := FIELD_SIZE
## Styl zamiast tego z ustawień gry (-1 = z ustawień).
var style_override: int = -1
var show_legend := true

static var _role_points: Dictionary[StringName, Vector2] = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	Settings.settings_changed.connect(queue_redraw)


func setup(p_player: PlayerData) -> void:
	player = p_player
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(field_size.x + SIDE_MARGIN * 2.0, field_size.y + GOAL_MARGIN * 2.0 + (LEGEND_HEIGHT if show_legend else 0.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


## Położenia ról (znormalizowane) liczone raz z taktyk.
static func get_role_points() -> Dictionary[StringName, Vector2]:
	if not _role_points.is_empty():
		return _role_points
	var sums: Dictionary[StringName, Vector3] = {}  # x, y, liczba
	for tactic in GameData.get_tactic_list():
		for slot in tactic.slots:
			var forward := (slot.lane - 1 + slot.depth) / FormationSlot.LANE_COUNT
			sums[slot.role_id] = sums.get(slot.role_id, Vector3.ZERO) + Vector3(slot.x, 1.0 - forward, 1.0)
	for role_id in GameData.roles:
		if sums.has(role_id):
			var sum := sums[role_id]
			_role_points[role_id] = Vector2(sum.x, sum.y) / sum.z
		elif FALLBACK_POINTS.has(role_id):
			_role_points[role_id] = FALLBACK_POINTS[role_id]
		else:
			push_warning("PositionMap: role '%s' is not used by any tactic – no point on the map" % role_id)
	return _role_points


func _get_field_rect() -> Rect2:
	return Rect2(Vector2(SIDE_MARGIN, GOAL_MARGIN), field_size)


func _get_role_position(role_id: StringName) -> Vector2:
	var field := _get_field_rect()
	return (field.position + get_role_points()[role_id] * field.size).round()


func _get_tooltip(at_position: Vector2) -> String:
	if player == null:
		return ""
	for role_id in get_role_points():
		if _get_role_position(role_id).distance_to(at_position) <= HOVER_RADIUS:
			var role := GameData.get_role(role_id)
			var fit_key: String = ["POSITION_NONE", "POSITION_SECONDARY", "POSITION_NATURAL"][player.get_role_fit(role_id)]
			return tr("POSITION_TOOLTIP") % [tr(role.name_key) if role != null else role_id, tr(fit_key)]
	return ""


# --- Rysowanie ---

func _draw() -> void:
	_draw_field()
	var style := (Settings.position_dot_style if style_override < 0 else style_override) as DotStyle
	var font := get_theme_default_font()
	for role_id in get_role_points():
		var fit := player.get_role_fit(role_id) if player != null else PlayerData.RoleFit.NONE
		var role := GameData.get_role(role_id)
		_draw_dot(style, _get_role_position(role_id), fit, tr(role.short_key) if role != null else "", font)
	if show_legend:
		_draw_legend(style, font)


func _draw_field() -> void:
	var dim := Settings.pitch_dim
	var field := _get_field_rect()
	var line := PitchDimmer.dim_color(LINE_COLOR, dim * 0.5)
	# cień i ciemna ramka wokół murawy (z pasem na bramki)
	var outer := Rect2(field.position - Vector2(4, GOAL_MARGIN - 2), field.size + Vector2(8, (GOAL_MARGIN - 2) * 2))
	draw_rect(Rect2(outer.position + Vector2(2, 2), outer.size), Color(0, 0, 0, 0.35))
	draw_rect(outer, PitchDimmer.dim_color(STRIPE_COLORS[1], dim))
	var stripes := 10
	var stripe_height := field.size.y / stripes
	for i in stripes:
		draw_rect(Rect2(field.position.x, field.position.y + i * stripe_height, field.size.x, stripe_height),
				PitchDimmer.dim_color(STRIPE_COLORS[i % 2], dim))
	draw_rect(outer, Color(0.04, 0.07, 0.05), false, 1.0)
	# linie
	draw_rect(field, line, false, 1.0)
	var center := field.get_center()
	draw_line(Vector2(field.position.x, center.y), Vector2(field.end.x, center.y), line)
	draw_arc(center, field.size.x * 0.14, 0.0, TAU, 32, line)
	draw_rect(Rect2(center - Vector2.ONE, Vector2(2, 2)), line)
	for top in [true, false]:
		var box_size := Vector2(field.size.x * 0.56, field.size.y * 0.15)
		var goal_box_size := Vector2(field.size.x * 0.23, field.size.y * 0.05)
		var goal_size := Vector2(field.size.x * 0.17, GOAL_MARGIN - 4.0)
		var y := field.position.y if top else field.end.y
		var direction := 1.0 if top else -1.0
		for rect_size: Vector2 in [box_size, goal_box_size]:
			var rect_y := y if top else y - rect_size.y
			draw_rect(Rect2(center.x - rect_size.x / 2.0, rect_y, rect_size.x, rect_size.y), line, false, 1.0)
		var goal_y := y - goal_size.y if top else y
		draw_rect(Rect2(center.x - goal_size.x / 2.0, goal_y, goal_size.x, goal_size.y), Color(1, 1, 1, 0.35))
		draw_rect(Rect2(center.x - 1.0, y + direction * box_size.y * 0.7 - 1.0, 2.0, 2.0), line)


func _draw_dot(style: DotStyle, pos: Vector2, fit: PlayerData.RoleFit, label: String, font: Font) -> void:
	var palette: Array[Color] = GREEN if fit == PlayerData.RoleFit.NATURAL else YELLOW
	match style:
		DotStyle.GEM:
			if fit == PlayerData.RoleFit.NONE:
				draw_circle(pos, 4.0, EMPTY_DOT)
				draw_circle(pos, 4.0, Color(1, 1, 1, 0.22), false, 1.0)
				return
			draw_circle(pos + Vector2(1, 2), 7.0, Color(0, 0, 0, 0.4))
			draw_circle(pos, 7.0, palette[0])
			draw_circle(pos, 6.0, palette[1].darkened(0.18))
			draw_circle(pos - Vector2(0.5, 0.5), 5.0, palette[1])
			draw_circle(pos - Vector2(1.5, 1.5), 3.0, palette[2])
			draw_rect(Rect2(pos - Vector2(3, 4), Vector2(2, 2)), palette[3])
		DotStyle.BADGE:
			var rect := Rect2(pos - BADGE_SIZE / 2.0, BADGE_SIZE)
			var text_color := Color(1, 1, 1, 0.45)
			if fit == PlayerData.RoleFit.NONE:
				draw_rect(rect, EMPTY_DOT)
				draw_rect(rect, Color(1, 1, 1, 0.2), false, 1.0)
			else:
				draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.4))
				draw_rect(rect, palette[1])
				draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 4)), Color(palette[2], 0.6))
				draw_rect(rect, palette[0], false, 1.0)
				text_color = Color.WHITE if fit == PlayerData.RoleFit.NATURAL else Color("#3a2a05")
			if label.is_empty():
				return
			var font_size := 10
			var baseline := roundf(rect.get_center().y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
			if fit == PlayerData.RoleFit.NATURAL:
				draw_string(font, Vector2(rect.position.x + 1, baseline + 1), label, HORIZONTAL_ALIGNMENT_CENTER,
						rect.size.x, font_size, Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(rect.position.x, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x,
					font_size, text_color)
		DotStyle.ROLE_BADGE:
			if fit == PlayerData.RoleFit.NONE:
				draw_circle(pos, 4.0, EMPTY_DOT)
				draw_circle(pos, 4.0, Color(1, 1, 1, 0.22), false, 1.0)
				return
			var rect := Rect2(pos - ROLE_BADGE_SIZE / 2.0, ROLE_BADGE_SIZE)
			draw_rect(Rect2(rect.position + Vector2(1, 2), rect.size), Color(0, 0, 0, 0.4))
			draw_rect(rect, palette[1])
			var baseline := roundf(pos.y + (font.get_ascent(ROLE_BADGE_FONT_SIZE) - font.get_descent(ROLE_BADGE_FONT_SIZE)) / 2.0)
			draw_string(font, Vector2(rect.position.x, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x,
					ROLE_BADGE_FONT_SIZE, Color.WHITE if fit == PlayerData.RoleFit.NATURAL else Color("#3a2a05"))
		DotStyle.RING:
			if fit != PlayerData.RoleFit.NONE:
				draw_circle(pos, 11.0, Color(palette[1], 0.16))
				draw_circle(pos, 8.5, Color(palette[1], 0.24))
				draw_circle(pos, 8.0, palette[0], false, 1.0)
				draw_circle(pos, 6.5, palette[2], false, 2.0)
			draw_circle(pos, 3.0, Color(0.03, 0.05, 0.04, 0.9))
			draw_circle(pos, 3.0, Color(1, 1, 1, 0.25), false, 1.0)


func _draw_legend(style: DotStyle, font: Font) -> void:
	var font_size := 12
	var y := GOAL_MARGIN * 2.0 + field_size.y + 6.0
	var items := [[PlayerData.RoleFit.NATURAL, "POSITION_NATURAL"], [PlayerData.RoleFit.SECONDARY, "POSITION_SECONDARY"]]
	for item: Array in items:
		var dot_pos := Vector2(SIDE_MARGIN + 12.0, y + 8.0)
		_draw_dot(style, dot_pos, item[0], "", font)
		var baseline := roundf(dot_pos.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
		draw_string(font, Vector2(SIDE_MARGIN + 32.0, baseline), tr(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
				Color(0.91, 0.937, 0.878, 0.8))
		y += 19.0

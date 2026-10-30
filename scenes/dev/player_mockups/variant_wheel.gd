extends RefCounted
## Wariant 3 „Koło cech” – wykres-pizza jak w skórkach analitycznych FM24 (Mustermann, Statman), ale z twarzą
## zawodnika w środku: każda cecha to klin, a każdy punkt na ściankach jeden pierścień. Reszta w barwach i ramkach
## z obecnej gry (zieleń, pikselowe panele, złote nagłówki).

const Kit := preload("res://scenes/dev/player_mockups/mock_kit.gd")

const BG := Color(0.078, 0.129, 0.102)
const TEXT := Color("#e8efe0")
const MUTED := Color(0.91, 0.937, 0.878, 0.62)
const GOLD := Color("#f0e6a8")


static func build(ctx: Dictionary) -> Control:
	var root := Kit.root(BG)
	var title_font := Kit.font(Kit.LATO_BOLD)
	var body_font := Kit.font(Kit.LATO)
	var fonts := {"title": title_font, "body": body_font}
	var back_normal := UiFrames.make_stylebox(UiFrames.Style.PITCH, 8.0)
	Kit.button(root, Kit.tr_key("COMMON_BACK"), Rect2(36, 24, 130, 44), back_normal, UiFrames.make_stylebox(UiFrames.Style.GOLD, 8.0),
			TEXT, title_font, 18, ctx.back)
	_add_identity(root, ctx, Rect2(36, 84, 440, 626), fonts)
	var wheel := Wheel.new(ctx, Rect2(492, 0, 740, 720), fonts)
	root.add_child(wheel)
	var disc := Disc.new(wheel.position + wheel.center, Wheel.INNER_RADIUS - 8.0)
	root.add_child(disc)
	Kit.portrait(disc, ctx, Vector2(disc.size.x / 2.0 - 128.0, disc.size.y - 256.0), 4)
	_add_dice(root, ctx, Rect2(1248, 24, 636, 686), fonts)
	var titles := ["Ostatnie mecze", "Historia transferów", "Statystyki sezonu"]
	var width := (1848.0 - 2.0 * 16.0) / 3.0
	for i in titles.size():
		_add_module(root, titles[i], Rect2(36 + i * (width + 16.0), 728, width, 328), fonts)
	return root


static func _frame(root: Control, rect: Rect2) -> void:
	Kit.panel(root, rect, UiFrames.make_stylebox(UiFrames.Style.PITCH, 8.0))


static func _add_identity(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	var team: TeamData = ctx.team
	var x := rect.position.x
	Kit.text(root, player.first_name, Vector2(x, rect.position.y), 30, MUTED, fonts.body)
	Kit.text(root, player.last_name, Vector2(x, rect.position.y + 30), 68, TEXT, fonts.title)
	Kit.fill(root, Rect2(x, rect.position.y + 120, 88, 54), team.primary_color)
	Kit.text(root, str(player.number), Vector2(x, rect.position.y + 122), 40, team.secondary_color, fonts.title, 88.0, HORIZONTAL_ALIGNMENT_CENTER)
	Kit.text(root, Kit.position_name(ctx), Vector2(x + 104, rect.position.y + 118), 24, TEXT, fonts.title)
	Kit.text(root, team.name, Vector2(x + 104, rect.position.y + 148), 19, team.primary_color.lightened(0.45), fonts.body)
	root.add_child(Kit.FlagView.new(ctx.nation, Vector2(x, rect.position.y + 196), 3))
	Kit.text(root, ctx.nation_name, Vector2(x + 60, rect.position.y + 197), 22, TEXT, fonts.body)
	Kit.text(root, "%s %d" % [Kit.tr_key("PLAYER_AGE"), player.age], Vector2(x + 240, rect.position.y + 197), 22, TEXT, fonts.body)
	var pitch := Kit.MiniPitch.new(player, Rect2(x, rect.position.y + 246, 380, 262), true)
	pitch.label_font = fonts.title
	pitch.font_size = 14
	root.add_child(pitch)
	var y := rect.position.y + 526.0
	Kit.text(root, "%s:  %s" % [Kit.tr_key("PLAYER_LINEUP"), Kit.lineup_text(ctx)], Vector2(x, y), 20, TEXT, fonts.body)
	Kit.text(root, "%s:  %d" % [Kit.tr_key("PLAYER_DICE_POWER"), Kit.dice_power(ctx)], Vector2(x, y + 32), 20, GOLD, fonts.title)


static func _add_dice(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	var cell_height := (rect.size.y - 34.0) / 3.0
	Kit.text(root, Kit.tr_key("PLAYER_DICE_TITLE") % [Lineup.ACTIVE_DICE_COUNT, player.dice.size()], rect.position, 19, GOLD, fonts.title)
	for die_index in player.dice.size():
		var die := player.dice[die_index]
		var active: bool = ctx.lineup.is_die_active(player, die_index)
		var box := UiFrames.make_stylebox(UiFrames.Style.GOLD if active else UiFrames.Style.PITCH, 8.0)
		var card := Kit.panel(root, Rect2(rect.position.x, rect.position.y + 32 + die_index * cell_height, rect.size.x, cell_height - 8), box)
		Kit.clickable(card, ctx, die_index)
		var net := DieNetView.new()
		net.setup(die, 1, &"", not active)
		net.face_tooltips = true
		net.position = Vector2(18, round((card.size.y - 160.0) / 2.0))
		net.size = net.get_combined_minimum_size()
		card.add_child(net)
		var color := TEXT if active else MUTED
		Kit.text(card, Kit.tr_key(die.type.name_key), Vector2(254, 20), 22, color, fonts.title)
		Kit.text(card, Kit.tr_key("PLAYER_DIE_ACTIVE") if active else Kit.tr_key("PLAYER_DIE_INACTIVE"), Vector2(254, 48), 16,
				die.type.color.lightened(0.5) if active else MUTED, fonts.body)
		var attributes := Kit.die_attributes(die)
		for i in attributes.size():
			var y := 82.0 + i * 30.0
			Kit.text(card, attributes[i].name, Vector2(254, y), 19, color, fonts.body)
			Kit.text(card, str(attributes[i].total), Vector2(254, y), 20, color, fonts.title, 350.0, HORIZONTAL_ALIGNMENT_RIGHT)


static func _add_module(root: Control, title: String, rect: Rect2, fonts: Dictionary) -> void:
	_frame(root, rect)
	Kit.text(root, title, rect.position + Vector2(20, 14), 20, GOLD, fonts.title)
	for i in 5:
		var y := rect.position.y + 58.0 + i * 50.0
		Kit.fill(root, Rect2(rect.position.x + 20, y, rect.size.x * (0.5 - i * 0.05), 12), Color(1, 1, 1, 0.08))
		Kit.fill(root, Rect2(rect.end.x - 100, y, 80, 12), Color(1, 1, 1, 0.08))


## Tarcza pod twarzą: przycina portret do koła, żeby koszulka kończyła się na obręczy.
class Disc extends Control:
	func _init(at: Vector2, radius: float) -> void:
		position = at - Vector2.ONE * radius
		size = Vector2.ONE * radius * 2.0
		clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size / 2.0, size.x / 2.0, Color(0.05, 0.09, 0.07))


class Wheel extends Control:
	const INNER_RADIUS := 142.0
	const OUTER_RADIUS := 300.0
	const LABEL_RADIUS := 320.0
	const MIN_RINGS := 10
	const WEDGE_GAP := 0.03
	const RING_GAP := 2.0

	var ctx: Dictionary
	var fonts: Dictionary
	var center := Vector2(370, 362)
	## [{id, name, total, type_id, color, active}]
	var wedges: Array[Dictionary] = []

	func _init(p_ctx: Dictionary, rect: Rect2, p_fonts: Dictionary) -> void:
		ctx = p_ctx
		fonts = p_fonts
		position = rect.position
		size = rect.size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var player: PlayerData = ctx.player
		for die_index in player.dice.size():
			var die := player.dice[die_index]
			var active: bool = ctx.lineup.is_die_active(player, die_index)
			for attribute: Dictionary in Kit.die_attributes(die):
				var wedge := attribute.duplicate()
				wedge["color"] = die.type.color
				wedge["active"] = active
				wedges.append(wedge)

	func _draw() -> void:
		draw_circle(center, OUTER_RADIUS + 6.0, Color(0, 0, 0, 0.22))
		var rings := MIN_RINGS
		for wedge: Dictionary in wedges:
			rings = maxi(rings, wedge.total)
		var ring_size := (OUTER_RADIUS - INNER_RADIUS) / rings
		var step := TAU / wedges.size()
		for i in wedges.size():
			var wedge: Dictionary = wedges[i]
			var start := -PI / 2.0 + i * step
			for ring in rings:
				var filled: bool = ring < wedge.total
				var color: Color = Color(1, 1, 1, 0.045)
				if filled:
					color = wedge.color if wedge.active else Color(wedge.color.darkened(0.45), 0.65)
				_draw_segment(start + WEDGE_GAP, start + step - WEDGE_GAP, INNER_RADIUS + ring * ring_size,
						INNER_RADIUS + (ring + 1) * ring_size - RING_GAP, color)
			_draw_label(wedge, start + step / 2.0)
		draw_circle(center, INNER_RADIUS - 6.0, ctx.team.primary_color, false, 3.0)

	func _draw_segment(from_angle: float, to_angle: float, inner: float, outer: float, color: Color) -> void:
		var points := PackedVector2Array()
		var steps := 8
		for i in steps + 1:
			points.append(center + Vector2.from_angle(lerpf(from_angle, to_angle, float(i) / steps)) * outer)
		for i in steps + 1:
			points.append(center + Vector2.from_angle(lerpf(to_angle, from_angle, float(i) / steps)) * inner)
		draw_colored_polygon(points, color)

	func _draw_label(wedge: Dictionary, angle: float) -> void:
		var direction := Vector2.from_angle(angle)
		var anchor := center + direction * LABEL_RADIUS
		var name_width: float = fonts.body.get_string_size(wedge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var color := TEXT if wedge.active else MUTED
		var value := str(wedge.total)
		var x := anchor.x if direction.x >= 0.0 else anchor.x - name_width
		if absf(direction.x) < 0.35:
			x = anchor.x - name_width / 2.0
		var y := anchor.y + 14.0 * direction.y + 4.0
		draw_string(fonts.title, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
		draw_string(fonts.body, Vector2(x, y + 19.0), wedge.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, color)

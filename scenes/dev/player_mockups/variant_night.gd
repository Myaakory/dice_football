extends RefCounted
## Wariant 2 „Mecz wieczorny” – z Football, Tactics & Glory: stadion nocą, prawdziwa murawa z gry, ciemne
## półprzezroczyste panele, karta zawodnika z wielką pozycją za portretem i żółte przyciski.

const Kit := preload("res://scenes/dev/player_mockups/mock_kit.gd")

const SKY_TOP := Color("#0c2238")
const SKY_LOW := Color("#1d5a7a")
const GLASS := Color(0.05, 0.12, 0.19, 0.93)
const GLASS_LIGHT := Color(0.12, 0.23, 0.32, 0.9)
const BAR := Color(0.2, 0.25, 0.3, 0.92)
const TEXT := Color("#f1f5f8")
const MUTED := Color("#9fb4c4")
const YELLOW := Color("#f3d44b")
const YELLOW_DARK := Color("#c9a825")
const GRASS: Texture2D = preload("res://assets/graphics/pitch/parts/grass.png")
const HORIZON := 640.0


static func build(ctx: Dictionary) -> Control:
	var root := Kit.root(SKY_TOP)
	_add_stadium(root, ctx)
	var title_font := Kit.font(Kit.CARLITO_BOLD)
	var body_font := Kit.font(Kit.CARLITO)
	var fonts := {"title": title_font, "body": body_font}
	var player: PlayerData = ctx.player
	Kit.fill(root, Rect2(0, 0, 1920, 64), Color(0, 0, 0, 0.72))
	Kit.text(root, "Aktywne kości: %d z %d. Kliknij kość, żeby ją włączyć." % [Lineup.ACTIVE_DICE_COUNT, player.dice.size()],
			Vector2(0, 18), 24, Color("#bfe6f5"), body_font, 1920.0, HORIZONTAL_ALIGNMENT_CENTER)
	_add_dice(root, ctx, Rect2(120, 92, 1000, 372), fonts)
	_add_positions(root, ctx, Rect2(120, 476, 1000, 236), fonts)
	_add_profile(root, ctx, Rect2(1140, 92, 660, 620), fonts)
	var titles := ["Ostatnie mecze", "Historia transferów", "Statystyki sezonu"]
	for i in titles.size():
		_add_module(root, titles[i], Rect2(120 + i * 566, 730, 548, 268), fonts)
	Kit.fill(root, Rect2(0, 1016, 1920, 64), Color(0, 0, 0, 0.72))
	Kit.button(root, Kit.tr_key("COMMON_BACK"), Rect2(120, 1028, 200, 40), Kit.style(YELLOW), Kit.style(YELLOW.lightened(0.25)),
			Color("#2a2a12"), title_font, 22, ctx.back)
	return root


static func _add_stadium(root: Control, ctx: Dictionary) -> void:
	var sky := TextureRect.new()
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.set_color(0, SKY_TOP)
	gradient.set_color(1, SKY_LOW)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.size = Vector2(1920, HORIZON)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child(sky)
	_add_crowd(root, ctx)
	for x: float in [60.0, 960.0, 1860.0]:
		_add_light(root, Vector2(x, 66))
	var grass := TextureRect.new()
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grass.texture = GRASS
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.position = Vector2(0, HORIZON)
	grass.size = Vector2(1920, 1080 - HORIZON)
	PixelArt.apply(grass)
	root.add_child(grass)
	for i in range(0, 24, 2):
		Kit.fill(root, Rect2(i * 80, HORIZON, 80, 1080 - HORIZON), Color(0.06, 0.1, 0.02, 0.2))
	Kit.fill(root, Rect2(0, HORIZON + 4, 1920, 2), Color(1, 1, 1, 0.65))
	Kit.fill(root, Rect2(0, HORIZON, 1920, 1080 - HORIZON), Color(0.03, 0.08, 0.13, 0.3))


## Rozmyta trybuna jak tło FTG: mały obraz plam (barwy klubu w tłumie) rozciągnięty filtrem liniowym.
static func _add_crowd(root: Control, ctx: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var width := 96
	var height := 14
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var team: TeamData = ctx.team
	for y in height:
		for x in width:
			var color := Color(0.07, 0.17, 0.26).lerp(Color(0.12, 0.3, 0.42), rng.randf())
			if rng.randf() < 0.2:
				color = color.lerp(team.primary_color, 0.45)
			image.set_pixel(x, y, color)
	var crowd := TextureRect.new()
	crowd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crowd.texture = ImageTexture.create_from_image(image)
	crowd.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crowd.position = Vector2(0, HORIZON - 280)
	crowd.size = Vector2(1920, 280)
	crowd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(crowd)


static func _add_light(root: Control, pos: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.85, 0.95, 1.0, 0.75))
	gradient.set_color(1, Color(0.6, 0.85, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 360
	texture.height = 360
	var glow := TextureRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture = texture
	glow.position = pos - Vector2(180, 80)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	root.add_child(glow)
	for x in 4:
		for y in 2:
			Kit.fill(root, Rect2(pos.x - 28 + x * 14, pos.y + 90 + y * 14, 10, 10), Color("#eefaff"))


static func _title_bar(root: Control, rect: Rect2, title: String, fonts: Dictionary) -> void:
	Kit.fill(root, rect, GLASS)
	Kit.fill(root, Rect2(rect.position, Vector2(rect.size.x, 38)), BAR)
	Kit.text(root, title, rect.position + Vector2(14, 6), 21, MUTED, fonts.title)


static func _add_dice(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	_title_bar(root, rect, "Kości zawodnika", fonts)
	var cell_width := rect.size.x / 3.0
	for die_index in player.dice.size():
		var die := player.dice[die_index]
		var active: bool = ctx.lineup.is_die_active(player, die_index)
		var cell := Kit.panel(root, Rect2(rect.position.x + die_index * cell_width + 6, rect.position.y + 44, cell_width - 12, 322),
				Kit.style(GLASS_LIGHT if active else Color(0.05, 0.1, 0.15, 0.6)))
		Kit.clickable(cell, ctx, die_index)
		if active:
			Kit.fill(cell, Rect2(0, 0, cell.size.x, 3), YELLOW)
		Kit.text(cell, Kit.tr_key(die.type.name_key), Vector2(12, 10), 22, TEXT if active else MUTED, fonts.title)
		Kit.text(cell, str(die.get_total()), Vector2(0, 2), 34, YELLOW if active else MUTED, fonts.title, cell.size.x - 12,
				HORIZONTAL_ALIGNMENT_RIGHT)
		var net := DieNetView.new()
		net.setup(die, 1, &"", not active)
		net.face_tooltips = true
		net.position = Vector2(round((cell.size.x - 214.0) / 2.0), 50)
		net.size = net.get_combined_minimum_size()
		cell.add_child(net)
		var attributes := Kit.die_attributes(die)
		for i in attributes.size():
			var y := 220.0 + i * 31.0
			Kit.text(cell, attributes[i].name, Vector2(14, y), 21, TEXT if active else MUTED, fonts.body)
			Kit.text(cell, str(attributes[i].total), Vector2(0, y), 22, TEXT if active else MUTED, fonts.title, cell.size.x - 14,
					HORIZONTAL_ALIGNMENT_RIGHT)


static func _add_positions(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	_title_bar(root, rect, Kit.tr_key("PLAYER_POSITIONS"), fonts)
	var pitch := Kit.MiniPitch.new(player, Rect2(rect.position + Vector2(10, 46), Vector2(290, 182)), true)
	pitch.label_font = fonts.title
	pitch.font_size = 15
	root.add_child(pitch)
	var x := rect.position.x + 330.0
	var y := rect.position.y + 52.0
	for entry: Array in [[player.natural_roles, 1.0, Kit.GREEN_DOT], [player.secondary_roles, 0.55, Kit.YELLOW_DOT]]:
		for role_id: StringName in entry[0]:
			var role := GameData.get_role(role_id)
			Kit.text(root, Kit.tr_key(role.name_key), Vector2(x, y), 21, TEXT, fonts.body)
			Kit.fill(root, Rect2(x + 250, y + 8, 370, 12), Color(0, 0, 0, 0.5))
			Kit.fill(root, Rect2(x + 250, y + 8, 370 * entry[1], 12), entry[2])
			y += 34.0
	var hint_y := rect.end.y - 34.0
	Kit.text(root, Kit.tr_key("POSITION_NATURAL"), Vector2(x, hint_y), 18, Kit.GREEN_DOT.lightened(0.4), fonts.body)
	Kit.text(root, Kit.tr_key("POSITION_SECONDARY"), Vector2(x + 250, hint_y), 18, Kit.YELLOW_DOT.lightened(0.3), fonts.body)


static func _add_profile(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	_title_bar(root, rect, "Karta zawodnika", fonts)
	var hero := Kit.clip(root, Rect2(rect.position + Vector2(0, 38), Vector2(rect.size.x, 332)))
	Kit.fill(hero, Rect2(Vector2.ZERO, hero.size), Color(0.1, 0.2, 0.28, 0.55))
	var role_id: StringName = player.natural_roles[0] if not player.natural_roles.is_empty() else player.position_id
	var role := GameData.get_role(role_id)
	Kit.text(hero, Kit.tr_key(role.short_key) if role != null else "", Vector2(16, 128), 210, Color(1, 1, 1, 0.13), fonts.title)
	Kit.portrait(hero, ctx, Vector2(hero.size.x - 330, hero.size.y - 320), 5)
	Kit.text(hero, player.get_full_name(), Vector2(20, 14), 40, TEXT, fonts.title)
	Kit.text(hero, "#%d" % player.number, Vector2(20, 62), 30, YELLOW, fonts.title)
	Kit.text(hero, "%s %d" % [Kit.tr_key("PLAYER_AGE"), player.age], Vector2(84, 66), 24, MUTED, fonts.body)
	hero.add_child(Kit.FlagView.new(ctx.nation, Vector2(20, 104), 3))
	Kit.text(hero, ctx.nation_name, Vector2(78, 104), 24, TEXT, fonts.body)

	var stats_y := rect.position.y + 380.0
	var stats: Array[Array] = []
	for die_index in player.dice.size():
		var die := player.dice[die_index]
		var active: bool = ctx.lineup.is_die_active(player, die_index)
		stats.append([Kit.tr_key(die.type.name_key).replace("Kość ", "").capitalize(), die.get_total(), TEXT if active else MUTED])
	stats.append(["Aktywne", Kit.dice_power(ctx), YELLOW])
	var width := rect.size.x / stats.size()
	for i in stats.size():
		var x := rect.position.x + i * width
		var color: Color = stats[i][2]
		Kit.text(root, stats[i][0], Vector2(x, stats_y), 19, MUTED, fonts.body, width, HORIZONTAL_ALIGNMENT_CENTER)
		Kit.text(root, str(stats[i][1]), Vector2(x, stats_y + 22), 52, color, fonts.title, width, HORIZONTAL_ALIGNMENT_CENTER)
	var y := rect.position.y + 480.0
	Kit.fill(root, Rect2(rect.position.x + 20, y - 8, rect.size.x - 40, 1), Color(1, 1, 1, 0.15))
	for row: Array in [[Kit.tr_key("PLAYER_TEAM"), ctx.team.name], [Kit.tr_key("PLAYER_POSITION"), Kit.position_name(ctx)],
			[Kit.tr_key("PLAYER_LINEUP"), Kit.lineup_text(ctx)]]:
		Kit.text(root, row[0], Vector2(rect.position.x + 20, y), 22, MUTED, fonts.body)
		Kit.text(root, row[1], Vector2(rect.position.x + 170, y), 22, TEXT, fonts.title)
		y += 40.0


static func _add_module(root: Control, title: String, rect: Rect2, fonts: Dictionary) -> void:
	_title_bar(root, rect, title, fonts)
	for i in 4:
		var y := rect.position.y + 56.0 + i * 50.0
		Kit.fill(root, Rect2(rect.position.x + 16, y, rect.size.x * (0.5 - i * 0.05), 14), Color(1, 1, 1, 0.07))
		Kit.fill(root, Rect2(rect.end.x - 90, y, 74, 14), Color(1, 1, 1, 0.07))

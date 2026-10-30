extends RefCounted
## Wariant 1 „Trybuna” – gęsty ciemny pulpit jak skórki FM24 (Tato24): blok w barwach klubu z wielkim numerem na
## koszulce, tabela danych, a kości jako główny panel: każda cecha z sumą nad swoją parą ścianek.

const Kit := preload("res://scenes/dev/player_mockups/mock_kit.gd")

const BG := Color("#161b24")
const PANEL := Color("#1e2430")
const ROW := Color("#252c3a")
const LINE := Color("#343e50")
const TEXT := Color("#e9edf3")
const MUTED := Color("#8f9bad")
const GAP := 12.0
const ROW_HEIGHT := 41.0


static func build(ctx: Dictionary) -> Control:
	var root := Kit.root(BG)
	var title_font := Kit.font(Kit.BAHN, 700, 75)
	var semi_font := Kit.font(Kit.BAHN, 600, 87)
	var body_font := Kit.font(Kit.BAHN, 400, 100)
	var fonts := {"title": title_font, "semi": semi_font, "body": body_font}
	Kit.button(root, Kit.tr_key("COMMON_BACK"), Rect2(24, 14, 120, 40), Kit.style(ROW, LINE, 1), Kit.style(LINE, MUTED, 1),
			TEXT, semi_font, 18, ctx.back)
	Kit.text(root, "%s  /  Kadra  /  %s" % [ctx.team.name, ctx.player.get_full_name()], Vector2(162, 21), 18, MUTED, body_font)
	_add_hero(root, ctx, Rect2(24, 66, 640, 344), fonts)
	_add_info(root, ctx, Rect2(24, 66 + 344 + GAP, 640, 300), fonts)
	_add_positions(root, ctx, Rect2(676, 66, 268, 656), fonts)
	_add_dice(root, ctx, Rect2(956, 66, 940, 656), fonts)
	var modules := ["Ostatnie mecze", "Historia transferów", "Statystyki sezonu"]
	var widths := [640.0, 608.0, 600.0]
	var x := 24.0
	for i in modules.size():
		_add_module(root, modules[i], Rect2(x, 734, widths[i], 322), fonts)
		x += widths[i] + GAP
	return root


static func _panel(root: Control, rect: Rect2, title: String, fonts: Dictionary) -> void:
	Kit.panel(root, rect, Kit.style(PANEL, LINE, 1))
	if not title.is_empty():
		Kit.text(root, title, rect.position + Vector2(16, 10), 19, TEXT, fonts.semi)
		Kit.fill(root, Rect2(rect.position + Vector2(16, 40), Vector2(rect.size.x - 32, 1)), LINE)


static func _add_hero(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var team: TeamData = ctx.team
	var player: PlayerData = ctx.player
	var primary := team.primary_color
	var hero := Kit.clip(root, rect)
	Kit.fill(hero, Rect2(Vector2.ZERO, rect.size), primary)
	Kit.text(hero, str(player.number), Vector2(0, -40), 380, primary.darkened(0.2), fonts.title, rect.size.x - 12,
			HORIZONTAL_ALIGNMENT_RIGHT)
	Kit.portrait(hero, ctx, Vector2(0, rect.size.y - 8 - 320), 5)
	Kit.fill(hero, Rect2(0, rect.size.y - 8, rect.size.x, 8), team.secondary_color)
	Kit.text(hero, player.first_name, Vector2(334, 20), 26, Color(1, 1, 1, 0.85), fonts.semi)
	Kit.text(hero, player.last_name.to_upper(), Vector2(332, 44), 62, Color.WHITE, fonts.title)
	Kit.text(hero, Kit.position_name(ctx), Vector2(334, 120), 22, Color(1, 1, 1, 0.85), fonts.semi)
	hero.add_child(Kit.FlagView.new(ctx.nation, Vector2(334, 288), 3))
	Kit.text(hero, ctx.nation_name, Vector2(390, 290), 22, Color.WHITE, fonts.semi)


static func _add_info(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	_panel(root, rect, Kit.tr_key("PLAYER_INFO"), fonts)
	var rows := [
		[Kit.tr_key("PLAYER_NUMBER"), str(ctx.player.number)],
		[Kit.tr_key("PLAYER_AGE"), str(ctx.player.age)],
		["Narodowość", ctx.nation_name],
		[Kit.tr_key("PLAYER_TEAM"), ctx.team.name],
		[Kit.tr_key("PLAYER_LINEUP"), Kit.lineup_text(ctx)],
		[Kit.tr_key("PLAYER_DICE_POWER"), str(Kit.dice_power(ctx))],
	]
	var y := rect.position.y + 48.0
	for i in rows.size():
		if i % 2 == 0:
			Kit.fill(root, Rect2(rect.position.x + 1, y, rect.size.x - 2, ROW_HEIGHT), ROW)
		Kit.text(root, rows[i][0], Vector2(rect.position.x + 16, y + 10), 19, MUTED, fonts.body)
		Kit.text(root, rows[i][1], Vector2(rect.position.x + 260, y + 10), 19, TEXT, fonts.semi)
		y += ROW_HEIGHT


static func _add_positions(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	_panel(root, rect, Kit.tr_key("PLAYER_POSITIONS"), fonts)
	var map := PositionMap.new()
	map.position = rect.position + Vector2(24, 56)
	map.size = map.get_combined_minimum_size()
	map.setup(ctx.player)
	root.add_child(map)
	var y := rect.position.y + 438.0
	Kit.text(root, Kit.tr_key("POSITION_NATURAL"), Vector2(rect.position.x + 16, y), 17, MUTED, fonts.body)
	Kit.text(root, "\n".join(Kit.role_shorts(ctx, ctx.player.natural_roles)), Vector2(rect.position.x + 16, y + 24), 19, TEXT, fonts.semi)
	if not ctx.player.secondary_roles.is_empty():
		Kit.text(root, Kit.tr_key("POSITION_SECONDARY"), Vector2(rect.position.x + 16, y + 92), 17, MUTED, fonts.body)
		Kit.text(root, "\n".join(Kit.role_shorts(ctx, ctx.player.secondary_roles)), Vector2(rect.position.x + 16, y + 116), 19, TEXT, fonts.semi)


static func _add_dice(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	_panel(root, rect, Kit.tr_key("PLAYER_DICE_TITLE") % [Lineup.ACTIVE_DICE_COUNT, player.dice.size()], fonts)
	var row_height := 198.0
	var y := rect.position.y + 50.0
	for die_index in player.dice.size():
		var die := player.dice[die_index]
		var active: bool = ctx.lineup.is_die_active(player, die_index)
		var row := Kit.panel(root, Rect2(rect.position.x + 12, y, rect.size.x - 24, row_height - 8),
				Kit.style(ROW if active else PANEL, die.type.color if active else LINE, 1))
		Kit.clickable(row, ctx, die_index)
		Kit.fill(row, Rect2(0, 0, 6, row.size.y), die.type.color if active else LINE)
		var name_color := TEXT if active else MUTED
		Kit.text(row, Kit.tr_key(die.type.name_key), Vector2(20, 14), 20, name_color, fonts.semi)
		Kit.text(row, Kit.tr_key("PLAYER_DIE_ACTIVE") if active else Kit.tr_key("PLAYER_DIE_INACTIVE"), Vector2(20, 42), 17,
				die.type.color.lightened(0.45) if active else MUTED, fonts.body)
		Kit.text(row, str(die.get_total()), Vector2(20, 88), 66, name_color, fonts.title)
		var strip := Kit.DieStrip.new(die, 2, not active, 18)
		strip.position = Vector2(190, 66)
		row.add_child(strip)
		var attributes := Kit.die_attributes(die)
		for pair in attributes.size():
			var x := 190.0 + strip.get_pair_x(pair)
			Kit.text(row, attributes[pair].name, Vector2(x, 20), 19, name_color, fonts.body)
			Kit.text(row, str(attributes[pair].total), Vector2(x, 14), 28, name_color, fonts.title, 210.0, HORIZONTAL_ALIGNMENT_RIGHT)
		y += row_height


static func _add_module(root: Control, title: String, rect: Rect2, fonts: Dictionary) -> void:
	_panel(root, rect, title, fonts)
	for i in 5:
		var y := rect.position.y + 52.0 + i * 52.0
		Kit.fill(root, Rect2(rect.position.x + 16, y + 8, rect.size.x * (0.46 - i * 0.03), 12), LINE.darkened(0.25))
		Kit.fill(root, Rect2(rect.end.x - 96, y + 8, 80, 12), LINE.darkened(0.25))
		Kit.fill(root, Rect2(rect.position.x + 16, y + 40, rect.size.x - 32, 1), LINE.darkened(0.3))

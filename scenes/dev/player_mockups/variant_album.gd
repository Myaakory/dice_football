extends RefCounted
## Wariant 4 „Album naklejek” – rozkładówka albumu w barwach klubu: wielka naklejka z portretem ×6, a miejsca na
## przyszłe moduły to puste pola na naklejki. Kości i pozycje to mniejsze naklejki na prawej stronie.

const Kit := preload("res://scenes/dev/player_mockups/mock_kit.gd")

const STICKER := Color("#f5f3ec")
const INK := Color("#23211d")
const SOFT_INK := Color("#6b675e")
const SIDE_MARGIN := 40.0
const SPINE_X := 960.0


static func build(ctx: Dictionary) -> Control:
	var team: TeamData = ctx.team
	var page := team.primary_color.darkened(0.12)
	var root := Kit.root(page)
	var title_font := Kit.font(Kit.IMPACT)
	var body_font := Kit.font(Kit.BAHN, 500, 87)
	var fonts := {"title": title_font, "body": body_font}
	_add_page_pattern(root, page)
	Kit.fill(root, Rect2(SPINE_X - 3, 0, 6, 1080), page.darkened(0.45))
	Kit.fill(root, Rect2(SPINE_X - 18, 0, 15, 1080), Color(0, 0, 0, 0.12))
	Kit.fill(root, Rect2(SPINE_X + 3, 0, 15, 1080), Color(1, 1, 1, 0.06))
	var back_style := Kit.style(STICKER, INK, 2)
	Kit.button(root, Kit.tr_key("COMMON_BACK"), Rect2(SIDE_MARGIN, 24, 120, 40), back_style, Kit.style(Color.WHITE, INK, 2), INK,
			body_font, 18, ctx.back)
	Kit.text(root, team.name, Vector2(SIDE_MARGIN + 140, 28), 26, Color.WHITE, body_font)
	_add_main_sticker(root, ctx, Rect2(SIDE_MARGIN + 34, 84, 440, 680), fonts)
	_add_facts(root, ctx, Rect2(SIDE_MARGIN + 500, 84, 340, 680), fonts)
	_add_dice(root, ctx, Rect2(SPINE_X + 40, 84, 880, 456), fonts)
	_add_positions(root, ctx, Rect2(SPINE_X + 40, 556, 880, 208), fonts)
	var slots := ["Ostatnie mecze", "Historia transferów", "Statystyki sezonu", "Trofea"]
	var width := (1920.0 - 2.0 * SIDE_MARGIN - 3.0 * 20.0) / 4.0
	for i in slots.size():
		_add_empty_slot(root, slots[i], Rect2(SIDE_MARGIN + i * (width + 20.0), 790, width, 262), page, fonts)
	return root


## Rastrowe kropki jak w drukowanym albumie (siatka co 16 px, gęstsze u góry).
static func _add_page_pattern(root: Control, page: Color) -> void:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var dot := Color(page.darkened(0.14), 1.0)
	for offset: Vector2i in [Vector2i(4, 4), Vector2i(20, 20)]:
		image.fill_rect(Rect2i(offset, Vector2i(4, 4)), dot)
	var pattern := TextureRect.new()
	pattern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pattern.texture = ImageTexture.create_from_image(image)
	pattern.stretch_mode = TextureRect.STRETCH_TILE
	pattern.size = Vector2(1920, 1080)
	root.add_child(pattern)


static func _sticker(root: Control, rect: Rect2) -> Panel:
	Kit.fill(root, Rect2(rect.position + Vector2(5, 6), rect.size), Color(0, 0, 0, 0.3))
	return Kit.panel(root, rect, Kit.style(STICKER, INK, 2))


static func _add_main_sticker(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	var team: TeamData = ctx.team
	var card := _sticker(root, rect)
	var photo := Kit.clip(card, Rect2(14, 14, rect.size.x - 28, 412))
	var grass := TextureRect.new()
	grass.texture = preload("res://assets/graphics/pitch/parts/grass.png")
	grass.stretch_mode = TextureRect.STRETCH_TILE
	grass.size = photo.size
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelArt.apply(grass)
	photo.add_child(grass)
	Kit.fill(photo, Rect2(0, 0, photo.size.x, 240), Color("#a9c9dc"))
	Kit.fill(photo, Rect2(0, 240, photo.size.x, 2), Color(1, 1, 1, 0.8))
	Kit.portrait(photo, ctx, Vector2(round((photo.size.x - 384.0) / 2.0), photo.size.y - 384.0), 6)
	Kit.fill(card, Rect2(14, 426, rect.size.x - 28, 12), team.secondary_color)
	Kit.fill(card, Rect2(14, 438, rect.size.x - 28, 124), team.primary_color)
	Kit.text(card, player.first_name, Vector2(30, 444), 26, Color.WHITE, fonts.body)
	Kit.text(card, player.last_name.to_upper(), Vector2(30, 472), 66, Color.WHITE, fonts.title)
	Kit.text(card, str(player.number), Vector2(0, 446), 86, team.primary_color.lightened(0.28), fonts.title, rect.size.x - 32,
			HORIZONTAL_ALIGNMENT_RIGHT)
	card.add_child(Kit.FlagView.new(ctx.nation, Vector2(30, 582), 4))
	Kit.text(card, ctx.nation_name, Vector2(108, 584), 34, INK, fonts.body)
	Kit.text(card, Kit.position_name(ctx), Vector2(30, 638), 22, SOFT_INK, fonts.body)


static func _add_facts(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	var card := _sticker(root, rect)
	var rows := [
		[Kit.tr_key("PLAYER_NUMBER"), str(player.number)],
		[Kit.tr_key("PLAYER_AGE"), str(player.age)],
		[Kit.tr_key("PLAYER_POSITION"), Kit.position_name(ctx)],
		[Kit.tr_key("PLAYER_TEAM"), ctx.team.name],
		[Kit.tr_key("PLAYER_LINEUP"), Kit.lineup_text(ctx)],
	]
	var y := 22.0
	for row: Array in rows:
		Kit.text(card, row[0], Vector2(24, y), 19, SOFT_INK, fonts.body)
		Kit.text(card, row[1], Vector2(24, y + 24), 26, INK, fonts.body)
		y += 86.0
	Kit.fill(card, Rect2(24, y + 6, rect.size.x - 48, 2), INK)
	Kit.text(card, Kit.tr_key("PLAYER_DICE_POWER"), Vector2(24, y + 22), 19, SOFT_INK, fonts.body)
	Kit.text(card, str(Kit.dice_power(ctx)), Vector2(24, y + 42), 104, ctx.team.primary_color, fonts.title)


static func _add_dice(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	var height := (rect.size.y - 16.0) / 3.0
	for die_index in player.dice.size():
		var die := player.dice[die_index]
		var active: bool = ctx.lineup.is_die_active(player, die_index)
		var card_rect := Rect2(rect.position.x, rect.position.y + die_index * (height + 8.0), rect.size.x, height)
		var card := _sticker(root, card_rect)
		Kit.clickable(card, ctx, die_index)
		if not active:
			card.modulate = Color(0.78, 0.78, 0.78)
		Kit.fill(card, Rect2(10, 10, 14, card_rect.size.y - 20), die.type.color)
		Kit.text(card, Kit.tr_key(die.type.name_key), Vector2(40, 16), 26, INK, fonts.body)
		Kit.text(card, Kit.tr_key("PLAYER_DIE_ACTIVE") if active else Kit.tr_key("PLAYER_DIE_INACTIVE"), Vector2(40, 48), 18,
				die.type.color.darkened(0.3) if active else SOFT_INK, fonts.body)
		Kit.text(card, str(die.get_total()), Vector2(40, 66), 66, INK, fonts.title)
		var strip := Kit.DieStrip.new(die, 1, not active, 44)
		strip.position = Vector2(420, 60)
		card.add_child(strip)
		var attributes := Kit.die_attributes(die)
		for pair in attributes.size():
			var x := 420.0 + strip.get_pair_x(pair)
			Kit.text(card, attributes[pair].name, Vector2(x - 8, 18), 17, SOFT_INK, fonts.body, 124.0, HORIZONTAL_ALIGNMENT_CENTER)
			Kit.text(card, str(attributes[pair].total), Vector2(x - 8, 116), 24, INK, fonts.body, 124.0, HORIZONTAL_ALIGNMENT_CENTER)


static func _add_positions(root: Control, ctx: Dictionary, rect: Rect2, fonts: Dictionary) -> void:
	var player: PlayerData = ctx.player
	var card := _sticker(root, rect)
	var pitch := Kit.MiniPitch.new(player, Rect2(12, 12, 300, 184), true)
	pitch.label_font = fonts.body
	pitch.font_size = 14
	card.add_child(pitch)
	Kit.text(card, Kit.tr_key("PLAYER_POSITIONS"), Vector2(336, 14), 26, INK, fonts.body)
	Kit.text(card, Kit.tr_key("POSITION_NATURAL"), Vector2(336, 56), 18, SOFT_INK, fonts.body)
	Kit.text(card, ", ".join(Kit.role_shorts(ctx, player.natural_roles)), Vector2(336, 78), 22, INK, fonts.body)
	if not player.secondary_roles.is_empty():
		Kit.text(card, Kit.tr_key("POSITION_SECONDARY"), Vector2(336, 118), 18, SOFT_INK, fonts.body)
		Kit.text(card, ", ".join(Kit.role_shorts(ctx, player.secondary_roles)), Vector2(336, 140), 22, INK, fonts.body)


## Puste pole na naklejkę – w albumie widać obrys i podpis, dopóki moduł nie powstanie.
static func _add_empty_slot(root: Control, title: String, rect: Rect2, page: Color, fonts: Dictionary) -> void:
	Kit.fill(root, rect, Color(page.darkened(0.3), 0.55))
	var border := Color(1, 1, 1, 0.55)
	var dash := 14.0
	var x := rect.position.x
	while x < rect.end.x - dash:
		Kit.fill(root, Rect2(x, rect.position.y, dash, 2), border)
		Kit.fill(root, Rect2(x, rect.end.y - 2, dash, 2), border)
		x += dash * 2.0
	var y := rect.position.y
	while y < rect.end.y - dash:
		Kit.fill(root, Rect2(rect.position.x, y, 2, dash), border)
		Kit.fill(root, Rect2(rect.end.x - 2, y, 2, dash), border)
		y += dash * 2.0
	Kit.text(root, title, rect.position + Vector2(0, rect.size.y / 2.0 - 16.0), 24, Color(1, 1, 1, 0.8), fonts.body, rect.size.x,
			HORIZONTAL_ALIGNMENT_CENTER)

class_name PortraitComposer
extends RefCounted
## Składa portret zawodnika (32 px boisko, 64 px karta) z szablonów części z tools/portraits/ (eksport:
## `python tools/portraits/portrait_tool.py export`). Szablony są narysowane kolorami palety domyślnej: każdy kolor
## to rola (skin.shade, hair.base, shirt.light…), którą podmienia się na kolor zawodnika / drużyny – tak samo jak
## resolve_palette() w portrait_core.py (te same rampy HSV, wzory mix i collapse, zaokrąglanie jak w Pythonie),
## więc wynik jest identyczny piksel w piksel z podglądem narzędzia.
## Manifest i szablony ładują się raz (szablon jako lista pikseli z indeksem roli); portrety trzyma tylko mała
## pamięć podręczna tego, co jest wyświetlane – nic per zawodnik (docs/architecture/world_scale.md).

const DIR := "res://assets/graphics/portraits/retro/"
const CARD_SIZE := 64
const PITCH_SIZE := 32
const CACHE_SIZE := 64
const KIT_FIELD := "field"
const KIT_GOALKEEPER := "goalkeeper"

static var _manifest: Dictionary = {}
## Indeks roli -> nazwa i odwrotnie (kolejność z template_palette).
static var _roles: PackedStringArray = []
static var _role_index: Dictionary = {}
## Kolor szablonu (0xRRGGBB) -> indeks roli.
static var _color_role: Dictionary = {}
static var _files: Dictionary = {}
static var _fitted: Dictionary = {}
## Ścieżka części -> [PackedInt32Array indeksów pikseli, PackedByteArray indeksów ról].
static var _templates: Dictionary = {}
## Klucz -> ImageTexture; kolejność wstawienia = kolejność użycia (najstarszy wypada pierwszy).
static var _cache: Dictionary = {}


static func get_manifest() -> Dictionary:
	_ensure_loaded()
	return _manifest


## Portret zawodnika w barwach drużyny: bramkarz dostaje koszulkę bramkarską w bramkarskich barwach klubu.
## scale = całkowite powiększenie (nearest), np. 2 dla karty 64 px pokazywanej jako 128.
static func get_player_texture(player: PlayerData, team: TeamData, size: int, scale := 1) -> ImageTexture:
	var goalkeeper := player.is_goalkeeper()
	var shirt := team.gk_primary_color if goalkeeper else team.primary_color
	var trim := team.gk_secondary_color if goalkeeper else team.secondary_color
	return get_texture(player.get_portrait_look(), size, shirt, trim,
			KIT_GOALKEEPER if goalkeeper else KIT_FIELD, scale)


static func get_texture(look: Dictionary, size: int, shirt: Color, trim: Color, kit := KIT_FIELD,
		scale := 1) -> ImageTexture:
	_ensure_loaded()
	var key :="%s|%d|%s|%s|%s|%d" % [_look_key(look), size, shirt.to_html(false), trim.to_html(false), kit, scale]
	if _cache.has(key):
		var cached: ImageTexture = _cache[key]
		_cache.erase(key)
		_cache[key] = cached
		return cached
	var image := compose(look, size, shirt, trim, kit)
	if scale > 1:
		image.resize(size * scale, size * scale, Image.INTERPOLATE_NEAREST)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	while _cache.size() > CACHE_SIZE:
		_cache.erase(_cache.keys()[0])
	return texture


## Obraz size×size (RGBA8) bez pamięci podręcznej. look = pule wyglądu (PortraitLooks), kit = field / goalkeeper.
static func compose(look: Dictionary, size: int, shirt: Color, trim: Color, kit := KIT_FIELD) -> Image:
	_ensure_loaded()
	var data := PackedByteArray()
	data.resize(size * size * 4)
	if _manifest.is_empty():
		return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	var palette := build_palette(look, shirt, trim)
	var colors := PackedByteArray()
	colors.resize(_roles.size() * 4)
	for i in _roles.size():
		var rgb := _hex_to_rgb(palette.get(_roles[i], "#ff00ff"))
		colors[i * 4] = rgb[0]
		colors[i * 4 + 1] = rgb[1]
		colors[i * 4 + 2] = rgb[2]
		colors[i * 4 + 3] = 255
	for layer: String in _manifest["layer_order"]:
		var template := _get_template(_part_file(layer, _layer_variant(look, layer, kit), look.get("head", ""), size))
		if template.is_empty():
			continue
		var pixels: PackedInt32Array = template[0]
		var roles: PackedByteArray = template[1]
		for i in pixels.size():
			var o := pixels[i] * 4
			var c := roles[i] * 4
			data[o] = colors[c]
			data[o + 1] = colors[c + 1]
			data[o + 2] = colors[c + 2]
			data[o + 3] = 255
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)


## Pełna paleta ról zawodnika {rola: "#rrggbb"} – port resolve_palette() z portrait_core.py.
static func build_palette(look: Dictionary, shirt: Color, trim: Color) -> Dictionary:
	_ensure_loaded()
	var pal := {}
	var palettes: Dictionary = _manifest["palettes"]
	var groups: Dictionary = _manifest["palette_groups"]
	for pool: String in ["skin", "hair_color", "eye_color", "accessory"]:
		var pool_palettes: Dictionary = palettes[pool]
		var ramp: Dictionary = pool_palettes.get(look.get(pool, ""), pool_palettes.values()[0])
		for shade: String in ramp:
			pal["%s.%s" % [groups[pool], shade]] = ramp[shade]
	var team_ramp: Dictionary = _manifest["team_ramp"]
	for group: String in ["shirt", "trim"]:
		var ramp := make_team_ramp(team_ramp[group], shirt if group == "shirt" else trim, team_ramp)
		for shade: String in ramp:
			pal["%s.%s" % [group, shade]] = ramp[shade]
	for entry: Array in _manifest["derived_roles"]:
		pal[entry[0]] = mix(_role_or_hex(pal, entry[1]), _role_or_hex(pal, entry[2]), float(entry[3]))
	var fixed: Dictionary = _manifest["fixed_roles"]
	for role: String in fixed:
		pal[role] = fixed[role]
	var collapse: Dictionary = _manifest["collapse"]
	for role: String in collapse:
		pal[role] = pal[collapse[role]]
	return pal


## make_ramp() dla koloru drużyny: shades = {nazwa: [dl, dh, ds]}, params = contrast / hue_shift / saturation.
static func make_team_ramp(shades: Dictionary, color: Color, params: Dictionary) -> Dictionary:
	var base := shift("#%02x%02x%02x" % [color.r8, color.g8, color.b8], 0.0, 0.0, float(params["saturation"]))
	var ramp := {}
	for shade: String in shades:
		var d: Array = shades[shade]
		ramp[shade] = shift(base, float(d[0]) * float(params["contrast"]), float(d[1]) * float(params["hue_shift"]),
				float(d[2]))
	return ramp


# ───────────── kolory: dokładny port portrait_core.py (shift, mix) i colorsys ─────────────

## Jaśniej/ciemniej w HSV (patrz shift() w portrait_core.py – kolejność działań musi zostać ta sama).
static func shift(hex: String, dl: float, dh: float, ds: float) -> String:
	var c := _hex_to_rgb(hex)
	var hsv := _rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)
	var h: float = hsv[0]
	var s: float = hsv[1]
	var v: float = hsv[2]
	if dl < 0:
		v = v * (1 + dl * 2.0)
	else:
		v = v + (1 - v) * dl * 1.6
		s = s * (1 - dl * 1.1)
	h = fposmod(h + dh, 1.0)
	v = minf(1.0, maxf(0.03, v))
	s = minf(1.0, maxf(0.0, s + ds))
	var rgb := _hsv_to_rgb(h, s, v)
	return _rgb_to_hex(rgb[0] * 255, rgb[1] * 255, rgb[2] * 255)


static func mix(a: String, b: String, t: float) -> String:
	var ca := _hex_to_rgb(a)
	var cb := _hex_to_rgb(b)
	return _rgb_to_hex(ca[0] + (cb[0] - ca[0]) * t, ca[1] + (cb[1] - ca[1]) * t, ca[2] + (cb[2] - ca[2]) * t)


static func _rgb_to_hsv(r: float, g: float, b: float) -> Array[float]:
	var maxc := maxf(r, maxf(g, b))
	var minc := minf(r, minf(g, b))
	var v := maxc
	if minc == maxc:
		return [0.0, 0.0, v]
	var s := (maxc - minc) / maxc
	var rc := (maxc - r) / (maxc - minc)
	var gc := (maxc - g) / (maxc - minc)
	var bc := (maxc - b) / (maxc - minc)
	var h: float
	if r == maxc:
		h = bc - gc
	elif g == maxc:
		h = 2.0 + rc - bc
	else:
		h = 4.0 + gc - rc
	h = fposmod(h / 6.0, 1.0)
	return [h, s, v]


static func _hsv_to_rgb(h: float, s: float, v: float) -> Array[float]:
	if s == 0.0:
		return [v, v, v]
	var i := int(h * 6.0)
	var f := (h * 6.0) - i
	var p := v * (1.0 - s)
	var q := v * (1.0 - s * f)
	var t := v * (1.0 - s * (1.0 - f))
	match posmod(i, 6):
		0:
			return [v, t, p]
		1:
			return [q, v, p]
		2:
			return [p, v, t]
		3:
			return [p, q, v]
		4:
			return [t, p, v]
	return [v, p, q]


static func _hex_to_rgb(hex: String) -> PackedInt32Array:
	var h := hex.trim_prefix("#")
	return PackedInt32Array([h.substr(0, 2).hex_to_int(), h.substr(2, 2).hex_to_int(), h.substr(4, 2).hex_to_int()])


static func _rgb_to_hex(r: float, g: float, b: float) -> String:
	return "#%02x%02x%02x" % [_channel(r), _channel(g), _channel(b)]


## max(0, min(255, round(v))) z Pythona: round() zaokrągla połówki do parzystej.
static func _channel(value: float) -> int:
	var f := floorf(value)
	var result := int(f)
	var frac := value - f
	if frac > 0.5 or (frac == 0.5 and result % 2 != 0):
		result += 1
	return clampi(result, 0, 255)


static func _role_or_hex(pal: Dictionary, value: String) -> String:
	return value if value.begins_with("#") else pal[value]


# ───────────── szablony ─────────────

static func _layer_variant(look: Dictionary, layer: String, kit: String) -> String:
	if layer == "hair_back":
		return look.get("hair", "")
	if layer == "shirt":
		return kit
	return look.get(layer, "")


static func _part_file(layer: String, variant: String, head: String, size: int) -> String:
	if _fitted.has(layer):
		return "%s/%s@%s_%d.png" % [layer, variant, head, size]
	return "%s/%s_%d.png" % [layer, variant, size]


## [piksele, role] szablonu albo [] (brak pliku = pusta część, np. wariant "none").
static func _get_template(rel: String) -> Array:
	if _templates.has(rel):
		return _templates[rel]
	var result := []
	if _files.has(rel):
		var texture := load(DIR + rel) as Texture2D
		if texture == null:
			push_error("PortraitComposer: missing template %s" % rel)
		else:
			result = _read_template(texture.get_image(), rel)
	_templates[rel] = result
	return result


static func _read_template(image: Image, rel: String) -> Array:
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	var pixels := PackedInt32Array()
	var roles := PackedByteArray()
	for i in image.get_width() * image.get_height():
		if data[i * 4 + 3] < 128:
			continue
		var key := (data[i * 4] << 16) | (data[i * 4 + 1] << 8) | data[i * 4 + 2]
		if not _color_role.has(key):
			push_error("PortraitComposer: %s pixel %d has colour #%06x outside the template palette" % [rel, i, key])
			continue
		pixels.append(i)
		roles.append(_color_role[key])
	return [pixels, roles]


static func _ensure_loaded() -> void:
	if not _manifest.is_empty():
		return
	var file := FileAccess.open(DIR + "manifest.json", FileAccess.READ)
	if file == null:
		push_error("PortraitComposer: cannot open %smanifest.json" % DIR)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("PortraitComposer: invalid manifest.json")
		return
	_manifest = parsed
	var template_palette: Dictionary = _manifest["template_palette"]
	for role: String in template_palette:
		_role_index[role] = _roles.size()
		_roles.append(role)
	var template_colors: Dictionary = _manifest["template_colors"]
	for hex: String in template_colors:
		_color_role[hex.trim_prefix("#").hex_to_int()] = _role_index[template_colors[hex]]
	for rel: String in _manifest["files"]:
		_files[rel] = true
	for layer: String in _manifest["fitted_to_head"]:
		_fitted[layer] = true


static func _look_key(look: Dictionary) -> String:
	var parts := PackedStringArray()
	for pool: String in _manifest.get("look_pools", []):
		parts.append(str(look.get(pool, "")))
	return ",".join(parts)

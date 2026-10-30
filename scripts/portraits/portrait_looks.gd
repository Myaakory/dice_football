class_name PortraitLooks
extends RefCounted
## Losowanie wyglądu zawodnika (te same kroki co random_look / nationality_look w tools/portraits/portrait_tool.py)
## z wag zatwierdzonych elementów zapisanych w manifeście portretów. Deterministyczne: ten sam seed (np. id
## zawodnika) daje zawsze ten sam wygląd, dopóki nie zmienią się zatwierdzone elementy i wagi w manifeście.
## Wygląd to zwykły Dictionary {pula: wariant} – head, eyes, brows, nose, mouth, hair, facial_hair, marks, extras
## oraz kolory skin, hair_color, eye_color, accessory. Koszulka nie należy do wyglądu (barwy klubu).

const ANY := "any"


## Wygląd z tekstu seeda (np. id zawodnika). nationality = id z data/nationalities.csv: najpierw pochodzenie
## z wag narodowości, potem każda pula z wag tego pochodzenia; puste = kolumna "any".
static func generate(seed_text: String, nationality: StringName = &"") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_from_text("portrait:" + seed_text)
	return generate_with(rng, nationality)


static func generate_with(rng: RandomNumberGenerator, nationality: StringName = &"") -> Dictionary:
	var manifest := PortraitComposer.get_manifest()
	if manifest.is_empty():
		return {}
	var weights: Dictionary = manifest["weights"]
	var region := ANY
	if nationality != &"":
		var nations: Dictionary = manifest["nationalities"]
		if nations.has(String(nationality)):
			region = _weighted(rng, nations[String(nationality)])
			if not weights.has(region):
				push_warning("PortraitLooks: origin %s of %s has no weights column" % [region, nationality])
				region = ANY
		else:
			push_warning("PortraitLooks: unknown nationality %s" % nationality)
	var profile: Dictionary = weights.get(region, {})
	var base: Dictionary = weights[ANY]
	var allowed: Dictionary = manifest["allowed"]
	var look := {}
	for pool: String in manifest["look_pools"]:
		look[pool] = _weighted(rng, _pick_weights(profile, base, pool, allowed.get(pool, [])))
	return look


## Stabilny hash tekstu (FNV-1a 32 bit) – nie zależy od wersji silnika.
static func seed_from_text(text: String) -> int:
	var h := 2166136261
	for byte in text.to_utf8_buffer():
		h = ((h ^ byte) * 16777619) & 0xFFFFFFFF
	return h


## Pula bez wag w kolumnie regionu bierze "any", bez wag w "any" – równo z dozwolonych (pick_weights).
static func _pick_weights(profile: Dictionary, base: Dictionary, pool: String, allowed: Array) -> Dictionary:
	for table: Dictionary in [profile.get(pool, {}), base.get(pool, {})]:
		for weight: float in table.values():
			if weight > 0:
				return table
	var equal := {}
	for variant: String in allowed:
		equal[variant] = 1.0
	if equal.is_empty():
		push_error("PortraitLooks: pool %s has nothing to pick from" % pool)
	return equal


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys: Array[String] = []
	var total := 0.0
	for key: String in weights:
		if float(weights[key]) > 0:
			keys.append(key)
			total += float(weights[key])
	if keys.is_empty():
		return ""
	var r := rng.randf() * total
	for key in keys:
		r -= float(weights[key])
		if r <= 0:
			return key
	return keys[-1]

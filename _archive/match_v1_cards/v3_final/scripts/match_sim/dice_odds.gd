class_name DiceOdds
extends RefCounted
## Szacowanie szans bez rzucania: suma punktów kości przybliżona rozkładem normalnym. Używane przez AI,
## docelowo też w szybkiej symulacji lig.
## Limit kości testu (PlayContest.get_test_cap): test dostaje tyle „slotów”, ile kości może przyjąć, kości (od
## najwyższej średniej) trafiają do slotów na przemian, a slot daje maksimum swoich kości (dokładny rozkład). Suma
## slotów to dolne oszacowanie sumy najlepszych kości – lekko zaniża szanse, gdy dwie najlepsze trafią do jednego slotu.


## Szansa, że strona zapełni wszystkie wymagania karty jednym rzutem (bez przerzutów; bez testu bramkarza).
static func fill_probability(contest: PlayContest, attacking: bool) -> float:
	return _tests_probability(contest, attacking, false)


## Szansa, że bramkarz zapełni test interwencji jednym rzutem (0, gdy karta go nie ma).
static func keeper_probability(contest: PlayContest) -> float:
	if not contest.card.has_keeper_test():
		return 0.0
	return _tests_probability(contest, false, true)


## Iloczyn szans testów strony: zwykłych (keeper = false) albo testów bramkarza (keeper = true).
static func _tests_probability(contest: PlayContest, attacking: bool, keeper: bool) -> float:
	var requirements := contest.card.get_requirements(attacking)
	var probability := 1.0
	for i in requirements.size():
		if requirements[i].is_keeper() != keeper:
			continue
		var moments := _requirement_moments(contest, attacking, i, _slot_count(contest, attacking, i))
		probability *= probability_at_least(moments.x, moments.y, requirements[i].points)
	return probability


## Oczekiwana suma liczących się punktów strony (do kalibracji progów).
static func expected_points(contest: PlayContest, attacking: bool) -> float:
	var requirements := contest.card.get_requirements(attacking)
	var total := 0.0
	for i in requirements.size():
		if requirements[i].is_keeper():
			continue
		total += _requirement_moments(contest, attacking, i, _slot_count(contest, attacking, i)).x
	return total


static func probability_at_least(mean: float, variance: float, threshold: float) -> float:
	if variance <= 0.000001:
		return 1.0 if mean >= threshold - 0.0001 else 0.0
	return 1.0 - normal_cdf((threshold - mean) / sqrt(variance))


static func normal_cdf(z: float) -> float:
	return 0.5 * (1.0 + _erf(z / sqrt(2.0)))


## Przybliżenie funkcji błędu (Abramowitz i Stegun 7.1.26, błąd < 1.5e-7).
static func _erf(x: float) -> float:
	var sign_x := signf(x)
	x = absf(x)
	var t := 1.0 / (1.0 + 0.3275911 * x)
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return sign_x * y


## Liczba slotów testu = limit jego kości (-1 = bez limitu).
static func _slot_count(contest: PlayContest, attacking: bool, index: int) -> int:
	var cap := contest.get_test_cap(attacking, index)
	return -1 if cap <= 0 else cap


## Średnia (x) i wariancja (y) punktów jednego wymagania przy danej liczbie slotów.
static func _requirement_moments(contest: PlayContest, attacking: bool, index: int, slot_count: int) -> Vector2:
	var requirement := contest.card.get_requirements(attacking)[index]
	# Punkty każdej ścianki dla tego wymagania (0 = nie trafia).
	var faces: Array[PackedFloat64Array] = []
	var means := PackedFloat64Array()
	for contest_die in contest.get_dice(attacking):
		var efficiency := contest.get_test_efficiency(contest_die, index)
		if efficiency <= 0.0:
			continue
		var die := contest_die.die
		var values := PackedFloat64Array()
		var mean := 0.0
		for face in die.get_face_count():
			var value := 0.0
			var term := requirement.attributes.find(die.get_face_attribute(face))
			if term != -1:
				value = die.get_face_value(face) * efficiency * requirement.weights[term]
			values.append(value)
			mean += value
		if mean > 0.0:
			faces.append(values)
			means.append(mean / values.size())
	var mean_total := 0.0
	var variance_total := 0.0
	if slot_count < 0 or slot_count >= faces.size():
		for values in faces:
			var moments := _max_moments([values])
			mean_total += moments.x
			variance_total += moments.y
		return Vector2(mean_total, variance_total)
	if slot_count == 0:
		return Vector2.ZERO
	var order: Array[int] = []
	for d in faces.size():
		order.append(d)
	order.sort_custom(func(a: int, b: int) -> bool: return means[a] > means[b])
	for slot in slot_count:
		var group: Array[PackedFloat64Array] = []
		for rank in range(slot, order.size(), slot_count):
			group.append(faces[order[rank]])
		var moments := _max_moments(group)
		mean_total += moments.x
		variance_total += moments.y
	return Vector2(mean_total, variance_total)


## Średnia (x) i wariancja (y) maksimum niezależnych kości (każda: tablica punktów ścianek).
static func _max_moments(group: Array[PackedFloat64Array]) -> Vector2:
	var levels := {}
	for values in group:
		for value in values:
			levels[value] = true
	var sorted_levels: Array = levels.keys()
	sorted_levels.sort()
	var mean := 0.0
	var square := 0.0
	var previous_cdf := 0.0
	for level: float in sorted_levels:
		var cdf := 1.0
		for values in group:
			var below := 0
			for value in values:
				if value <= level + 0.000001:
					below += 1
			cdf *= float(below) / values.size()
		var p := cdf - previous_cdf
		mean += p * level
		square += p * level * level
		previous_cdf = cdf
	return Vector2(mean, square - mean * mean)

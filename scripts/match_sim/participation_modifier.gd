class_name ParticipationModifier
extends RefCounted
## Reguła mnożnika udziału zawodnika w teście (W14, W15): „zawodnik w takiej relacji do pola testu (i spełniający
## warunki) liczy się ×weight”. Mnożnik zawodnika = największy z pasujących modyfikatorów (0, gdy żaden nie pasuje).
## Podstawowe zasady (pole akcji ×2, pola sąsiednie ×1, podający, przelot) to domyślna lista MatchRules
## (get_participation_modifiers); perki trenera (B5a) to dodatkowe modyfikatory drużyny (MatchTeam), np.
## „DM w akcjach obronnych w polu karnym ×2” = SUPPORT, DEFENSE, roles [DM], zones [1], weight 2.
## Czyste dane – PROTOTYP, zasady: res://docs/design/match_rules.md.

## Gdzie stoi zawodnik względem testu: w polu testu, w polu sąsiednim (przód, tył, bok – bez skosów), w polu piłki
## (podający – tylko atak, gdy strona nie ma testu przy polu startowym), w polu przelotu (tylko obrona).
enum Relation { ACTION, SUPPORT, PASSER, FLYOVER }
## Strona, której dotyczy modyfikator (nie „Side” – to globalny enum Godota).
enum SideFilter { BOTH, ATTACK, DEFENSE }
## Kanał zagrania, przy którym działa (ANY = każdy; inaczej PlayCard.Lane + 1).
enum LaneFilter { ANY, CENTER, WING }

var relation: Relation = Relation.ACTION
var weight: float = 1.0
var side: SideFilter = SideFilter.BOTH
## Role zawodnika (RoleData.id); puste = każda rola.
var roles: Array[StringName] = []
## Strefy pola testu w perspektywie drużyny zawodnika (obrońca: 1 = własne pole karne); puste = wszędzie.
var zones: Array[int] = []
var lane: LaneFilter = LaneFilter.ANY


static func create(p_relation: Relation, p_weight: float, p_side: SideFilter = SideFilter.BOTH) -> ParticipationModifier:
	var modifier := ParticipationModifier.new()
	modifier.relation = p_relation
	modifier.weight = p_weight
	modifier.side = p_side
	return modifier


## Czy modyfikator dotyczy zawodnika (bez sprawdzania relacji pola). own_zone: strefa pola testu w perspektywie
## drużyny zawodnika, card_lane: PlayCard.Lane zagrania.
func applies(role_id: StringName, attacking: bool, own_zone: int, card_lane: int) -> bool:
	if (side == SideFilter.ATTACK and not attacking) or (side == SideFilter.DEFENSE and attacking):
		return false
	if not roles.is_empty() and not role_id in roles:
		return false
	if not zones.is_empty() and not own_zone in zones:
		return false
	return lane == LaneFilter.ANY or lane == card_lane + 1


## Mnożnik udziału zawodnika w polu `cell` (perspektywa atakujących) przy teście w polu `test_cell`: największy
## z pasujących modyfikatorów. passer: czy działa relacja PASSER (strona bez testu przy polu startowym).
## role_id pusty = podgląd pola bez konkretnego zawodnika (liczą się tylko modyfikatory bez warunku roli).
static func get_weight(modifiers: Array[ParticipationModifier], cell: Vector2i, attacking: bool, origin: Vector2i,
		test_cell: Vector2i, flyover: Array[Vector2i], passer: bool, card_lane: int, role_id: StringName = &"") -> float:
	var distance := absi(cell.x - test_cell.x) + absi(cell.y - test_cell.y)
	# Szybka ścieżka (większość zawodników): żadna relacja nie zachodzi.
	if distance > 1 and not (passer and attacking and cell == origin) and not (not attacking and cell in flyover):
		return 0.0
	var own_zone := test_cell.x if attacking else MatchRules.ZONE_COUNT + 1 - test_cell.x
	var best := 0.0
	for modifier in modifiers:
		if modifier.weight <= best:
			continue
		var holds := false
		match modifier.relation:
			Relation.ACTION:
				holds = distance == 0
			Relation.SUPPORT:
				holds = distance == 1
			Relation.PASSER:
				holds = passer and attacking and cell == origin
			Relation.FLYOVER:
				holds = not attacking and cell in flyover
		if holds and modifier.applies(role_id, attacking, own_zone, card_lane):
			best = modifier.weight
	return best

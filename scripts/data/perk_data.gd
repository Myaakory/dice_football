class_name PerkData
extends RefCounted
## Perk trenera (W15): reguła mnożnika udziału zawodników jego drużyny w akcjach – np. „napastnik w polu akcji
## w polu karnym rywala ×3”. W meczu staje się modyfikatorem udziału drużyny (ParticipationModifier, MatchTeam).
## Dane: zakładka perks arkusza (data/perks.csv).

var id: StringName
var name_key: String
var description_key: String
## Gotowy modyfikator udziału (relacja, strona, role, strefy, kanał, mnożnik).
var modifier: ParticipationModifier

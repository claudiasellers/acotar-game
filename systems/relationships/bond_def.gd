## One bond's tables (docs/contracts/relationships.md): data/relationships/<id>.tres,
## written by tools/relationships/gen_bonds.gd.
class_name BondDef
extends Resource

## The bond id; for people, their speaker id in the dialogue roster.
@export var id: StringName
## Fact prefix: tam, luc, mare.
@export var prefix: String = ""
@export var stages: Array[BondStage] = []
@export var deeds: Array[BondDeed] = []
@export var moods: Array[BondMood] = []


func deed_of(deed_id: StringName) -> BondDeed:
	for d in deeds:
		if d.id == deed_id:
			return d
	return null


func did_fact(deed_id: StringName) -> String:
	return "fact.%s_did_%s" % [prefix, deed_id]


func warm_fact(stage: BondStage) -> String:
	return "fact.%s_warm_%s" % [prefix, stage.id] if stage.warm_at > 0 else ""


func mood_fact(mood_id: StringName) -> String:
	return "fact.%s_mood_%s" % [prefix, mood_id]


## Every fact this bond can raise (stages it owns, deeds, warm, moods).
func facts() -> PackedStringArray:
	var out := PackedStringArray()
	for s in stages:
		if not s.raised_elsewhere:
			out.append(s.fact)
		if s.warm_at > 0:
			out.append(warm_fact(s))
	for d in deeds:
		out.append(did_fact(d.id))
	for m in moods:
		if not out.has(mood_fact(m.id)):
			out.append(mood_fact(m.id))
	return out

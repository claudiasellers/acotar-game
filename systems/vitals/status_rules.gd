## What each status tag is (buff, debuff or half-buff) and how it stacks
## (plans/feyre-vitals/plan.md §7, contract §4). Its picture is
## Icons.texture(Icons.STATUS, tag).
class_name StatusRules
extends RefCounted

enum Kind { BUFF, HALF, DEBUFF }

## Debuffs first, then the half-buff, then buffs: the row reads danger first.
const ORDER: Array[StringName] = [
	&"venom", &"drowsy", &"roar_shake", &"chilled", &"starving",
	&"giddy",
	&"heal", &"steady", &"swift", &"strong", &"warm", &"quiet", &"bright", &"keen", &"cool",
	&"well_rested", &"well_fed", &"stuffed", &"at_ease",
]
const DEBUFFS: Array[StringName] = [&"venom", &"drowsy", &"roar_shake", &"chilled", &"starving"]
const HALF: Array[StringName] = [&"giddy"]
## Brew tags that live in BodyState.effects (Chemistry results).
const BREW_TAGS: Array[StringName] = [&"steady", &"swift", &"strong", &"warm", &"quiet", &"bright", &"keen", &"cool"]
## Additive, capped at 1.0. Venom ignores duration (it creeps); drowsy decays.
const ADDITIVE: Array[StringName] = [&"venom", &"drowsy"]
## Distinct brew tags allowed at once (Valheim's three food slots, plan §7a.4).
const MAX_BREW_TAGS := 3


static func kind(tag: StringName) -> Kind:
	if DEBUFFS.has(tag):
		return Kind.DEBUFF
	if HALF.has(tag):
		return Kind.HALF
	return Kind.BUFF


static func is_debuff(tag: StringName) -> bool:
	return DEBUFFS.has(tag)


static func sort_key(tag: StringName) -> int:
	var i := ORDER.find(tag)
	return i if i >= 0 else ORDER.size()


## Stacks a new application onto the current {magnitude, remaining, total}.
## Additive tags add and cap at 1; the rest keep the stronger and the longer.
static func stack(tag: StringName, current: Dictionary, magnitude: float, seconds: float) -> Dictionary:
	var m := float(current.get("magnitude", 0.0))
	var r := float(current.get("remaining", 0.0))
	if ADDITIVE.has(tag):
		return {"magnitude": minf(m + magnitude, 1.0), "remaining": maxf(r, seconds), "total": maxf(r, seconds)}
	var t := maxf(r, seconds)
	return {"magnitude": maxf(m, magnitude), "remaining": t, "total": maxf(float(current.get("total", 0.0)), t)}

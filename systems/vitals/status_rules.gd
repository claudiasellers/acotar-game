## What each status tag is (buff, debuff or half-buff) and how it stacks
## (plans/feyre-vitals/plan.md §7, contract §4). Its picture is
## Icons.texture(Icons.STATUS, tag).
class_name StatusRules
extends RefCounted

enum Kind { BUFF, HALF, DEBUFF, GAUGE }

## The gauges hold the first slots, then debuffs, the half-buff and buffs:
## the row reads danger first.
const ORDER: Array[StringName] = [
	&"cold", &"hunger",
	&"venom", &"drowsy", &"roar_shake",
	&"giddy",
	&"heal", &"steady", &"swift", &"strong", &"warm", &"quiet", &"bright", &"keen", &"cool",
	&"well_rested", &"stuffed", &"at_ease",
]
## Always on screen, calm to danger, so nothing about her body is a surprise
## (the owner, 2026-11-24): BodyState.cold and BodyState.hunger, 0..1.
const GAUGES: Array[StringName] = [&"cold", &"hunger"]
## Where each gauge turns uneasy, then dangerous. Cold from 0.7 is "chilled":
## from 0.85 for 20 s it costs health. Hunger from 0.9 is "starving".
const STAGES := {&"cold": Vector2(0.4, 0.7), &"hunger": Vector2(0.5, 0.9)}
const DEBUFFS: Array[StringName] = [&"venom", &"drowsy", &"roar_shake"]
const HALF: Array[StringName] = [&"giddy"]
## Brew tags that live in BodyState.effects (Chemistry results).
const BREW_TAGS: Array[StringName] = [&"steady", &"swift", &"strong", &"warm", &"quiet", &"bright", &"keen", &"cool"]
## Additive, capped at 1.0. Venom ignores duration (it creeps); drowsy decays.
const ADDITIVE: Array[StringName] = [&"venom", &"drowsy"]
## Distinct brew tags allowed at once (Valheim's three food slots, plan §7a.4).
const MAX_BREW_TAGS := 3


static func kind(tag: StringName) -> Kind:
	if GAUGES.has(tag):
		return Kind.GAUGE
	if DEBUFFS.has(tag):
		return Kind.DEBUFF
	if HALF.has(tag):
		return Kind.HALF
	return Kind.BUFF


static func is_debuff(tag: StringName) -> bool:
	return DEBUFFS.has(tag)


## A gauge's stage at `magnitude`: 0 calm, 1 uneasy, 2 danger.
static func stage(tag: StringName, magnitude: float) -> int:
	var at: Vector2 = STAGES.get(tag, Vector2(INF, INF))
	return 2 if magnitude >= at.y else (1 if magnitude >= at.x else 0)


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

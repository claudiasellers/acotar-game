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
## tag -> [name, what it does], in Feyre's own voice: the words the HUD
## teaches and the Wardrobe's "How I am" page shows. Every tag in ORDER has a line.
const INFO := {
	&"cold": ["Cold", "How cold I am. Cold shakes my aim and slows my stamina; deep cold costs me health. A fire or a warm brew helps."],
	&"hunger": ["Hunger", "How hungry I am. Hunger slows my stamina, and at home it keeps my health from mending far. Bread would help."],
	&"venom": ["Venom", "Poison, creeping. My health won't mend while it's in me, and once it's strong it drains me. A salve or a night in a bed draws it out."],
	&"drowsy": ["Drowsy", "My eyelids are heavy and my aim sways. It passes on its own; a keen brew clears it."],
	&"roar_shake": ["Roar shake", "That roar went through me. My aim sways until it passes."],
	&"giddy": ["Giddy", "Fae food went to my head. My aim wanders until it wears off."],
	&"heal": ["Healing", "Food is mending me over a few breaths, further than I'd mend on my own."],
	&"steady": ["Steady", "My bow hand is steadier, and the fear sits lighter."],
	&"swift": ["Swift", "My stamina comes back faster."],
	&"strong": ["Strong", "Fewer pulls to break a grip on me, and my stamina comes back a little faster."],
	&"warm": ["Warm", "The cold stays out, and the worst of it can't reach me."],
	&"quiet": ["Quiet", "My scent is masked, so beasts and lesser faeries track me less."],
	&"bright": ["Bright", "The world around me catches the light."],
	&"keen": ["Keen", "My eyes are clear: drowsiness can't take hold."],
	&"cool": ["Cool", "Fire hurts me less."],
	&"well_rested": ["Well rested", "A good night's sleep. My health mends a little further on its own for a day."],
	&"stuffed": ["Stuffed", "As full as I've ever been."],
	&"at_ease": ["At ease", "A good moment. Being at ease lets my health mend further on its own and gives me more stamina."],
}
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


## A tag's name for the player ("Roar shake"), or the tag itself if it has none.
static func title(tag: StringName) -> String:
	return String(INFO[tag][0]) if INFO.has(tag) else String(tag).capitalize()


## What a tag does, in one or two short sentences.
static func blurb(tag: StringName) -> String:
	return String(INFO[tag][1]) if INFO.has(tag) else ""


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

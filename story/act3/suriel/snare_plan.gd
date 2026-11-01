## How well Feyre set the Suriel's snare, and what that buys her (L26).
##
## Canon (Keeper, ch 13-15): young birch, a freshly killed chicken, a
## double-loop snare, close to running water; she waits hidden in an oak. The
## naga always come ("They heard my scream, and they smelled you."). A good
## snare buys time, so more answers before "We are not alone". canon:"X" for
## the scoring itself and for every bait other than the chicken.
##
## Pure functions, so tests and the encounter share one rule.
class_name SnarePlan
extends RefCounted

## Inside the young-birch ring (radius ~18 m round the snare site) counts in full.
const BIRCH_GOOD := 22.0
const BIRCH_FADE := 40.0
## "Close to running water": the Thornwater within this many metres.
const WATER_GOOD := 35.0
const WATER_FADE := 60.0
## Answers in book order. The fifth (the blight) is cut off by "We are not
## alone" unless the setup was near perfect.
const MAX_ANSWERS := 5
const FULL_BLIGHT_QUALITY := 0.92
## Seconds of hidden, unsmelled waiting before the Suriel comes, by bait.
const WAIT_WORST := 60.0
const WAIT_BEST := 20.0
## Each second her scent reaches the snare costs this much quality (max 0.4).
const SMELL_COST := 0.02

const WEIGHTS := {"site": 0.2, "water": 0.2, "loops": 0.2, "bait": 0.3, "hidden": 0.1}


## setup: birch_distance, water_distance (m), loops (0-2), bait (0-1 from
## bait_score), elevated (bool: up a tree), smelled_seconds.
## Returns {quality, parts: {site, water, loops, bait, hidden}, smell_cost}.
static func score(setup: Dictionary) -> Dictionary:
	var parts := {
		"site": _falloff(float(setup.get("birch_distance", 999.0)), BIRCH_GOOD, BIRCH_FADE),
		"water": _falloff(float(setup.get("water_distance", 999.0)), WATER_GOOD, WATER_FADE),
		"loops": [0.0, 0.4, 1.0][clampi(int(setup.get("loops", 0)), 0, 2)],
		"bait": clampf(float(setup.get("bait", 0.0)), 0.0, 1.0),
		"hidden": 1.0 if bool(setup.get("elevated", false)) else 0.6,
	}
	var q := 0.0
	for k: String in WEIGHTS:
		q += float(WEIGHTS[k]) * float(parts[k])
	var cost := minf(0.4, float(setup.get("smelled_seconds", 0.0)) * SMELL_COST)
	return {"quality": clampf(q - cost, 0.0, 1.0), "parts": parts, "smell_cost": cost}


## How many of the five answers she hears before the naga interrupt.
static func answers_for(quality: float) -> int:
	return clampi(1 + int(quality * 5.0), 1, MAX_ANSWERS)


## The blight answer runs to its end (Hybern's king, the Deceiver) only then.
static func blight_full(quality: float) -> bool:
	return quality >= FULL_BLIGHT_QUALITY


## Seconds of good waiting the bait needs before the Suriel comes.
static func wait_seconds(bait: float) -> float:
	return lerpf(WAIT_WORST, WAIT_BEST, clampf(bait, 0.0, 1.0))


## How the naga open: farther off when she scouted the stream first (canon:
## she scouts "several different routes to the stream"), closer after a
## poor snare (more thrashing, more scent).
static func naga_distance(quality: float, scouted: bool) -> float:
	return lerpf(9.0, 13.0, quality) + (4.0 if scouted else 0.0)


## A bait's pull, 0-1, from what the item is. Fresh meat is what the book
## asks for; fae things draw a faerie (X); bitter things put it off (X).
static func bait_score(item_id: StringName) -> float:
	if String(item_id).contains("chicken"):
		return 0.85
	var item := ItemCatalog.get_item(item_id) if ItemCatalog.has(item_id) else null
	var ing := item as IngredientData
	if ing == null:
		return 0.0
	var s := 0.15
	if ing.icon == &"meat" and ing.tags.has(&"vital"):
		s = 0.75
	elif ing.icon == &"meat":
		s = 0.4
	elif ing.tags.has(&"vital"):
		s = 0.3
	if ing.tags.has(&"fae"):
		s += 0.2
	if ing.tags.has(&"bitter"):
		s -= 0.3
	return clampf(s, 0.0, 1.0)


## What she carries that could bait a snare, best first.
static func baits_in(inventory: Inventory) -> Array[StringName]:
	var out: Array[StringName] = []
	for container: StringName in [Inventory.SATCHEL, Inventory.POUCH]:
		for id: StringName in inventory.contents(container):
			var item := ItemCatalog.get_item(id)
			if item and item.has_craft_tag(&"cordage"):
				continue  # the loops, not the bait
			if not out.has(id) and bait_score(id) > 0.0:
				out.append(id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return bait_score(a) > bait_score(b))
	return out


## Cordage she carries for the loops (sinew, spider silk...), up to two.
static func loops_from(inventory: Inventory) -> int:
	var n := 0
	for id in inventory.ids_with_craft_tag(&"cordage"):
		n += inventory.count(id)
	return mini(n, 2)


static func _falloff(d: float, good: float, fade: float) -> float:
	if d <= good:
		return 1.0
	return clampf(1.0 - (d - good) / fade, 0.0, 1.0)

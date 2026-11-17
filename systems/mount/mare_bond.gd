## Feyre and the white mare's bond (lane L47-8, docs/contracts/mare_bond.md).
## It runs beside the main story and never touches a phase flag (R2). Small
## deeds of care and riding earn points (capped each game day, so it can't be
## ground out); enough points, and the deed each step needs, raise the next
## bond fact (`fact.mare_bond_*`) through the director's ActionTrigger. Each
## step lets her hear Feyre's whistle from farther off and carry her farther
## from the manor. Points and progress live in WorldDeltas region `mount`.
## The facts are the only thing anything else reads. All [X] except the bareback
## step, which is canon (ch 20: Tamlin teaches her to ride bareback).
class_name MareBond
extends RefCounted

const DELTAS := &"mount"

## Each step: the fact it raises, the points it needs, how far she hears the
## whistle from (m, from her or from the stables when she's home), and how far
## from the stables she will carry Feyre (m). INF means anywhere north of the Wall.
const TIERS: Array[Dictionary] = [
	{"fact": "first_dinner_eaten", "points": 0, "hear": 0.0, "carry": 0.0},
	{"fact": "fact.mare_ridden", "points": 0, "hear": 150.0, "carry": 600.0},
	{"fact": "fact.mare_bond_trusted", "points": 12, "hear": 400.0, "carry": 1500.0},
	{"fact": "fact.mare_bond_bareback", "points": 30, "hear": 1000.0, "carry": 4000.0, "bareback_m": 300.0},
	{"fact": "fact.mare_bond_heart", "points": 55, "hear": INF, "carry": INF, "needs": "calanmai_attended"},
]
## Points per deed, and how many of that deed count in one game day.
const POINTS := {&"brushed": 3, &"treat": 1, &"piece": 2, &"ride": 1, &"region": 3, &"answered": 1}
const DAILY := {&"brushed": 1, &"treat": 3, &"piece": 3, &"ride": 8, &"region": 99, &"answered": 2}
## Metres ridden together for each &"ride" point.
const RIDE_STEP := 400.0
## The bareback step: the saddle can come off once she trusts Feyre (tier 2).
const BAREBACK_FROM := 2
## Fact raised the first time Feyre whistles from beyond her hearing (a thought).
const TOO_FAR_FACT := "fact.mare_bond_too_far"

## Raises a fact (the director sets it to fire its ActionTrigger); falls back to WorldState.
static var raise: Callable
## Called with (tier) when a new step is reached (the director plays the moment).
static var on_tier: Array[Callable] = []


static func _day() -> int:
	return Clock.day


static func _val(key: String, fallback: Variant) -> Variant:
	return WorldDeltas.get_region_value(DELTAS, key, fallback)


static func _put(key: String, value: Variant) -> void:
	WorldDeltas.set_region_value(DELTAS, key, value)


## 0: not hers yet; 1: ridden; 2: trusted; 3: bareback; 4: her heart.
static func tier() -> int:
	for i in range(TIERS.size() - 1, 0, -1):
		if WorldState.has_flag(TIERS[i]["fact"]):
			return i
	return 0


static func points() -> int:
	return int(_val("bond_points", 0))


## How far off she hears the whistle now (m).
static func hear_range() -> float:
	return float(TIERS[tier()]["hear"])


## How far from the stables she will carry Feyre now (m).
static func carry_range() -> float:
	return float(TIERS[tier()]["carry"])


static func can_ride_bareback() -> bool:
	return tier() >= BAREBACK_FROM


## How many of `kind` have counted today.
static func today(kind: StringName) -> int:
	if int(_val("bond_day", -1)) != _day():
		return 0
	return int((_val("bond_today", {}) as Dictionary).get(String(kind), 0))


## A deed: earns its points unless today's cap is reached. Returns points earned.
static func earn(kind: StringName, count: int = 1) -> int:
	if not POINTS.has(kind) or tier() < 1:
		return 0
	var counts: Dictionary = (_val("bond_today", {}) as Dictionary).duplicate()
	if int(_val("bond_day", -1)) != _day():
		counts = {}
		_put("bond_day", _day())
	var had := int(counts.get(String(kind), 0))
	var n := clampi(count, 0, int(DAILY[kind]) - had)
	if n <= 0:
		return 0
	counts[String(kind)] = had + n
	_put("bond_today", counts)
	var got := n * int(POINTS[kind])
	_put("bond_points", points() + got)
	check()
	return got


## The care screen's deeds (MareCare.on_care).
static func on_care(kind: StringName, amount: int) -> void:
	earn(kind, amount)


## Metres ridden together (bareback counts toward the bareback step too).
static func ride(metres: float, bareback: bool) -> void:
	if metres <= 0.0 or tier() < 1:
		return
	var m := float(_val("ride_m", 0.0)) + metres
	var steps := int(m / RIDE_STEP)
	_put("ride_m", m - steps * RIDE_STEP)
	if bareback:
		_put("bareback_m", float(_val("bareback_m", 0.0)) + metres)
	if steps > 0:
		earn(&"ride", steps)
	elif bareback:
		check()


static func bareback_metres() -> float:
	return float(_val("bareback_m", 0.0))


## A region reached on her back: the first time is a deed.
static func reach_region(id: StringName) -> bool:
	if id == &"" or tier() < 1:
		return false
	var seen: Array = (_val("bond_regions", []) as Array).duplicate()
	if seen.has(String(id)):
		return false
	seen.append(String(id))
	_put("bond_regions", seen)
	earn(&"region")
	return true


## Raises the next step if its points and deed are done. Returns the new tier, or -1.
static func check() -> int:
	var now := tier()
	if now < 1 or now + 1 >= TIERS.size():
		return -1
	var next: Dictionary = TIERS[now + 1]
	if points() < int(next["points"]):
		return -1
	if next.has("bareback_m") and bareback_metres() < float(next["bareback_m"]):
		return -1
	if next.has("needs") and not WorldState.has_flag(next["needs"]):
		return -1
	if raise.is_valid():
		raise.call(String(next["fact"]))
	else:
		WorldState.set_flag(next["fact"], true)
	for c in on_tier:
		if c.is_valid():
			c.call(now + 1)
	return now + 1

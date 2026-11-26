## Feyre and the white mare's bond (lane L47-8, docs/contracts/mare_bond.md),
## run by the one bond engine (L90, docs/contracts/relationships.md): her
## ladder is data/relationships/mare.tres, written from TIERS and MILESTONES
## below by tools/relationships/gen_bonds.gd. It never touches a phase flag
## (R2). It grows on what they do together, never on the passage of days: each
## step opens on one threshold deed behind a real barrier, plus a few first
## times, all one-off milestones. A milestone is done when fact.mare_did_<id>
## is up, and nothing else records it. What is the mare's own lives here: how
## far she hears the whistle and carries Feyre, the bareback run, the places
## reached on her back, the balm and the blight (WorldDeltas region `mount`).
## All [X] except the frame, which is canon: the first ride (ch 9), bareback
## lessons before Calanmai (ch 20), her following the drums and being left at
## the Rite (ch 20-21).
class_name MareBond
extends RefCounted

const DELTAS := &"mount"
## Her bond in the engine (data/relationships/mare.tres).
const BOND := &"mare"

## Each step: the fact it raises, how far she hears the whistle from (m, from
## her or from the stables when she's home), and how far from the stables she
## will carry Feyre (m). INF means anywhere north of the Wall.
const TIERS: Array[Dictionary] = [
	{"fact": "first_dinner_eaten", "hear": 0.0, "carry": 0.0},
	{"fact": "fact.mare_ridden", "hear": 150.0, "carry": 600.0},
	{"fact": "fact.mare_bond_trusted", "hear": 400.0, "carry": 1500.0},
	{"fact": "fact.mare_bond_bareback", "hear": 1000.0, "carry": 4000.0},
	{"fact": "fact.mare_bond_heart", "hear": INF, "carry": INF},
]
## What each step needs, in the order her page tells them. The last of each is
## the threshold deed behind its barrier.
##  2: she comes to the whistle; brushed to a gleam; a honeyplum from Feyre's
##     hand (they grow only in Blossom Vale, beyond where she'll carry Feyre yet).
##  3: turned back once at the edge of her range; three places reached on her
##     back; 300 m in one bareback ride (Tamlin's lessons, ch 20).
##  4: she balked once at the Blighted Reaches; 200 m ridden into them with
##     the sweetbalm on her muzzle (mugwort grows only in the Western Fells);
##     the morning after Calanmai, Feyre goes to her (left at the Rite, ch 21).
const MILESTONES := {
	2: [&"answered", &"gleam", &"honeyplum"],
	3: [&"edge", &"places", &"bareback_run"],
	4: [&"balked", &"blight_ride", &"reunion"],
}
## Three places reached on her back for &"places".
const PLACES := 3
## One unbroken bareback ride this long (m) for &"bareback_run".
const BAREBACK_RUN := 300.0
## This far (m) into the blight with the balm on for &"blight_ride".
const BLIGHT_RIDE := 200.0
## Where she won't go without the balm: the smell of what's loose there (Keeper).
const BLIGHT_REGION := &"blighted_reaches"
## The balm: what it takes, made at her side (MareTendingView, the Care tab).
const BALM_NEEDS: Array[StringName] = [&"ing_mugwort", &"ing_lavender", &"ing_honey"]
## The bareback step: the saddle can come off once she trusts Feyre (tier 2).
const BAREBACK_FROM := 2
## Fact raised the first time Feyre whistles from beyond her hearing (a thought).
const TOO_FAR_FACT := "fact.mare_bond_too_far"
## Fact raised the first time she balks at the blight (a thought, Lucien's line).
const BALKED_FACT := "fact.mare_balked_blight"
## Raised when each milestone is done: `fact.mare_did_<id>` (her page's memories,
## Feyre's thoughts). Facts only, never phase flags.
const DID_PREFIX := "fact.mare_did_"
const CALANMAI_FLAG := "calanmai_attended"

static func _val(key: String, fallback: Variant) -> Variant:
	return WorldDeltas.get_region_value(DELTAS, key, fallback)


static func _put(key: String, value: Variant) -> void:
	WorldDeltas.set_region_value(DELTAS, key, value)


## 0: not hers yet; 1: ridden; 2: trusted; 3: bareback; 4: her heart.
static func tier() -> int:
	return maxi(Relationships.stage(BOND), 0)


## How far off she hears the whistle now (m).
static func hear_range() -> float:
	return float(TIERS[tier()]["hear"])


## How far from the stables she will carry Feyre now (m).
static func carry_range() -> float:
	return float(TIERS[tier()]["carry"])


static func can_ride_bareback() -> bool:
	return tier() >= BAREBACK_FROM


# ------------------------------------------------------------------ milestones

static func done(id: StringName) -> bool:
	return Relationships.done(BOND, id)


## The step (2..4) a milestone belongs to, or 0.
static func step_of(id: StringName) -> int:
	for s: int in MILESTONES:
		if (MILESTONES[s] as Array).has(id):
			return s
	return 0


## Records a milestone (once; before the first ride nothing counts). Returns
## true the first time. A milestone may be done early; its step still waits
## for the one before it.
static func mark(id: StringName) -> bool:
	return step_of(id) != 0 and Relationships.deed(BOND, id)


## The milestones of `step` still to do, in order.
static func missing(step: int) -> Array[StringName]:
	return Relationships.missing(BOND, step)


## The step being worked toward now (2..4), or 0 when she isn't Feyre's yet
## or the bond is whole.
static func working_on() -> int:
	var t := tier()
	return t + 1 if t >= 1 and t + 1 < TIERS.size() else 0


## The milestone her page is about now: the first undone one of the next step.
static func next_milestone() -> StringName:
	var m := missing(working_on())
	return m.front() if not m.is_empty() else &""


# ------------------------------------------------------------------ deeds

## Care (MareCare.on_care): a gleam from the brush, a honeyplum from the hand.
static func on_care(kind: StringName, _amount: int) -> void:
	match kind:
		&"brushed":
			mark(&"gleam")
		&"honeyplum":
			mark(&"honeyplum")


## She came to Feyre's whistle (MountDirector.whistle).
static func answered() -> void:
	mark(&"answered")


## She turned for home at the edge of how far she'll carry Feyre.
static func reached_edge() -> void:
	mark(&"edge")


## Metres ridden together. A bareback ride counts toward the one unbroken run;
## a stretch in the saddle ends it.
static func ride(metres: float, bareback: bool) -> void:
	if metres <= 0.0 or tier() < 1:
		return
	if not bareback:
		_put("bareback_run_m", 0.0)
		return
	var run := float(_val("bareback_run_m", 0.0)) + metres
	_put("bareback_run_m", run)
	if run >= BAREBACK_RUN:
		mark(&"bareback_run")


## Feyre got down: the unbroken bareback run is over.
static func ride_ended() -> void:
	_put("bareback_run_m", 0.0)


static func bareback_run() -> float:
	return float(_val("bareback_run_m", 0.0))


## A region reached on her back: the first time counts toward &"places".
static func reach_region(id: StringName) -> bool:
	if id == &"" or tier() < 1:
		return false
	var seen: Array = (_val("bond_regions", []) as Array).duplicate()
	if seen.has(String(id)):
		return false
	seen.append(String(id))
	_put("bond_regions", seen)
	if seen.size() >= PLACES:
		mark(&"places")
	return true


static func places_reached() -> int:
	return (_val("bond_regions", []) as Array).size()


## Feyre beside her on foot. After Calanmai, the first time is the reunion
## (she was left at the Rite, ch 21).
static func beside() -> void:
	if WorldState.has_flag(CALANMAI_FLAG):
		mark(&"reunion")


## She planted her feet at the blight. Returns true the first time.
static func balked() -> bool:
	if not WorldState.has_flag(BALKED_FACT):
		WorldState.set_flag(BALKED_FACT, true)
	var n := int(_val("balks", 0)) + 1
	_put("balks", n)
	return mark(&"balked")


static func balks() -> int:
	return int(_val("balks", 0))


## True while the sweetbalm is on her muzzle (until she's next home).
static func balmed() -> bool:
	return bool(_val("balm", false))


static func can_make_balm(inventory: Inventory) -> bool:
	if inventory == null:
		return false
	for id in BALM_NEEDS:
		if inventory.count(id) <= 0:
			return false
	return true


## Makes the balm from the satchel and puts it on her. False if anything's missing.
static func put_balm(inventory: Inventory) -> bool:
	if not can_make_balm(inventory):
		return false
	for id in BALM_NEEDS:
		inventory.remove(id, 1)
	_put("balm", true)
	_put("blight_m", 0.0)
	return true


## Home at the stables: the balm has worn off.
static func balm_off() -> void:
	_put("balm", false)


## Metres ridden on blighted ground (only possible with the balm on).
static func blight_ride(metres: float) -> void:
	if metres <= 0.0 or not balmed():
		return
	var m := float(_val("blight_m", 0.0)) + metres
	_put("blight_m", m)
	if m >= BLIGHT_RIDE:
		mark(&"blight_ride")


# ------------------------------------------------------------------ steps

## Opens every step whose milestones are done, in order. Returns the new tier, or -1.
static func check() -> int:
	return Relationships.check(BOND)

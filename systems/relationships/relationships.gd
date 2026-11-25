## The one bond engine (lane L90, docs/contracts/relationships.md; design:
## plans/relationship-loops/plan.md). Tamlin, Lucien and the white mare each
## have a ladder of stages; a stage opens when the book has reached its gate
## AND Feyre's deeds have earned it, or at its canon floor beat when they
## haven't, so the story is never blocked. Stages never drop. A bad deed only
## sets a cool mood for a day.
##
## Everything it knows is a `fact.` flag: a deed is done when
## fact.<prefix>_did_<deed> is up, a stage when its fact is up. Regard is the
## sum of the done deeds' weights and never leaves this file (no number on
## screen, R2). It never sets a phase, canon or story flag.
class_name Relationships
extends RefCounted

const DIR := "res://data/relationships/"
const DELTAS := &"relationships"
## Attitudes (how they hold themselves with her, read by PresenceActor):
## cool turns away from her (a cool mood; Tamlin's way), baiting watches her
## and goes back to his business if she lingers (Lucien before the patrol,
## Keeper ch6-9), neutral turns to her, warm turns to her from farther off.
const COOL := &"cool"
const BAITING := &"baiting"
const NEUTRAL := &"neutral"
const WARM := &"warm"

## The RelationshipDirector's group. A fact is raised through its ActionTrigger
## when one is in the tree; with none (a bare test) on WorldState directly.
## Nothing else listens to the core: a stage or deed is news only as its fact,
## through EventBus.flag_changed (R8).
const DIRECTOR_GROUP := &"relationship_director"

## The only static state: the BondDefs as loaded (read-only data), and the
## bonds being checked now (empty whenever check() isn't running).
static var _defs: Dictionary = {}
## Bonds being checked now: a fact raised inside check() comes back through
## flag_changed, and the outer pass already handles it.
static var _checking: Dictionary = {}


## Every bond, by id.
static func defs() -> Dictionary:
	if _defs.is_empty():
		for f in DirAccess.get_files_at(DIR):
			var file := f.trim_suffix(".remap")
			if file.ends_with(".tres"):
				var d := load(DIR + file) as BondDef
				if d:
					_defs[d.id] = d
	return _defs


static func def(bond: StringName) -> BondDef:
	return defs().get(bond) as BondDef


static func stage(bond: StringName) -> int:
	var d := def(bond)
	if d == null:
		return -1
	for i in range(d.stages.size() - 1, -1, -1):
		if WorldState.has_flag(d.stages[i].fact):
			return i
	return -1


static func stage_id(bond: StringName) -> StringName:
	var i := stage(bond)
	return def(bond).stages[i].id if i >= 0 else &""


static func done(bond: StringName, deed_id: StringName) -> bool:
	var d := def(bond)
	return d != null and d.deed_of(deed_id) != null and WorldState.has_flag(d.did_fact(deed_id))


## Marks a deed once (not before its from_stage), then opens what is due.
## True the first time.
static func deed(bond: StringName, deed_id: StringName) -> bool:
	var d := def(bond)
	if d == null:
		return false
	var dd := d.deed_of(deed_id)
	if dd == null or done(bond, deed_id) or stage(bond) < dd.from_stage:
		return false
	_raise(d.did_fact(deed_id))
	check(bond)
	return true


## The `needs` of `stage_index` still undone, in order.
static func missing(bond: StringName, stage_index: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var d := def(bond)
	if d == null or stage_index < 0 or stage_index >= d.stages.size():
		return out
	for id in d.stages[stage_index].needs:
		if not done(bond, id):
			out.append(id)
	return out


## Opens every stage that is due, in order, and raises the warm facts earned.
## Returns the new stage, or -1 when none opened.
static func check(bond: StringName) -> int:
	var d := def(bond)
	if d == null or _checking.has(bond):
		return -1
	_checking[bond] = true
	var reached := -1
	var now := stage(bond)
	while now + 1 < d.stages.size() and _due(d, d.stages[now + 1]):
		now += 1
		var s := d.stages[now]
		if not s.raised_elsewhere:
			_raise(s.fact)
		reached = now
	var r := _regard(d)
	for i in range(0, now + 1):
		var s := d.stages[i]
		if s.warm_at > 0 and r >= s.warm_at and not WorldState.has_flag(d.warm_fact(s)):
			_raise(d.warm_fact(s))
	_checking.erase(bond)
	return reached


## The current stage has turned warm.
static func warm(bond: StringName) -> bool:
	var d := def(bond)
	var i := stage(bond)
	return i >= 0 and d.stages[i].warm_at > 0 and WorldState.has_flag(d.warm_fact(d.stages[i]))


## The mood on now, or &"".
static func mood(bond: StringName) -> StringName:
	var d := def(bond)
	if d == null:
		return &""
	for m in d.moods:
		if WorldState.has_flag(d.mood_fact(m.id)):
			return m.id
	return &""


## How they hold themselves with her now: cool during a cool mood, warm once
## the current stage is warm, else the stage's own attitude.
static func attitude(bond: StringName) -> StringName:
	var i := stage(bond)
	if i < 0:
		return NEUTRAL
	if mood(bond) == COOL:
		return COOL
	if warm(bond):
		return WARM
	return def(bond).stages[i].attitude


## Starts a mood (once a stage past the first is reached): it lasts until the
## `days`-th dawn after `today`. False when it was already on.
static func start_mood(bond: StringName, mood_id: StringName, today: int) -> bool:
	var d := def(bond)
	if d == null or stage(bond) < 1:
		return false
	for m in d.moods:
		if m.id == mood_id:
			WorldDeltas.set_region_value(DELTAS, "mood_until.%s" % bond, today + m.days + 1)
			if WorldState.has_flag(d.mood_fact(m.id)):
				return false
			_raise(d.mood_fact(m.id))
			return true
	return false


## A new day: moods past their last dawn end.
static func dawn(day: int) -> void:
	for bond: StringName in defs():
		var d := def(bond)
		var until := int(WorldDeltas.get_region_value(DELTAS, "mood_until.%s" % bond, 0))
		if until > 0 and day >= until:
			WorldDeltas.set_region_value(DELTAS, "mood_until.%s" % bond, 0)
			for m in d.moods:
				WorldState.set_flag(d.mood_fact(m.id), false)


static func _due(d: BondDef, s: BondStage) -> bool:
	if s.raised_elsewhere:
		return WorldState.has_flag(s.fact)
	if s.gate != "" and not WorldState.has_flag(s.gate):
		return false
	for id in s.needs:
		if not WorldState.has_flag(d.did_fact(id)):
			return false
	if _regard(d) >= s.floor:
		return true
	return s.canon_floor != "" and WorldState.has_flag(s.canon_floor)


static func _regard(d: BondDef) -> int:
	var r := 0
	for dd in d.deeds:
		if WorldState.has_flag(d.did_fact(dd.id)):
			r += dd.weight
	return r


static func _raise(fact: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var director := tree.get_first_node_in_group(DIRECTOR_GROUP) if tree else null
	if director:
		director.call(&"fire", fact)
	if not WorldState.has_flag(fact):
		WorldState.raise_deed(fact)

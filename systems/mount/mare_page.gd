## Her page (lane L47-8, docs/contracts/mare_bond.md): the sketchbook page on
## the tending screen that says, in Feyre's hand, what the mare does now, what
## Feyre means to try next and what she remembers. It's the one place the bond
## is spelled out (R2 as amended for L54: opt-in, never on the HUD, the map or
## in the world). Hints follow the journal's HintLadder: they unlock with play
## time on the milestone or failed tries (a balk, a turn for home), and show
## only when asked ("Think on it"). Hint state lives in WorldDeltas `mount`.
class_name MarePage
extends RefCounted

const DATA := "res://data/mount/mare_page.tres"
const KEY := "page_hints"
## Hint time is written back this often (s), not every frame.
const FLUSH := 5.0

static var _data: MarePageData
static var _ladder: HintLadder
static var _since_flush: float = 0.0


static func data() -> MarePageData:
	if _data == null and ResourceLoader.exists(DATA):
		_data = load(DATA) as MarePageData
	return _data


static func ladder() -> HintLadder:
	if _ladder == null:
		_ladder = HintLadder.new()
		_ladder.from_dict(WorldDeltas.get_region_value(MareBond.DELTAS, KEY, {}) as Dictionary)
	return _ladder


## Forgets the cached hint state (a new game, a load, a test).
static func reset() -> void:
	_ladder = null
	_since_flush = 0.0


static func _flush() -> void:
	_since_flush = 0.0
	WorldDeltas.set_region_value(MareBond.DELTAS, KEY, ladder().to_dict())


## What she does now.
static func now_line() -> String:
	var d := data()
	var t := MareBond.tier()
	return d.now[t] if d and t < d.now.size() else ""


## The milestone her page is about: the first undone, ready one of the step
## being worked toward (null when there's none).
static func current() -> MareBondNote:
	var d := data()
	if d == null:
		return null
	for id in MareBond.missing(MareBond.working_on()):
		var n := d.note(id)
		if n and n.ready():
			return n
	return null


static func after_line() -> String:
	var n := current()
	return n.after.format({"places": MareBond.places_reached()}) if n else ""


## Play time on the current milestone (MountDirector._process, unpaused only).
static func tick(delta: float) -> void:
	var n := current()
	if n == null:
		return
	ladder().tick(n.id, delta)
	_since_flush += delta
	if _since_flush >= FLUSH:
		_flush()


## A failed try at the current milestone (she balked, she turned for home).
static func fail() -> void:
	var n := current()
	if n:
		ladder().note_fail(n.id)
		_flush()


## The hints shown so far for the current milestone.
static func hints_shown() -> PackedStringArray:
	var n := current()
	var out := PackedStringArray()
	if n:
		for k in mini(ladder().shown(n.id), n.hints.size()):
			out.append(_keyed(n.hints[k]))
	return out


static func can_think() -> bool:
	var n := current()
	return n != null and ladder().can_reveal(n.id, n.hints.size())


## "Think on it": reveals the next unlocked hint. Returns it, or "".
static func think() -> String:
	var n := current()
	if n == null:
		return ""
	var k := ladder().reveal(n.id, n.hints.size())
	_flush()
	return _keyed(n.hints[k]) if k >= 0 else ""


## A hint's {tend} names the tending key as it's bound now.
static func _keyed(hint: String) -> String:
	return hint.format({"tend": KeyPrompt.key(MountDirector.TEND_ACTION)})


## Memories of every milestone done, in bond order.
static func memories() -> PackedStringArray:
	var out := PackedStringArray()
	var d := data()
	if d == null:
		return out
	for step: int in MareBond.MILESTONES:
		for id: StringName in MareBond.MILESTONES[step]:
			var n := d.note(id)
			if n and MareBond.done(id):
				out.append(n.memory)
	return out

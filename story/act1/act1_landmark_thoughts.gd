## Feyre's thoughts along the way to the ch1 clearing (R2: the world teaches,
## the card only confirms): each landmark on the route from the cottage to the
## doe raises one line, once, plainer the closer she gets; drifting well away
## from the clearing for a while gets a gentle "wrong way" (at most twice).
## Shown on the GuideJournal card, only in AUTO mode and only before the wolf
## is spotted. Each one also counts as progress, so the hunt thread's own
## stall nudges stay quiet while she's on the trail.
class_name Act1LandmarkThoughts
extends Node

## [id, Keeper line id, canon, icon, line, where: Vector2, radius m].
## Lines by the Storykeeper against ch1 (voice-lines-act1.md, hint table).
const LANDMARKS := [
	[&"bark", "H1_bark", "A", &"trail", "Bark stripped low. Something's been feeding here.",
			Act1Wayfinding.TRAIL_END, 45.0],
	[&"prints", "H1_prints", "X", &"trail", "Fresh prints, not yet snowed over. A doe.",
			Act1Wayfinding.TRAIL_END, 10.0],
	[&"slowing", "H1_slowing", "X", &"trail", "Shorter steps. She's slowing to feed.",
			Vector2.INF, 14.0],  # the middle of the track line, filled in by _route()
	[&"ice", "H1_ice", "A", &"trail", "Holes in the brook ice. Something still drinks here.",
			Vector2.INF, 15.0],  # where the tracks cross the frozen creek, by _route()
	[&"downwind", "H1_downwind", "A", &"trail", "Into the brambles. Stay downwind. One shot.",
			HumanRealmLayout.DOE_CLEARING, 120.0],
]
const WRONG_WAY := [&"wrong_way", "H1_wrong_way", "A", &"trail",
		"Nothing out here. Whatever's left has pulled in deeper."]
const DONE_FLAG := "fact.wolf_spotted"
## Wrong way: this much farther from the clearing than her closest, this long,
## once she's this far from the cottage; then a rest before the second.
const WRONG_BY := 90.0
const WRONG_FOR := 20.0
const LEAVE_HOME := 60.0
const WRONG_REST := 180.0
const WRONG_MAX := 2

var landmarks: Array = LANDMARKS.duplicate(true)
var reached: Dictionary = {}
var wrong_shown: int = 0
var _route_built: bool = false
var _closest: float = INF
var _away_for: float = 0.0
var _rest: float = 0.0
var _queued: Array = []


func _ready() -> void:
	name = "Act1LandmarkThoughts"


func _process(delta: float) -> void:
	if WorldState.has_flag(DONE_FLAG):
		set_process(false)
		return
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null:
		return
	update(Vector2(feyre.global_position.x, feyre.global_position.z), delta)
	if not _queued.is_empty():
		_try_show()


## Advances from where Feyre stands (x, z). Returns the line raised, or "".
func update(at: Vector2, delta: float) -> String:
	_route()
	var raised := ""
	for spec: Array in landmarks:
		if reached.has(spec[0]) or at.distance_to(spec[5]) > float(spec[6]):
			continue
		reached[spec[0]] = true
		# Reaching several at once (a jump ahead) shows only the closest-in.
		raised = spec[4]
		_queued = spec
	var to_clearing := at.distance_to(HumanRealmLayout.DOE_CLEARING)
	_closest = minf(_closest, to_clearing)
	_rest = maxf(_rest - delta, 0.0)
	var away := at.distance_to(HumanRealmLayout.COTTAGE) > LEAVE_HOME \
			and to_clearing - _closest > WRONG_BY
	_away_for = _away_for + delta if away else 0.0
	if _away_for >= WRONG_FOR and _rest <= 0.0 and wrong_shown < WRONG_MAX:
		wrong_shown += 1
		_away_for = 0.0
		_rest = WRONG_REST
		_closest = to_clearing
		raised = WRONG_WAY[4]
		_queued = WRONG_WAY
	return raised


func _route() -> void:
	if _route_built:
		return
	_route_built = true
	var track := Act1Wayfinding.track_points()
	var crossing := track[0]
	for p in track:
		if HumanRealmLayout.distance_to_creek(p) < HumanRealmLayout.distance_to_creek(crossing):
			crossing = p
	for spec: Array in landmarks:
		match spec[0]:
			&"slowing":
				spec[5] = track[track.size() / 2]
			&"ice":
				spec[5] = crossing


func _try_show() -> void:
	var journal := get_tree().get_first_node_in_group(GuideSettings.GROUP) as GuideJournal
	if journal == null:
		_queued = []
		return
	if journal.mode != GuideSettings.Mode.AUTO:
		_queued = []
		return
	if journal.showing or not journal.can_show():
		return
	var spec := _queued
	_queued = []
	journal.director.note_progress()
	journal.show_thought(thread_for(spec), 0, false)


## A one-line thread for the card (voice file: res://audio/voice/feyre/<Keeper id>.ogg).
static func thread_for(spec: Array) -> GuideThread:
	var thread := GuideThread.new()
	thread.id = StringName("landmark_%s" % spec[0])
	thread.voice_ids = PackedStringArray([spec[1]])
	thread.canon = spec[2]
	thread.icon = spec[3]
	thread.lines = PackedStringArray([spec[4]])
	return thread

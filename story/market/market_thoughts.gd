## Feyre's thoughts on the walk to market with the wolf's pelt (lane L53;
## R2: the world and her own voice lead, nothing points). From the moment the
## pelt is in her satchel until it is sold, each place on the cottage road
## raises one line, once, on the GuideJournal card (AUTO mode only, like
## Act1LandmarkThoughts); the last one, by the well, names her three buyers.
## Wandering well away from the village with the pelt gets one nudge, twice
## at most. Lines: the Keeper, close to ch 3 (lines 679-795) [A]; the nudge [X].
class_name MarketThoughts
extends Node

const PELT := &"obj_wolf_pelt"
const DONE_FLAG := "pelt_sold"
## [id, Keeper line id, canon, icon, line, where: Vector2, radius m]
const PLACES := [
	[&"yard", "M3_yard", "A", &"trail",
			"Nesta was up at dawn chopping wood. She knows I'll come home with coin.",
			HumanRealmLayout.COTTAGE, 30.0],
	[&"road", "M3_road", "A", &"trail",
			"One road through the snow fields. If I do well, maybe something delicious tonight.",
			Vector2(150.0, 2230.0), 30.0],
	[&"edge", "M3_edge", "A", &"trail",
			"Stone houses, dull and grim. And spices on the wind, things we can't afford.",
			Vector2(300.0, 2243.0), 28.0],
	[&"square", "M3_square", "A", &"trail",
			"The Children of the Blessed. Exactly what I needed on market day.",
			HumanRealmLayout.VILLAGE_SQUARE, 24.0],
	[&"buyers", "M3_buyers", "A", &"trail",
			"The cobbler, the clothier, or the woman by the well. Fine. It'll be that sort of day.",
			Vector2(377.6, 2256.6), 11.0],
]
const WRONG_WAY := [&"wrong_way", "M3_wrong_way", "X", &"trail",
		"The coin's in the village, not out here. East, down the cottage road."]
## Wrong way: this much farther from the square than her closest, this long.
const WRONG_BY := 120.0
const WRONG_FOR := 25.0
const WRONG_REST := 150.0
const WRONG_MAX := 2

var reached: Dictionary = {}
var wrong_shown: int = 0
var _closest: float = INF
var _away_for: float = 0.0
var _rest: float = 0.0
var _queued: Array = []


func _ready() -> void:
	name = "MarketThoughts"


func _process(delta: float) -> void:
	if WorldState.has_flag(DONE_FLAG) or Act1LandmarkThoughts.past_winter():
		set_process(false)
		return
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null or not carrying():
		return
	update(Vector2(feyre.global_position.x, feyre.global_position.z), delta)
	if not _queued.is_empty():
		_try_show()


static func carrying() -> bool:
	return Gameplay.inventory.count(PELT) > 0


## Advances from where Feyre stands (x, z), pelt in hand. Returns the line raised, or "".
func update(at: Vector2, delta: float) -> String:
	var raised := ""
	for spec: Array in PLACES:
		if reached.has(spec[0]) or at.distance_to(spec[5]) > float(spec[6]):
			continue
		reached[spec[0]] = true
		raised = spec[4]
		_queued = spec
	var to_square := at.distance_to(HumanRealmLayout.VILLAGE_SQUARE)
	_closest = minf(_closest, to_square)
	_rest = maxf(_rest - delta, 0.0)
	_away_for = _away_for + delta if to_square - _closest > WRONG_BY else 0.0
	if _away_for >= WRONG_FOR and _rest <= 0.0 and wrong_shown < WRONG_MAX:
		wrong_shown += 1
		_away_for = 0.0
		_rest = WRONG_REST
		_closest = to_square
		raised = WRONG_WAY[4]
		_queued = WRONG_WAY
	return raised


func _try_show() -> void:
	var journal := get_tree().get_first_node_in_group(GuideSettings.GROUP) as GuideJournal
	if journal == null or journal.mode != GuideSettings.Mode.AUTO:
		_queued = []
		return
	if journal.showing or not journal.can_show():
		return
	# Never on top of a spoken caption (the dialogue lane's rule).
	var dd := get_tree().get_first_node_in_group(DialogueDirector.GROUP) as DialogueDirector
	if dd and (dd.busy() or dd.held()):
		return
	var spec := _queued
	_queued = []
	journal.director.note_progress()
	journal.show_thought(Act1LandmarkThoughts.thread_for(spec), 0, false)

## Fast travel by the whorl stones (contract: docs/contracts/fast_travel.md).
##
## One node in the game scene (story/act1/act1_game.gd adds it). It reads every
## WhorlStoneDef in data/fast_travel/ and puts each pair into the world when its
## region streams in (under the region's root, so it frees with the region).
##
## What she has marked is kept in WorldDeltas region "fast_travel" (key = the
## stone id), so it saves and loads with the world. Nothing here sets a
## WorldState flag or changes the story phase (R2); there are no markers and no
## objective text. Travel is an off-screen ride (Keeper: "a ride, not a
## teleport"): the screen fades, she is put down by the stones, and it fades back.
class_name WhorlStones
extends Node

const GROUP := &"whorl_stone"
const DEFS_DIR := "res://data/fast_travel"
const DELTAS_REGION := &"fast_travel"
const PLACES_PATH := "res://data/map/map_places.tres"
## Phases where the court is not hers to ride (home across the Wall, the pass).
const NO_TRAVEL_PHASES: Array[StringName] = [&"p7_return_home", &"p8_the_pass"]
const MARK_LINES: Array[String] = [
	"A whorl, worn almost flat. I traced it with a finger, and painted a rose beside it.",
	"Another pair of stones, the same faint whorl. My rose goes beside it.",
]
## Her thought when the second pair is marked and there is somewhere to ride.
const RIDE_THOUGHT := "Two marked now. I could ride between them blind."

static var _defs: Array[WhorlStoneDef] = []
static var _places: MapPlaceSet


func _ready() -> void:
	name = "WhorlStones"
	WorldStreamer.region_loaded.connect(_on_region_loaded)
	for id in WorldStreamer.loaded_ids():
		var root := WorldStreamer.loaded_root(StringName(id))
		if root:
			_on_region_loaded(StringName(id), root)


func _exit_tree() -> void:
	if WorldStreamer.region_loaded.is_connected(_on_region_loaded):
		WorldStreamer.region_loaded.disconnect(_on_region_loaded)


func _on_region_loaded(region_id: StringName, root: Node3D) -> void:
	spawn_for(region_id, root)


## Puts the pairs that stand in `region_id` under `root`. Returns how many.
static func spawn_for(region_id: StringName, root: Node3D) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var n := 0
	for d in defs():
		if d.region_id != region_id or root.has_node(NodePath("WhorlStone_%s" % d.id)):
			continue
		var s := WhorlStone.make(d)
		root.add_child(s)
		s.global_transform = WhorlStone.ground_transform(d)
		n += 1
	return n


# --- Data ------------------------------------------------------------------------

## Every pair, sorted by id (stable).
static func defs() -> Array[WhorlStoneDef]:
	if _defs.is_empty():
		var found: Array[WhorlStoneDef] = []
		for f in ResourceLoader.list_directory(DEFS_DIR):
			if f.ends_with(".tres"):
				var d := load(DEFS_DIR.path_join(f)) as WhorlStoneDef
				if d:
					found.append(d)
		found.sort_custom(func(a: WhorlStoneDef, b: WhorlStoneDef) -> bool: return String(a.id) < String(b.id))
		_defs = found
	return _defs


static func get_def(id: StringName) -> WhorlStoneDef:
	for d in defs():
		if d.id == id:
			return d
	return null


## The name on the map for a pair's place (the same words the map writes).
static func place_label(d: WhorlStoneDef) -> String:
	if _places == null:
		_places = load(PLACES_PATH) as MapPlaceSet if ResourceLoader.exists(PLACES_PATH) else MapPlaceSet.new()
	for p in _places.places:
		if p.id == d.place_id:
			return p.label
	return String(d.place_id).capitalize()


# --- Marks (saved with the world) --------------------------------------------

static func is_marked(id: StringName) -> bool:
	return WorldDeltas.get_region_value(DELTAS_REGION, String(id), null) != null


static func mark(id: StringName) -> void:
	WorldDeltas.set_region_value(DELTAS_REGION, String(id), true)


static func marked_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for d in defs():
		if is_marked(d.id):
			out.append(String(d.id))
	return out


## Her line on the find card when she paints a mark: the first, then the rest.
static func mark_line() -> String:
	return MARK_LINES[0] if marked_ids().size() <= 1 else MARK_LINES[1]


# --- Travel --------------------------------------------------------------------

## Whether she may ride from a stone now: only in free play (no story scene,
## no dialogue), and not in the phases the court is closed to her.
static func can_travel() -> bool:
	return StoryControl.mode == StoryControl.Mode.FULL and not NO_TRAVEL_PHASES.has(PhaseManager.current_phase)


## The pairs she can ride to from `from_id`: marked, not this one, and in a
## region the story has opened (PhaseManager). Sorted by id.
static func destinations(from_id: StringName) -> Array[WhorlStoneDef]:
	var out: Array[WhorlStoneDef] = []
	for d in defs():
		if d.id != from_id and is_marked(d.id) and PhaseManager.is_region_unlocked(d.region_id):
			out.append(d)
	return out


## E at a marked pair: the card of stones to ride to, or her line when there
## is nowhere yet (only this mark, or the story holds her here).
static func open_card(tree: SceneTree, from: WhorlStoneDef, user: Node) -> void:
	if not can_travel():
		return
	var to := destinations(from.id)
	if to.is_empty():
		PickupLog.of(tree).note("My rose, beside the whorl. The only stones I've marked.")
		return
	WhorlTravelCard.open(tree, from, to, user)


## Rides to a pair: fade, put down by the stones, fade back. Returns the ride
## (a node under the root), or null when travel isn't allowed.
static func travel(tree: SceneTree, to: WhorlStoneDef) -> WhorlRide:
	if not can_travel() or to == null or not PhaseManager.is_region_unlocked(to.region_id):
		return null
	return WhorlRide.go(tree, to)

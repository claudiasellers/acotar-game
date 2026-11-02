## Which Act II scenes are coded, and where they hang (docs/contracts/act2.md).
##
## StoryDirector asks space_for() before it builds a generic MomentSpace for a
## moment, and calls attach() for every anchor it sees, which adds the scenes
## that have no data moment of their own (the arrival, Alis's welcome).
## Lanes building Act II scenes (L24, L25) each add their own rows here.
class_name Act2Spaces
extends RefCounted

## Moment id -> {"script": scene script, "stage": Act2Stage .tres}.
const CODED := {
	&"first_dinner": {"script": "res://story/act2/first_dinner.gd", "stage": "res://data/story/act2/first_dinner_stage.tres"},
	&"curtain_trap": {"script": "res://story/act2/curtain_trap.gd", "stage": "res://data/story/act2/curtain_trap_stage.tres"},
	# L25: the grounds' dangers (ch9-11).
	&"bogge": {"script": "res://story/act2/bogge_hunt.gd", "stage": "res://data/story/act2/bogge_stage.tres"},
	&"puca": {"script": "res://story/act2/puca_lure.gd", "stage": "res://data/story/act2/puca_stage.tres"},
	# L44: the wider court (ch18-19).
	&"starlight_pool": {"script": "res://story/act4/starlight_pool_swim.gd", "stage": "res://data/story/act4/starlight_pool_stage.tres"},
	&"attor": {"script": "res://story/act4/attor_in_the_garden.gd", "stage": "res://data/story/act4/attor_stage.tres"},
	# L45: Calanmai (ch20-22), docs/contracts/calanmai.md.
	&"calanmai_fires": {"script": "res://story/act5/calanmai/rite_fires.gd", "stage": "res://data/story/act5/rite_fires_stage.tres"},
	&"cave_mouth": {"script": "res://story/act5/calanmai/cave_path.gd", "stage": "res://data/story/act5/cave_path_stage.tres"},
	&"bite": {"script": "res://story/act5/calanmai/hallway_bite.gd", "stage": "res://data/story/act5/hallway_bite_stage.tres"},
	&"paintings_shown": {"script": "res://story/act5/calanmai/gown_dinner.gd", "stage": "res://data/story/act5/gown_dinner_stage.tres"},
}

## Anchor id -> list of {"name", "script", "stage"}: scenes with no moment.
const EXTRA := {
	&"manor_dining_table": [
		{"name": "ManorArrival", "script": "res://story/act2/manor_arrival.gd", "stage": "res://data/story/act2/manor_arrival_stage.tres"},
		# L45: lunch with the bruise bared, then dinner and the white roses (ch22).
		{"name": "BruiseLunch", "script": "res://story/act5/calanmai/bruise_lunch.gd", "stage": "res://data/story/act5/bruise_lunch_stage.tres"},
		{"name": "RoseDinner", "script": "res://story/act5/calanmai/rose_dinner.gd", "stage": "res://data/story/act5/rose_dinner_stage.tres"},
	],
	&"feyre_bedroom_window": [
		{"name": "AlisWelcome", "script": "res://story/act2/alis_welcome.gd", "stage": "res://data/story/act2/alis_welcome_stage.tres"},
		# L45: the bruise in her vanity mirror (ch22).
		{"name": "BruiseVanity", "script": "res://story/act5/calanmai/bruise_vanity.gd", "stage": "res://data/story/act5/bruise_vanity_stage.tres"},
	],
	# L45: the order to stay inside at dusk, and Lucien's account of the Rite after (ch20-21).
	&"manor_window_hide": [
		{"name": "FireNightOrder", "script": "res://story/act5/calanmai/fire_night_order.gd", "stage": "res://data/story/act5/fire_night_order_stage.tres"},
		{"name": "RiteExplained", "script": "res://story/act5/calanmai/rite_explained.gd", "stage": "res://data/story/act5/rite_explained_stage.tres"},
	],
	# L45: supper alone in the empty kitchen (ch21).
	&"manor_alis_hiding": [
		{"name": "KitchenSupper", "script": "res://story/act5/calanmai/kitchen_supper.gd", "stage": "res://data/story/act5/kitchen_supper_stage.tres"},
	],
}


static func coded_ids() -> PackedStringArray:
	return PackedStringArray(CODED.keys())


## The coded scene for a moment, or null when the generic MomentSpace plays it.
static func space_for(moment: StoryMoment) -> SceneSpace:
	if moment == null or not CODED.has(moment.id):
		return null
	var spec: Dictionary = CODED[moment.id]
	var space := _make(spec)
	if space == null:
		return null
	space.moment = moment
	return space


## Hangs the extra (moment-less) scenes for one anchor. Safe to call twice.
static func attach(anchor: Node3D) -> Array[SceneSpace]:
	var spaces: Array[SceneSpace] = []
	var anchor_id := StringName(anchor.get_meta(&"anchor_id", anchor.name))
	for spec: Dictionary in EXTRA.get(anchor_id, []):
		var node_name := String(spec["name"])
		var existing := anchor.get_node_or_null(node_name) as SceneSpace
		if existing:
			spaces.append(existing)
			continue
		var space := _make(spec)
		if space == null:
			continue
		space.name = node_name
		anchor.add_child(space)
		spaces.append(space)
	return spaces


static func _make(spec: Dictionary) -> Act2Space:
	var script := load(String(spec["script"])) as Script
	if script == null:
		push_error("Act2Spaces: can't load %s" % spec["script"])
		return null
	var space := script.new() as Act2Space
	if space == null:
		push_error("Act2Spaces: %s is not an Act2Space" % spec["script"])
		return null
	var stage_path := String(spec.get("stage", ""))
	if stage_path != "":
		space.stage = load(stage_path) as Act2Stage
	return space

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
}

## Anchor id -> list of {"name", "script", "stage"}: scenes with no moment.
const EXTRA := {
	&"manor_dining_table": [
		{"name": "ManorArrival", "script": "res://story/act2/manor_arrival.gd", "stage": "res://data/story/act2/manor_arrival_stage.tres"},
	],
	&"feyre_bedroom_window": [
		{"name": "AlisWelcome", "script": "res://story/act2/alis_welcome.gd", "stage": "res://data/story/act2/alis_welcome_stage.tres"},
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

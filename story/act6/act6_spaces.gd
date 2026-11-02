## P6 "The blight tightens" (ch 23-27, lane L46): the playable scenes around
## L33's two films (docs/contracts/blight.md). Same shape as Act2Spaces.EXTRA:
## StoryDirector calls attach() for every anchor it sees and these scenes hang
## there. They write facts only; the data moments (gen_moments.py) raise the
## deeds from those facts, and L33's films play glamour_lift and rhysand_visit.
class_name Act6Spaces
extends RefCounted

const STAGES := "res://data/story/act6/"

## Anchor id -> list of {"name", "script", "stage"}.
const ROWS := {
	# ch23: Tamlin takes her riding to a glen; the picnic before "Eyes Open".
	&"hall_mark_1": [
		{"name": "GlenInvite", "script": "res://story/act6/glen_invite.gd", "stage": "glen_invite_stage.tres"},
	],
	&"glamour_lift_glade": [
		{"name": "GlenPicnic", "script": "res://story/act6/glen_picnic.gd", "stage": "glen_picnic_stage.tres"},
		{"name": "EyesOpenWonders", "script": "res://story/act6/eyes_open_wonders.gd", "stage": "eyes_open_wonders_stage.tres"},
	],
	# ch24: Alis as she truly is, the morning after.
	&"feyre_bedroom_window": [
		{"name": "AlisTrueMorning", "script": "res://story/act6/alis_true_morning.gd", "stage": "alis_true_morning_stage.tres"},
	],
	# ch24: the head on the heron's bill, the morning after that.
	&"manor_fountain": [
		{"name": "FountainHead", "script": "res://story/act6/fountain_head.gd", "stage": "fountain_head_stage.tres"},
	],
}


## Hangs the P6 scenes for one anchor. Safe to call twice.
static func attach(anchor: Node3D) -> Array[SceneSpace]:
	var spaces: Array[SceneSpace] = []
	var anchor_id := StringName(anchor.get_meta(&"anchor_id", anchor.name))
	for spec: Dictionary in ROWS.get(anchor_id, []):
		var node_name := String(spec["name"])
		var existing := anchor.get_node_or_null(node_name) as SceneSpace
		if existing:
			spaces.append(existing)
			continue
		var script := load(String(spec["script"])) as Script
		var space := script.new() as Act2Space if script else null
		if space == null:
			push_error("Act6Spaces: can't build %s" % spec["script"])
			continue
		space.stage = load(STAGES + String(spec["stage"])) as Act2Stage
		space.name = node_name
		anchor.add_child(space)
		spaces.append(space)
	return spaces


## Every anchor P6 hangs a scene on (for the contract test).
static func anchor_ids() -> PackedStringArray:
	return PackedStringArray(ROWS.keys())

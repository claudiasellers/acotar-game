## Places the story in the world (docs/contracts/story_anchors.md).
##
## Every StoryMoment in data/story/moments/ names an anchor. Region lanes put
## a Marker3D named after that anchor, in group "story_anchor", in their region
## scene. When WorldStreamer loads the region, the director hangs a
## MomentSpace for each matching moment under the anchor. Moments with no
## anchor live under the director itself (they listen for deeds anywhere).
## Story state lives in WorldState flags, so a region can unload and reload
## at any time.
extends Node

const MOMENTS_DIR := "res://data/story/moments"

var moments: Array[StoryMoment] = []
var _by_anchor: Dictionary = {}  # anchor id -> Array[StoryMoment]
var _pending_anchor: StringName = &""


func _ready() -> void:
	load_moments(MOMENTS_DIR)
	WorldStreamer.region_loaded.connect(_on_region_loaded)
	EventBus.travel_requested.connect(_on_travel_requested)


func load_moments(dir_path: String) -> void:
	moments.clear()
	_by_anchor.clear()
	for child in get_children():
		child.queue_free()
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var moment := load("%s/%s" % [dir_path, clean]) as StoryMoment
		if moment == null:
			continue
		moments.append(moment)
		if moment.anchor_id == &"":
			add_child(_space_for(moment))
		else:
			if not _by_anchor.has(moment.anchor_id):
				_by_anchor[moment.anchor_id] = []
			_by_anchor[moment.anchor_id].append(moment)


func get_moment(id: StringName) -> StoryMoment:
	for moment in moments:
		if moment.id == id:
			return moment
	return null


## Anchor ids the story needs, for the contract and the region lanes' checks.
func anchor_ids() -> PackedStringArray:
	return PackedStringArray(_by_anchor.keys())


## Hangs the moments for one anchor under it. Safe to call twice.
func attach_anchor(anchor: Node3D) -> Array[MomentSpace]:
	var spaces: Array[MomentSpace] = []
	var anchor_id := StringName(anchor.get_meta(&"anchor_id", anchor.name))
	for moment: StoryMoment in _by_anchor.get(anchor_id, []):
		var existing := anchor.get_node_or_null(NodePath("Moment_%s" % moment.id)) as MomentSpace
		if existing:
			spaces.append(existing)
			continue
		var space := _space_for(moment)
		anchor.add_child(space)
		spaces.append(space)
	if anchor_id == _pending_anchor:
		_pending_anchor = &""
		var p := get_tree().get_first_node_in_group(&"player") as Node3D
		if p:
			p.global_position = anchor.global_position + Vector3.UP * 0.2
	return spaces


## Attaches every anchor found under a node (a loaded region, a test scene).
func attach_all(root: Node) -> int:
	var count := 0
	for anchor in root.get_tree().get_nodes_in_group(&"story_anchor"):
		if anchor is Node3D and (root == anchor or root.is_ancestor_of(anchor)):
			count += attach_anchor(anchor).size()
	return count


func _space_for(moment: StoryMoment) -> MomentSpace:
	var space := MomentSpace.new()
	space.name = "Moment_%s" % moment.id
	space.moment = moment
	return space


func _on_region_loaded(_region_id: StringName, root: Node3D) -> void:
	attach_all(root)


## Carriage home, ride back: move Feyre into the region and stream it in.
func _on_travel_requested(region_id: StringName, anchor_id: StringName) -> void:
	var region := WorldStreamer.get_region(region_id)
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if region == null or p == null:
		return
	p.global_position = region.center + Vector3.UP * 2.0
	_pending_anchor = anchor_id
	WorldStreamer.update_for(region.center)

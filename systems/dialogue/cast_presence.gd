## Puts the cast where the book has them in free roam (lane L34), so there is
## someone to talk to as Feyre passes through: her family in the cottage, the
## villagers at market, Alis, Lucien and Tamlin about the manor, sentries at
## the border, and the masked household and court folk once she can see them.
##
## Spots are keyed to phase, flags and hour only (data/dialogue/presence.tres,
## Keeper-checked roster) and never write WorldState. A spot spawns while its
## region is loaded and Feyre is within SPAWN_DIST, and goes when she leaves or
## it stops fitting. Tamlin, Lucien and Alis step aside while any staged scene
## runs or the story has spawned its own actor for them, so they never double.
## Nesta, Elain and their father stay for the beast scene (it gathers them).
class_name CastPresence
extends Node

const ROSTER_PATH := "res://data/dialogue/presence.tres"
const TICK := 1.0
const SPAWN_DIST := 90.0
const DESPAWN_DIST := 130.0
## Cast who leave the stage to a scene's own actor.
const STAGED := [&"tamlin", &"lucien", &"alis"]
const CAST_MODEL := "res://characters/%s/%s_model.tscn"

@export var roster: PresenceRoster
## Tests turn this off and call step() directly.
var auto_tick: bool = true
## spot id -> spawned node.
var spawned: Dictionary = {}

var _t: float = 0.0
var _scene_count: int = 0
var _house: Node3D
var _rooms: Dictionary = {}


func _init() -> void:
	name = "CastPresence"


func _ready() -> void:
	if roster == null and ResourceLoader.exists(ROSTER_PATH):
		roster = load(ROSTER_PATH) as PresenceRoster
	EventBus.scene_space_started.connect(func(_id: StringName) -> void: _scene_count += 1)
	EventBus.scene_space_finished.connect(func(_id: StringName) -> void: _scene_count = maxi(_scene_count - 1, 0))


func _process(delta: float) -> void:
	if not auto_tick:
		return
	_t += delta
	if _t < TICK:
		return
	_t = 0.0
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre:
		step(feyre.global_position)


## Spawns and clears spots for Feyre at `at`.
func step(at: Vector3) -> void:
	if roster == null:
		return
	var loaded := WorldStreamer.loaded_ids()
	for spot in roster.spots:
		var node: Node3D = spawned.get(spot.id)
		if node != null and not is_instance_valid(node):
			spawned.erase(spot.id)
			node = null
		var want := fits(spot) and (loaded.is_empty() or loaded.has(String(spot.region)) or spot.region == &"")
		var where := Vector3.INF
		if want:
			where = world_position(spot)
			want = where != Vector3.INF
		if want:
			var d := Vector2(where.x, where.z).distance_to(Vector2(at.x, at.z))
			want = d <= (DESPAWN_DIST if node else SPAWN_DIST)
		if want and node == null:
			_spawn(spot, where)
		elif not want and node != null:
			node.queue_free()
			spawned.erase(spot.id)


## Phase, flags, hour, and the staging rule.
func fits(spot: PresenceSpot) -> bool:
	if not spot.phases.is_empty() and not spot.phases.has(String(PhaseManager.current_phase)):
		return false
	if not spot.fits_hour(Clock.hour()):
		return false
	for f in spot.require_flags:
		if not WorldState.has_flag(f):
			return false
	for f in spot.forbid_flags:
		if WorldState.has_flag(f):
			return false
	if spot.speaker in STAGED:
		if _scene_count > 0 or StoryControl.mode != StoryControl.Mode.FULL:
			return false
		if is_inside_tree() and get_tree().get_first_node_in_group(StringName("story_actor_%s" % spot.speaker)) != null:
			return false
	return true


## Where a spot stands in the world, or Vector3.INF while that can't be known
## (the house or the anchor isn't loaded).
func world_position(spot: PresenceSpot) -> Vector3:
	if spot.room != &"":
		var house := _find_house()
		var room := _room(spot.room)
		if house == null or room.is_empty():
			return Vector3.INF
		return house.to_global(Vector3(spot.at.x, ManorHouseBuilder.floor_y(int(room["level"])), spot.at.y))
	if spot.anchor != &"":
		var anchor := _find_anchor(spot.anchor)
		if anchor == null:
			return Vector3.INF
		return _ground(anchor.global_transform * Vector3(spot.at.x, 0.0, spot.at.y))
	return _ground(Vector3(spot.at.x, WorldHeight.height_at(spot.at.x, spot.at.y), spot.at.y))


func _spawn(spot: PresenceSpot, where: Vector3) -> void:
	var node: Node3D
	var path := spot.scene
	if path == "" or not ResourceLoader.exists(path):
		path = CAST_MODEL % [spot.speaker, spot.speaker]
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if path.begins_with("res://characters/"):
		node = PresenceActor.make(spot.speaker, scene)
	else:
		node = scene.instantiate() as Node3D
		if node is CourtNpc:
			(node as CourtNpc).wander_radius = spot.wander
		node.set_meta(&"speaker", spot.speaker)
		node.add_to_group(DialogueDirector.PRESENCE_GROUP)
	node.name = "Presence_%s" % spot.id
	node.set_meta(&"presence_spot", spot.id)
	add_child(node)
	node.global_position = where
	node.rotation.y = deg_to_rad(spot.yaw_deg)
	if node is FamilyMember:
		# Their routine spots don't exist in the cottage; they keep to this one
		# until a scene cue moves them.
		(node as FamilyMember).set_scripted(true)
		(node as FamilyMember).go_to(where)
	if node is CourtNpc:
		(node as CourtNpc).home = where
	spawned[spot.id] = node


## Drops a point onto whatever floor is under it (cottage boards, terrain).
func _ground(p: Vector3) -> Vector3:
	if not is_inside_tree():
		return p
	var world := get_viewport().world_3d if get_viewport() else null
	if world == null:
		return p
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 4.0)
	var hit := world.direct_space_state.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


func _find_house() -> Node3D:
	if _house != null and is_instance_valid(_house) and _house.is_inside_tree():
		return _house
	_house = null
	for id in ["manor_dining_table", "hall_mark_1", "manor_infirmary", "manor_gallery"]:
		var a := _find_anchor(StringName(id))
		if a:
			_house = a.get_parent() as Node3D
			break
	return _house


func _find_anchor(anchor_id: StringName) -> Node3D:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(node.get_meta(&"anchor_id", node.name)) == anchor_id:
			return node as Node3D
	return null


func _room(id: StringName) -> Dictionary:
	if _rooms.is_empty():
		for r in HallMap.load_rooms():
			if not _rooms.has(r["id"]):
				_rooms[r["id"]] = r
	return _rooms.get(id, {})

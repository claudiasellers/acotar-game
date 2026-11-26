## Base for every wayside spot's node: knows its WaysideSpot, the director,
## whether it was found, and the shared beats (Feyre's thought on the find
## card, items into the satchel with sparkle + chime + bounce, a sketch).
## Kinds that take the interact key join group "station" (Interactor ranks
## them with everything else in reach) and name their verb through use_verb.
class_name WaysideSpotNode
extends Node3D

const PROMPT_RADIUS := 3.0

var spot: WaysideSpot
var director: Wayside



## Override: build the meshes. Called once, inside the tree.
func build() -> void:
	pass


const GROUP := &"wayside_spot"


func _ready() -> void:
	add_to_group(GROUP)
	build()


## Feyre (the director's target or the "player" group).
func player() -> Node3D:
	if director:
		return director._who()
	return get_tree().get_first_node_in_group(&"player") as Node3D


func flat_distance_to_player() -> float:
	var p := player()
	if p == null:
		return INF
	return Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()


func player_speed() -> float:
	var p := player()
	if p is CharacterBody3D:
		var v := (p as CharacterBody3D).velocity
		return Vector2(v.x, v.z).length()
	return 0.0


func found() -> bool:
	return Wayside.is_found(spot.id)


## Records the find, says the line, hands over the items. Returns the items given.
func complete(value: Variant = true, line_override: String = "") -> PackedStringArray:
	Wayside.mark_found(spot.id, value)
	var text := line_override if line_override != "" else spot.line
	if text != "" and is_inside_tree():
		PickupLog.of(get_tree()).note(text)
	var given := give(spot.items)
	var sketch: String = spot.param("sketch", "")
	if sketch != "":
		Gameplay.sketchbook.add(StringName("wayside_%s" % spot.id), sketch)
	if director:
		director.spot_found.emit(spot.id, spot.kind)
	return given


func give(items: PackedStringArray) -> PackedStringArray:
	var given := PackedStringArray()
	for id in items:
		if Gameplay.inventory.add(StringName(id), 1) > 0:
			given.append(id)
			var item := ItemCatalog.get_item(StringName(id))
			if is_inside_tree():
				Juice.pickup(self, player(), item.color if item else Color(1, 0.9, 0.95), item != null and item.is_rare())
	return given


## Interactor's reach for a kind with the interact key, and what the use
## prompt says there (Interactor reads both).
var use_reach: float = PROMPT_RADIUS
var use_verb: String:
	get:
		return prompt_verb() if shows_prompt() else ""


## The verb a kind's prompt says; kinds say their own.
func prompt_verb() -> String:
	return "look closer"


## Whether the prompt names E here: until it is found; a kind that is used
## again and again (the snare) says so always.
func shows_prompt() -> bool:
	return not found()


## A model under this node: a CourtAssets id (the court's model library) or
## a res:// path to a .glb/.gltf (its first mesh, with its own materials).
func add_model(asset: StringName, at: Vector3 = Vector3.ZERO, yaw: float = 0.0, scale_by: float = 1.0) -> MeshInstance3D:
	var mesh := model_mesh(asset)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if not String(asset).begins_with("res://"):
		var mat := CourtAssets.material_for(asset)
		if mat:
			mi.material_override = mat
	mi.position = at
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scale_by
	add_child(mi)
	return mi


static var _path_meshes := {}


static func model_mesh(asset: StringName) -> Mesh:
	var s := String(asset)
	if not s.begins_with("res://"):
		return CourtAssets.mesh(asset) if CourtAssets.has_model(asset) else null
	if _path_meshes.has(s):
		return _path_meshes[s]
	var mesh: Mesh = null
	var packed := load(s) as PackedScene
	if packed:
		var root := packed.instantiate()
		var mi := _first_mesh(root)
		if mi:
			mesh = mi.mesh
		root.free()
	_path_meshes[s] = mesh
	return mesh


static func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return node
	for c in node.get_children():
		var m := _first_mesh(c)
		if m:
			return m
	return null


## Ground height at a world x/z (the terrain matches WorldHeight by contract).
static func ground(x: float, z: float) -> float:
	return WorldHeight.height_at(x, z)

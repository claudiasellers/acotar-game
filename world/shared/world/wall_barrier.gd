## The Wall stops Feyre (T107). She can walk up to it and see through it (the
## shimmer stays see-through), but she can't walk, ride, climb or tunnel across:
## in Act 1 she stays in the human realm, once the Beast has taken her she stays
## in Prythian. The only crossings are the story's own (the ride north, Return
## Home, later chapters' travel), which move her with her physics off, under
## story control or by teleport, and those all still work.
##
## Two parts, both owned by World (never streamed):
## - a tall, thin invisible slab along z = WALL_Z on ActorBody.LAYER: Feyre and
##   the mare mask that layer, so they slide along it; the camera's spring arm,
##   floor and ledge rays only mask the world layer, so they ignore it;
## - a guard for whatever gets past the slab (a mantle tween, a fast frame, a
##   short placement): a free-moving watched body that ends a physics frame on
##   the other side of the line by a small step goes back to her own side.
class_name WallBarrier
extends Node3D

signal stopped(body: Node3D)

## Bodies the guard watches besides Feyre (group "player"): the mare.
const GROUP := &"wall_bound"
const PLAYER_GROUP := &"player"
## A move longer than this in one physics frame is a teleport (story travel,
## Return Home, a load), never walking or riding.
const TELEPORT_STEP := 20.0
const THICKNESS := 1.0
const HEIGHT := 2000.0

## A later story beat can open the Wall outright (both parts off).
var open := false:
	set(value):
		open = value
		if _body:
			_body.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
		_last.clear()

var _body: StaticBody3D
var _last := {}


func _ready() -> void:
	name = "WallBarrier"
	_body = StaticBody3D.new()
	_body.name = "Slab"
	_body.collision_layer = ActorBody.LAYER
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WorldMap.MAP_RECT.size.x, HEIGHT, THICKNESS)
	shape.shape = box
	_body.add_child(shape)
	add_child(_body)
	_body.global_position = Vector3(WorldMap.MAP_RECT.get_center().x, HEIGHT * 0.25, WorldMap.WALL_Z)
	open = open


func _physics_process(_delta: float) -> void:
	if open:
		return
	var seen := {}
	for body in _watched():
		var id := body.get_instance_id()
		seen[id] = true
		var p := body.global_position
		if _last.has(id):
			var prev: Vector3 = _last[id]
			if is_free(body) and crossed(prev, p):
				_send_back(body, prev)
				continue
		_last[id] = p
	for id: int in _last.keys():
		if not seen.has(id):
			_last.erase(id)


## True when a frame's move from `prev` to `now` walked across the line (not a
## teleport).
static func crossed(prev: Vector3, now: Vector3) -> bool:
	return WorldMap.is_in_prythian(prev) != WorldMap.is_in_prythian(now) \
			and prev.distance_to(now) < TELEPORT_STEP


## The player moving herself (or the mare she rides): physics on and, for
## Feyre, not held by a story scene. The ride north turns her physics off.
static func is_free(body: Node3D) -> bool:
	if not body.is_physics_processing():
		return false
	if body.is_in_group(PLAYER_GROUP):
		return StoryControl.can_move()
	return true


func _watched() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for group in [PLAYER_GROUP, GROUP]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node3D and not out.has(n):
				out.append(n as Node3D)
	return out


## Same x and height, back on the side she came from (so she slides along).
func _send_back(body: Node3D, prev: Vector3) -> void:
	var at := Vector3(body.global_position.x, body.global_position.y, prev.z)
	if body.get(&"is_mantling") == true and body.has_method(&"teleport"):
		body.call(&"teleport", at)  # also ends the climb tween
	else:
		body.global_position = at
	if body is CharacterBody3D:
		var b := body as CharacterBody3D
		b.velocity.z = 0.0
	_last[body.get_instance_id()] = at
	stopped.emit(body)

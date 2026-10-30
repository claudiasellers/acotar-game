## The cottage's front door swings in as Feyre comes up to it and shuts again
## behind her, so she can walk in to the hearth and the bed (plans/act1-fixlist.md
## F13: the intact door's collision blocked the way and nothing opened it).
## Hung on the act1_cottage_door anchor; turns the world lane's
## CottageDoor/IntactState (mesh and collider together) about its hinge edge.
## Shut while the beast is at the door: he breaks it (fact.cottage_door_broken).
class_name CottageDoorLatch
extends Node3D

const OPEN_RADIUS := 2.4
const CLOSE_RADIUS := 4.0
const CLOSE_AFTER := 1.5
const SWING_SECONDS := 0.5
## Inward, toward the room (+Z of the cottage).
const OPEN_ANGLE := deg_to_rad(-95.0)
## The door leaf's hinge side in the door's own space (cottage_door_intact.glb
## spans x -0.474..0.474).
const HINGE := Vector3(-0.474, 0.0, -0.06)

var leaf: Node3D
var is_open: bool = false
var _closed_xform: Transform3D
var _far_for: float = 0.0
var _tween: Tween


func _ready() -> void:
	name = "CottageDoorLatch"
	leaf = find_leaf(get_parent())
	if leaf:
		_closed_xform = leaf.transform


## CottageDoor/IntactState beside the anchor (anchor -> Interior -> cottage).
static func find_leaf(anchor: Node) -> Node3D:
	var cottage := anchor.get_parent().get_parent() if anchor and anchor.get_parent() else null
	return cottage.get_node_or_null(^"CottageDoor/IntactState") as Node3D if cottage else null


func _physics_process(delta: float) -> void:
	if leaf == null or not is_instance_valid(leaf):
		return
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	var beast_here := false
	for door in get_tree().get_nodes_in_group(BeastDoor.GROUP):
		beast_here = beast_here or (door as BeastDoor).running
	var d := INF
	if feyre:
		d = feyre.global_position.distance_to(leaf.get_parent().global_position)
	if beast_here:
		set_open(false)
	elif d <= OPEN_RADIUS:
		_far_for = 0.0
		set_open(true)
	elif d >= CLOSE_RADIUS:
		_far_for += delta
		if _far_for >= CLOSE_AFTER:
			set_open(false)


func set_open(open: bool) -> void:
	if open == is_open or leaf == null:
		return
	is_open = open
	var target := _closed_xform
	if open:
		var pivot := _closed_xform * HINGE
		target = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis(Vector3.UP, OPEN_ANGLE), Vector3.ZERO) \
				* Transform3D(Basis.IDENTITY, -pivot) * _closed_xform
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(leaf, ^"transform", target, SWING_SECONDS)

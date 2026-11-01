## Lucien at the hall table (ch 17 [C]): he can't bear it. He backs away,
## doubles over and retches, then walks out through the front doors and is
## gone. Driven by the triage's clock (tick), so tests can run it.
## A rigged figure's PersonAnimator (creature_motion.md) gets a `flinch` for
## the retch and plays its walk from the ground speed; a stand-in just moves.
class_name LucienExit
extends RefCounted

enum Stage { BACK, RETCH, WALK, GONE }

const BACK_METRES := 1.6
const BACK_SPEED := 1.1
const RETCH_SECONDS := 2.2
## How far he leans over the retch (radians, the whole figure about his feet).
const RETCH_BEND := 0.3
const WALK_SPEED := 1.6

var lucien: Node3D
var stage: Stage = Stage.BACK
var door: Vector3
var _back_to: Vector3
var _t: float = 0.0
var _model: Node3D


## `away_from`: the table he backs away from; `door_at`: where he leaves (world).
func _init(node: Node3D, away_from: Vector3, door_at: Vector3) -> void:
	lucien = node
	door = door_at
	var p := node.global_position
	var away := Vector3(p.x - away_from.x, 0.0, p.z - away_from.z)
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	_back_to = p + away * BACK_METRES
	_face(away_from)  # backing away, eyes still on the table
	_model = node


func tick(delta: float) -> void:
	if lucien == null or not is_instance_valid(lucien) or stage == Stage.GONE:
		return
	_t += delta
	match stage:
		Stage.BACK:
			if _move_to(_back_to, BACK_SPEED, delta):
				stage = Stage.RETCH
				_t = 0.0
				var anim := lucien.find_child("PersonAnimator", true, false)
				if anim and anim.has_method(&"gesture"):
					anim.call(&"gesture", &"flinch")
		Stage.RETCH:
			if _model:
				_model.rotation.x = RETCH_BEND * sin(clampf(_t / RETCH_SECONDS, 0.0, 1.0) * PI)
			if _t >= RETCH_SECONDS:
				if _model:
					_model.rotation.x = 0.0
				stage = Stage.WALK
				_face(door, true)
		Stage.WALK:
			_face(door, true)
			if _move_to(door, WALK_SPEED, delta):
				lucien.visible = false
				stage = Stage.GONE


func gone() -> bool:
	return stage == Stage.GONE


func _move_to(target: Vector3, speed: float, delta: float) -> bool:
	var p := lucien.global_position
	var to := Vector3(target.x - p.x, 0.0, target.z - p.z)
	var step := speed * delta
	if to.length() <= step:
		lucien.global_position = Vector3(target.x, p.y, target.z)
		return true
	lucien.global_position = p + to.normalized() * step
	return false


## Turns him to face a point (or the way he walks).
func _face(at: Vector3, _walking: bool = false) -> void:
	var p := lucien.global_position
	var d := Vector3(at.x - p.x, 0.0, at.z - p.z)
	if d.length() > 0.05 and lucien.is_inside_tree():
		lucien.look_at(p + d, Vector3.UP, true)

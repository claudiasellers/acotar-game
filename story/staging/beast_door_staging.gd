## The beast at the door, staged like a film (lane L22). A child of the
## BeastDoor space (one line in beast_door.gd). It moves only the camera:
## the scene keeps every StoryControl mode and the decision window's actions.
##
## - The door bursts: a cut behind Feyre's shoulder at the doorway, full bars,
##   (the scene's own tremble carries into every shot).
## - "It fills the room": a low angle at her side looking up at his head with a
##   slow push, so he is too big for the frame.
## - The window (knife or bracelets): her own view, through a tighter lens
##   with half bars, so she can throw.
## - The father pleads: a two-shot of the beast and her father from her side
##   of the room.
## - The ash arrow snapped: close on the beast's head from her eye line.
## - The scene ends: eased back to her camera, bars out.
## Any shot whose line is blocked (a wall, a beam) falls back to her own view
## through a tighter lens.
class_name BeastDoorStaging
extends Node

const DOOR_FOV := 50.0
const LOW_FOV := 38.0
const WINDOW_FOV := 55.0
const TWO_SHOT_FOV := 44.0
const CLOSE_FOV := 30.0
const PLEAD_DELAY := 0.8
const RELEASE := 1.6

var space: Node
## The last shot taken: &"", &"door", &"low", &"window", &"plead", &"close", &"released".
var shot_name: StringName = &""


func _ready() -> void:
	space = get_parent()
	EventBus.story_actor_cue.connect(_on_cue)
	EventBus.scene_space_finished.connect(_on_space_finished)
	StoryControl.focus_changed.connect(_on_focus)


func _running() -> bool:
	return space != null and bool(space.get(&"running"))


func _beast() -> Node3D:
	var b: Variant = space.get(&"beast") if space else null
	if b is Node3D and is_instance_valid(b):
		return b
	return get_tree().get_first_node_in_group(&"beast") as Node3D


func _feyre() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _father() -> Node3D:
	for n in get_tree().get_nodes_in_group(&"family"):
		if StringName(n.get(&"member_id")) == &"father":
			return n as Node3D
	return null


func _on_cue(actor: StringName, cue: StringName) -> void:
	if not _running():
		return
	match [actor, cue]:
		[&"tamlin_beast", &"enter"]:
			_door_bursts.call_deferred()
		[&"father", &"plead"], [&"family", &"plead"]:
			_plead()
		[&"tamlin_beast", &"snap_ash_arrow"]:
			_close()


func _on_focus(target: Node3D) -> void:
	if _running() and target != null and target == _beast() and shot_name == &"door":
		_low()


## The decision window opens (LOOK with the throw allowed; the mode itself
## does not change, so it is watched here): she needs her own view to throw.
func _process(_delta: float) -> void:
	if shot_name in [&"door", &"low"] and _running() and StoryControl.mode == StoryControl.Mode.LOOK \
			and StoryControl.allowed_actions.has("fire"):
		shot_name = &"window"
		var cine := _cine()
		cine.follow(WINDOW_FOV, 0.4)
		cine.bars_to(0.5, 0.4)


func _on_space_finished(space_id: StringName) -> void:
	var own: Variant = space.get(&"space_id") if space else null
	if shot_name == &"" or shot_name == &"released" or (own != null and StringName(own) != space_id):
		return
	shot_name = &"released"
	Cine.of(get_tree()).drop(self, RELEASE)


func _door_bursts() -> void:
	var beast := _beast()
	var feyre := _feyre()
	if beast == null or feyre == null:
		return
	shot_name = &"door"
	var cine := _cine()
	cine.bars_to(1.0, 0.25)
	var head := func() -> Vector3: return _head(beast)
	var spot := _spot(_eyeline(feyre, beast, 1.1, 1.55), head.call(), [beast, feyre])
	if spot != Vector3.INF:
		cine.shot(_look(spot, head.call()), DOOR_FOV, 0.0, head)
	else:
		cine.follow(DOOR_FOV, 0.2)


func _low() -> void:
	var beast := _beast()
	var feyre := _feyre()
	if beast == null or feyre == null:
		return
	shot_name = &"low"
	var head := func() -> Vector3: return _head(beast)
	var to := Vector3(beast.global_position.x - feyre.global_position.x, 0.0, beast.global_position.z - feyre.global_position.z)
	var dir := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP).normalized()
	var low := feyre.global_position + Vector3.UP * 0.7
	var spot := _spot([low + dir * 0.8 + right * 0.9, low + dir * 0.8 - right * 0.9, low + dir * 1.6,
			beast.global_position - dir * 2.2 + Vector3.UP * 0.6], head.call(), [beast, feyre])
	var cine := _cine()
	if spot != Vector3.INF:
		cine.shot(_look(spot, head.call()), LOW_FOV, 0.0, head, 0.5, 2.5)
	else:
		cine.follow(LOW_FOV + 6.0, 0.4)


func _plead() -> void:
	await get_tree().create_timer(PLEAD_DELAY, true, false, true).timeout
	if not _running():
		return
	var beast := _beast()
	var father := _father()
	var feyre := _feyre()
	if beast == null or father == null or feyre == null:
		return
	shot_name = &"plead"
	var head := _head(beast)
	var a := father.global_position + Vector3.UP * 1.2
	# From the side of the line her own eyes are on.
	var side := signf((feyre.global_position - beast.global_position).cross(father.global_position - beast.global_position).y)
	side = side if side != 0.0 else 1.0
	var mid := func() -> Vector3: return (_head(beast) + father.global_position + Vector3.UP * 1.2) * 0.5
	var cine := _cine()
	cine.bars_to(1.0, 0.4)
	for s in [-side, side]:
		var spot := Cine.two_shot(a, head, s, TWO_SHOT_FOV, 1.4)
		if _clear(spot, head, [beast, father, feyre]) and _clear(spot, a, [beast, father, feyre]):
			cine.shot(_look(spot, mid.call()), TWO_SHOT_FOV, 0.0, mid, 0.3, 4.0)
			return
	cine.follow(TWO_SHOT_FOV + 6.0, 0.5)


func _close() -> void:
	var beast := _beast()
	var feyre := _feyre()
	if beast == null or feyre == null:
		return
	shot_name = &"close"
	var head := func() -> Vector3: return _head(beast)
	var spot := _spot(_eyeline(feyre, beast, 0.5, 1.6), head.call(), [beast, feyre])
	var cine := _cine()
	cine.bars_to(1.0, 0.3)
	if spot != Vector3.INF:
		cine.shot(_look(spot, head.call()), CLOSE_FOV, 0.0, head, 0.2, 1.5)
	else:
		cine.follow(CLOSE_FOV + 10.0, 0.3)


## Spots on her side of him that might see him, best first: over either
## shoulder, her own eyes, then just inside the doorway on her line to him.
func _eyeline(feyre: Node3D, beast: Node3D, back: float, up: float) -> Array[Vector3]:
	var f := feyre.global_position
	var b := beast.global_position
	var flat := Vector3(b.x - f.x, 0.0, b.z - f.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	return [Cine.over_shoulder(f, b, back, 0.45, up), Cine.over_shoulder(f, b, back, -0.45, up),
			f + Vector3.UP * up, Vector3(b.x, f.y, b.z) - dir * minf(2.4, flat.length() * 0.6) + Vector3.UP * up]


## The first of `spots` that sees `target` past walls and beams; INF for none.
func _spot(spots: Array[Vector3], target: Vector3, ignore: Array) -> Vector3:
	for s in spots:
		if _clear(s, target, ignore):
			return s
	return Vector3.INF


func _look(from: Vector3, at: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(at - from, Vector3.UP), from)


func _clear(from: Vector3, to: Vector3, ignore: Array) -> bool:
	var exclude: Array[RID] = []
	for n in ignore:
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
		for body in (n as Node).find_children("*", "CollisionObject3D", true, false):
			exclude.append((body as CollisionObject3D).get_rid())
	return Cine.sees((ignore[0] as Node3D).get_world_3d(), from, to, exclude)


## His head: a bone named like one on his skeleton, else high on his body.
func _head(beast: Node3D) -> Vector3:
	if not is_instance_valid(beast):
		return Vector3.ZERO
	for sk in beast.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower().ends_with("head"):
				return skel.global_transform * skel.get_bone_global_pose(i).origin
	return beast.global_position + Vector3.UP * 2.0



## The film camera, taken for this scene's next move.
func _cine() -> Cine:
	var cine := Cine.of(get_tree())
	cine.claim(self)
	return cine

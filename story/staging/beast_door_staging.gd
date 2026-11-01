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
## Longest wait for him to stand still before the low shot.
const SETTLE_MAX := 1.6
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
	if is_instance_valid(b) and b is Node3D:
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
		cine.bars_to(0.5, 0.4)
		var beast := _beast()
		var feyre := _feyre()
		var spot := Vector3.INF
		if beast and feyre:
			spot = _spot(_eyeline(feyre, beast, 1.3, 1.6), _head(beast), [beast, feyre], beast)
		if spot != Vector3.INF:
			# Over her shoulder at him: her hands, his face.
			var head := func() -> Vector3: return _head(beast)
			cine.shot(_look(spot, head.call()), WINDOW_FOV, 0.4, head)
		else:
			cine.follow(WINDOW_FOV, 0.4)


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
	# Inside the room, facing the door he comes through.
	var door_v: Variant = beast.get(&"door") if &"door" in beast else null
	var door: Node3D = door_v if is_instance_valid(door_v) and door_v is Node3D else null
	var spots: Array[Vector3] = []
	var at := head.call() as Vector3
	if door:
		var inward := -door.global_basis.z
		inward.y = 0.0
		inward = inward.normalized()
		var right := inward.cross(Vector3.UP).normalized()
		var floor_y := feyre.global_position.y
		at = Vector3(door.global_position.x, floor_y + 1.3, door.global_position.z)
		for d in [4.2, 3.4, 2.6]:
			for sd in [0.9, -0.9, 0.0]:
				var p: Vector3 = door.global_position + inward * d + right * sd
				spots.append(Vector3(p.x, floor_y + 1.35, p.z))
	spots.append_array(_eyeline(feyre, beast, 1.1, 1.55))
	var spot := _spot(spots, at, [beast, feyre], beast)
	if spot != Vector3.INF:
		cine.shot(_look(spot, at), DOOR_FOV, 0.0, head)
	else:
		cine.follow(DOOR_FOV, 0.2)


func _low() -> void:
	shot_name = &"low"
	# He is still bursting in when the scene turns to him: hold the door shot
	# (it tracks him through) until he stands, then cut low in front of him.
	var waited := 0.0
	var still := 0.0
	var beast := _beast()
	while beast and waited < SETTLE_MAX:
		var was := beast.global_position
		await get_tree().process_frame
		var dt := get_process_delta_time()
		waited += dt
		beast = _beast()
		if beast == null or shot_name != &"low":
			return
		# Still for a quarter second, and not before he has had time to start.
		still = still + dt if beast.global_position.distance_to(was) < 0.01 else 0.0
		if still >= 0.25 and waited >= 0.5:
			break
	var feyre := _feyre()
	if beast == null or feyre == null:
		return
	var head := func() -> Vector3: return _head(beast)
	var to := Vector3(beast.global_position.x - feyre.global_position.x, 0.0, beast.global_position.z - feyre.global_position.z)
	var dir := to.normalized() if to.length() > 0.01 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP).normalized()
	var floor_y := feyre.global_position.y
	var fwd := -beast.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else -dir
	var side := fwd.cross(Vector3.UP).normalized()
	var spots: Array[Vector3] = []
	# In front of him and low, looking up into his face; then her side of him.
	for sd in [1.1, -1.1, 0.5]:
		var p: Vector3 = beast.global_position + fwd * 2.4 + side * sd
		spots.append(Vector3(p.x, floor_y + 0.6, p.z))
	var low := feyre.global_position + Vector3.UP * 0.6
	spots.append_array([low + dir * 0.6 + right * 0.9, low + dir * 0.6 - right * 0.9, low - dir * 0.5])
	var spot := _spot(spots, head.call(), [beast, feyre], beast)
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
		if _clear(spot, head, [beast, father, feyre]) and _clear(spot, a, [beast, father, feyre]) \
				and _free_at(spot, [beast, father, feyre], beast):
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
	var h := head.call() as Vector3
	var fwd := -beast.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var side := fwd.cross(Vector3.UP).normalized()
	# Close on his face, a little off his eye line; then over her shoulder.
	var spots: Array[Vector3] = [h + fwd * 1.8 + side * 0.5, h + fwd * 1.8 - side * 0.5, h + fwd * 2.4]
	spots.append_array(_eyeline(feyre, beast, 0.9, 1.6))
	var spot := _spot(spots, h, [beast, feyre], beast)
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


## The first of `spots` that sees `target` past walls and beams, has room for
## the lens (not inside a wall, a beam or him); INF for none.
func _spot(spots: Array[Vector3], target: Vector3, ignore: Array, beast: Node3D) -> Vector3:
	for s in spots:
		if _clear(s, target, ignore) and _free_at(s, ignore, beast):
			return s
	return Vector3.INF


## Room for the camera at `spot`: no collider within a hand's breadth, and
## out of his body (his collision is excluded from the rays, his mesh is not).
func _free_at(spot: Vector3, ignore: Array, beast: Node3D) -> bool:
	if beast:
		var b := beast.global_position
		if Vector2(spot.x - b.x, spot.z - b.z).length() < 1.4 or spot.distance_to(_head(beast)) < 1.3:
			return false
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.25
	q.shape = ball
	q.transform = Transform3D(Basis.IDENTITY, spot)
	var exclude: Array[RID] = []
	for n in ignore:
		if n is CollisionObject3D:
			exclude.append((n as CollisionObject3D).get_rid())
		for body in (n as Node).find_children("*", "CollisionObject3D", true, false):
			exclude.append((body as CollisionObject3D).get_rid())
	q.exclude = exclude
	return (ignore[0] as Node3D).get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


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

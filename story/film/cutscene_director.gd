## Stages one cutscene in the game world (lane L33): a child of the FilmPlayer
## made by `Films.play(space, id)`. Each beat `<name>` of the film calls this
## director's `_b_<name>()` when it has one ("fact.x.y" beats call `_b_x_y`).
##
## Everything is placed in the story moment's own frame (`at(local)`), the
## anchor the moment hangs on, so a scene plays wherever its region put it.
## The director owns the camera (Cine), the cast's poses (FilmPose) and the
## props it adds; when the film ends, however it ends, it takes its props
## away, lets the cast go, puts Feyre where play resumes and eases back into
## her camera. Contract: docs/contracts/film.md.
class_name CutsceneDirector
extends Node

## Feyre's own shot at the hand-over: behind her right shoulder.
const HANDOVER_BLEND := 2.0

var space: Node3D
## The frame every `local` point is in: the moment's anchor by default, the
## manor house's own layout frame after `use_house()`.
var frame: Transform3D
var player: FilmPlayer
var cine: Cine
var feyre: Node3D
var grade: FilmGrade
var props: Array[Node] = []
var _done: bool = false
var _posed: Array = []   # [FilmPose]


func _ready() -> void:
	cine = Cine.of(get_tree())
	feyre = get_tree().get_first_node_in_group(&"player") as Node3D
	player.beat.connect(_on_beat)
	player.finished.connect(_on_finished)
	player.take_input_lead()
	var scene := get_tree().current_scene
	if scene:
		player.hide_ui_of(scene)
	grade = FilmGrade.new()
	player.add_child(grade)
	frame = space.global_transform if space else Transform3D()
	_setup()


## Builds the set and places the cast before the first frame (override).
func _setup() -> void:
	pass


## Puts Feyre where play resumes, after the film (override).
func _end_mark() -> Transform3D:
	return feyre.global_transform if feyre else Transform3D()


func _on_beat(beat_name: StringName) -> void:
	if _done:
		return
	var m := "_b_" + String(beat_name).trim_prefix("fact.").replace(".", "_")
	if has_method(m):
		call(m)


func _on_finished(_skipped: bool) -> void:
	if _done:
		return
	_done = true
	_teardown()
	for p in _posed:
		if is_instance_valid(p):
			(p as FilmPose).to(&"", 0.5)
	for n in props:
		if is_instance_valid(n):
			n.queue_free()
	props.clear()
	if feyre and is_instance_valid(feyre):
		var end := _end_mark()
		feyre.global_position = end.origin
		_face_feyre(-end.basis.z)
		var model: Variant = feyre.get(&"model")
		if model is Node3D:
			(model as Node3D).visible = true
		if feyre.has_method(&"recenter_camera"):
			feyre.call(&"recenter_camera")
	grade.to(0.0, 1.0)
	cine.drop(self, HANDOVER_BLEND)


## Undoes anything the scene changed besides props and poses (override).
func _teardown() -> void:
	pass


## Runs `f` in `seconds` unless the film has ended by then (skipped).
func after(seconds: float, f: Callable) -> void:
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_callback(func() -> void:
		if not _done:
			f.call())


# --- the frame -------------------------------------------------------------------

func at(local: Vector3) -> Vector3:
	return frame * local


## Points from now on are in the manor house's layout frame (the numbers in
## data/regions/spring_court/manor_estate/house/*.tres): the house is the
## parent of every manor story anchor. False (frame unchanged) elsewhere.
func use_house() -> bool:
	var n: Node = space
	while n != null:
		if n.is_in_group(&"story_anchor") and n.get_parent() is Node3D:
			frame = (n.get_parent() as Node3D).global_transform
			return true
		n = n.get_parent()
	var a := find_anchor(&"manor_dining_table")
	if a and a.get_parent() is Node3D:
		frame = (a.get_parent() as Node3D).global_transform
		return true
	return false


func find_anchor(id: StringName) -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == id:
			return a as Node3D
	return null


## A point in the frame, dropped onto the ground under it (terrain or floor).
func ground(local: Vector3, up: float = 0.0) -> Vector3:
	var p := at(local)
	var hit := _ray(p + Vector3.UP * 3.0, p + Vector3.DOWN * 6.0)
	if not hit.is_empty():
		return (hit.position as Vector3) + Vector3.UP * up
	return Vector3(p.x, WorldHeight.height_at(p.x, p.z) + up, p.z) if _outdoors() else p


func _outdoors() -> bool:
	var p := at(Vector3.ZERO)
	return absf(WorldHeight.height_at(p.x, p.z) - p.y) < 2.0


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if feyre is CollisionObject3D:
		q.exclude = [(feyre as CollisionObject3D).get_rid()]
	return get_viewport().world_3d.direct_space_state.intersect_ray(q)


# --- the cast --------------------------------------------------------------------

func actor(id: StringName) -> Node3D:
	if space and space.has_method(&"actor"):
		var a: Variant = space.call(&"actor", String(id))
		if a is Node3D and a != space:
			return a as Node3D
	return get_tree().get_first_node_in_group(StringName("story_actor_%s" % id)) as Node3D


## A cast member this scene brings itself (a stand-in until the cast lane
## models them), placed on `local` facing `face_local`.
func bring(id: StringName, local: Vector3, face_local: Vector3) -> Node3D:
	var who := actor(id)
	if who == null:
		who = StandIns.figure(String(id))
		who.add_to_group(StringName("story_actor_%s" % id))
		(space if space else get_tree().current_scene).add_child(who)
		props.append(who)
	put(who, local, face_local)
	return who


## Stands `who` on `local` (on the ground), facing `face_local` (-Z forward).
func put(who: Node3D, local: Vector3, face_local: Vector3) -> void:
	if who == null:
		return
	var p := ground(local)
	var f := at(face_local)
	who.global_position = p
	var d := Vector3(f.x - p.x, 0.0, f.z - p.z)
	if d.length() > 0.01:
		who.global_basis = Basis.looking_at(d.normalized(), Vector3.UP)


## Feyre on `local` facing `face_local`; her model turns, not her camera.
func put_feyre(local: Vector3, face_local: Vector3) -> void:
	if feyre == null:
		return
	feyre.global_position = ground(local)
	var f := at(face_local)
	_face_feyre(Vector3(f.x - feyre.global_position.x, 0.0, f.z - feyre.global_position.z))
	if feyre is CharacterBody3D:
		(feyre as CharacterBody3D).velocity = Vector3.ZERO


func _face_feyre(dir: Vector3) -> void:
	var model: Variant = feyre.get(&"model")
	dir.y = 0.0
	if model is Node3D and dir.length() > 0.01:
		(model as Node3D).global_basis = Basis.looking_at(dir.normalized(), Vector3.UP)


func feyre_model() -> Node3D:
	var model: Variant = feyre.get(&"model") if feyre else null
	return model as Node3D


func pose(who: Node3D, pose_name: StringName, seconds: float = 0.6) -> void:
	var p := FilmPose.on(who)
	if p:
		p.to(pose_name, seconds)
		if not _posed.has(p):
			_posed.append(p)


## The model's AnimationPlayer (a cast scene root or Feyre's model).
static func anim_of(who: Node) -> AnimationPlayer:
	if who == null:
		return null
	var a: Variant = who.get(&"anim")
	if a is AnimationPlayer:
		return a
	return who.find_child("AnimationPlayer", true, false) as AnimationPlayer


## Walks `who` to `local` over `seconds`, its walk clip under it, then idle.
func walk(who: Node3D, local: Vector3, seconds: float) -> void:
	if who == null:
		return
	var to := ground(local)
	var from := who.global_position
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if d.length() > 0.05:
		who.global_basis = Basis.looking_at(d.normalized(), Vector3.UP)
	var ap := anim_of(who)
	var speed := d.length() / maxf(seconds, 0.1)
	if ap and ap.has_animation(&"walk"):
		ap.play(&"walk", 0.25)
		ap.speed_scale = clampf(speed / 1.4, 0.4, 1.4)
	var tw := create_tween()
	tw.tween_property(who, ^"global_position", to, seconds).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func() -> void:
		if ap and ap.has_animation(&"idle"):
			ap.speed_scale = 1.0
			ap.play(&"idle", 0.4))


## Turns `who` to face `face_local` over `seconds`.
func turn(who: Node3D, face_local: Vector3, seconds: float = 0.5) -> void:
	if who == null:
		return
	var f := at(face_local)
	var d := Vector3(f.x - who.global_position.x, 0.0, f.z - who.global_position.z)
	if d.length() < 0.01:
		return
	var target := Basis.looking_at(d.normalized(), Vector3.UP).get_rotation_quaternion()
	var start := who.global_basis.get_rotation_quaternion()
	create_tween().tween_method(func(k: float) -> void:
		who.global_basis = Basis(start.slerp(target, k)), 0.0, 1.0, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## A head point on a figure (for framing): its top minus a little.
static func head_of(who: Node3D) -> Vector3:
	if who == null:
		return Vector3.ZERO
	for s in who.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var i := sk.find_bone("Head")
		if i < 0:
			i = sk.find_bone("head")
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin + Vector3.UP * 0.07
	return who.global_position + Vector3.UP * 1.62


# --- props -----------------------------------------------------------------------

## Adds `node` to the world for this scene; it goes when the film ends.
func add_prop(node: Node3D, world_pos: Vector3) -> Node3D:
	(space if space else get_tree().current_scene).add_child(node)
	node.global_position = world_pos
	props.append(node)
	return node


## Set dressing that stays after the film (until the region reloads), so the
## hand-over shows the same place: it lives under the moment's space.
func add_set(node: Node3D, world_pos: Vector3) -> Node3D:
	(space if space else get_tree().current_scene).add_child(node)
	node.global_position = world_pos
	return node


func load_prop(path: String, world_pos: Vector3, yaw_deg: float = 0.0, s: float = 1.0, keep: bool = false) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	if keep:
		add_set(n, world_pos)
	else:
		add_prop(n, world_pos)
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * s
	return n


## Holds a prop glb in `who`'s hand bone (any rig with that bone).
func hold(who: Node3D, path: String, bone: String, grip: Transform3D = Transform3D.IDENTITY) -> Node3D:
	if who == null or not ResourceLoader.exists(path):
		return null
	for s in who.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		if sk.find_bone(bone) < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = bone
		sk.add_child(att)
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		att.add_child(inst)
		inst.transform = grip
		props.append(att)
		return inst
	return null


# --- the camera ------------------------------------------------------------------

## An authored shot in the frame: from `from_local` looking at `at_local`.
func shot(from_local: Vector3, at_local: Vector3, fov: float, push: float = 0.0, push_time: float = 0.0,
		blend: float = 0.0) -> void:
	shot_world(at(from_local), at(at_local), fov, push, push_time, blend)


func shot_world(from: Vector3, look: Vector3, fov: float, push: float = 0.0, push_time: float = 0.0,
		blend: float = 0.0) -> void:
	cine.claim(self)
	cine.shot(Transform3D(Basis(), from).looking_at(look, Vector3.UP), fov, blend,
			func() -> Vector3: return look, push, push_time)


## A shot that keeps a moving figure's head framed.
func shot_on(from: Vector3, who: Node3D, fov: float, push: float = 0.0, push_time: float = 0.0,
		blend: float = 0.0, lift: float = 0.0) -> void:
	cine.claim(self)
	var look := head_of(who) + Vector3.UP * lift
	cine.shot(Transform3D(Basis(), from).looking_at(look, Vector3.UP), fov, blend,
			func() -> Vector3: return head_of(who) + Vector3.UP * lift, push, push_time)


## Over `who`'s shoulder toward `target` (both figures): the standard two-shot.
func over(who: Node3D, target: Node3D, fov: float = 38.0, side: float = 0.42, push: float = 0.2,
		push_time: float = 4.0) -> void:
	var a := head_of(who)
	var b := head_of(target)
	var from := Cine.over_shoulder(Vector3(a.x, who.global_position.y, a.z), b, 1.25, side, a.y - who.global_position.y)
	shot_on(from, target, fov, push, push_time)


## A close shot on `who`'s face from in front, a little to one side.
func close(who: Node3D, dist: float = 1.1, side: float = 0.35, fov: float = 32.0, push: float = 0.15,
		push_time: float = 4.0, lift: float = -0.04) -> void:
	var h := head_of(who)
	var fwd := -who.global_basis.z
	if who == feyre and feyre_model():
		fwd = -feyre_model().global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	shot_on(h + fwd * dist + right * side + Vector3.UP * 0.02, who, fov, push, push_time, 0.0, lift)

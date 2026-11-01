## Shared pieces for the grounds' horror scenes (L25: the Bogge, the puca):
## reading where Feyre looks, summoning the real creature (or its scene when
## no creature lane answers), a black veil, looping dread sounds and a reset
## that ends the scene without its deed so she can try again.
class_name Act2DreadSpace
extends Act2Space

## Fired when the scene ends without its deed (a look at the Bogge).
signal failed(fact: String)

## Tests replace how the view is read: returns [from: Vector3, dir: Vector3].
var gaze_override: Callable

var _veil: ColorRect
var _veil_layer: CanvasLayer
var _sounds: Dictionary = {}  # id -> AudioStreamPlayer


## Where Feyre is looking from and towards (the camera; tests override).
func view() -> Array:
	if gaze_override.is_valid():
		return gaze_override.call()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		var p := player()
		if p == null:
			return [global_position, Vector3.FORWARD]
		return [p.global_position + Vector3.UP * 1.6, -p.global_basis.z]
	return [cam.global_position, -cam.global_basis.z]


## Degrees between her view and a point.
func view_angle_to(point: Vector3) -> float:
	var v := view()
	var to := point - (v[0] as Vector3)
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg((v[1] as Vector3).angle_to(to))


func looking_at(target: Node3D, cone_deg: float) -> bool:
	return target != null and view_angle_to(target.global_position + Vector3.UP * 1.2) <= cone_deg


## Puts the real creature on a mark: the creature lane's spawner answers when
## it is in the world; otherwise the creature's own scene is built here.
func summon(actor_id: StringName, scene_path: String, at_mark: StringName, face_mark: StringName = &"") -> Node3D:
	var origin := ground_at(mark(at_mark))
	var face := mark(face_mark) if face_mark != &"" else global_position
	var xform := Transform3D(Basis.IDENTITY, origin)
	if not Vector2(origin.x, origin.z).is_equal_approx(Vector2(face.x, face.z)):
		xform = xform.looking_at(Vector3(face.x, origin.y, face.z), Vector3.UP)
	var who := request_actor(actor_id, xform, func() -> Node3D:
		var scene := load(scene_path) as PackedScene
		return scene.instantiate() as Node3D if scene else Act2Cast.build(String(actor_id)))
	who.global_transform = xform
	actors[actor_id] = who
	return who


## Lets go of an actor: one this scene built is taken out of its story
## group at once (so a retry this frame summons a fresh one) and freed; a
## creature lane's actor is left where it is.
func release_actor(actor_id: StringName) -> void:
	var who := actor(actor_id)
	if who and is_ancestor_of(who):
		who.remove_from_group(StringName("story_actor_%s" % actor_id))
	dismiss(actor_id)


## Moves Feyre (after a failure, or in tests) onto a mark, facing another.
func place_player(at_mark: StringName, face_mark: StringName = &"") -> void:
	var p := player()
	if p == null:
		return
	p.global_position = ground_at(mark(at_mark)) + Vector3.UP * 0.1
	if face_mark != &"":
		var face := mark(face_mark)
		var flat := Vector3(face.x, p.global_position.y, face.z)
		if not flat.is_equal_approx(p.global_position):
			p.look_at(flat, Vector3.UP)
	if &"velocity" in p:
		p.set(&"velocity", Vector3.ZERO)


## The ground under a point (a ray from 40 m above), or the point itself.
func ground_at(point: Vector3) -> Vector3:
	if not is_inside_tree():
		return point
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return point
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 40.0, point + Vector3.DOWN * 40.0)
	var p := player()
	if p is CollisionObject3D:
		query.exclude = [(p as CollisionObject3D).get_rid()]
	var hit := space_state.intersect_ray(query)
	return hit["position"] if hit else point


## Fades a full-screen black veil to `alpha` over `seconds`.
func veil(alpha: float, seconds: float) -> void:
	if not is_inside_tree():
		return
	if _veil == null:
		_veil_layer = CanvasLayer.new()
		_veil_layer.name = "Veil"
		_veil_layer.layer = 30
		add_child(_veil_layer)
		_veil = ColorRect.new()
		_veil.color = Color(0.0, 0.0, 0.0, 0.0)
		_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		_veil_layer.add_child(_veil)
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", alpha, maxf(seconds, 0.01))


func veil_alpha() -> float:
	return _veil.color.a if _veil else 0.0


## Starts (or retunes) a looping dread sound; volume_db <= -60 stops it.
func sound(id: StringName, volume_db: float, pitch: float = 1.0) -> void:
	if not is_inside_tree():
		return
	var player_node := _sounds.get(id) as AudioStreamPlayer
	if volume_db <= -60.0:
		if player_node:
			player_node.stop()
		return
	if player_node == null:
		player_node = AudioStreamPlayer.new()
		player_node.name = "Sound_%s" % id
		player_node.stream = Act2DreadAudio.stream(id)
		add_child(player_node)
		_sounds[id] = player_node
	player_node.volume_db = volume_db
	player_node.pitch_scale = pitch
	if not player_node.playing:
		player_node.play()


func sound_playing(id: StringName) -> bool:
	var player_node := _sounds.get(id) as AudioStreamPlayer
	return player_node != null and player_node.playing


func silence() -> void:
	for id: StringName in _sounds:
		(_sounds[id] as AudioStreamPlayer).stop()


## Ends the scene without its deed: the fail fact is recorded (through an
## ActionTrigger, like every flag), control comes back and she can walk in
## again to retry.
func abort(fail_fact: String = "") -> void:
	if fail_fact != "":
		raise(fail_fact)
	running = false
	_must_leave = true
	silence()
	StoryControl.release()
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	EventBus.scene_space_finished.emit(space_id)
	failed.emit(fail_fact)


## Throws away the current beats and plays `tail` instead (a failure).
func replace_beats(tail: Array) -> void:
	if not running:
		return
	if beat_index >= 0 and beat_index < beats.size():
		(beats[beat_index] as SceneBeat).exit(self)
	beats = tail
	beat_index = -1
	_advance()

## A film camera for staged moments (lane L22).
##
## Cine gives scenes the grammar of a film without taking Feyre away from the
## player for long:
## - `follow(fov)`: a camera that rides Feyre's own, with a tighter lens. She
##   keeps full control; the frame just closes in on what she is staring at.
## - `shot(...)`: an authored angle, cut to or eased into, that can track a
##   moving point with a little lag and push in slowly.
## - `release()`: eases back into Feyre's camera and hands the view back.
## - `bars_to(k)`: letterbox bars to 2.39:1 (k = 1) or off (k = 0).
## A faint handheld breath plays on authored shots unless reduced effects is on.
## Timing is in real seconds, so a slowed world (the bow's slow draw) does not
## stretch a cut. One Cine per scene tree, made on demand by `Cine.of(tree)`.
## Contract: docs/contracts/creature_motion.md (Staging).
class_name Cine
extends Node

const NODE_NAME := &"Cine"
const BAR_ASPECT := 2.39
## Handheld breath: degrees of sway and its rate.
const HAND_DEG := 0.18
const HAND_HZ := 0.23

## The camera Cine renders through while active.
var camera: Camera3D
## Feyre's camera (or whichever camera was current when Cine took over).
var player_camera: Camera3D
var active: bool = false
## 0..1, how far the bars are in.
var bars: float = 0.0

var _layer: CanvasLayer
var _top: ColorRect
var _bottom: ColorRect
var _bar_from: float = 0.0
var _bar_to: float = 0.0
var _bar_len: float = 0.0
var _bar_t: float = 1.0

var _from: Transform3D
var _from_fov: float = 70.0
var _blend: float = 0.0
var _t: float = 1.0
## What the camera is heading for: &"follow", &"shot" or &"release".
var target_kind: StringName = &""
var _follow_fov: float = 70.0
var _shot: Transform3D
var _shot_fov: float = 50.0
var _track: Callable
var _look: Vector3 = Vector3.FORWARD
var _track_lag: float = 4.0
var _push: float = 0.0
var _push_time: float = 0.0
var _push_t: float = 0.0
var _hand_t: float = 0.0
var _last_usec: int = 0


## The scene tree's Cine, made the first time it is asked for.
static func of(tree: SceneTree) -> Cine:
	var existing := tree.root.get_node_or_null(NodePath(String(NODE_NAME))) as Cine
	if existing:
		return existing
	var c := Cine.new()
	c.name = NODE_NAME
	tree.root.add_child(c)
	return c


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "CineCamera"
	add_child(camera)
	_layer = CanvasLayer.new()
	_layer.name = "Letterbox"
	_layer.layer = 4
	add_child(_layer)
	_top = _bar()
	_bottom = _bar()
	_last_usec = Time.get_ticks_usec()


func _bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2.ZERO
	_layer.add_child(r)
	return r


## Rides Feyre's camera with a `fov` lens, easing in over `blend` seconds.
func follow(fov: float, blend: float = 0.8) -> void:
	_begin(blend)
	target_kind = &"follow"
	_follow_fov = fov


## An authored angle: from `xform` with a `fov` lens, cut (`blend` 0) or eased
## in. `track` (a Callable returning a world point) keeps the subject framed,
## turning after it with a little lag. `push` metres of slow dolly toward the
## subject over `push_time` seconds.
func shot(xform: Transform3D, fov: float, blend: float = 0.0, track: Callable = Callable(),
		push: float = 0.0, push_time: float = 0.0) -> void:
	_begin(blend)
	target_kind = &"shot"
	_shot = xform
	_shot_fov = fov
	_track = track
	_look = -xform.basis.z
	if track.is_valid():
		_look = (Vector3(track.call()) - xform.origin).normalized()
	_push = push
	_push_time = push_time
	_push_t = 0.0


## Eases back into Feyre's camera over `blend` seconds and gives her the view.
func release(blend: float = 1.2) -> void:
	if not active:
		return
	_begin(blend)
	target_kind = &"release"


## Letterbox bars: `k` 1 is a 2.39:1 frame, 0 is none, over `seconds`.
func bars_to(k: float, seconds: float = 0.6) -> void:
	_bar_from = bars
	_bar_to = clampf(k, 0.0, 1.0)
	_bar_len = maxf(seconds, 0.0)
	_bar_t = 0.0 if _bar_len > 0.0 else 1.0
	if _bar_len == 0.0:
		bars = _bar_to


## Where the camera is right now (the blend start for the next move).
func _begin(blend: float) -> void:
	var view := get_viewport().get_camera_3d()
	if not active:
		if view and view != camera:
			player_camera = view
		var feyre := get_tree().get_first_node_in_group(&"player")
		if feyre and feyre.get(&"camera") is Camera3D:
			player_camera = feyre.get(&"camera")
		if player_camera == null:
			return
		_from = player_camera.global_transform
		_from_fov = player_camera.fov
		camera.far = player_camera.far
		camera.near = player_camera.near
		camera.attributes = player_camera.attributes
		camera.environment = player_camera.environment
		camera.cull_mask = player_camera.cull_mask
		camera.global_transform = _from
		camera.fov = _from_fov
		camera.current = true
		active = true
	else:
		_from = camera.global_transform
		_from_fov = camera.fov
	_blend = maxf(blend, 0.0)
	_t = 0.0 if _blend > 0.0 else 1.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_usec) / 1e6, 0.1)
	_last_usec = now
	_update_bars(dt)
	if not active:
		return
	if player_camera == null or not is_instance_valid(player_camera):
		_finish()
		return
	if _blend > 0.0:
		_t = minf(_t + dt / _blend, 1.0)
	var aim := _target_pose(dt)
	var k := _ease(_t)
	var q := Quaternion(_from.basis.orthonormalized()).slerp(Quaternion(aim[0].basis.orthonormalized()), k)
	camera.global_transform = Transform3D(Basis(q), _from.origin.lerp(aim[0].origin, k))
	camera.fov = lerpf(_from_fov, aim[1], k)
	if target_kind == &"release" and _t >= 1.0:
		_finish()


## [Transform3D, fov] the camera is heading for this frame.
func _target_pose(dt: float) -> Array:
	match target_kind:
		&"follow":
			return [player_camera.global_transform, _follow_fov]
		&"release":
			return [player_camera.global_transform, player_camera.fov]
	# An authored shot.
	var origin := _shot.origin
	var forward := -_shot.basis.z
	if _track.is_valid():
		var want := (Vector3(_track.call()) - origin).normalized()
		_look = _look.slerp(want, 1.0 - exp(-_track_lag * dt)).normalized()
		forward = _look
	if _push_time > 0.0:
		_push_t = minf(_push_t + dt / _push_time, 1.0)
		origin += (-_shot.basis.z) * _push * _ease(_push_t)
	var basis := Basis.looking_at(forward, Vector3.UP)
	if not _reduced_effects():
		_hand_t += dt
		var w := TAU * HAND_HZ * _hand_t
		var yaw := deg_to_rad(HAND_DEG) * (sin(w) + 0.4 * sin(2.3 * w + 1.1))
		var pitch := deg_to_rad(HAND_DEG) * 0.7 * (sin(1.3 * w + 0.5) + 0.3 * sin(3.1 * w))
		basis = basis * Basis.from_euler(Vector3(pitch, yaw, 0.0))
	return [Transform3D(basis, origin), _shot_fov]


func _finish() -> void:
	active = false
	target_kind = &""
	if player_camera and is_instance_valid(player_camera):
		player_camera.current = true


func _exit_tree() -> void:
	if active:
		_finish()


func _update_bars(dt: float) -> void:
	if _bar_t < 1.0:
		_bar_t = minf(_bar_t + dt / maxf(_bar_len, 1e-3), 1.0)
		bars = lerpf(_bar_from, _bar_to, _ease(_bar_t))
	var size := get_viewport().get_visible_rect().size
	var full := maxf((size.y - size.x / BAR_ASPECT) * 0.5, 0.0)
	var h := full * bars
	_top.position = Vector2.ZERO
	_top.size = Vector2(size.x, h)
	_bottom.position = Vector2(0.0, size.y - h)
	_bottom.size = Vector2(size.x, h)
	_layer.visible = bars > 0.001


## Smootherstep: no jolt at either end of a move.
static func _ease(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _reduced_effects() -> bool:
	return GameSettings.reduced_effects


## A camera spot `dist` metres from `subject` that sees it: the first of the
## flat directions `dirs` whose line to the subject is clear of trees and
## ground, `height` above the ground there. Falls back to the first direction.
static func clear_view(world: World3D, subject: Vector3, dirs: Array[Vector3], dist: float,
		height: float, exclude: Array[RID] = []) -> Vector3:
	var space := world.direct_space_state
	# On the shared map's terrain, or on a greybox/test floor of its own.
	var on_terrain := absf(WorldHeight.height_at(subject.x, subject.z) - subject.y) < 3.0
	var first := Vector3.INF
	for d in dirs:
		var flat := Vector3(d.x, 0.0, d.z).normalized()
		var spot := subject + flat * dist
		var ground := maxf(WorldHeight.height_at(spot.x, spot.z), subject.y - 1.0) if on_terrain else subject.y
		spot.y = ground + height
		if first == Vector3.INF:
			first = spot
		var q := PhysicsRayQueryParameters3D.create(spot, subject + Vector3.UP * 0.5)
		q.exclude = exclude
		if space.intersect_ray(q).is_empty() and (not on_terrain or _ground_clear(spot, subject + Vector3.UP * 0.5)):
			return spot
	return first


## True when the terrain (WorldHeight) stays below the line from `a` to `b`.
static func _ground_clear(a: Vector3, b: Vector3) -> bool:
	for i in range(1, 8):
		var p := a.lerp(b, i / 8.0)
		if WorldHeight.height_at(p.x, p.z) > p.y - 0.15:
			return false
	return true

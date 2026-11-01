## An animal moment: a doe at the water, hares in the grass, swans on the
## river, a bunting on a branch. Stop and watch them a moment (camera on them,
## not running) and she lets them be (the doe she lets "wander on", ch 11): a
## sketch and a thought, the first time. Sprint at them and they bolt; they're
## back the next time she passes. Small creatures are the creatures lane's
## ambient scenes, which move and flee on their own; the doe is its model with
## a little grazing loop, so it can't be hunted here.
class_name WaysideVignette
extends WaysideSpotNode

## Run or sprint inside this and they bolt.
const BOLT_RADIUS := 14.0
## Within this, not running, with the camera on them, she gets to watch.
const WATCH_RADIUS := 24.0
const WATCH_DEGREES := 22.0
const WATCH_SECONDS := 1.5

var animals: Array[Node3D] = []
var _flee := 0.0
var _flee_dir := Vector3.FORWARD
var _t := 0.0
var _watched := 0.0
var _self_driven := false


func build() -> void:
	var scene := load(String(spot.param("scene", ""))) as PackedScene
	if scene == null:
		return
	var count := int(spot.param("count", 1))
	for i in count:
		var a: Node3D = scene.instantiate()
		var ang := TAU * float(i) / maxf(count, 1)
		var off := Vector3(cos(ang), 0.0, sin(ang)) * (0.0 if count == 1 else float(spot.param("spread", 1.6)))
		a.position = off
		a.position.y = ground(spot.position.x + off.x, spot.position.z + off.z) - spot.position.y
		a.rotation.y = randf_range(-PI, PI) if count > 1 else 0.0
		a.scale = Vector3.ONE * float(spot.param("scale", 1.0))
		add_child(a)
		animals.append(a)
		_self_driven = _self_driven or a is Creature


func _process(delta: float) -> void:
	_t += delta
	var d := flat_distance_to_player()
	var fast := player_speed() > 4.5
	if not _self_driven and _flee <= 0.0 and d < BOLT_RADIUS and fast:
		_flee = 0.01
		var p := player()
		_flee_dir = (global_position - p.global_position).normalized() if p else Vector3.FORWARD
		_flee_dir.y = 0.0
	if _flee > 0.0:
		_flee += delta
		for a in animals:
			a.position += _flee_dir * delta * float(spot.param("flee_speed", 9.0))
			a.rotation.y = atan2(_flee_dir.x, _flee_dir.z)
			if _flee > 1.6:
				a.visible = false
		return
	if spot.param("graze", false):
		for i in animals.size():
			# Head down to graze, up to listen.
			animals[i].rotation.x = 0.12 * sin(_t * 0.7 + i) if d > WATCH_RADIUS else 0.0
	if found():
		return
	_watched = _watched + delta if d < WATCH_RADIUS and not fast and _looking_at() else 0.0
	if _watched >= WATCH_SECONDS:
		complete()


func _looking_at() -> bool:
	var p := player()
	if not p is Feyre or (p as Feyre).camera == null:
		return false
	var cam := (p as Feyre).camera
	for a in animals:
		if not is_instance_valid(a) or not a.visible:
			continue
		var to := (a.global_position + Vector3.UP * 0.4) - cam.global_position
		if rad_to_deg((-cam.global_basis.z).angle_to(to)) < WATCH_DEGREES:
			return true
	return false

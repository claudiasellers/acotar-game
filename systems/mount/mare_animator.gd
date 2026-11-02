## Plays the white horse's gait clips (tools/blender/white_mare.py, the shared
## quadruped rig of docs/contracts/creature_motion.md) from her ground speed:
## idle, walk, trot or gallop, each at a rate that keeps her hooves planted,
## with short cross-fades between gaits. `graze` plays when she stands idle
## for a while with no rider, `rear` (hit clip) when she balks. On top, the
## body pitches with the slope. Used by WhiteHorse for the ch5 ride and the mount.
class_name MareAnimator
extends Node

const GAITS_FILE := "res://data/animation/creatures/white_horse_gaits.txt"
const LOCO: Array[StringName] = [&"walk", &"trot", &"gallop"]
const LOOPS: Array[StringName] = [&"idle", &"walk", &"trot", &"gallop", &"graze"]
## Gait thresholds (m/s): below WALK_MIN she stands; trot from TROT_FROM; gallop from GALLOP_FROM.
const WALK_MIN := 0.25
const TROT_FROM := 3.0
const GALLOP_FROM := 7.0
## Cadence limits, so the legs never look frantic or treacly.
const MIN_RATE := 0.55
const MAX_RATE := 1.45
const FADE := 0.22
const GRAZE_AFTER := 6.0

var anim: AnimationPlayer
var body: Node3D
var native_speeds: Dictionary = {&"walk": 1.0, &"trot": 3.3, &"gallop": 16.0}
var clip: StringName = &""
var rate: float = 1.0
## When false (a rider is up), she never drops her head to graze.
var may_graze: bool = true
## The speed the animator reads; the owner sets it each frame.
var speed: float = 0.0

var _still: float = 0.0
var _busy: float = 0.0
var _pitch: float = 0.0


## Finds the AnimationPlayer under `model` and drives it. Null if it has none.
static func attach(model: Node3D, owner_body: Node3D) -> MareAnimator:
	if model == null:
		return null
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(&"idle"):
		return null
	var a := MareAnimator.new()
	a.name = "MareAnimator"
	a.anim = player
	a.body = owner_body
	var table := CreatureAnimator.read_gaits(GAITS_FILE)
	for c in LOCO:
		if table.has(c) and float(table[c][0]) > 0.0:
			a.native_speeds[c] = float(table[c][0])
	for c in LOOPS:
		if player.has_animation(c):
			player.get_animation(c).loop_mode = Animation.LOOP_LINEAR
	model.add_child(a)
	a._go(&"idle", 1.0)
	return a


## Which clip plays at `v` m/s, and how fast.
func gait_for(v: float) -> Array:
	if v < WALK_MIN:
		return [&"idle", 1.0]
	var c := &"walk" if v < TROT_FROM else (&"trot" if v < GALLOP_FROM else &"gallop")
	return [c, clampf(v / float(native_speeds[c]), MIN_RATE, MAX_RATE)]


## A snort and a toss of the head, refusing to go on (dread ahead).
func balk() -> void:
	if _busy > 0.0 or anim == null:
		return
	var c := &"hit_l" if randf() < 0.5 else &"hit_r"
	if anim.has_animation(c):
		anim.play(c, 0.1, 0.8)
		clip = c
		_busy = anim.get_animation(c).length / 0.8 * 0.8


func _process(delta: float) -> void:
	if anim == null:
		return
	if _busy > 0.0:
		_busy -= delta
		return
	var g := gait_for(speed)
	var c: StringName = g[0]
	_still = _still + delta if c == &"idle" else 0.0
	if c == &"idle" and may_graze and _still > GRAZE_AFTER and anim.has_animation(&"graze"):
		c = &"graze"
	if c != clip:
		_go(c, g[1])
	rate = g[1]
	anim.speed_scale = rate
	_conform(delta)


func _go(c: StringName, r: float) -> void:
	clip = c
	rate = r
	anim.play(c, FADE)
	anim.speed_scale = r


## Pitch the model with the slope under her front and hind hooves.
func _conform(delta: float) -> void:
	if body == null or not body.is_inside_tree() or anim == null:
		return
	var model := anim.get_parent() as Node3D
	while model and model.get_parent() != body:
		model = model.get_parent() as Node3D
	if model == null:
		return
	var space := body.get_world_3d().direct_space_state
	var fwd := -body.global_basis.z
	var hf := _ground(space, body.global_position + fwd * 0.9)
	var hb := _ground(space, body.global_position - fwd * 0.9)
	var want := 0.0
	if not is_nan(hf) and not is_nan(hb):
		want = clampf(atan2(hf - hb, 1.8), -0.45, 0.45)
	_pitch = lerpf(_pitch, want, clampf(6.0 * delta, 0.0, 1.0))
	model.rotation.x = _pitch


func _ground(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.DOWN * 2.5, 1)
	if body is CollisionObject3D:
		q.exclude = [(body as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return NAN if hit.is_empty() else (hit.position as Vector3).y

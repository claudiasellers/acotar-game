## Drives Feyre's body animation from how she is moving, with the retargeted
## motion-capture clips in characters/feyre/anim/feyre_moves.glb (CC0, see
## CREDITS.md there).
##
## An AnimationTree state machine: Loco is a 1D blend space over idle, walk,
## run and sprint keyed on ground speed and time-scaled so planted feet match
## the ground (each clip's native speed comes from the retarget generator);
## the air states follow JumpMotor (take-off, double, flourish, rise, fall,
## land, hero landing). Lean and squash live in MovementFeel.
class_name FeyreAnimator
extends Node

const MOVES_SCENE := "res://characters/feyre/anim/feyre_moves.glb"
const SPEEDS_FILE := "res://data/animation/feyre_moves_speeds.txt"
const LIBRARY := &"moves"
const LOCO_CLIPS: Array[StringName] = [&"idle", &"walk", &"run", &"sprint"]
const AIR_STATES: Array[StringName] = [&"jump_start", &"jump_double", &"jump_flourish",
		&"jump_rise", &"jump_fall", &"jump_land", &"land_hero"]
const XFADE := 0.12
## Ground speed below which she stands (blend space idle point is 0).
const STAND_SPEED := 0.25
## Slowest stride: below it she blends toward standing.
const SLOW_WALK := 0.6
## Game speed (m/s) where the walk clip plays pure; slower is a slower stride.
const SLOW_WALK_POINT := 1.6
## Fastest playback beyond the sprint clip before the cadence looks frantic.
const MAX_SCALE := 1.8
## Above this ground speed a landing goes straight back to running.
const LAND_RUN_THROUGH := 2.0
## Landing impact (m/s) worth a landing clip at all.
const LAND_MIN_IMPACT := 5.0

var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
## Native ground speed (m/s) per locomotion clip.
var native_speeds: Dictionary = {}
var clip_lengths: Dictionary = {}
## Game ground speed (m/s) at which each gait clip plays pure (blend-space points).
var gait_points: Dictionary = {}

var _mover: CharacterBody3D
var _motor: JumpMotor
var _state: StringName = &"Loco"
var _state_time: float = 0.0


## Adds the moves library to `anim` and builds the tree. Returns null when the
## mocap set is missing (the model keeps its procedural clips).
static func attach(model: Node3D, anim: AnimationPlayer, mover: CharacterBody3D) -> FeyreAnimator:
	if anim == null or not ResourceLoader.exists(MOVES_SCENE):
		return null
	var lib := load_library()
	if lib == null:
		return null
	if not anim.has_animation_library(LIBRARY):
		anim.add_animation_library(LIBRARY, lib)
	var animator := FeyreAnimator.new()
	animator.name = "FeyreAnimator"
	animator._mover = mover
	animator._read_speeds(lib)
	animator._read_gait_points(mover)
	model.add_child(animator)
	animator._build_tree(anim)
	anim.stop()
	return animator


## The AnimationLibrary inside feyre_moves.glb, loops set.
static func load_library() -> AnimationLibrary:
	var scene := load(MOVES_SCENE) as PackedScene
	if scene == null:
		return null
	var inst := scene.instantiate()
	var player := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib: AnimationLibrary = null
	if player != null and player.has_animation_library(&""):
		lib = player.get_animation_library(&"").duplicate(true) as AnimationLibrary
	inst.free()
	if lib == null:
		return null
	for clip: StringName in LOCO_CLIPS + [&"jump_rise", &"jump_fall"]:
		if lib.has_animation(clip):
			lib.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return lib


func _ready() -> void:
	if _mover is Feyre:
		_motor = (_mover as Feyre).jump_motor
		_motor.jumped.connect(_on_jumped)
		_motor.landed.connect(_on_landed)


func _process(delta: float) -> void:
	if tree == null or _mover == null:
		return
	_state_time += delta
	var v := _mover.velocity
	var speed := Vector2(v.x, v.z).length()
	var blend := loco_blend(speed)
	tree.set(&"parameters/Loco/space/blend_position", blend.x)
	tree.set(&"parameters/Loco/scale/scale", blend.y)

	var airborne := _motor != null and _motor.airborne and not _mover.is_on_floor()
	match _state:
		&"jump_start", &"jump_double":
			if _finished():
				_go(&"jump_rise" if v.y > 0.0 else &"jump_fall")
		&"jump_flourish":
			if _finished():
				_go(&"jump_fall")
		&"jump_rise":
			if v.y <= 0.0:
				_go(&"jump_fall")
		&"jump_land", &"land_hero":
			if _finished() or (speed > LAND_RUN_THROUGH and _state_time > 0.15):
				_go(&"Loco")
		&"Loco":
			if airborne and v.y < -2.0:
				_go(&"jump_fall")


## Blend-space position and playback rate for a ground speed. Clip points sit
## at the game's own gait speeds (`gait_points`: her default pace plays the run
## clip, Shift plays the sprint), and the rate is the ground speed over the
## blended clips' native speed, so planted feet move with the ground.
func loco_blend(speed: float) -> Vector2:
	if speed <= STAND_SPEED:
		return Vector2(0.0, 1.0)
	var clips: Array[StringName] = []
	for clip: StringName in [&"walk", &"run", &"sprint"]:
		if gait_points.has(clip) and native_speeds.has(clip):
			clips.append(clip)
	if clips.is_empty():
		return Vector2(speed, 1.0)
	var first: float = gait_points[clips[0]]
	if speed < SLOW_WALK:
		# Ease out of standing: a slow stride blended with idle.
		var native: float = native_speeds[clips[0]]
		return Vector2(speed / SLOW_WALK * first, SLOW_WALK / native)
	if speed <= first:
		return Vector2(first, clampf(speed / float(native_speeds[clips[0]]), 0.5, MAX_SCALE))
	for i in range(1, clips.size()):
		var p0: float = gait_points[clips[i - 1]]
		var p1: float = gait_points[clips[i]]
		if speed <= p1:
			var t := (speed - p0) / maxf(p1 - p0, 0.01)
			var native := lerpf(native_speeds[clips[i - 1]], native_speeds[clips[i]], t)
			return Vector2(speed, clampf(speed / native, 0.5, MAX_SCALE))
	var last := clips[clips.size() - 1]
	return Vector2(gait_points[last], clampf(speed / float(native_speeds[last]), 0.5, MAX_SCALE))


## Take-off is already happening this frame, so jump 1 goes straight to the
## rising pose (the crouch clip would read as a delay).
func _on_jumped(index: int) -> void:
	_go([&"jump_rise", &"jump_double", &"jump_flourish"][clampi(index, 1, 3) - 1])


func _on_landed(impact: float, index: int) -> void:
	var speed := Vector2(_mover.velocity.x, _mover.velocity.z).length()
	if index == 3:
		_go(&"land_hero")
	elif impact >= LAND_MIN_IMPACT and speed < LAND_RUN_THROUGH:
		_go(&"jump_land")
	else:
		_go(&"Loco")


func _go(state: StringName) -> void:
	if playback == null:
		return
	_state = state
	_state_time = 0.0
	playback.travel(state, true)


func _finished() -> bool:
	var length: float = clip_lengths.get(_state, 0.0)
	return _state_time >= length - XFADE


func _read_gait_points(mover: CharacterBody3D) -> void:
	gait_points[&"walk"] = SLOW_WALK_POINT
	gait_points[&"run"] = float(mover.get(&"run_speed")) if mover is Feyre else 5.5
	gait_points[&"sprint"] = float(mover.get(&"sprint_speed")) if mover is Feyre else 9.0


func _read_speeds(lib: AnimationLibrary) -> void:
	for clip in lib.get_animation_list():
		clip_lengths[clip] = lib.get_animation(clip).length
	var text := FileAccess.get_file_as_string(SPEEDS_FILE)
	for line in text.split("\n"):
		var parts := line.strip_edges().split(" ", false)
		if parts.size() >= 2 and not parts[0].begins_with("#") and parts[1].is_valid_float():
			if float(parts[1]) > 0.0:
				native_speeds[StringName(parts[0])] = float(parts[1])


func _build_tree(anim: AnimationPlayer) -> void:
	var sm := AnimationNodeStateMachine.new()
	var loco := AnimationNodeBlendTree.new()
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = maxf(float(gait_points.get(&"sprint", 9.0)) * 1.3, 12.0)
	space.sync = true
	for clip in LOCO_CLIPS:
		if not anim.has_animation(LIBRARY + "/" + clip):
			continue
		var node := AnimationNodeAnimation.new()
		node.animation = LIBRARY + "/" + clip
		space.add_blend_point(node, 0.0 if clip == &"idle" else float(gait_points.get(clip, 1.0)), -1, clip)
	loco.add_node(&"space", space)
	loco.add_node(&"scale", AnimationNodeTimeScale.new())
	loco.connect_node(&"scale", 0, &"space")
	loco.connect_node(&"output", 0, &"scale")
	sm.add_node(&"Loco", loco)
	var states: Array[StringName] = [&"Loco"]
	for clip in AIR_STATES:
		if not anim.has_animation(LIBRARY + "/" + clip):
			continue
		var node := AnimationNodeAnimation.new()
		node.animation = LIBRARY + "/" + clip
		sm.add_node(clip, node)
		states.append(clip)
	for a in states:
		for b in states:
			if a != b:
				var tr := AnimationNodeStateMachineTransition.new()
				tr.xfade_time = XFADE
				tr.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
				sm.add_transition(a, b, tr)
	sm.add_transition(&"Start", &"Loco", AnimationNodeStateMachineTransition.new())
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	tree.tree_root = sm
	anim.get_parent().add_child(tree)
	tree.root_node = tree.get_path_to(anim.get_node(anim.root_node))
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	playback = tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback

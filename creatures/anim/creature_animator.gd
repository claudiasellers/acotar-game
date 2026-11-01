## Drives a rigged creature model (tools/blender/creature_rig.py) from how the
## creature moves and what happens to it. Contract: docs/contracts/creature_motion.md.
##
## An AnimationTree blend tree: a 1D blend space over idle, walk, trot and
## gallop keyed on ground speed (each clip's native speed comes from
## data/animation/creatures/<model>_gaits.txt, so planted paws match the
## ground), blended with stalk and graze by the brain's `gait_hint`, two
## one-shot flinches (hit_l, hit_r) and a final transition into a death clip
## that falls away from the last blow. On top of the clips: the body pitches
## and rolls with the slope and leans into fast turns, the corpse lies along
## the ground, and arrows that stick in the body ride the nearest bone.
class_name CreatureAnimator
extends Node

const GAITS_FILE := "res://data/animation/creatures/%s_gaits.txt"
const LOOPS: Array[StringName] = [&"idle", &"walk", &"trot", &"gallop", &"stalk", &"graze"]
const LOCO: Array[StringName] = [&"walk", &"trot", &"gallop"]
## Cadence limits: past these the legs look frantic or treacly.
const MAX_RATE := 1.6
const MIN_RATE := 0.5
## How fast the stalk and graze layers come and go (per second).
const LAYER_SPEED := 3.0
## How much of the slope the living body follows (pitch, roll); the dead lie flat on it.
const SLOPE_PITCH := 0.85
const SLOPE_ROLL := 0.35
## Lean into turns: radians of roll per (rad/s of turn x m/s of speed), and its cap.
const LEAN_GAIN := 0.035
const LEAN_MAX := 0.3

var creature: Creature
var anim: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
## Native ground speed (m/s) per gait clip, already multiplied by model_scale.
var native_speeds: Dictionary = {}
var clip_lengths: Dictionary = {}
var dead: bool = false
## The flank it fell onto: -1 left, +1 right (0 while alive).
var fell_to: int = 0
## Playback rate of the whole body (staging slows it; see slow()).
var time_scale: float = 1.0
var _manual: bool = false
var _slow_tween: Tween
## Which side the last arrow struck: -1 left, +1 right (0 none yet).
var last_hit_side: int = 0

var _stalk: float = 0.0
var _graze: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _lean: float = 0.0
var _last_yaw: float = 0.0
var _model_scale: Vector3 = Vector3.ONE
var _ray_tick: int = 0
var _attachments: Dictionary = {}


## Builds the animator for `c` when its model is rigged (has an AnimationPlayer
## with the clip set). Returns null for unrigged models, which keep the old topple.
static func attach(c: Creature) -> CreatureAnimator:
	if c.model == null:
		return null
	var player := c.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(&"idle") or not player.has_animation(&"death_l"):
		return null
	var a := CreatureAnimator.new()
	a.name = "CreatureAnimator"
	a.creature = c
	a.anim = player
	var skeletons := c.model.find_children("*", "Skeleton3D", true, false)
	a.skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	a._model_scale = c.model.scale
	a._read_gaits(c.data)
	a._set_loops()
	c.add_child(a)
	a._build_tree()
	c.child_entered_tree.connect(a._on_child_entered)
	return a


## The gait table for this model: name -> [native speed or -1, length].
static func read_gaits(path: String) -> Dictionary:
	var out := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts := line.split(" ", false)
		if parts.size() < 3:
			continue
		var speed := -1.0 if parts[1] == "-" else parts[1].to_float()
		out[StringName(parts[0])] = [speed, parts[2].to_float()]
	return out


func _read_gaits(data: CreatureData) -> void:
	var model_name := data.model_scene.resource_path.get_file().get_basename() if data.model_scene else String(data.kind)
	var table := read_gaits(GAITS_FILE % model_name)
	for clip in table:
		var row: Array = table[clip]
		clip_lengths[clip] = row[1]
		if row[0] > 0.0:
			native_speeds[clip] = row[0] * data.model_scale
	# A model without a table still moves: guess from the creature's own speeds.
	for i in LOCO.size():
		if not native_speeds.has(LOCO[i]):
			native_speeds[LOCO[i]] = [data.walk_speed, (data.walk_speed + data.run_speed) * 0.3, data.run_speed * 0.8][i]


func _set_loops() -> void:
	for clip in LOOPS:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = maxf(native_speeds[&"gallop"] * 2.0, 1.0)
	loco.add_blend_point(_anim_node(&"idle"), 0.0, -1, &"idle")
	for clip in LOCO:
		loco.add_blend_point(_anim_node(clip), native_speeds[clip], -1, clip)
	bt.add_node(&"loco", loco)
	bt.add_node(&"loco_rate", AnimationNodeTimeScale.new())
	bt.connect_node(&"loco_rate", 0, &"loco")
	var last := &"loco_rate"
	if anim.has_animation(&"stalk"):
		bt.add_node(&"stalk", _anim_node(&"stalk"))
		bt.add_node(&"stalk_rate", AnimationNodeTimeScale.new())
		bt.connect_node(&"stalk_rate", 0, &"stalk")
		bt.add_node(&"stalk_mix", AnimationNodeBlend2.new())
		bt.connect_node(&"stalk_mix", 0, last)
		bt.connect_node(&"stalk_mix", 1, &"stalk_rate")
		last = &"stalk_mix"
	if anim.has_animation(&"graze"):
		bt.add_node(&"graze", _anim_node(&"graze"))
		bt.add_node(&"graze_mix", AnimationNodeBlend2.new())
		bt.connect_node(&"graze_mix", 0, last)
		bt.connect_node(&"graze_mix", 1, &"graze")
		last = &"graze_mix"
	for clip in [&"hit_l", &"hit_r"]:
		if not anim.has_animation(clip):
			continue
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.04
		shot.fadeout_time = 0.3
		shot.mix_mode = AnimationNodeOneShot.MIX_MODE_BLEND
		var shot_name := StringName("%s_shot" % clip)
		bt.add_node(shot_name, shot)
		bt.add_node(clip, _anim_node(clip))
		bt.connect_node(shot_name, 0, last)
		bt.connect_node(shot_name, 1, clip)
		last = shot_name
	var life := AnimationNodeTransition.new()
	life.xfade_time = 0.08
	for input in [&"alive", &"death_l", &"death_r"]:
		life.add_input(input)
	bt.add_node(&"life", life)
	bt.add_node(&"death_l", _anim_node(&"death_l"))
	bt.add_node(&"death_r", _anim_node(&"death_r"))
	bt.connect_node(&"life", 0, last)
	bt.connect_node(&"life", 1, &"death_l")
	bt.connect_node(&"life", 2, &"death_r")
	bt.connect_node(&"output", 0, &"life")
	tree = AnimationTree.new()
	tree.name = "CreatureTree"
	tree.tree_root = bt
	# The tree resolves tracks from its parent, which must be the model root
	# (the AnimationPlayer's own root).
	creature.model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	anim.stop()


## Playback rate for the locomotion blend at ground speed `speed`: 1 between
## gait points (each blend point is a clip's native speed), slower for the first
## steps from standing, faster past the gallop, within the cadence limits.
func loco_rate(speed: float) -> float:
	var walk: float = native_speeds[&"walk"]
	var top: float = native_speeds[&"gallop"]
	if speed < walk:
		return clampf(speed / walk, MIN_RATE, 1.0)
	if speed > top:
		return clampf(speed / top, 1.0, MAX_RATE)
	return 1.0


## An arrow struck the side its position is on (local x < 0 is the left).
func hit(from: Vector3) -> void:
	if dead or tree == null:
		return
	var local := creature.to_local(from)
	last_hit_side = -1 if local.x < 0.0 else 1
	var shot := &"parameters/hit_l_shot/request" if last_hit_side < 0 else &"parameters/hit_r_shot/request"
	tree.set(shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Falls away from the last blow (struck on the right, it goes down on its
## left flank); with no blow on record, a side fixed by its id.
func die() -> void:
	if dead:
		return
	dead = true
	if last_hit_side != 0:
		fell_to = -last_hit_side
	else:
		fell_to = -1 if hash(creature.creature_id) % 2 == 0 else 1
	if tree:
		for clip in [&"hit_l_shot", &"hit_r_shot"]:
			tree.set("parameters/%s/request" % clip, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		tree.set(&"parameters/life/transition_request", "death_l" if fell_to < 0 else "death_r")


## Seconds the death clip runs before the body is still.
func death_length() -> float:
	return float(clip_lengths.get(&"death_l" if fell_to <= 0 else &"death_r", 3.0))


## Slows this body's motion for staging (a hit-stop, the kill in slow
## motion): `scale` at once, held `hold` real seconds, eased back to 1 over
## `ramp`. Only this creature slows; the world keeps time.
func slow(scale: float, hold: float, ramp: float) -> void:
	if tree == null:
		return
	if _slow_tween:
		_slow_tween.kill()
	time_scale = scale
	_slow_tween = create_tween()
	_slow_tween.set_ignore_time_scale(true)
	_slow_tween.tween_interval(hold)
	_slow_tween.tween_property(self, ^"time_scale", 1.0, ramp).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _process(delta: float) -> void:
	if tree == null:
		return
	# The tree runs itself at 1x; while slowed it is advanced here.
	var slowed := not is_equal_approx(time_scale, 1.0)
	if slowed and not _manual:
		_manual = true
		tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	elif not slowed and _manual:
		_manual = false
		tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	if _manual:
		tree.advance(delta * time_scale)


func _physics_process(delta: float) -> void:
	if creature == null or tree == null:
		return
	if not dead:
		_drive_gait(delta)
	_conform(delta)


func _drive_gait(delta: float) -> void:
	var v := creature.velocity
	var speed := Vector2(v.x, v.z).length()
	tree.set(&"parameters/loco/blend_position", speed)
	tree.set(&"parameters/loco_rate/scale", loco_rate(speed))
	var hint := creature.gait_hint
	_stalk = move_toward(_stalk, 1.0 if hint == &"stalk" else 0.0, LAYER_SPEED * delta)
	_graze = move_toward(_graze, 1.0 if hint == &"graze" and speed < 0.4 else 0.0, LAYER_SPEED * 0.6 * delta)
	if anim.has_animation(&"stalk"):
		tree.set(&"parameters/stalk_mix/blend_amount", _stalk)
		# Frozen mid-step when he stops: the stalk holds its pose rather than idling.
		var native: float = native_speeds.get(&"stalk", 0.8)
		tree.set(&"parameters/stalk_rate/scale", clampf(speed / native, 0.0, 1.8))
	if anim.has_animation(&"graze"):
		tree.set(&"parameters/graze_mix/blend_amount", _graze)
	var yaw := creature.rotation.y
	var turn := wrapf(yaw - _last_yaw, -PI, PI) / maxf(delta, 1e-4)
	_last_yaw = yaw
	var lean := clampf(turn * speed * LEAN_GAIN, -LEAN_MAX, LEAN_MAX)
	_lean = lerpf(_lean, lean, clampf(6.0 * delta, 0.0, 1.0))


## Tilts the model to the ground under it: front-to-back and side-to-side
## heights from four short rays, eased. Living bodies take most of the pitch
## and some of the roll; a corpse lies along the slope.
func _conform(delta: float) -> void:
	var model := creature.model
	if model == null or not creature.is_inside_tree():
		return
	_ray_tick += 1
	if _ray_tick % 2 == 0:
		var space := creature.get_world_3d().direct_space_state
		var half_l := creature.data.body_length * 0.4 * creature.data.model_scale
		var half_w := creature.data.body_width * (1.2 if dead else 0.5)
		var basis := creature.global_basis
		var fwd := -basis.z
		var right := basis.x
		var hf := _ground(space, creature.global_position + fwd * half_l)
		var hb := _ground(space, creature.global_position - fwd * half_l)
		var hr := _ground(space, creature.global_position + right * half_w)
		var hl := _ground(space, creature.global_position - right * half_w)
		var k := clampf(8.0 * delta, 0.0, 1.0)
		if not is_nan(hf) and not is_nan(hb):
			_pitch = lerpf(_pitch, atan2(hf - hb, half_l * 2.0) * (1.0 if dead else SLOPE_PITCH), k)
		if not is_nan(hr) and not is_nan(hl):
			_roll = lerpf(_roll, atan2(hr - hl, half_w * 2.0) * (1.0 if dead else SLOPE_ROLL), k)
	var lean := 0.0 if dead else -_lean
	model.basis = Basis.from_euler(Vector3(_pitch, 0.0, _roll + lean)) * Basis.from_scale(_model_scale)


func _ground(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 4.0, Creature.WORLD_MASK,
			[creature.get_rid()])
	var hit_info := space.intersect_ray(q)
	return NAN if hit_info.is_empty() else (hit_info.position as Vector3).y


## Arrows reparent themselves to the creature body when they stick (Arrow._stick);
## move each onto the nearest bone so it rides the body as it moves and falls.
func _on_child_entered(node: Node) -> void:
	if node is Node3D and node.is_in_group(&"stuck_arrows"):
		_pin.call_deferred(node)


func _pin(arrow: Node3D) -> void:
	if not is_instance_valid(arrow) or skeleton == null or arrow.get_parent() != creature:
		return
	var bone := nearest_bone(arrow.global_position)
	if bone < 0:
		return
	var holder := _attachments.get(bone) as BoneAttachment3D
	if holder == null:
		holder = BoneAttachment3D.new()
		holder.name = "Pin_%s" % skeleton.get_bone_name(bone)
		skeleton.add_child(holder)
		holder.bone_idx = bone
		_attachments[bone] = holder
	arrow.reparent(holder, true)


## The bone whose segment (head to each child's head) passes closest to `point`.
func nearest_bone(point: Vector3) -> int:
	if skeleton == null:
		return -1
	var xf := skeleton.global_transform
	var best := -1
	var best_d := INF
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i) in ["root", "body"]:
			continue
		var head := xf * skeleton.get_bone_global_pose(i).origin
		var kids := skeleton.get_bone_children(i)
		if kids.is_empty():
			var d := point.distance_to(head)
			if d < best_d:
				best_d = d
				best = i
			continue
		for c in kids:
			var tail := xf * skeleton.get_bone_global_pose(c).origin
			var d := point.distance_to(Geometry3D.get_closest_point_to_segment(point, head, tail))
			if d < best_d:
				best_d = d
				best = i
	return best

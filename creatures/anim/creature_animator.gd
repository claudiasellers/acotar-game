## Drives a rigged creature model (tools/blender/creature_rig.py) from how the
## creature moves and what happens to it. Contract: docs/contracts/creature_motion.md.
##
## An AnimationTree blend tree. One gait at a time (the model's own, from its
## gaits file: walk, trot, gallop for a quadruped, walk, run for a biped; or
## the stalk on the brain's `gait_hint`), picked from the body's real ground
## speed with hysteresis and cross-faded over a fraction of a second. Every
## gait clip runs at the same strides per second, so they stay in step through
## a change, and that cadence is the ground speed over the stride length of
## whatever is playing (data/animation/creatures/<model>_gaits.txt): a planted
## paw stays where it landed at any speed. From standing the stride grows with
## the speed. On top: graze by `gait_hint`, `alert` by set_alert(), an action
## layer for attacks and other one-off clips (play_attack, play_oneshot), two
## one-shot flinches (hit_l, hit_r) and a final transition into a death clip
## that falls away from the last blow. On top of the clips: the body pitches
## and rolls with the slope and leans into fast turns, the corpse lies along
## the ground, and arrows that stick in the body ride the nearest bone.
class_name CreatureAnimator
extends Node

const GAITS_FILE := "res://data/animation/creatures/%s_gaits.txt"
const LOOPS: Array[StringName] = [&"idle", &"walk", &"trot", &"gallop", &"run", &"stalk", &"graze", &"alert"]
## The gaits of a model whose table names none.
const LOCO: Array[StringName] = [&"walk", &"trot", &"gallop"]
## Clips with a native speed that are layers or states, not steps of the gait ladder.
const NOT_LOCO: Array[StringName] = [&"idle", &"stalk", &"swim"]
## The action layer's fades (seconds).
const ACTION_IN := 0.07
const ACTION_OUT := 0.22
## Cadence limit: past this the legs look frantic.
const MAX_RATE := 1.7
## Below this share of the walk's native speed the stride shortens (and the
## body settles toward idle) instead of the legs slowing further.
const SHORT_STRIDE := 0.6
## A gait changes when the speed passes the midpoint (geometric) of the two
## native speeds by this margin, up or down, so it never flickers at a boundary.
const GAIT_MARGIN := 0.12
## How fast one gait gives way to the next (per second).
const GAIT_SHIFT := 4.0
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
## Length (s) of each clip as imported.
var clip_lengths: Dictionary = {}
## Metres the body covers in one cycle of each gait clip.
var strides: Dictionary = {}
## This model's gait ladder, slowest first (from the gaits file).
var loco: Array[StringName] = []
## Seconds into a clip at which its blow lands, and metres the clip expects the
## code to carry the body (attack and reaction clips; from the gaits file).
var clip_contact: Dictionary = {}
var clip_travel: Dictionary = {}
var dead: bool = false
## The flank it fell onto: -1 left, +1 right (0 while alive).
var fell_to: int = 0
## Playback rate of the whole body (staging slows it; see slow()).
var time_scale: float = 1.0
var _manual: bool = false
var _slow_tween: Tween
## Which side the last arrow struck: -1 left, +1 right (0 none yet).
var last_hit_side: int = 0

## The gait in play: an index into `loco`.
var gait: int = 0
## Strides per second of every gait clip.
var cadence: float = 0.0
var _speed: float = 0.0
## How far each gait above the first has taken over from the one below (0..1).
var _shift: Array[float] = []
var _alert_on: bool = false
var _alert: float = 0.0
var _action_node: AnimationNodeAnimation
var _death_nodes: Dictionary = {}
var _action_queue: Array[StringName] = []
var _action_left: float = 0.0
var _action_mix: float = 0.0
var _action_on: bool = false
var _action_hold: bool = false
var _action_loop: bool = false
var _death_clip: StringName = &"death_l"
var _stalk: float = 0.0
var _graze: float = 0.0
## Gait clip -> the tree parameter of its playback rate.
var _rate_params: Dictionary = {}
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


## For a model played without an animator (a story actor's): marks as looping
## every clip its gaits file says loops. Returns how many it marked.
static func apply_loops(player: AnimationPlayer, gaits_path: String) -> int:
	var n := 0
	var table := read_gaits(gaits_path)
	for clip: StringName in table:
		if table[clip][2] and player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			n += 1
	return n


## The gait table for this model: name -> [native speed or -1, length, loops,
## contact_s or -1, travel_m]. The last three are false, -1, 0 in older tables.
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
		var loops := parts.size() > 3 and parts[3] == "1"
		var contact := parts[4].to_float() if parts.size() > 4 and parts[4] != "-" else -1.0
		var travel := parts[5].to_float() if parts.size() > 5 and parts[5] != "-" else 0.0
		out[StringName(parts[0])] = [speed, parts[2].to_float(), loops, contact, travel]
	return out


func _read_gaits(data: CreatureData) -> void:
	var model_name := data.model_scene.resource_path.get_file().get_basename() if data.model_scene else String(data.kind)
	var table := read_gaits(GAITS_FILE % model_name)
	for clip in table:
		var row: Array = table[clip]
		clip_lengths[clip] = row[1]
		if row[0] > 0.0:
			native_speeds[clip] = row[0] * data.model_scale
			# Metres per cycle as authored; the imported clip may be a frame longer.
			strides[clip] = row[0] * row[1] * data.model_scale
			if clip not in NOT_LOCO and anim.has_animation(clip):
				loco.append(clip)
		if anim.has_animation(clip):
			clip_lengths[clip] = anim.get_animation(clip).length
			if row[2]:
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if row[3] >= 0.0:
			clip_contact[clip] = row[3]
		if row[4] != 0.0:
			clip_travel[clip] = row[4] * data.model_scale
	loco.sort_custom(func(a: StringName, b: StringName) -> bool: return native_speeds[a] < native_speeds[b])
	if not loco.is_empty():
		_shift.resize(loco.size())
		_shift.fill(0.0)
		return
	# A model without a table still moves: guess from the creature's own speeds.
	loco = LOCO.duplicate()
	_shift.resize(loco.size())
	_shift.fill(0.0)
	for i in LOCO.size():
		var clip := LOCO[i]
		if not native_speeds.has(clip):
			native_speeds[clip] = [data.walk_speed, (data.walk_speed + data.run_speed) * 0.3, data.run_speed * 0.8][i]
			clip_lengths[clip] = anim.get_animation(clip).length if anim.has_animation(clip) else 1.0
			strides[clip] = float(native_speeds[clip]) * float(clip_lengths[clip])


func _set_loops() -> void:
	for clip in LOOPS:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


func _anim_node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


## A gait clip behind its own rate, so every gait can run at one cadence.
func _add_gait(bt: AnimationNodeBlendTree, clip: StringName) -> StringName:
	var rate := StringName("%s_rate" % clip)
	bt.add_node(clip, _anim_node(clip))
	bt.add_node(rate, AnimationNodeTimeScale.new())
	bt.connect_node(rate, 0, clip)
	_rate_params[clip] = StringName("parameters/%s/scale" % rate)
	return rate


## Blends `over` onto `under`; both keep running, so they stay in step.
func _add_mix(bt: AnimationNodeBlendTree, mix: StringName, under: StringName, over: StringName) -> StringName:
	var node := AnimationNodeBlend2.new()
	node.sync = true
	bt.add_node(mix, node)
	bt.connect_node(mix, 0, under)
	bt.connect_node(mix, 1, over)
	return mix


func _build_tree() -> void:
	var bt := AnimationNodeBlendTree.new()
	bt.add_node(&"idle", _anim_node(&"idle"))
	var last := &"idle"
	for clip in loco:
		last = _add_mix(bt, StringName("%s_mix" % clip), last, _add_gait(bt, clip))
	if anim.has_animation(&"stalk"):
		last = _add_mix(bt, &"stalk_mix", last, _add_gait(bt, &"stalk"))
	if anim.has_animation(&"graze"):
		bt.add_node(&"graze", _anim_node(&"graze"))
		bt.add_node(&"graze_mix", AnimationNodeBlend2.new())
		bt.connect_node(&"graze_mix", 0, last)
		bt.connect_node(&"graze_mix", 1, &"graze")
		last = &"graze_mix"
	if anim.has_animation(&"alert"):
		bt.add_node(&"alert", _anim_node(&"alert"))
		bt.add_node(&"alert_mix", AnimationNodeBlend2.new())
		bt.connect_node(&"alert_mix", 0, last)
		bt.connect_node(&"alert_mix", 1, &"alert")
		last = &"alert_mix"
	# The action layer: one clip at a time, restarted by a seek and faded by
	# hand, so a telegraph runs straight into its attack with no dip between.
	_action_node = _anim_node(&"idle")
	bt.add_node(&"action", _action_node)
	bt.add_node(&"action_seek", AnimationNodeTimeSeek.new())
	bt.connect_node(&"action_seek", 0, &"action")
	bt.add_node(&"action_mix", AnimationNodeBlend2.new())
	bt.connect_node(&"action_mix", 0, last)
	bt.add_node(&"action_scale", AnimationNodeTimeScale.new())
	bt.connect_node(&"action_scale", 0, &"action_seek")
	bt.connect_node(&"action_mix", 1, &"action_scale")
	last = &"action_mix"
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
	# Two inputs per flank as before; a special death (death_throat) plays on
	# the flank's input with its clip swapped in.
	for input in [&"alive", &"death_l", &"death_r"]:
		life.add_input(input)
	bt.add_node(&"life", life)
	for clip in [&"death_l", &"death_r"]:
		_death_nodes[clip] = _anim_node(clip)
		bt.add_node(clip, _death_nodes[clip])
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
	# A Transition starts on no input at all: without this nothing plays until he dies.
	tree.set(&"parameters/life/transition_request", "alive")
	anim.stop()


## The gait (an index into `loco`) for ground speed `speed`, given the one in play.
func gait_for(speed: float, current: int) -> int:
	var g := current
	while g < loco.size() - 1 and speed > _midpoint(g) * (1.0 + GAIT_MARGIN):
		g += 1
	while g > 0 and speed < _midpoint(g - 1) * (1.0 - GAIT_MARGIN):
		g -= 1
	return g


func _midpoint(lower: int) -> float:
	return sqrt(float(native_speeds[loco[lower]]) * float(native_speeds[loco[lower + 1]]))


## Playback rate of the gait in play (1 = the clip's native speed).
func gait_rate() -> float:
	var clip := &"stalk" if _stalk > 0.5 and clip_lengths.has(&"stalk") else loco[gait]
	return cadence * float(clip_lengths.get(clip, 1.0))


## An arrow struck the side its position is on (local x < 0 is the left).
func hit(from: Vector3) -> void:
	if dead or tree == null:
		return
	var local := creature.to_local(from)
	last_hit_side = -1 if local.x < 0.0 else 1
	var shot := &"parameters/hit_l_shot/request" if last_hit_side < 0 else &"parameters/hit_r_shot/request"
	tree.set(shot, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Plays `telegraph_<id>` and then `attack_<id>` on the action layer. Returns
## the seconds from now until the blow lands (the attack clip's contact_s
## after the telegraph), or -1 when the model has no such attack.
func play_attack(id: StringName) -> float:
	var warn := StringName("telegraph_%s" % id)
	var strike := StringName("attack_%s" % id)
	if dead or tree == null or not anim.has_animation(strike):
		return -1.0
	var clips: Array[StringName] = [strike]
	var lead := 0.0
	if anim.has_animation(warn):
		clips.push_front(warn)
		lead = _length(warn)
	_start_actions(clips)
	return lead + float(clip_contact.get(strike, 0.0))


## The wind-up before a blow, on its own so the code can hold or cancel it:
## `telegraph_<id>`, stretched to `seconds` (the attack row's windup_s), its
## last pose held until play_strike, play_attack or cancel_attack. A family
## that calls this has no other tell: a model without the clip is an error.
func play_windup(id: StringName, seconds: float) -> void:
	if dead or tree == null:
		return
	var clip := StringName("telegraph_%s" % id)
	if not anim.has_animation(clip):
		push_error("%s has no %s clip" % [creature.name, clip])
		return
	_start_actions([clip])
	_action_hold = true
	_action_left = maxf(seconds, 0.05)
	tree.set(&"parameters/action_scale/scale", _length(clip) / _action_left)


## The blow alone (`attack_<id>`), after a wind-up the code timed itself.
## Returns the seconds until it lands, or -1 when the model has no such clip.
func play_strike(id: StringName) -> float:
	var strike := StringName("attack_%s" % id)
	if dead or tree == null or not anim.has_animation(strike):
		return -1.0
	_start_actions([strike])
	return float(clip_contact.get(strike, 0.0))


## Stops an attack (or any action clip) where it is and eases back to moving.
func cancel_attack() -> void:
	_action_queue.clear()
	_action_left = 0.0
	_action_on = false
	_action_hold = false
	_action_loop = false


## Plays one clip once on the action layer (startle, call, recover, stagger,
## dodge_l...). Returns its length, or 0 when the model does not have it.
func play_oneshot(clip: StringName) -> float:
	if dead or tree == null or not anim.has_animation(clip):
		return 0.0
	_start_actions([clip])
	return _length(clip)


## Keeps one clip on the action layer, looping, until another play_*, a
## wind-up or cancel_attack replaces it (a briarling's day-long bush pose, a
## sleeper). A clip that does not loop by itself starts over each time it
## ends. Returns its length, or 0 when the model does not have it.
func hold(clip: StringName) -> float:
	if dead or tree == null or not anim.has_animation(clip):
		return 0.0
	_start_actions([clip])
	_action_loop = true
	return _length(clip)


## True while an attack or one-off clip is playing.
func is_acting() -> bool:
	return _action_on


## The clip on the action layer, or &"" when there is none.
func action_clip() -> StringName:
	return _action_node.animation if _action_on else &""


## The looping `alert` layer: head up, looking about. Shows while it stands.
func set_alert(on: bool) -> void:
	_alert_on = on


func _length(clip: StringName) -> float:
	return float(clip_lengths.get(clip, anim.get_animation(clip).length))


func _start_actions(clips: Array[StringName]) -> void:
	_action_queue = clips
	_next_action()


func _next_action() -> void:
	var clip: StringName = _action_queue.pop_front()
	_action_node.animation = clip
	tree.set(&"parameters/action_seek/seek_request", 0.0)
	_action_left = _length(clip)
	_action_on = true
	_action_hold = false
	_action_loop = false
	tree.set(&"parameters/action_scale/scale", 1.0)


func _drive_action(delta: float) -> void:
	if _action_on:
		_action_left -= delta
		if _action_left <= 0.0 and _action_loop:
			_action_left += _length(_action_node.animation)
			if anim.get_animation(_action_node.animation).loop_mode == Animation.LOOP_NONE:
				tree.set(&"parameters/action_seek/seek_request", 0.0)
		elif _action_left <= 0.0:
			if _action_queue.is_empty():
				_action_on = _action_hold
			else:
				_next_action()
	_action_mix = move_toward(_action_mix, 1.0 if _action_on else 0.0, delta / (ACTION_IN if _action_on else ACTION_OUT))
	tree.set(&"parameters/action_mix/blend_amount", smoothstep(0.0, 1.0, _action_mix))


## Falls away from the last blow (struck on the right, it goes down on its
## left flank); with no blow on record, a side fixed by its id. `variant`
## names a special death the model may have (`throat` plays death_throat).
func die(variant: StringName = &"") -> void:
	if dead:
		return
	dead = true
	if last_hit_side != 0:
		fell_to = -last_hit_side
	else:
		fell_to = -1 if hash(creature.creature_id) % 2 == 0 else 1
	var flank := &"death_l" if fell_to < 0 else &"death_r"
	_death_clip = flank
	var special := StringName("death_%s" % variant)
	if variant != &"" and anim.has_animation(special):
		_death_clip = special
	if tree:
		cancel_attack()
		for clip in [&"hit_l_shot", &"hit_r_shot"]:
			tree.set("parameters/%s/request" % clip, AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
		(_death_nodes[flank] as AnimationNodeAnimation).animation = _death_clip
		tree.set(&"parameters/life/transition_request", String(flank))


## Seconds the death clip runs before the body is still.
func death_length() -> float:
	return float(clip_lengths.get(_death_clip, 3.0))


## A BoneAttachment3D riding the named bone (a model's sockets: throat, mouth,
## grab_point, talon_l...), or null when the model has no such bone.
func socket(bone_name: StringName) -> BoneAttachment3D:
	if skeleton == null:
		return null
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return null
	var holder := _attachments.get(bone) as BoneAttachment3D
	if holder == null:
		holder = BoneAttachment3D.new()
		holder.name = "Pin_%s" % bone_name
		skeleton.add_child(holder)
		holder.bone_idx = bone
		_attachments[bone] = holder
	return holder


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
	_drive_action(delta * time_scale)
	_conform(delta)


func _drive_gait(delta: float) -> void:
	# Where the body really went, not where the brain wanted it: a wolf held
	# by a wall doesn't paddle.
	var v := creature.get_real_velocity()
	_speed = lerpf(_speed, Vector2(v.x, v.z).length(), clampf(14.0 * delta, 0.0, 1.0))
	var speed := _speed if _speed > 0.03 else 0.0
	var hint := creature.gait_hint
	var stalks := anim.has_animation(&"stalk")
	gait = gait_for(speed, gait)
	for i in range(1, loco.size()):
		_shift[i] = move_toward(_shift[i], 1.0 if gait >= i else 0.0, GAIT_SHIFT * delta)
	_stalk = move_toward(_stalk, 1.0 if hint == &"stalk" and stalks else 0.0, LAYER_SPEED * delta)
	_graze = move_toward(_graze, 1.0 if hint == &"graze" and speed < 0.4 else 0.0, LAYER_SPEED * 0.6 * delta)
	# From standing, the stride grows with the speed before the cadence does.
	var stepping := clampf(speed / (SHORT_STRIDE * float(native_speeds[loco[0]])), 0.0, 1.0)
	_shift[0] = stepping
	# Each gait's share: its own shift, less whatever the faster ones have taken.
	var weights := {&"stalk": _stalk}
	var left := 1.0 - _stalk
	for i in range(loco.size() - 1, -1, -1):
		weights[loco[i]] = left * _shift[i]
		left *= 1.0 - _shift[i]
	# One cadence for every gait: ground speed over the stride of the blend,
	# so the paws on the ground move back exactly as fast as the body goes on.
	var metres := 0.0
	var beat := 0.0
	var total := 0.0
	for clip: StringName in weights:
		var w: float = weights[clip]
		if w <= 0.0 or not clip_lengths.has(clip):
			continue
		metres += w * float(strides.get(clip, 0.0))
		beat += w / float(clip_lengths[clip])
		total += w
	# A stalk at speed 0 freezes mid-step: the cadence falls to nothing.
	cadence = 0.0
	if metres > 0.001:
		cadence = minf(speed / metres, MAX_RATE * beat / total)
	for i in loco.size():
		tree.set("parameters/%s_mix/blend_amount" % loco[i], _shift[i])
	for clip: StringName in _rate_params:
		tree.set(_rate_params[clip], cadence * float(clip_lengths.get(clip, 1.0)))
	if stalks:
		tree.set(&"parameters/stalk_mix/blend_amount", _stalk)
	if anim.has_animation(&"graze"):
		tree.set(&"parameters/graze_mix/blend_amount", _graze)
	if anim.has_animation(&"alert"):
		_alert = move_toward(_alert, 1.0 if _alert_on and speed < 0.4 else 0.0, LAYER_SPEED * delta)
		tree.set(&"parameters/alert_mix/blend_amount", _alert)
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
	arrow.reparent(socket(skeleton.get_bone_name(bone)), true)


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

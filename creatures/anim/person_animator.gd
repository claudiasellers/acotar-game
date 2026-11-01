## Drives a rigged villager or court figure (tools/blender/person_rig.py) from
## how its owner moves: idle weight shifts standing, a heel-to-toe walk matched
## to its speed, a talking layer, flinch and bow gestures, and its head turning
## to Feyre when she is near (NoticePlayer). Each figure starts its clips at its
## own offset, so a crowd never breathes or steps in lockstep.
## Contract: docs/contracts/creature_motion.md.
class_name PersonAnimator
extends Node

const GAITS_FILE := "res://data/animation/people/%s_gaits.txt"
const GESTURES: Array[StringName] = [&"flinch", &"bow"]
const MIN_RATE := 0.5
const MAX_RATE := 1.5

var anim: AnimationPlayer
var tree: AnimationTree
var skeleton: Skeleton3D
var mover: Node3D
var notice: NoticePlayer
var native_walk: float = 1.2
## Set by dialogue or scenes: the hands talk while true.
var talking: bool = false

var _talk: float = 0.0
var _speed: float = 0.0
var _last_pos: Vector3
var _started: bool = false


## For a model scene instance `model` carried by `owner_node` (which moves it).
## Null when the model is not rigged.
static func attach(model: Node3D, owner_node: Node3D, model_name: String) -> PersonAnimator:
	if model == null:
		return null
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(&"walk") or not player.has_animation(&"idle"):
		return null
	var a := PersonAnimator.new()
	a.name = "PersonAnimator"
	a.anim = player
	a.mover = owner_node
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	a.skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	var table := CreatureAnimator.read_gaits(GAITS_FILE % model_name)
	if table.has(&"walk") and table[&"walk"][0] > 0.0:
		a.native_walk = table[&"walk"][0] * model.scale.x
	for clip in [&"idle", &"walk", &"talk"]:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	model.add_child(a)
	a._build_tree(model)
	return a


func _build_tree(model: Node3D) -> void:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = native_walk * 3.0
	loco.add_blend_point(_node(&"idle"), 0.0, -1, &"idle")
	loco.add_blend_point(_node(&"walk"), native_walk, -1, &"walk")
	bt.add_node(&"loco", loco)
	bt.add_node(&"loco_rate", AnimationNodeTimeScale.new())
	bt.connect_node(&"loco_rate", 0, &"loco")
	var last := &"loco_rate"
	if anim.has_animation(&"talk"):
		bt.add_node(&"talk", _node(&"talk"))
		bt.add_node(&"talk_mix", AnimationNodeBlend2.new())
		bt.connect_node(&"talk_mix", 0, last)
		bt.connect_node(&"talk_mix", 1, &"talk")
		last = &"talk_mix"
	for clip in GESTURES:
		if not anim.has_animation(clip):
			continue
		var shot := AnimationNodeOneShot.new()
		shot.fadein_time = 0.12
		shot.fadeout_time = 0.35
		var shot_name := StringName("%s_shot" % clip)
		bt.add_node(shot_name, shot)
		bt.add_node(clip, _node(clip))
		bt.connect_node(shot_name, 0, last)
		bt.connect_node(shot_name, 1, clip)
		last = shot_name
	bt.connect_node(&"output", 0, last)
	tree = AnimationTree.new()
	tree.name = "PersonTree"
	tree.tree_root = bt
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(anim)
	tree.active = true
	anim.stop()


func _node(clip: StringName) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


## Plays a one-off gesture: &"flinch" or &"bow".
func gesture(clip: StringName) -> void:
	if tree and clip in GESTURES and anim.has_animation(clip):
		tree.set("parameters/%s_shot/request" % clip, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Playback rate for the idle-walk blend at `speed` m/s: feet match the ground.
func loco_rate(speed: float) -> float:
	if speed < 0.05:
		return 1.0
	return clampf(speed / native_walk, MIN_RATE, MAX_RATE) if speed < native_walk else clampf(speed / native_walk, 1.0, MAX_RATE)


func _process(delta: float) -> void:
	if tree == null or mover == null or not mover.is_inside_tree():
		return
	var model := get_parent() as Node3D
	tree.active = model.is_visible_in_tree()
	if notice:
		notice.enabled = tree.active
	if not tree.active:
		return
	var pos := mover.global_position
	if not _started:
		_started = true
		_last_pos = pos
		# Its own place in the breath and the stride.
		tree.advance(float(hash(mover.get_path()) % 6000) / 1000.0)
		if skeleton:
			notice = NoticePlayer.attach(skeleton, mover)
		return
	var step := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() / maxf(delta, 1e-4)
	_last_pos = pos
	_speed = lerpf(_speed, step, clampf(10.0 * delta, 0.0, 1.0))
	var walking := _speed if _speed > 0.08 else 0.0
	tree.set(&"parameters/loco/blend_position", minf(walking, native_walk))
	tree.set(&"parameters/loco_rate/scale", loco_rate(walking) if walking > 0.0 else 1.0)
	_talk = move_toward(_talk, 1.0 if talking and walking == 0.0 else 0.0, 2.5 * delta)
	if anim.has_animation(&"talk"):
		tree.set(&"parameters/talk_mix/blend_amount", _talk)

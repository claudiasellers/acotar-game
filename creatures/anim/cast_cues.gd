## Story cues a main-cast model acts out on its own (lane L22). A child of the
## cast model, which the story spaces use as the actor (StandIns.figure); it
## answers EventBus.story_actor_cue for the actor whose group the model is in
## (story_actor_<id>).
##
## leaves_sick (Lucien, ch17): he backs off a few unsteady steps from what he
## is looking at, retches twice, bent double, then turns and walks out: to the
## actor's `exit_to` meta (a world point) when the scene sets one, else out of
## the manor's front doors when he is in the hall, else 9 m on, away from the
## sight. Then he is gone from view (hidden, his head-turn off).
class_name CastCues
extends Node

const BACK_STEPS := 1.4       # metres backed off
const BACK_SECONDS := 1.6
const HEAVES := [1.2, 1.3]    # seconds per retch
const STEADY := 0.7           # a breath, upright-ish, before he turns away
const TURN_SECONDS := 0.6
const WALK_SPEED := 1.6       # shaken, not hurrying
const WALK_CLIP_SPEED := 3.2  # the walk clip's authored ground speed
const AWAY := 9.0
## Within this of the manor's front doors he is in the hall and leaves by them.
const HALL_REACH := 16.0

## &"", &"back", &"retch", &"turn", &"walk", &"gone".
var stage: StringName = &""
var hunch: HunchModifier

var _model: Node3D
var _t: float = 0.0
var _from: Vector3
var _away: Vector3       # flat unit vector, away from the sight
var _exit: Vector3
var _yaw_from: float
var _yaw_to: float


static func attach(model: Node3D, sk: Skeleton3D) -> CastCues:
	var c := CastCues.new()
	c.name = "CastCues"
	c._model = model
	if sk:
		c.hunch = HunchModifier.attach(sk)
	model.add_child(c)
	return c


func _ready() -> void:
	EventBus.story_actor_cue.connect(_on_cue)


func _on_cue(actor: StringName, cue: StringName) -> void:
	if not _model.is_in_group(StringName("story_actor_%s" % actor)):
		return
	if cue == &"leaves_sick" and stage in [&"", &"gone"]:
		_leave_sick()


func _anim() -> AnimationPlayer:
	return _model.get(&"anim") as AnimationPlayer if &"anim" in _model else null


func _notice(on: bool) -> void:
	var n: Variant = _model.get(&"notice") if &"notice" in _model else null
	if n is NoticePlayer:
		(n as NoticePlayer).enabled = on


## What turned his stomach: the nearest story actor that is not him (the
## faerie on the table), else what he faces.
func _sight() -> Vector3:
	var me := _model.global_position
	var best := me - _model.global_basis.z * 2.0
	var best_d := INF
	for n in _model.get_tree().get_nodes_in_group(&"story_actor_summer_faerie"):
		var d := (n as Node3D).global_position.distance_to(me)
		if d < best_d:
			best_d = d
			best = (n as Node3D).global_position
	return best


func _leave_sick() -> void:
	_notice(false)
	_model.visible = true
	var me := _model.global_position
	var sight := _sight()
	var flat := Vector3(me.x - sight.x, 0.0, me.z - sight.z)
	_away = flat.normalized() if flat.length() > 0.05 else _model.global_basis.z
	# He faces the sight while he backs off from it.
	_face(-_away)
	var exit: Variant = _model.get_meta(&"exit_to") if _model.has_meta(&"exit_to") else null
	var door := ManorSitePlan.FRONT_DOOR
	if exit is Vector3:
		_exit = exit
	elif Vector2(me.x - door.x, me.z - door.z).length() < HALL_REACH:
		# In the manor's hall: out through the front doors.
		_exit = Vector3(door.x, me.y, door.z + 0.8)
	else:
		_exit = me + _away * (BACK_STEPS + AWAY)
	_from = me
	_t = 0.0
	stage = &"back"
	var anim := _anim()
	if anim and anim.has_animation(&"walk"):
		anim.play(&"walk", 0.25, -(BACK_STEPS / BACK_SECONDS) / WALK_CLIP_SPEED * 1.4)


func _face(dir: Vector3) -> void:
	_model.rotation.y = atan2(-dir.x, -dir.z)


func _process(delta: float) -> void:
	if stage in [&"", &"gone"]:
		return
	_t += delta
	var anim := _anim()
	match stage:
		&"back":
			# Unsteady: fast off the mark, slowing, a small stagger to the side.
			var k := clampf(_t / BACK_SECONDS, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 2.2)
			var side := _away.cross(Vector3.UP) * sin(k * PI) * 0.12
			_model.global_position = _from + _away * BACK_STEPS * e + side
			if hunch:
				hunch.amount = 0.25 * k
			if k >= 1.0:
				stage = &"retch"
				_t = 0.0
				if anim and anim.has_animation(&"idle"):
					anim.play(&"idle", 0.3, 1.0)
		&"retch":
			# Two heaves: bent double fast, held, half up; the second weaker.
			var total := 0.0
			for h: float in HEAVES:
				total += h
			var t := _t
			var amt := 0.3
			var i := 0
			for h: float in HEAVES:
				if t < h:
					var p := t / h
					var heave := smoothstep(0.0, 0.18, p) * (1.0 - smoothstep(0.55, 1.0, p))
					amt = 0.35 + heave * (1.0 - 0.25 * i)
					break
				t -= h
				i += 1
			if _t >= total:
				amt = lerpf(0.35, 0.1, clampf((_t - total) / STEADY, 0.0, 1.0))
			if hunch:
				hunch.amount = amt
			if _t >= total + STEADY:
				stage = &"turn"
				_t = 0.0
				_yaw_from = _model.rotation.y
				var to := Vector3(_exit.x - _model.global_position.x, 0.0, _exit.z - _model.global_position.z)
				_yaw_to = atan2(-to.x, -to.z)
				if anim and anim.has_animation(&"walk"):
					anim.play(&"walk", 0.3, WALK_SPEED / WALK_CLIP_SPEED)
		&"turn":
			var k := clampf(_t / TURN_SECONDS, 0.0, 1.0)
			_model.rotation.y = lerp_angle(_yaw_from, _yaw_to, smoothstep(0.0, 1.0, k))
			_model.global_position += -_model.global_basis.z * WALK_SPEED * 0.5 * delta
			if hunch:
				hunch.amount = 0.1
			if k >= 1.0:
				stage = &"walk"
				_t = 0.0
		&"walk":
			var to := Vector3(_exit.x - _model.global_position.x, 0.0, _exit.z - _model.global_position.z)
			if to.length() < 0.3:
				_gone()
				return
			var step := minf(WALK_SPEED * delta, to.length())
			_face(to.normalized())
			_model.global_position += to.normalized() * step
			if hunch:
				hunch.amount = 0.1


## Out of the hall: out of sight. Kept, not freed, so the story can still find him.
func _gone() -> void:
	stage = &"gone"
	if hunch:
		hunch.amount = 0.0
	var anim := _anim()
	if anim and anim.has_animation(&"idle"):
		anim.play(&"idle")
	_model.visible = false

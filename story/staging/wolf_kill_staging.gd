## The wolf kill, staged like a film (lane L22). It lives as a child of the
## WolfKill space (one line in wolf_kill.gd) and only listens: the beats,
## flags and canon stay with the scene.
##
## - The doe (the scene's first focus, lane L34-4): her camera drifts to the
##   doe and the lens closes a little, no bars, so the player sees what she's
##   hunting before anything else happens.
## - Lining up the shot (L34-4): while she holds the bow drawn and aimed on
##   him, the lens tightens and the bars edge in; the bow's own slow draw
##   slows the world (BowController, unchanged: this never touches time or
##   the arrow). It lets go when she looses, lowers or looks away.
## - His eyes (the scene's focus on him): the lens tightens on him through
##   Feyre's own camera, she keeps full control to draw, and the bars come in
##   halfway. They ease out when the focus lets go.
## - The ash arrow: a hit-stop. His body freezes for an instant under the
##   impact, her view jolts, and the lens closes on him while he looks at her.
## - The kill: his body goes into slow motion as the second arrow lands. A
##   cut to a low long-lens angle from the side he falls toward shows the face,
##   the arrows and the legs going out, with a slow push in. Then a cut behind
##   Feyre's shoulder looks down the clearing at him while he breathes his
##   last, before easing back into her camera. Her controls are held for these
##   few seconds; interact skips to the end once he is down.
class_name WolfKillStaging
extends Node

const DOE_FOV := 48.0
const AIM_FOV := 40.0
const AIM_BARS := 0.3
## Degrees off him her view may be and still count as lined up (and the
## wider angle at which it lets go again).
const AIM_ON_DEG := 9.0
const AIM_OFF_DEG := 16.0
const NOTICE_FOV := 36.0
const NOTICE_BARS := 0.5
const ASH_LOOK_FOV := 54.0
const ASH_LOOK := 1.8
const DEATH_FOV := 34.0
const DEATH_DIST := 6.0
const DEATH_HEIGHT := 0.85
const SHOULDER_FOV := 20.0
## Real seconds for each piece of the kill.
const BEAT_IN := 0.3
const FALL_HOLD := 4.2
const LAST_BREATHS := 3.6
const RELEASE := 1.8
const SKIP_AFTER := 1.5

var space: Node
## Where the kill is: &"" idle, &"fall", &"breaths", &"release", &"done".
var stage: StringName = &""

var _noticing: bool = false
var _on_doe: bool = false
## The lens is tightened on him for a drawn, aimed shot.
var aiming: bool = false
var _skip: bool = false
var _since: float = 0.0
## Another scene took over during the kill shots.
var _yielded: bool = false


func _ready() -> void:
	space = get_parent()
	EventBus.creature_hit.connect(_on_hit)
	EventBus.creature_killed.connect(_on_killed)
	EventBus.scene_space_finished.connect(_on_space_finished)
	EventBus.scene_space_started.connect(_on_space_started)
	StoryControl.focus_changed.connect(_on_focus)


func _running() -> bool:
	return space != null and bool(space.get(&"running"))


func _wolf() -> Node3D:
	var w: Variant = space.get(&"wolf") if space else null
	return w as Node3D if is_instance_valid(w) and w is Node3D else null


func _doe() -> Node3D:
	var d: Variant = space.get(&"doe") if space else null
	return d as Node3D if is_instance_valid(d) and d is Node3D else null


func _animator() -> CreatureAnimator:
	var w := _wolf()
	return w.get(&"animator") as CreatureAnimator if w else null


func _on_focus(target: Node3D) -> void:
	if not _running() or stage != &"":
		return
	var cine := _cine()
	if target != null and target == _wolf():
		_on_doe = false
		aiming = false
		_noticing = true
		cine.follow(NOTICE_FOV, 0.9)
		cine.bars_to(NOTICE_BARS, 0.9)
	elif target != null and target == _doe():
		_on_doe = true
		cine.follow(DOE_FOV, 1.2)
	elif target == null and (_noticing or _on_doe):
		_noticing = false
		_on_doe = false
		cine.drop(self, 1.4)


func _on_hit(_id: StringName, kind: StringName, cause: StringName, _part: StringName) -> void:
	if not _running() or kind != &"great_wolf" or cause != &"arrow_ash" or stage != &"":
		return
	aiming = false
	var anim := _animator()
	if anim:
		anim.slow(0.06, 0.12, 0.3)
	_jolt(0.35, 0.35)
	# He whirls and looks at her once: the lens closes on his face for the look.
	var cine := _cine()
	cine.follow(ASH_LOOK_FOV, 0.35)
	cine.bars_to(NOTICE_BARS, 0.35)
	await _real(ASH_LOOK)
	if stage == &"" and cine.target_kind == &"follow":
		cine.drop(self, 1.0)


func _on_killed(_id: StringName, kind: StringName, _cause: StringName, _at: Vector3) -> void:
	if kind != &"great_wolf" or not _running() or stage != &"":
		return
	_kill.call_deferred()


## The scene may end (and release her controls) while the kill still plays.
func _on_space_finished(space_id: StringName) -> void:
	if (stage == &"fall" or stage == &"breaths") and not _yielded and space_id == _own_id():
		StoryControl.set_mode(StoryControl.Mode.NONE)


## Another scene starting owns her controls: the kill cuts back to her camera
## and leaves StoryControl alone.
func _on_space_started(space_id: StringName) -> void:
	if (stage == &"fall" or stage == &"breaths") and space_id != _own_id():
		_yielded = true
		_end()


func _own_id() -> StringName:
	var id: Variant = space.get(&"space_id") if space else null
	return StringName(id) if id != null else &"wolf_kill"


func _kill() -> void:
	var wolf := _wolf()
	if wolf == null:
		return
	stage = &"fall"
	_since = 0.0
	_noticing = false
	StoryControl.set_mode(StoryControl.Mode.NONE)
	var anim := _animator()
	if anim:
		anim.slow(0.3, 0.45, 1.2)
	await _real(BEAT_IN)
	if stage != &"fall" or not is_instance_valid(wolf):
		return
	var cine := _cine()
	cine.bars_to(1.0, 0.35)
	var chest := func() -> Vector3: return _chest(wolf)
	var spot := _death_spot(wolf)
	cine.shot(Transform3D(Basis.looking_at(chest.call() - spot, Vector3.UP), spot), DEATH_FOV, 0.0,
			chest, 1.0, FALL_HOLD + 0.5)
	await _real(FALL_HOLD)
	if stage == &"fall" and is_instance_valid(wolf):
		stage = &"breaths"
		var over := _shoulder_spot(wolf)
		if over != Vector3.INF:
			cine.shot(Transform3D(Basis.looking_at(chest.call() - over, Vector3.UP), over), SHOULDER_FOV,
					0.0, chest, 0.5, LAST_BREATHS + 0.5)
		await _real(LAST_BREATHS)
	_end()


func _end() -> void:
	if stage == &"release" or stage == &"done":
		return
	stage = &"release"
	Cine.of(get_tree()).drop(self, RELEASE)
	if not _yielded:
		StoryControl.release()
	await _real(RELEASE)
	stage = &"done"


func _process(delta: float) -> void:
	if stage == &"fall" or stage == &"breaths":
		_since += delta / maxf(Engine.time_scale, 0.01)
	elif stage == &"" and _running() and not _noticing and not _on_doe:
		_line_up()


## The drawn, aimed shot on him: tighten while lined up, let go otherwise.
func _line_up() -> void:
	var wolf := _wolf()
	var feyre := get_tree().get_first_node_in_group(&"player")
	var bow: Variant = feyre.get(&"bow_controller") if feyre else null
	var cam: Variant = feyre.get(&"camera") if feyre else null
	var want := false
	if wolf and bow is BowController and cam is Camera3D and not bool(space.get(&"wolf_dead")):
		var drawing := (bow as BowController).is_drawing and Input.is_action_pressed(&"aim")
		var off := aim_off_degrees(cam as Camera3D, _chest(wolf))
		want = drawing and off <= (AIM_OFF_DEG if aiming else AIM_ON_DEG)
	if want and not aiming:
		aiming = true
		var cine := _cine()
		cine.follow(AIM_FOV, 0.5)
		cine.bars_to(AIM_BARS, 0.5)
	elif not want and aiming:
		aiming = false
		var cine := Cine.of(get_tree())
		cine.bars_to(0.0, 0.5)
		cine.drop(self, 0.6)


## Degrees between where `cam` looks and `point`.
static func aim_off_degrees(cam: Camera3D, point: Vector3) -> float:
	var fwd := -cam.global_basis.z
	var to := point - cam.global_position
	if to.length() < 0.01:
		return 0.0
	return rad_to_deg(fwd.angle_to(to.normalized()))


func _unhandled_input(event: InputEvent) -> void:
	if (stage == &"fall" or stage == &"breaths") and _since >= SKIP_AFTER \
			and event.is_action_pressed(&"interact"):
		_end()


## A low spot on the side he falls toward (his belly, legs and face turn to
## it), a little ahead of him, that sees him past the trees.
func _death_spot(wolf: Node3D) -> Vector3:
	var anim := _animator()
	var side := 1.0
	if anim and anim.fell_to != 0:
		side = -float(anim.fell_to)
	var b := wolf.global_basis
	var dirs: Array[Vector3] = []
	for deg in [0.0, 25.0, -25.0, 50.0, -50.0, 80.0]:
		var local := Vector3(side, 0.0, -0.9).normalized().rotated(Vector3.UP, deg_to_rad(deg) * side)
		dirs.append(b * local)
	return Cine.clear_view(wolf.get_world_3d(), wolf.global_position, dirs, DEATH_DIST, DEATH_HEIGHT,
			_rids(wolf))


## Just behind and above Feyre's right shoulder, looking down the line to
## him. INF when there is no clear line (she is deep in the thicket).
func _shoulder_spot(wolf: Node3D) -> Vector3:
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre == null:
		return Vector3.INF
	var to := wolf.global_position - feyre.global_position
	to.y = 0.0
	if to.length() < 2.0:
		return Vector3.INF
	var dir := to.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	# Well back with a long lens: her shoulder a dark edge of frame, him large.
	var spot := feyre.global_position - dir * 3.5 + right * 0.8 + Vector3.UP * 1.95
	var q := PhysicsRayQueryParameters3D.create(spot, _chest(wolf))
	var exclude := _rids(wolf)
	if feyre is CollisionObject3D:
		exclude.append((feyre as CollisionObject3D).get_rid())
	q.exclude = exclude
	if not wolf.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return Vector3.INF
	return spot


func _chest(wolf: Node3D) -> Vector3:
	if not is_instance_valid(wolf):
		return Vector3.ZERO
	var anim := wolf.get(&"animator") as CreatureAnimator
	if anim and anim.skeleton:
		var bone := anim.skeleton.find_bone("chest")
		if bone >= 0:
			return anim.skeleton.global_transform * anim.skeleton.get_bone_global_pose(bone).origin
	return wolf.global_position + Vector3.UP * 0.8


func _rids(wolf: Node3D) -> Array[RID]:
	var out: Array[RID] = []
	if wolf is CollisionObject3D:
		out.append((wolf as CollisionObject3D).get_rid())
	return out


## A jolt in her view: `amount` of StoryControl's shake, gone in `seconds`.
func _jolt(amount: float, seconds: float) -> void:
	StoryControl.shake = maxf(StoryControl.shake, amount)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(StoryControl, ^"shake", 0.0, seconds).set_ease(Tween.EASE_OUT)


func _real(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## The film camera, taken for this scene's next move.
func _cine() -> Cine:
	var cine := Cine.of(get_tree())
	cine.claim(self)
	return cine

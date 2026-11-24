## The ch1 wolf hunt's rim light (lane L18). A child of the WolfKill space,
## like WolfKillStaging; it only listens. The hunt's light is the overcast
## day itself (human_winter's daylight dread look, GradePreset.dread_day_look);
## this adds one thing: a cold rim on the doe and on the great wolf, a short
## spot behind each on the far side from the camera, so back, ears and the
## wolf's ruff edge against the grey woods. No light on the clearing itself
## (L18-14: a pool of light there blew the centre snow to white).
##
## Lights only: the beats, the camera, time and the doe look are untouched.
## The rims come up as the hunt starts and go once it ends.
class_name WolfHuntLighting
extends Node

const RIM_COLOR := Color(0.74, 0.82, 1.0)
const RIM_ENERGY := 12.0
## Ends just past the body, so the rim never pools on the snow behind it.
const RIM_RANGE := 3.0
const RIM_ANGLE := 40.0
## Rim offset from the actor's body: past it, away from the camera, and up.
const RIM_BACK := 1.6
const RIM_UP := 2.4
## Body centre height above the actor's origin.
const BODY_UP := 0.8
## Seconds for the rims to come up, and to go again after the hunt.
const FADE_IN := 3.0
const FADE_OUT := 6.0

var space: Node
## Scales the rims (tuning and probes; 1 in game).
var gain := 1.0
## 0 = no rims, 1 = full.
var amount := 0.0
var doe_rim: SpotLight3D
var wolf_rim: SpotLight3D


func _ready() -> void:
	space = get_parent()


func _running() -> bool:
	return space != null and bool(space.get(&"running"))


func _process(delta: float) -> void:
	var on := _running()
	if on and doe_rim == null:
		_build()
	if doe_rim == null:
		return
	amount = move_toward(amount, 1.0 if on else 0.0, delta / (FADE_IN if on else FADE_OUT))
	_rim(doe_rim, _actor(&"doe"))
	_rim(wolf_rim, _actor(&"wolf"))
	if amount <= 0.0 and not on:
		_clear()


func _build() -> void:
	var parent := space as Node3D
	if parent == null:
		return
	doe_rim = _make_rim("DoeRim")
	wolf_rim = _make_rim("WolfRim")
	parent.add_child(doe_rim)
	parent.add_child(wolf_rim)


func _make_rim(rim_name: String) -> SpotLight3D:
	var rim := SpotLight3D.new()
	rim.name = rim_name
	rim.light_color = RIM_COLOR
	rim.spot_range = RIM_RANGE
	rim.spot_angle = RIM_ANGLE
	rim.spot_attenuation = 1.0
	rim.shadow_enabled = false
	rim.light_energy = 0.0
	rim.visible = false
	return rim


## A rim behind `actor` as the camera sees it; hidden without an actor.
func _rim(rim: SpotLight3D, actor: Node3D) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if actor == null or cam == null:
		rim.visible = false
		return
	var body := actor.global_position + Vector3.UP * BODY_UP
	var away := body - cam.global_position
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	rim.global_position = body + away * RIM_BACK + Vector3.UP * RIM_UP
	rim.look_at(body, Vector3.UP)
	rim.light_energy = RIM_ENERGY * amount * gain
	rim.visible = amount > 0.0


func _actor(key: StringName) -> Node3D:
	var a: Variant = space.get(key) if space != null else null
	return a as Node3D if is_instance_valid(a) and a is Node3D else null


func _clear() -> void:
	for l: Light3D in [doe_rim, wolf_rim]:
		if l != null and is_instance_valid(l):
			l.queue_free()
	doe_rim = null
	wolf_rim = null
	amount = 0.0

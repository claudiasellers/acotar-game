## The ch1 wolf hunt, lit so it reads (lane L18-11). A child of the WolfKill
## space, like WolfKillStaging; it only listens. The user found the hunt "a
## little dark ALL around": the scene's dread took the winter day toward the
## night-horror grade. human_winter now has a daylight dread look (overcast,
## drained, the fog closing in; GradePreset.dread_day_look), and this rig adds
## the light a player believes in, while the woods round the clearing stay
## grey and blind:
##
## - A break in the overcast: a wide cold shaft from high over the clearing,
##   shadowed, so the trunks lay bars across the snow and the shaft shows in
##   the fog. The clearing becomes a stage; the doe stands in its light.
## - A cold rim on the doe and on the great wolf: a short spot behind each,
##   on the far side from the camera, so back, ears and the wolf's ruff edge
##   against the grey woods (his golden eyes stay his own).
##
## Lights only: the beats, the camera, time and the doe look are untouched.
## The break opens as the hunt starts and closes once it ends.
class_name WolfHuntLighting
extends Node

const BREAK_COLOR := Color(0.86, 0.9, 1.0)
const BREAK_ENERGY := 8.0
const BREAK_RANGE := 70.0
const BREAK_ANGLE := 24.0
## Where the break hangs from the doe's spot: high, and back toward the south
## (behind the thicket side) so it rakes across the clearing.
const BREAK_FROM := Vector3(-6.0, 34.0, 14.0)
## How much of the shaft shows in the volumetric fog.
const BREAK_FOG := 0.6
const RIM_COLOR := Color(0.74, 0.82, 1.0)
const RIM_ENERGY := 18.0
const RIM_RANGE := 6.0
const RIM_ANGLE := 40.0
## Rim offset from the actor's body: past it, away from the camera, and up.
const RIM_BACK := 1.6
const RIM_UP := 2.4
## Body centre height above the actor's origin.
const BODY_UP := 0.8
## Seconds for the cloud to open, and to close again after the hunt.
const OPEN_SECONDS := 3.0
const CLOSE_SECONDS := 6.0

var space: Node
## Scales every light of the rig (tuning and probes; 1 in game).
var gain := 1.0
## 0 = the day's own light, 1 = the full rig.
var amount := 0.0
var cloud_break: SpotLight3D
var doe_rim: SpotLight3D
var wolf_rim: SpotLight3D


func _ready() -> void:
	space = get_parent()


func _running() -> bool:
	return space != null and bool(space.get(&"running"))


func _process(delta: float) -> void:
	var on := _running()
	if on and cloud_break == null:
		_build()
	if cloud_break == null:
		return
	amount = move_toward(amount, 1.0 if on else 0.0, delta / (OPEN_SECONDS if on else CLOSE_SECONDS))
	_place_break()
	_rim(doe_rim, _actor(&"doe"))
	_rim(wolf_rim, _actor(&"wolf"))
	cloud_break.light_energy = BREAK_ENERGY * amount * gain
	if amount <= 0.0 and not on:
		_clear()


func _build() -> void:
	var parent := space as Node3D
	if parent == null:
		return
	cloud_break = SpotLight3D.new()
	cloud_break.name = "CloudBreak"
	cloud_break.light_color = BREAK_COLOR
	cloud_break.spot_range = BREAK_RANGE
	cloud_break.spot_angle = BREAK_ANGLE
	cloud_break.spot_attenuation = 0.3
	cloud_break.spot_angle_attenuation = 2.0
	cloud_break.shadow_enabled = true
	cloud_break.light_volumetric_fog_energy = BREAK_FOG
	cloud_break.light_energy = 0.0
	parent.add_child(cloud_break)
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


## Over the doe's spot (where she grazes, or where the space put her), so the
## pool of light is the clearing.
func _place_break() -> void:
	var doe := _actor(&"doe")
	var centre := doe.global_position if doe != null else (space as Node3D).global_position
	var parent := space as Node3D
	var offset := parent.global_basis * BREAK_FROM if parent != null else BREAK_FROM
	cloud_break.global_position = centre + offset
	cloud_break.look_at(centre, Vector3.FORWARD if absf(offset.normalized().y) > 0.99 else Vector3.UP)


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
	for l: Light3D in [cloud_break, doe_rim, wolf_rim]:
		if l != null and is_instance_valid(l):
			l.queue_free()
	cloud_break = null
	doe_rim = null
	wolf_rim = null
	amount = 0.0

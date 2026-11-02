## The beast at the door, lit so he reads (lane L55). A child of the BeastDoor
## space, like BeastDoorStaging. The dread grade takes the exposure down more
## than two stops and crushes the ambient, which is right for the room but
## left the cottage black: the user "couldn't see anything". This rig gives
## the scene three motivated lights, so the dark between them stays dark:
##
## - Moon through the broken door: a cold shadowed spot from outside, so the
##   doorway becomes a pale shaft and his body comes through it in silhouette.
## - The hearth: the room's fire flares with the gust from the door and burns
##   high, a warm key on his face, Feyre and her father (the hearth's own
##   shadowed FireLight is turned up, not doubled).
## - A rim on his back: a short cold spot behind his head and shoulders,
##   following him, so horns, mane and spine edge against the dark.
##
## Lights only: the grade, the camera and the beats are untouched. Everything
## fades back to the room's own light when the scene ends.
class_name BeastDoorLighting
extends Node

const MOON_COLOR := Color(0.68, 0.78, 1.0)
const MOON_ENERGY := 35.0
const MOON_RANGE := 14.0
const MOON_ANGLE := 30.0
## How far outside, and how high, the moon spot hangs from the door.
const MOON_BACK := 4.5
const MOON_UP := 3.4
## The hearth's FireLight is multiplied by this while the scene runs. The dread
## grade's exposure is 0.19 against the winter grade's 0.85 (x0.22) and its
## ambient is near black, so the fire must burn far hotter to carry the room:
## measured on the Mac (Forward+, beast_door_light_probe), without the back glow
## he was 3-6 of 255; with the full rig he reads at 19-31 (eyes, horns and mane against
## a pale moonlit wall), 58-96% of each frame stays near black, and under 1% of
## pixels pass 235. The door-burst shot stays a silhouette on purpose.
const FIRE_GAIN := 14.0
## The gust through the broken door: the fire leaps to this, then settles.
const FIRE_FLARE := 22.0
const FLARE_SECONDS := 0.9
const RIM_COLOR := Color(0.72, 0.8, 1.0)
const RIM_ENERGY := 30.0
const RIM_RANGE := 3.2
## A narrow cone aimed at his head from behind, so it never lights the wall
## around the door (an omni there blew that wall to white on the Mac, L55-1).
const RIM_ANGLE := 30.0
## Rim offset from his head: behind him (his +Z) and above.
const RIM_BACK := 1.0
## The moonlit glow behind him: a soft omni at the rim's spot that lights the
## wall around the doorway, so he stands as a dark shape against it. On the
## Mac a 60-energy omni there clipped that wall to white (L55-1); this level
## keeps it a pale glow.
const GLOW_ENERGY := 7.0
const GLOW_RANGE := 5.0
const RIM_UP := 0.7
const FADE_IN := 0.3
const FADE_OUT := 2.0

var space: Node
## Scales every light of the rig (tuning and probes; 1 in game).
var gain := 1.0
## 0 = the room's own light, 1 = the full rig.
var amount := 0.0
var moon: SpotLight3D
var rim: SpotLight3D
var glow: OmniLight3D
var fire: OmniLight3D
var _fire_base := 0.0
var _target := 0.0
var _rate := 1.0
var _flare := 0.0


func _ready() -> void:
	space = get_parent()
	EventBus.story_actor_cue.connect(_on_cue)
	EventBus.scene_space_finished.connect(_on_space_finished)
	set_process(false)


func _running() -> bool:
	return space != null and bool(space.get(&"running"))


func _on_cue(actor: StringName, cue: StringName) -> void:
	if actor == &"tamlin_beast" and cue == &"enter" and _running():
		light_up()


func _on_space_finished(space_id: StringName) -> void:
	var own: Variant = space.get(&"space_id") if space else null
	if own != null and StringName(own) != space_id:
		return
	if moon != null or fire != null:
		fade_out()


## The door breaks: moon, rim and the flaring fire come up together.
func light_up() -> void:
	var door := _door()
	var parent := space as Node3D if space is Node3D else null
	if parent == null:
		return
	if moon == null:
		moon = SpotLight3D.new()
		moon.name = "BeastMoon"
		moon.light_color = MOON_COLOR
		moon.spot_range = MOON_RANGE
		moon.spot_angle = MOON_ANGLE
		moon.spot_attenuation = 0.6
		moon.shadow_enabled = true
		# A faint shaft in the dread fog; more would fog the room white.
		moon.light_volumetric_fog_energy = 0.5
		moon.light_energy = 0.0
		parent.add_child(moon)
	var at := door.global_transform if door else parent.global_transform
	var outward := at.basis.z
	outward.y = 0.0
	outward = outward.normalized() if outward.length() > 0.01 else Vector3.BACK
	var sill := at.origin
	var from := sill + outward * MOON_BACK + Vector3.UP * MOON_UP
	var aim := sill - outward * 2.2 + Vector3.UP * 0.2
	moon.global_position = from
	moon.look_at(aim, Vector3.UP)
	if rim == null:
		rim = SpotLight3D.new()
		rim.name = "BeastRim"
		rim.light_color = RIM_COLOR
		rim.spot_range = RIM_RANGE
		rim.spot_angle = RIM_ANGLE
		rim.spot_attenuation = 1.2
		rim.shadow_enabled = false
		rim.light_energy = 0.0
		parent.add_child(rim)
	if glow == null:
		glow = OmniLight3D.new()
		glow.name = "BeastBackGlow"
		glow.light_color = RIM_COLOR
		glow.omni_range = GLOW_RANGE
		glow.omni_attenuation = 1.0
		glow.shadow_enabled = false
		glow.light_energy = 0.0
		parent.add_child(glow)
	if fire == null:
		fire = _hearth_light()
		if fire != null:
			_fire_base = _base_of(fire)
	_flare = FLARE_SECONDS
	_target = 1.0
	_rate = 1.0 / FADE_IN
	_follow()
	set_process(true)


func fade_out() -> void:
	_target = 0.0
	_rate = 1.0 / FADE_OUT
	set_process(true)


func _process(delta: float) -> void:
	amount = move_toward(amount, _target, _rate * delta)
	_flare = maxf(0.0, _flare - delta)
	_follow()
	_apply()
	if amount <= 0.0 and _target <= 0.0:
		_restore()
		set_process(false)


func _apply() -> void:
	if moon != null:
		moon.light_energy = MOON_ENERGY * amount * gain
	if rim != null:
		rim.light_energy = RIM_ENERGY * amount * gain
		rim.visible = amount > 0.0
	if glow != null:
		glow.light_energy = GLOW_ENERGY * amount * gain
		glow.visible = amount > 0.0
	if fire != null and is_instance_valid(fire):
		var k := lerpf(FIRE_GAIN, FIRE_FLARE, _flare / FLARE_SECONDS) * gain
		_set_base(fire, _fire_base * lerpf(1.0, k, amount))


## The rim rides behind his head; it holds still if he's gone.
func _follow() -> void:
	var beast := _beast()
	if rim == null or beast == null:
		return
	var back := beast.global_basis.z
	back.y = 0.0
	back = back.normalized() if back.length() > 0.01 else Vector3.BACK
	var head := _head(beast)
	rim.global_position = head + back * RIM_BACK + Vector3.UP * RIM_UP
	rim.look_at(head, Vector3.UP)
	if glow != null:
		glow.global_position = rim.global_position


func _restore() -> void:
	if fire != null and is_instance_valid(fire):
		_set_base(fire, _fire_base)
	fire = null
	for l: Light3D in [moon, rim, glow]:
		if l != null and is_instance_valid(l):
			l.queue_free()
	moon = null
	rim = null
	glow = null


## The fire_flicker script flickers around its own _base; plain lights take
## the energy directly.
static func _base_of(l: OmniLight3D) -> float:
	var b: Variant = l.get(&"_base")
	return float(b) if b != null and float(b) > 0.0 else l.light_energy


static func _set_base(l: OmniLight3D, energy: float) -> void:
	if l.get(&"_base") != null:
		l.set(&"_base", energy)
	l.light_energy = energy


func _hearth_light() -> OmniLight3D:
	var best: OmniLight3D
	var best_d := INF
	var origin := (space as Node3D).global_position if space is Node3D else Vector3.ZERO
	for h in get_tree().get_nodes_in_group(&"hearth"):
		for l in (h as Node).find_children("*", "OmniLight3D", true, false):
			var d := (l as Node3D).global_position.distance_to(origin)
			if d < best_d:
				best_d = d
				best = l
	return best


func _beast() -> Node3D:
	var b: Variant = space.get(&"beast") if space else null
	if is_instance_valid(b) and b is Node3D:
		return b
	return get_tree().get_first_node_in_group(&"beast") as Node3D


## The cottage door anchor (its +Z points outside, as BeastDoor places him);
## the beast's own door only if there is no anchor (the latch swings with the
## leaf, so its basis is no use once the door is open).
func _door() -> Node3D:
	for a in get_tree().get_nodes_in_group(&"story_anchor"):
		if StringName(a.get_meta(&"anchor_id", a.name)) == &"act1_cottage_door":
			return a as Node3D
	var beast := _beast()
	if beast != null and &"door" in beast:
		var d: Variant = beast.get(&"door")
		if is_instance_valid(d) and d is Node3D:
			return d
	return null


static func _head(beast: Node3D) -> Vector3:
	for sk in beast.find_children("*", "Skeleton3D", true, false):
		var skel := sk as Skeleton3D
		for i in skel.get_bone_count():
			if skel.get_bone_name(i).to_lower().ends_with("head"):
				return skel.global_transform * skel.get_bone_global_pose(i).origin
	return beast.global_position + Vector3.UP * 2.0

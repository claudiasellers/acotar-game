## Tamlin's beast form at the cottage door (lore: 03-characters/tamlin.md).
## Not a fight: a field force. While he is near, light gutters, the camera
## trembles and the room feels smaller. The story lane drives him with cues;
## he never raises story flags himself.
##
## The cast lane's model (characters/tamlin/beast/): it prowls or runs while he
## moves, roars as the door breaks and on "Murderer", and holds a snarl in the
## room. The gold, horned composite placeholder stays as a fallback.
class_name BeastActor
extends Node3D

signal stage_changed(stage: Stage)

enum Stage { HIDDEN, APPROACH, BREAK, PRESENCE, LOOM, SPEAK, LEAD, WITHDRAW, GONE, PATROL }

const GROUP := &"beast"
const MODEL_SCENE := "res://characters/tamlin/beast/tamlin_beast_model.tscn"
const LIGHT_GROUP := &"beast_affected_lights"
## Pressure falls to nothing at this distance (metres).
const RADIUS := 18.0

const STAGE_INTENSITY := {
	Stage.HIDDEN: 0.0, Stage.APPROACH: 0.35, Stage.BREAK: 1.0, Stage.PRESENCE: 0.7,
	Stage.LOOM: 0.9, Stage.SPEAK: 0.8, Stage.LEAD: 0.25, Stage.WITHDRAW: 0.2, Stage.GONE: 0.0,
	# Walking the borders at night: felt, not feared.
	Stage.PATROL: 0.15,
}

@export var actor_id: StringName = &"tamlin_beast"
@export var walk_speed: float = 1.4

var stage: Stage = Stage.HIDDEN
## Current strength of the field (0 to 1), eased toward the stage's level.
var intensity: float = 0.0
var door: Node3D

var _destination: Vector3
var _route: PackedVector3Array = PackedVector3Array()
var _route_index: int = 0
var _lights: Dictionary = {}
var _eye_mat: StandardMaterial3D
var _breath: float = 0.0
var _model: Node3D
## The cast lane's beast (tamlin_beast_model.gd: play(clip, ground_speed)), or
## null while the placeholder stands in.
var _cast: Node3D
var _moving: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_destination = global_position if is_inside_tree() else position
	if ResourceLoader.exists(MODEL_SCENE):
		_cast = (load(MODEL_SCENE) as PackedScene).instantiate() as Node3D
		_cast.name = "Model"
		_model = _cast
	else:
		_model = _build_placeholder()
	add_child(_model)
	visible = false
	if EventBus.has_signal(&"story_actor_cue"):
		EventBus.connect(&"story_actor_cue", _on_cue)


## 0 to 1 with a soft quadratic edge; 0 beyond `radius`.
static func falloff(distance: float, radius: float = RADIUS) -> float:
	var t := clampf(1.0 - distance / radius, 0.0, 1.0)
	return t * t


## How hard the beast presses on a point: scenes, the camera and Feyre's body
## state read this.
func pressure_at(at: Vector3) -> float:
	return intensity * falloff(global_position.distance_to(at))


func begin_approach(door_node: Node3D = null) -> void:
	door = door_node
	visible = true
	if door:
		_destination = door.global_position + door.global_basis.z * 1.5
	_set_stage(Stage.APPROACH)


## The door gives. Calls `break_open()` on the door if it has one, otherwise
## swings it hard on its hinge.
func break_door() -> void:
	_set_stage(Stage.BREAK)
	if door:
		if door.has_method(&"break_open"):
			door.call(&"break_open")
		else:
			create_tween().tween_property(door, ^"rotation:y", door.rotation.y + deg_to_rad(105.0), 0.25)
		_destination = door.global_position - door.global_basis.z * 1.2
	if is_inside_tree():
		CreatureSenses.emit_noise(get_tree(), global_position, 1.0)


func hold_presence() -> void:
	_set_stage(Stage.PRESENCE)


func loom(toward: Vector3) -> void:
	_destination = global_position + (toward - global_position).limit_length(1.5)
	_set_stage(Stage.LOOM)


func speak() -> void:
	_set_stage(Stage.SPEAK)


## The ride north: he walks ahead, the pressure low, and keeps going.
func lead(toward: Vector3) -> void:
	visible = true
	_destination = toward
	_set_stage(Stage.LEAD)


## Night patrol (BeastPatrol): walks `points` in a loop until withdrawn.
func patrol(points: PackedVector3Array) -> void:
	if points.is_empty():
		return
	visible = true
	_route = points
	_route_index = 0
	_destination = _route[0]
	_set_stage(Stage.PATROL)


func withdraw() -> void:
	if door:
		_destination = door.global_position + door.global_basis.z * 6.0
	_set_stage(Stage.WITHDRAW)


func _on_cue(actor: StringName, cue: StringName) -> void:
	if actor != actor_id:
		return
	match cue:
		&"enter":
			if stage == Stage.HIDDEN or stage == Stage.GONE:
				begin_approach(door)
			break_door()
		&"loom", &"accuse":
			var player := get_tree().get_first_node_in_group(&"player") as Node3D
			loom(player.global_position if player else global_position)
			if cue == &"accuse":
				# "Murderer": the roar is the loudest thing in the house.
				speak()
				_play_once(&"roar")
				CreatureSenses.emit_noise(get_tree(), global_position, 1.0)
		&"speak":
			speak()
		&"snap_ash_arrow":
			_play_once(&"snarl")
		&"leave":
			withdraw()
		&"lead":
			lead(global_position - global_basis.z * 40.0)


func _set_stage(next: Stage) -> void:
	stage = next
	stage_changed.emit(next)
	match next:
		Stage.BREAK:
			_play_once(&"roar")
		Stage.SPEAK:
			_play_once(&"snarl")


func _play_once(clip: StringName) -> void:
	if _cast:
		_cast.call(&"play", clip)


## Gait while he moves; at rest a held snarl while he is in the room, else idle.
## Never cuts off a roar or snarl that is still playing.
func _animate(moving: bool) -> void:
	if _cast == null:
		return
	var anim: AnimationPlayer = _cast.get(&"anim")
	if anim == null:
		return
	var current := anim.current_animation
	if not moving and anim.is_playing() and (current == &"roar" or current == &"snarl"):
		return
	var clip := &"idle"
	if moving:
		clip = &"run" if walk_speed > 4.0 else &"prowl"
	elif stage in [Stage.PRESENCE, Stage.LOOM, Stage.SPEAK, Stage.BREAK]:
		clip = &"snarl_hold"
	if current != clip or moving != _moving:
		_cast.call(&"play", clip, walk_speed if moving else -1.0)
	_moving = moving


func _process(delta: float) -> void:
	var goal: float = STAGE_INTENSITY[stage]
	# The break is a spike; everything else eases.
	intensity = goal if stage == Stage.BREAK else move_toward(intensity, goal, delta * 0.6)
	if stage == Stage.BREAK and intensity >= 1.0:
		stage = Stage.PRESENCE
	var to := _destination - global_position
	to.y = 0.0
	_animate(to.length() > 0.05 and visible)
	if to.length() > 0.05:
		global_position += to.limit_length(walk_speed * delta)
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 4.0 * delta)
	elif stage == Stage.PATROL:
		_route_index = (_route_index + 1) % _route.size()
		_destination = _route[_route_index]
	elif stage == Stage.WITHDRAW:
		_set_stage(Stage.GONE)
		visible = false
	_breath += delta
	if _model:
		_model.scale = Vector3.ONE * (1.0 + sin(_breath * 1.3) * 0.015 * (0.5 + intensity))
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 1.0 + intensity * 3.0 + (2.0 if stage == Stage.SPEAK else 0.0)
	_apply_field()


func _apply_field() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group(LIGHT_GROUP):
		var light := node as Light3D
		if light == null:
			continue
		if not _lights.has(light):
			_lights[light] = light.light_energy
		var p := pressure_at(light.global_position)
		var flicker := 0.85 + 0.15 * sin(_breath * 23.0 + light.get_instance_id())
		light.light_energy = _lights[light] * lerpf(1.0, 0.25 * flicker, p)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var shake := pressure_at(camera.global_position)
		shake = shake * shake * 0.04
		camera.h_offset = sin(_breath * 31.0) * shake
		camera.v_offset = cos(_breath * 27.0) * shake


func _build_placeholder() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.74, 0.55, 0.27)
	fur.roughness = 0.95
	var mane := StandardMaterial3D.new()
	mane.albedo_color = Color(0.52, 0.36, 0.17)
	var horn := StandardMaterial3D.new()
	horn.albedo_color = Color(0.86, 0.80, 0.66)
	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = Color(0.3, 0.85, 0.35)
	_eye_mat.emission_enabled = true
	_eye_mat.emission = Color(0.35, 0.95, 0.4)
	_eye_mat.emission_energy_multiplier = 1.0
	# Horse-sized: ~1.7 m at the shoulder, ~3 m long.
	var body := PlaceholderBody._capsule(0.75, 2.8, fur)
	body.rotation_degrees.x = 90.0
	body.position.y = 1.35
	root.add_child(body)
	var shoulders := PlaceholderBody._sphere(0.95, mane)
	shoulders.position = Vector3(0, 1.55, -0.85)
	root.add_child(shoulders)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var leg := PlaceholderBody._cylinder(0.2, 1.1, fur)
			leg.position = Vector3(side * 0.45, 0.55, end * 0.95)
			root.add_child(leg)
			var claw := PlaceholderBody._box(Vector3(0.3, 0.08, 0.25), horn)
			claw.position = Vector3(side * 0.45, 0.04, end * 0.95 - 0.12)
			root.add_child(claw)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 2.0, -1.75)
	root.add_child(head)
	var skull := PlaceholderBody._box(Vector3(0.75, 0.65, 0.8), fur)
	head.add_child(skull)
	var muzzle := PlaceholderBody._box(Vector3(0.45, 0.35, 0.55), fur)
	muzzle.position = Vector3(0, -0.15, -0.6)
	head.add_child(muzzle)
	for side in [-1.0, 1.0]:
		var eye := PlaceholderBody._sphere(0.06, _eye_mat)
		eye.position = Vector3(side * 0.22, 0.1, -0.41)
		head.add_child(eye)
		var fang := PlaceholderBody._box(Vector3(0.04, 0.18, 0.04), horn)
		fang.position = Vector3(side * 0.12, -0.38, -0.8)
		head.add_child(fang)
		# Curving horns: a sweep of segments back and out.
		var tip := Vector3(side * 0.3, 0.3, 0.1)
		for s in 6:
			var seg := PlaceholderBody._cylinder(0.09 - s * 0.012, 0.32, horn)
			seg.position = tip
			seg.rotation = Vector3(-0.6 + s * 0.35, 0.0, side * (0.5 - s * 0.15))
			head.add_child(seg)
			tip += Vector3(side * 0.12, 0.22 - s * 0.06, 0.12 + s * 0.04)
	return root

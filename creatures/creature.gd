## Base for every animal and fae beast that walks the world: a body, senses,
## health against arrows, tracks, death and a carcass to harvest.
##
## Subclasses override _think() to set `move_direction` and `move_speed`.
class_name Creature
extends CharacterBody3D

signal wounded(cause: StringName)
signal died(cause: StringName)

## Arrows and Feyre's aim ray hit layer 4, the same layer as targets.
const TARGET_LAYER := 1 << 3
const WORLD_MASK := 1 << 0
const GROUP := &"creatures"

@export var data: CreatureData
## Stable id for saves and story events. Defaults to the node name.
@export var creature_id: StringName = &""

var health: float = 10.0
var alive: bool = true
var bleeding: float = 0.0
## A lethal arrow is in it and it is dying (see CreatureData.lethal_delay).
var mortally_wounded: bool = false
var mortal_cause: StringName = &""
var _mortal_left: float = 0.0
var model: Node3D
var senses: CreatureSenses
var harvestable: Harvestable
## Desired motion this frame, set by _think().
var move_direction: Vector3 = Vector3.ZERO
var move_speed: float = 0.0
## While true, scenes drive the creature and its brain is paused.
var scripted: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _stride_left: float = 0.0
var _blood_left: float = 0.0
var _print_side: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)
	if creature_id == &"":
		creature_id = StringName(name)
	health = data.max_health
	collision_layer = TARGET_LAYER
	collision_mask = WORLD_MASK
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	_build_collision()
	model = PlaceholderBody.build(data)
	add_child(model)
	senses = CreatureSenses.new()
	senses.name = "Senses"
	senses.sight_range = data.sight_range
	senses.fov_degrees = data.sight_fov_degrees
	senses.hearing_range = data.hearing_range
	senses.scent_range = data.scent_range
	senses.position = Vector3(0, data.body_height * 0.95, -data.body_length * 0.45)
	add_child(senses)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if mortally_wounded:
		_mortal_left -= delta
		if _mortal_left <= 0.0:
			die(mortal_cause)
			return
	if not scripted:
		_think(delta)
	_move(delta)
	_leave_tracks(delta)


## Brain hook. Default: stand still.
func _think(_delta: float) -> void:
	move_direction = Vector3.ZERO


func _move(delta: float) -> void:
	var flat := Vector3(move_direction.x, 0.0, move_direction.z)
	var target := flat.normalized() * move_speed if flat.length_squared() > 0.0001 else Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, maxf(move_speed, 2.0) * 3.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta
	if horizontal.length_squared() > 0.04:
		face_towards(global_position + horizontal, delta)
	move_and_slide()


func face_towards(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length_squared() < 0.0001:
		return
	var yaw := atan2(-to.x, -to.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(data.turn_speed * delta, 0.0, 1.0))


## Called by Arrow when it strikes this body.
func on_arrow_hit(arrow: Node3D) -> void:
	if not alive:
		return
	var arrow_id := read_arrow_id(arrow)
	var result := resolve_arrow(data, health, arrow_id, mortally_wounded)
	health = result.health
	var cause := StringName("arrow_%s" % arrow_id)
	if result.killed:
		# The lethal arrow is what killed it, whatever finished it.
		die(mortal_cause if mortally_wounded else cause)
		return
	if result.mortal and not mortally_wounded:
		mortally_wounded = true
		mortal_cause = cause
		_mortal_left = data.lethal_delay
	bleeding = maxf(bleeding, 40.0)
	wounded.emit(cause)
	_on_wounded(arrow.global_position, cause)


## Brain hook for a non-lethal hit.
func _on_wounded(_from: Vector3, _cause: StringName) -> void:
	pass


func die(cause: StringName) -> void:
	if not alive:
		return
	alive = false
	health = 0.0
	velocity = Vector3.ZERO
	_topple()
	harvestable = Harvestable.new()
	harvestable.name = "Harvestable"
	harvestable.setup(creature_id, data.kind, data.harvest_yield())
	harvestable.position = Vector3(0, 0.3, 0)
	add_child(harvestable)
	if is_inside_tree():
		TrackLayer.leave(get_tree(), &"blood", global_position, rotation.y, data.print_size * 3.0)
	died.emit(cause)
	if EventBus.has_signal(&"creature_killed"):
		EventBus.emit_signal(&"creature_killed", creature_id, data.kind, cause, global_position)


## The arrow's type id: the systems lane's `arrow_id` property, then meta, then wood.
static func read_arrow_id(arrow: Object) -> StringName:
	if arrow == null:
		return &"wood"
	var value: Variant = arrow.get(&"arrow_id")
	if value != null and String(value) != "":
		return StringName(value)
	if arrow.has_meta(&"arrow_id"):
		return StringName(arrow.get_meta(&"arrow_id"))
	return &"wood"


## Pure rule for one arrow hit: {health, killed, mortal}. A lethal arrow kills
## at once, or with a lethal_delay leaves a mortal wound; any hit on a mortally
## wounded creature kills it.
static func resolve_arrow(creature: CreatureData, current_health: float, arrow_id: StringName,
		already_mortal: bool = false) -> Dictionary:
	if already_mortal:
		return {"health": 0.0, "killed": true, "mortal": true}
	if arrow_id in creature.lethal_arrow_ids:
		if creature.lethal_delay > 0.0:
			return {"health": maxf(current_health - creature.arrow_damage, 1.0), "killed": false, "mortal": true}
		return {"health": 0.0, "killed": true, "mortal": true}
	var remaining := current_health - creature.arrow_damage
	if creature.only_lethal_kills:
		return {"health": maxf(remaining, 1.0), "killed": false, "mortal": false}
	return {"health": maxf(remaining, 0.0), "killed": remaining <= 0.0, "mortal": false}


## Points away from a threat on the ground plane.
static func away_from(from: Vector3, threat: Vector3) -> Vector3:
	var dir := Vector3(from.x - threat.x, 0.0, from.z - threat.z)
	if dir.length_squared() < 0.0001:
		return Vector3.FORWARD
	return dir.normalized()


func _leave_tracks(delta: float) -> void:
	var step := Vector2(velocity.x, velocity.z).length() * delta
	if bleeding > 0.0:
		bleeding = maxf(bleeding - delta, 0.0)
		_blood_left -= step
		if _blood_left <= 0.0 and is_inside_tree():
			_blood_left = 1.5
			TrackLayer.leave(get_tree(), &"blood", global_position, rotation.y, data.print_size * 1.5)
	if data.body_plan == CreatureData.BodyPlan.BIRD or not is_on_floor():
		return
	_stride_left -= step
	if _stride_left > 0.0 or not is_inside_tree():
		return
	_stride_left = data.stride
	_print_side = -_print_side
	var side := global_basis.x * _print_side * data.body_width * 0.25
	TrackLayer.leave(get_tree(), &"print", global_position + side, rotation.y, data.print_size)
	if move_speed > data.walk_speed * 2.0 and randf() < data.twig_chance:
		TrackLayer.leave(get_tree(), &"twig", global_position + side * 2.0, rotation.y)


func _topple() -> void:
	if model == null:
		return
	var side := 1.0 if randf() < 0.5 else -1.0
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, ^"rotation:z", side * PI * 0.5, 0.55)
	tween.parallel().tween_property(model, ^"position:y", data.body_width * 0.5, 0.55)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box := BoxShape3D.new()
	box.size = Vector3(data.body_width, data.body_height, data.body_length * 0.85)
	shape.shape = box
	shape.position.y = data.body_height * 0.5
	add_child(shape)

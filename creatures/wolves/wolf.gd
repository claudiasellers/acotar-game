## An ordinary wolf of the human-realm forest. On its own it roams; in a pack
## it follows the pack's orders: stalk, flank, circle, and dart in.
class_name Wolf
extends Creature

@export var pack_path: NodePath

var pack: WolfPack

var _lunge_target: Vector3
var _lunge_time: float = 0.0
var _roam_target: Vector3
var _roam_timer: float = 0.0


func _ready() -> void:
	super._ready()
	if not pack_path.is_empty():
		pack = get_node_or_null(pack_path) as WolfPack
	if pack == null and get_parent() is WolfPack:
		pack = get_parent() as WolfPack
	if pack:
		pack.register(self)
	senses.sensed.connect(_on_sensed)


func _on_sensed(_kind: StringName, _at: Vector3, _strength: float) -> void:
	if pack and senses.awareness >= data.startle_threshold:
		pack.report(get_tree().get_first_node_in_group(&"player") as Node3D)


func _on_wounded(_from: Vector3, _cause: StringName) -> void:
	if pack:
		pack.report(get_tree().get_first_node_in_group(&"player") as Node3D)


## A short feint at the target, then back to the ring.
func lunge(at: Vector3) -> void:
	_lunge_target = at
	_lunge_time = 0.9


func _think(delta: float) -> void:
	if _lunge_time > 0.0:
		_lunge_time -= delta
		var toward := _lunge_target - global_position
		move_direction = toward if _lunge_time > 0.45 else -toward
		move_speed = data.run_speed
		return
	if pack == null or pack.phase == WolfPack.Phase.ROAM:
		_roam(delta)
		return
	var order := pack.order_for(self)
	var to: Vector3 = order.to - global_position
	to.y = 0.0
	if to.length() < 0.6:
		move_speed = 0.0
		if pack.target:
			face_towards(pack.target.global_position, delta)
		return
	move_direction = to
	move_speed = data.run_speed if order.run else data.walk_speed * 1.6


func _roam(delta: float) -> void:
	_roam_timer -= delta
	var anchor: Vector3 = pack.global_position if pack else global_position
	if _roam_timer <= 0.0:
		_roam_timer = randf_range(5.0, 10.0)
		var a := randf() * TAU
		_roam_target = anchor + Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 14.0)
	var to := _roam_target - global_position
	to.y = 0.0
	move_direction = to
	move_speed = data.walk_speed if to.length() > 1.0 else 0.0

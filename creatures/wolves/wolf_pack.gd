## Coordinates ordinary wolves: shares what any member senses, then spreads the
## pack around its target so it is never facing only one of them.
class_name WolfPack
extends Node3D

signal target_acquired(target: Node3D)
signal lunged(wolf: Node3D)
signal broke_off

enum Phase { ROAM, STALK, FLANK, CIRCLE, BREAK }

## Arc (degrees) the flanking slots spread over, centred on the approach line.
const FLANK_ARC := 220.0

@export var flank_radius: float = 10.0
@export var circle_radius: float = 5.0
@export var stalk_until: float = 28.0
## Members lost before the pack gives up.
@export var break_after_losses: int = 2

var phase: Phase = Phase.ROAM
var target: Node3D
var members: Array[Node3D] = []
var losses: int = 0

var _lunge_timer: float = 4.0


## Slots around `target`, spread over FLANK_ARC and centred on the line from
## the target back toward where the pack is coming from.
static func flank_slots(target_pos: Vector3, pack_center: Vector3, count: int, radius: float) -> Array[Vector3]:
	var slots: Array[Vector3] = []
	if count <= 0:
		return slots
	var back := Vector3(pack_center.x - target_pos.x, 0.0, pack_center.z - target_pos.z)
	if back.length_squared() < 0.0001:
		back = Vector3.BACK
	var base := atan2(back.x, back.z)
	var arc := deg_to_rad(FLANK_ARC)
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var a := base - arc * 0.5 + arc * t
		slots.append(target_pos + Vector3(sin(a), 0.0, cos(a)) * radius)
	return slots


func register(wolf: Node3D) -> void:
	if wolf in members:
		return
	members.append(wolf)
	if wolf.has_signal(&"died"):
		wolf.connect(&"died", func(_cause: StringName) -> void: _on_member_died(wolf))
	if wolf.has_signal(&"wounded"):
		wolf.connect(&"wounded", func(_cause: StringName) -> void: _on_member_hurt())


func alive_members() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m in members:
		if is_instance_valid(m) and m.get(&"alive"):
			out.append(m)
	return out


func center() -> Vector3:
	var live := alive_members()
	if live.is_empty():
		return global_position
	var sum := Vector3.ZERO
	for m in live:
		sum += m.global_position
	return sum / live.size()


## A member noticed something; the whole pack turns to it.
func report(seen: Node3D) -> void:
	if phase == Phase.BREAK or seen == null:
		return
	if target == null:
		target = seen
		phase = Phase.STALK
		target_acquired.emit(seen)


## Where `wolf` should be heading right now, and how fast (0 = walk, 1 = run).
func order_for(wolf: Node3D) -> Dictionary:
	var live := alive_members()
	var index := live.find(wolf)
	if target == null or index < 0 or phase == Phase.ROAM:
		return {"to": global_position, "run": false}
	if phase == Phase.BREAK:
		return {"to": wolf.global_position + Creature.away_from(wolf.global_position, target.global_position) * 40.0, "run": true}
	var radius := flank_radius if phase != Phase.CIRCLE else circle_radius
	if phase == Phase.STALK:
		return {"to": target.global_position, "run": false}
	var slots := flank_slots(target.global_position, center(), live.size(), radius)
	if phase == Phase.CIRCLE:
		# Slots creep around the target so the ring never sits still.
		var spin := Time.get_ticks_msec() * 0.00025
		var slot := slots[index] - target.global_position
		return {"to": target.global_position + slot.rotated(Vector3.UP, spin), "run": false}
	return {"to": slots[index], "run": true}


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		phase = Phase.ROAM if phase != Phase.BREAK else phase
		return
	var distance := center().distance_to(target.global_position)
	match phase:
		Phase.STALK:
			if distance < stalk_until:
				phase = Phase.FLANK
		Phase.FLANK:
			if _all_in_place(flank_radius):
				phase = Phase.CIRCLE
		Phase.CIRCLE:
			_lunge_timer -= delta
			if _lunge_timer <= 0.0:
				_lunge_timer = randf_range(3.0, 6.0)
				var live := alive_members()
				if not live.is_empty():
					var wolf: Node3D = live[randi() % live.size()]
					if wolf.has_method(&"lunge"):
						wolf.call(&"lunge", target.global_position)
					lunged.emit(wolf)


func _all_in_place(radius: float) -> bool:
	for m in alive_members():
		if absf(m.global_position.distance_to(target.global_position) - radius) > 2.5:
			return false
	return true


func _on_member_died(_wolf: Node3D) -> void:
	losses += 1
	if losses >= break_after_losses or alive_members().size() <= 1:
		_break()


func _on_member_hurt() -> void:
	# A wounded member makes the ring loosen back to the flank.
	if phase == Phase.CIRCLE:
		phase = Phase.FLANK


func _break() -> void:
	if phase == Phase.BREAK:
		return
	phase = Phase.BREAK
	broke_off.emit()

## A physical lock on a region: thorn wall, ward, sentry line, flooded ford.
##
## The gate's children are the lock. They are visible and solid while the
## region is locked, and vanish when PhaseManager unlocks it. Never an
## invisible wall.
class_name RegionGate
extends Node3D

## Clearance (m) above Feyre's highest triple-jump chain.
const HEADROOM := 1.5

@export var region_id: StringName


## How tall every gate piece is, both its collision and what you see: her
## highest jump chain plus headroom, so a lock can never be hopped (and a
## gate that blocks always looks as tall as it blocks).
static func min_height() -> float:
	return JumpMotor.max_chain_rise() + HEADROOM


## True when `node` is part of a gate: Feyre never mantles onto one.
static func owns(node: Object) -> bool:
	var n := node as Node
	while n != null:
		if n is RegionGate:
			return true
		n = n.get_parent()
	return false


func _ready() -> void:
	EventBus.region_unlocked.connect(_on_region_changed)
	EventBus.region_locked.connect(_on_region_changed)
	refresh()


func is_locked() -> bool:
	return not PhaseManager.is_region_unlocked(region_id)


func refresh() -> void:
	var locked := is_locked()
	visible = locked
	for body in find_children("*", "CollisionObject3D", true, false):
		body.process_mode = Node.PROCESS_MODE_INHERIT if locked else Node.PROCESS_MODE_DISABLED


func _on_region_changed(changed_id: StringName) -> void:
	if changed_id == region_id:
		refresh()

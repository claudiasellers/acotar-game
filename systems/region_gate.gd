## A physical lock on a region: thorn wall, ward, sentry line, flooded ford.
##
## The gate's children are the lock. They are visible and solid while the
## region is locked, and vanish when PhaseManager unlocks it. Never an
## invisible wall.
class_name RegionGate
extends Node3D

@export var region_id: StringName


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

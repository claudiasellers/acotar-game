## The white roses from his parents' garden (ch22 [C]), L45: Alis puts them in
## her painting room. From fact.white_roses_given they stand on the paint
## table (the surface found by a ray, so a refurnished room still holds them).
## Hung on the painting_room_easel anchor by Act3Anchors.ROWS.
class_name WhiteRosesVase
extends Node3D

const FROM := "fact.white_roses_given"
## The paint table's top, from the easel anchor (house painting room, world axes).
const SPOT := Vector3(0.45, 0.0, -7.2)
const TABLE_TOP := 0.85

var _vase: MeshInstance3D


func _ready() -> void:
	EventBus.flag_changed.connect(func(flag: String, _v: Variant) -> void:
		if flag == FROM:
			refresh.call_deferred())
	EventBus.game_loaded.connect(func(_slot: String) -> void: refresh.call_deferred())
	refresh.call_deferred()


func refresh() -> void:
	if not is_inside_tree():
		return
	var want := WorldState.has_flag(FROM)
	if not want:
		if _vase:
			_vase.queue_free()
			_vase = null
		return
	if _vase:
		return
	_vase = CalanmaiKit.prop(&"white_roses_vase")
	if _vase == null:
		return
	add_child(_vase)
	_vase.global_position = surface(get_parent() as Node3D)
	_vase.rotation.y = 0.4


## The top of whatever stands at SPOT (the paint table), or TABLE_TOP above the floor.
func surface(anchor: Node3D) -> Vector3:
	var base := anchor.global_position if anchor else global_position
	var at := base + SPOT
	var space := get_world_3d().direct_space_state if get_world_3d() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.UP * 0.05)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit["position"] as Vector3
	return at + Vector3.UP * TABLE_TOP

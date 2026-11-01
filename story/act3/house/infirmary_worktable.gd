## The small infirmary's worktable and deep sink (ch12, Keeper [C]: "more of
## a supply closet with a worktable", cabinets and drawers, "a deep sink at
## the back"). Always there; hung on the manor_infirmary anchor by
## Act3Anchors, placed from the wound-dressing stage marks ("table", "sink").
## Other scenes reach it as anchor.get_node(^"InfirmaryWorktable").
class_name InfirmaryWorktable
extends Node3D

const STAGE_PATH := "res://data/story/act3/house/wound_dressing_stage.tres"
## Tray slots along the tray, table-local (the model's tray sits at x -0.25).
const SLOTS := {&"a": Vector3(-0.55, 0.95, 0.0), &"b": Vector3(-0.35, 0.95, 0.0),
		&"c": Vector3(-0.15, 0.95, 0.0), &"d": Vector3(0.05, 0.95, 0.0)}

@export var stage: Act2Stage
var table: MeshInstance3D
var sink: MeshInstance3D
var _items: Dictionary = {}


func _ready() -> void:
	if stage == null and ResourceLoader.exists(STAGE_PATH):
		stage = load(STAGE_PATH) as Act2Stage
	table = HouseProps.model(&"infirmary_worktable")
	add_child(table)
	sink = HouseProps.model(&"deep_sink")
	add_child(sink)
	_place(table, &"table")
	_place(sink, &"sink")
	for mi: MeshInstance3D in [table, sink]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var aabb := mi.get_aabb()
		box.size = aabb.size
		shape.shape = box
		shape.position = aabb.get_center()
		body.add_child(shape)
		mi.add_child(body)


func _place(node: Node3D, mark_name: StringName) -> void:
	if stage == null or not stage.has_mark(mark_name):
		return
	node.position = stage.mark(mark_name)
	var yaw_mark := StringName(String(mark_name) + "_yaw")
	if stage.has_mark(yaw_mark):
		node.rotation.y = deg_to_rad(stage.mark(yaw_mark).y)


## World point at the middle of the tray.
func tray_point() -> Vector3:
	return table.global_transform * Vector3(-0.25, 0.95, 0.0)


## World point just above the sink's basin.
func sink_point() -> Vector3:
	return sink.global_transform * Vector3(0.0, 0.95, 0.0)


func slot_point(slot: StringName) -> Vector3:
	return table.global_transform * (SLOTS.get(slot, SLOTS[&"b"]) as Vector3)


## Sets an item down in a tray slot (&"a".."d"), replacing what was there.
func put(slot: StringName, item: Node3D) -> void:
	var old := _items.get(slot) as Node3D
	if old and old != item and is_instance_valid(old):
		old.queue_free()
	if item.get_parent() == null:
		add_child(item)
	item.global_position = slot_point(slot)
	_items[slot] = item


func item(slot: StringName) -> Node3D:
	var it := _items.get(slot) as Node3D
	return it if it and is_instance_valid(it) else null


func clear_tray() -> void:
	for it in _items.values():
		if it and is_instance_valid(it):
			(it as Node).queue_free()
	_items.clear()

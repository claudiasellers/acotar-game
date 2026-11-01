## The first dinner's table setting: Blender models from
## tools/blender/dinner_set.py (art/dinner/), placed on the stage's marks.
## Each dish is its own node so a bite can take it away with a sparkle.
class_name DinnerTable
extends Node3D

const DIR := "res://art/dinner/"
## Her plate, eaten in book order: "Stabbing a piece of chicken, I took a bite."
const BITES: Array[StringName] = [&"dinner_chicken", &"dinner_bread", &"dinner_sauce_peas"]

var dishes: Dictionary = {}  # mark/id -> Node3D


## Lays the table on the space's marks: "<model id>" or "<model id>@<n>" per mark.
func lay(space: Act2Space, setting: Dictionary) -> void:
	for mark_name: StringName in setting:
		var model_id := StringName(setting[mark_name])
		var dish := _dish(model_id)
		dish.name = String(mark_name).to_pascal_case()
		add_child(dish)
		dish.global_position = space.mark(mark_name)
		dishes[mark_name] = dish


func dish(mark_name: StringName) -> Node3D:
	var d := dishes.get(mark_name) as Node3D
	return d if d and is_instance_valid(d) else null


## Takes a dish off the table with a pop (sparkle and chime from the caller).
func take(mark_name: StringName) -> void:
	var d := dish(mark_name)
	dishes.erase(mark_name)
	if d == null:
		return
	if not d.is_inside_tree():
		d.queue_free()
		return
	var tween := d.create_tween()
	tween.tween_property(d, ^"scale", Vector3.ONE * 1.25, 0.08)
	tween.tween_property(d, ^"scale", Vector3.ONE * 0.01, 0.16)
	tween.tween_callback(d.queue_free)


func remaining() -> int:
	return dishes.size()


static func _dish(model_id: StringName) -> Node3D:
	var mi := MeshInstance3D.new()
	var pair := PropModels.pair(DIR + String(model_id) + ".glb", String(model_id))
	if not pair.is_empty() and pair[0] != null:
		mi.mesh = pair[0]
	else:
		var s := SphereMesh.new()
		s.radius = 0.04
		s.height = 0.06
		mi.mesh = s
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.8, 0.6)
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

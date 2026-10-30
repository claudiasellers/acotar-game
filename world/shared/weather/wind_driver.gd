## Feeds the GPU wind globals from the systems lane's Weather (any node in
## group "wind_source" with wind_at(pos) -> Vector3), or a gentle default.
class_name WindDriver
extends Node

@export var default_wind := Vector3(1.0, 0.0, 0.3)
@export var default_strength := 0.35

var current := Vector3.ZERO


func _process(_delta: float) -> void:
	current = sample(get_viewport().get_camera_3d().global_position if get_viewport() != null and get_viewport().get_camera_3d() != null else Vector3.ZERO)
	var strength := current.length()
	RenderingServer.global_shader_parameter_set(&"wind_direction", current.normalized() if strength > 0.0001 else default_wind.normalized())
	RenderingServer.global_shader_parameter_set(&"wind_strength", strength)


func sample(pos: Vector3) -> Vector3:
	var source := get_tree().get_first_node_in_group(&"wind_source") if is_inside_tree() else null
	if source != null and source.has_method(&"wind_at"):
		return source.call(&"wind_at", pos)
	var t := Time.get_ticks_msec() / 1000.0
	return default_wind.normalized() * default_strength * (0.8 + 0.2 * sin(t * 0.37))

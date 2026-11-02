## A light-weight stage for looking at the manor's paintings (L39): only the
## house, lit by its own room lights plus soft daylight. For layout shots in
## the cloud (tools/shots/take_shots.sh with "scene" set to this file's .tscn);
## final looks use the real World on the Mac.
extends Node3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.86, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.93)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.8
	add_child(sun)
	ManorHouseBuilder.build(self)

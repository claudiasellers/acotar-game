## What special arrows do when they land (docs/GAMEPLAY_M2.md item 3).
##
## Every effect also tags the arrow with meta "arrow_effect" and calls
## target.on_arrow_effect(effect, arrow) when the target has it, so creatures
## decide what sleep, lure and barbs mean for them.
class_name ArrowEffects
extends RefCounted

const ROPE_GROUP := &"rope_anchor"
const LIGHT_GROUP := &"arrow_light"
## Seconds a light arrow glows; signal flares are brief and bright.
const LIGHT_SECONDS := 45.0
const FLAME_SECONDS := 6.0
const ROPE_MAX_LENGTH := 14.0


static func apply(arrow: Arrow, target: Node, at: Vector3) -> void:
	var effect := arrow.data.effect
	if effect == &"":
		return
	arrow.set_meta(&"arrow_effect", effect)
	if target and target.has_method(&"on_arrow_effect"):
		target.on_arrow_effect(effect, arrow)
	var elements := element_state_of(target)
	match effect:
		&"fire":
			if elements:
				elements.ignite(0.8)
			_light(arrow, at, Color(1.0, 0.55, 0.2), 2.5, 4.0, FLAME_SECONDS)
		&"frost":
			if elements:
				elements.soak(0.4)
				elements.chill(0.6)
			_light(arrow, at, Color(0.7, 0.9, 1.0), 0.8, 2.5, 2.0)
		&"light":
			_light(arrow, at, Color(1.0, 0.95, 0.75), 1.6, 9.0, LIGHT_SECONDS)
		&"signal":
			_flare(arrow, at)
			Gameplay.emit(&"signal_flare", [at])
		&"rope":
			rope_anchor(arrow, at)


## The target's ElementState: itself, or a direct child of that type.
static func element_state_of(target: Node) -> ElementState:
	if target == null:
		return null
	if target is ElementState:
		return target
	for child in target.get_children():
		if child is ElementState:
			return child
	return null


## A line hanging from the arrow down to the ground, climbable by traversal
## (group "rope_anchor", meta "top" and "bottom").
static func rope_anchor(arrow: Arrow, at: Vector3) -> Node3D:
	var world := arrow.get_parent()
	if world == null:
		return null
	var space := arrow.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * ROPE_MAX_LENGTH, 1))
	var bottom: Vector3 = hit.position if hit else at + Vector3.DOWN * ROPE_MAX_LENGTH
	var anchor := Node3D.new()
	anchor.name = "RopeAnchor"
	anchor.add_to_group(ROPE_GROUP)
	anchor.set_meta(&"top", at)
	anchor.set_meta(&"bottom", bottom)
	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.012
	mesh.height = maxf(at.distance_to(bottom), 0.1)
	line.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.78, 0.62)
	line.material_override = mat
	anchor.add_child(line)
	world.add_child(anchor)
	anchor.global_position = (at + bottom) * 0.5
	return anchor


static func _light(arrow: Arrow, at: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.add_to_group(LIGHT_GROUP)
	var parent := arrow.get_parent()
	if parent == null:
		return
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_interval(maxf(seconds - 1.5, 0.0))
	tween.tween_property(light, ^"light_energy", 0.0, 1.5)
	tween.tween_callback(light.queue_free)


static func _flare(arrow: Arrow, at: Vector3) -> void:
	var parent := arrow.get_parent()
	if parent == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.3)
	light.light_energy = 6.0
	light.omni_range = 30.0
	light.add_to_group(LIGHT_GROUP)
	parent.add_child(light)
	light.global_position = at
	var tween := light.create_tween()
	tween.tween_property(light, ^"global_position", at + Vector3.UP * 25.0, 2.0)
	tween.parallel().tween_property(light, ^"light_energy", 0.0, 2.5)
	tween.tween_callback(light.queue_free)
	Juice.burst(null, &"unlock", at + Vector3.UP * 2.0)

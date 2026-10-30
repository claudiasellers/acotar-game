## Ambient magic of the estate (R3): floating rose petals in the gardens, the
## orchard and the avenue; glittering pollen motes over lawns and meadows;
## pastel butterflies by day; fireflies and faelights at dusk and night (read
## from Clock.time_of_day); spray on the fountains. All GPUParticles3D, one
## emitter per zone. No lights, sky or environment here (world contract §3).
class_name ManorAmbientLife
extends Node3D

const BUTTERFLY_SHADER := preload("res://world/spring_court/manor_estate/life/butterfly.gdshader")

## kind -> [[zone rect, amount], ...]
static func plan() -> Dictionary:
	var sp := ManorSitePlan
	return {
		&"petals": [[sp.ROSE_GARDEN, 700], [sp.WALLED_ORCHARD, 600], [Rect2(-16.0, 30.0, 32.0, 250.0), 450], [sp.GLASS_HOUSES, 120]],
		&"pollen": [[sp.EAST_MEADOW, 1400], [sp.WEST_DOWNS, 1100], [sp.DEER_PARK, 1100], [sp.SOUTH_LAWNS, 1600], [sp.ROSE_GARDEN, 400], [sp.SOUTHEAST_PARK, 600], [sp.SOUTHWEST_PARK, 600]],
		&"butterflies": [[sp.ROSE_GARDEN, 70], [sp.KITCHEN_GARDEN, 30], [sp.EAST_MEADOW, 140], [sp.WEST_DOWNS, 110], [sp.SOUTH_LAWNS, 160], [sp.WALLED_ORCHARD, 60], [sp.DEER_PARK, 90], [sp.PADDOCK, 40]],
		&"fireflies": [[sp.ROSE_GARDEN, 320], [sp.HEDGE_MAZE, 200], [Rect2(sp.POND_CENTER - sp.POND_RADII * 1.4, sp.POND_RADII * 2.8), 360], [sp.WALLED_ORCHARD, 220], [sp.NORTH_HILLS, 900], [sp.SOUTH_LAWNS, 700], [sp.EAST_MEADOW, 500], [sp.WEST_DOWNS, 400]],
	}


const HEIGHTS := {&"petals": [3.0, 2.5], &"pollen": [1.8, 1.6], &"butterflies": [1.2, 0.9], &"fireflies": [1.4, 1.3]}

var _day: Array[GPUParticles3D] = []
var _night: Array[GPUParticles3D] = []
var _was_night := -1


static func build(parent: Node3D) -> ManorAmbientLife:
	var life := ManorAmbientLife.new()
	life.name = "AmbientLife"
	parent.add_child(life)
	var p := plan()
	for kind: StringName in p:
		var i := 0
		for e in p[kind]:
			var em := life._emitter(kind, e[0], e[1])
			em.name = "%s_%d" % [kind, i]
			life.add_child(em)
			if kind == &"butterflies":
				life._day.append(em)
			elif kind == &"fireflies":
				life._night.append(em)
			i += 1
	for spot: Vector3 in [Vector3(0, 0, 0), Vector3(ManorRoseGarden.CENTER.x, 0, ManorRoseGarden.CENTER.y)]:
		var spray := life._spray(spot, 6.3 if spot == Vector3.ZERO else 2.8)
		life.add_child(spray)
	life._update(true)
	return life


func _process(_delta: float) -> void:
	_update(false)


static func is_dusk(time_of_day: float) -> bool:
	var h := time_of_day * 24.0
	return h >= 18.5 or h < 6.0


func _update(force: bool) -> void:
	var night := 1 if is_dusk(Clock.time_of_day) else 0
	if night == _was_night and not force:
		return
	_was_night = night
	for e in _night:
		e.emitting = night == 1
	for e in _day:
		e.emitting = night == 0


func emitters(kind: StringName) -> Array[GPUParticles3D]:
	var out: Array[GPUParticles3D] = []
	for c in get_children():
		if c is GPUParticles3D and String(c.name).begins_with(String(kind)):
			out.append(c)
	return out


func _emitter(kind: StringName, rect: Rect2, amount: int) -> GPUParticles3D:
	var c := rect.get_center()
	var h: Array = HEIGHTS[kind]
	var y := WorldHeight.height_at(c.x, c.y) + float(h[0])
	var em := GPUParticles3D.new()
	em.position = Vector3(c.x, y, c.y)
	em.amount = amount
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var extents := Vector3(rect.size.x * 0.5, float(h[1]), rect.size.y * 0.5)
	em.visibility_aabb = AABB(-extents - Vector3(4, 6, 4), extents * 2.0 + Vector3(8, 12, 8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.turbulence_enabled = true
	var ramp := Gradient.new()
	match kind:
		&"petals":
			em.lifetime = 14.0
			pm.gravity = Vector3(0.25, -0.12, 0.1)
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.4
			pm.angular_velocity_min = -90.0
			pm.angular_velocity_max = 90.0
			pm.turbulence_noise_strength = 1.4
			pm.turbulence_noise_scale = 6.0
			pm.scale_min = 0.6
			pm.scale_max = 1.2
			_ramp(ramp, [Color(1.0, 0.62, 0.76), Color(1.0, 0.85, 0.9), Color(0.98, 0.45, 0.6), Color(1.0, 0.96, 0.96)])
			em.draw_pass_1 = _card(Vector2(0.09, 0.07), _soft_material(false, 0.0, true))
		&"pollen":
			em.lifetime = 10.0
			pm.gravity = Vector3(0.05, 0.02, 0.0)
			pm.turbulence_noise_strength = 0.6
			pm.scale_min = 0.5
			pm.scale_max = 1.0
			_ramp(ramp, [Color(1.0, 0.95, 0.6), Color(1.0, 0.85, 0.95), Color(0.9, 1.0, 0.95)])
			em.draw_pass_1 = _card(Vector2(0.05, 0.05), _soft_material(true, 2.0, false))
		&"butterflies":
			em.lifetime = 18.0
			pm.gravity = Vector3.ZERO
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 1.0
			pm.direction = Vector3(1, 0.1, 0)
			pm.spread = 180.0
			pm.turbulence_noise_strength = 2.2
			pm.turbulence_noise_scale = 4.0
			pm.turbulence_influence_min = 0.2
			pm.turbulence_influence_max = 0.5
			pm.scale_min = 0.8
			pm.scale_max = 1.3
			_ramp(ramp, [Color(1.0, 0.6, 0.8), Color(0.78, 0.62, 1.0), Color(1.0, 0.9, 0.5), Color(0.62, 0.74, 1.0), Color(0.6, 0.95, 0.85)])
			var plane := PlaneMesh.new()
			plane.size = Vector2(0.22, 0.16)
			var sm := ShaderMaterial.new()
			sm.shader = BUTTERFLY_SHADER
			plane.material = sm
			em.draw_pass_1 = plane
		&"fireflies":
			em.lifetime = 8.0
			pm.gravity = Vector3(0, 0.03, 0)
			pm.turbulence_noise_strength = 0.9
			pm.scale_min = 0.6
			pm.scale_max = 1.4
			_ramp(ramp, [Color(1.0, 0.95, 0.55), Color(0.75, 1.0, 0.6), Color(1.0, 0.7, 0.9), Color(0.7, 0.8, 1.0)])
			em.draw_pass_1 = _card(Vector2(0.12, 0.12), _soft_material(true, 5.0, false))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_initial_ramp = tex
	em.process_material = pm
	em.preprocess = em.lifetime
	return em


func _spray(spot: Vector3, height: float) -> GPUParticles3D:
	var y := WorldHeight.height_at(spot.x, spot.z) + height
	var em := GPUParticles3D.new()
	em.name = "FountainSpray_%d_%d" % [int(spot.x), int(spot.z)]
	em.position = Vector3(spot.x, y, spot.z)
	em.amount = 220
	em.lifetime = 1.6
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	em.visibility_aabb = AABB(Vector3(-5, -8, -5), Vector3(10, 12, 10))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, -6.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	em.process_material = pm
	var mat := _soft_material(true, 0.6, false)
	mat.albedo_color = Color(0.85, 0.92, 1.0, 0.7)
	em.draw_pass_1 = _card(Vector2(0.12, 0.12), mat)
	return em


static func _ramp(g: Gradient, colors: Array) -> void:
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(colors.size() - 1, 1))
		cols.append(colors[i])
	g.offsets = offsets
	g.colors = cols


static func _card(size: Vector2, m: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.material = m
	return q


static var _soft_tex: GradientTexture2D


static func _soft_material(glow: bool, energy: float, petal: bool) -> StandardMaterial3D:
	if _soft_tex == null:
		_soft_tex = GradientTexture2D.new()
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
		_soft_tex.gradient = g
		_soft_tex.width = 32
		_soft_tex.height = 32
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if not petal else BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = Color(1.0, 0.95, 0.8)
		m.emission_energy_multiplier = energy
	return m

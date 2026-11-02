## The p4 scenes' dressing (L44): our own Blender props from
## tools/blender/wider_court_props.py (story/act4/models/), the estate's
## catalogue props through PropLib, and the water and sparkle effects.
## Everything is a real model or a particle effect; nothing is a grey box.
class_name Act4Props
extends RefCounted

const MODEL_DIR := "res://story/act4/models/"
## Ours: id -> [size (w, h, d), collides].
const OURS := {
	&"picnic_blanket": [Vector3(2.6, 0.2, 2.0), false],
	&"picnic_wine": [Vector3(0.4, 0.33, 0.42), false],
	&"sentry_butt": [Vector3(1.35, 1.75, 1.0), true],
	&"warbow_chest": [Vector3(1.15, 0.8, 0.62), true],
	&"fae_cauldron": [Vector3(0.95, 0.95, 0.95), true],
	&"grooming_kit": [Vector3(0.6, 0.33, 0.3), false],
}


## One of our props, base at y = 0, facing -Z. Collides when listed so.
static func model(id: StringName) -> Node3D:
	var spec: Array = OURS.get(id, [Vector3.ONE * 0.5, false])
	var size: Vector3 = spec[0]
	var root: Node3D
	if spec[1]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
		cs.position.y = size.y * 0.5
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	root.name = String(id)
	var pair := PropModels.pair(MODEL_DIR + String(id) + ".glb", String(id))
	if not pair.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = pair[0]
		mi.transform = PropShapes.fit(mi.mesh.get_aabb(), size)
		mi.visibility_range_end = 120.0
		root.add_child(mi)
	else:
		push_error("Act4Props: no model %s" % id)
	return root


## Puts a prop (ours, or an estate catalogue id) on the ground at `at`,
## facing `face`, under `parent`.
static func place(parent: Node, id: StringName, at: Vector3, face: Vector3 = Vector3.INF, scale_by: float = 1.0) -> Node3D:
	var node: Node3D = model(id) if OURS.has(id) else PropLib.build(id)
	parent.add_child(node)
	var ground := Act4Walk.ground_point(parent as Node3D if parent is Node3D else null, at)
	node.global_position = ground
	if face != Vector3.INF:
		var flat := Vector3(face.x, ground.y, face.z)
		if ground.distance_squared_to(flat) > 0.01:
			node.look_at(flat, Vector3.UP)
	if scale_by != 1.0:
		node.scale = Vector3.ONE * scale_by
	return node


## Lucien's picnic on the glen shore: the purple blanket, the wine, a basket
## and cushions, a faelight lantern for later.
static func picnic(owner: Node3D, at: Vector3, toward: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Picnic"
	owner.add_child(root)
	root.global_position = at
	var fwd := Vector3(toward.x - at.x, 0.0, toward.z - at.z).normalized()
	if fwd == Vector3.ZERO:
		fwd = Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	place(root, &"picnic_blanket", at, at + fwd)
	place(root, &"picnic_wine", at + right * 0.5 + fwd * 0.2, at)
	place(root, &"basket_produce", at - right * 1.6 - fwd * 0.4, at)
	place(root, &"cushion_pile", at + right * 1.7 - fwd * 0.6, at)
	place(root, &"faelight_lantern", at - right * 1.5 + fwd * 0.9, at)
	return root


## A ring of water thrown up where she goes in, then falling back.
static func splash(owner: Node3D, at: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Splash"
	p.one_shot = true
	p.amount = 90
	p.lifetime = 1.4
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 38.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 0.6
	pm.emission_ring_inner_radius = 0.3
	pm.emission_ring_height = 0.05
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.95))
	ramp.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	p.draw_pass_1 = _droplet_mesh(Color(0.93, 0.96, 1.0))
	owner.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p


## Starlight clinging to her as she swims: pearly motes that rise off her for
## a while and fade (the pool "filled with starlight", [C ch18]).
static func cling_sparkles(on: Node3D, seconds: float = 9.0) -> void:
	if on == null or not on.is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.name = "StarlightCling"
	p.amount = 60
	p.lifetime = 1.8
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.85, 0.0))
	ramp.add_point(0.25, Color(1.0, 0.95, 1.0, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.85, 0.8, 1.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	p.draw_pass_1 = _droplet_mesh(Color(1.0, 0.95, 0.85), true)
	on.add_child(p)
	p.position = Vector3.UP * 1.0
	p.emitting = true
	var t := on.get_tree().create_timer(seconds)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			on.get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if is_instance_valid(p):
					p.queue_free()))


## A soft camera-facing quad for droplets and motes (unshaded, additive glow
## for the starlight).
static func _droplet_mesh(tint: Color, glow: bool = false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07) if not glow else Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.emission_enabled = true
		m.emission = tint
		m.emission_energy_multiplier = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 32
	gt.height = 32
	m.albedo_texture = gt
	q.material = m
	return q


## Petals, leaves and grit whipped along `dir` (the wings' downdraft, the foul
## wind as it goes): rose and leaf-green flakes that tumble and fall.
static func gust_leaves(owner: Node3D, at: Vector3, dir: Vector3) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.name = "Gust"
	p.one_shot = true
	p.amount = 120
	p.lifetime = 2.4
	p.explosiveness = 0.7
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.5
	pm.direction = dir if dir != Vector3.ZERO else Vector3.UP
	pm.spread = 50.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0, -2.5, 0)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var cols := Gradient.new()
	cols.set_color(0, Color(0.96, 0.62, 0.72))
	cols.add_point(0.5, Color(0.55, 0.72, 0.48))
	cols.set_color(cols.get_point_count() - 1, Color(0.82, 0.74, 0.62))
	var ct := GradientTexture1D.new()
	ct.gradient = cols
	pm.color_initial_ramp = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.06)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.7
	q.material = m
	p.draw_pass_1 = q
	owner.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## A puff of gravel dust where an unseen foot came down.
static func grit_puff(owner: Node3D, at: Vector3) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.name = "Grit"
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.9
	p.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.80, 0.74, 0.9))
	ramp.set_color(1, Color(0.86, 0.80, 0.74, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	p.draw_pass_1 = _droplet_mesh(Color(0.9, 0.84, 0.78))
	owner.add_child(p)
	p.global_position = at + Vector3.UP * 0.05
	p.emitting = true
	p.finished.connect(p.queue_free)

## The opening film's hook (lane L33, film #17): deep in the dark winter wood,
## snow slides off a branch, and a huge yellow eye opens, far too aware.
## A real lit set (not the mural): the horror is never painted over (R3).
## Built in code for a FilmInsert's own world.
class_name WolfEyeStage
extends Node3D

const WOLF := "res://creatures/models/great_wolf.gltf"
const TREE := "res://world/spring_court/shared/models/winter_bare.glb"
const BOUGH := "res://world/spring_court/shared/models/winter_bough.glb"
const SEED := 1702

var camera: Camera3D
var eye: Node3D
var wolf_point: Vector3
var _t: float = 0.0
var _from: Transform3D
var _to: Transform3D
var _aimed: bool = false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.006, 0.014)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.07, 0.12)
	env.ambient_light_energy = 0.4
	# AgX like every grade (T3b); 1.8 holds Filmic's mid band (docs/tuning.md).
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.14)
	env.fog_density = 0.06
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.25
	moon.rotation_degrees = Vector3(-35, 150, 0)
	add_child(moon)
	var snow_mat := MaterialLibrary.surface()
	snow_mat.albedo_color = Color(0.55, 0.6, 0.72)
	snow_mat.roughness = 0.9
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	ground.material_override = snow_mat
	add_child(ground)
	var bark := MaterialLibrary.surface()
	bark.albedo_color = Color(0.06, 0.05, 0.05)
	# Real winter trees (lane L61): tools/woods/blender/woods_trees.py grows
	# each trunk, limb and twig as one Skin-modifier surface, so nothing here
	# is a cylinder. Two meshes, shared by every tree.
	var tree_mesh := _near_mesh(TREE)
	var bough_mesh := _near_mesh(BOUGH)
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(2.5, 18.0)
		var s := rng.randf_range(0.8, 1.2)
		_tree(tree_mesh, bark, Vector3(cos(a) * r, 0.0, sin(a) * r - 2.0), rng.randf() * TAU, s)
	# The tree the snow-laden bough grows from, just off the wolf's left.
	_tree(tree_mesh, bark, Vector3(-2.4, 0.0, -1.2), 0.6, 1.0)
	# The bough that sheds its snow: it spans x -2.1..0.3 at 2.6 m, the
	# span the Shed particles cover.
	var branch := MeshInstance3D.new()
	branch.name = "Bough"
	branch.mesh = bough_mesh
	branch.material_override = bark
	branch.position = Vector3(-2.1, 2.6, -1.2)
	branch.rotation_degrees.z = -8.0
	add_child(branch)
	add_child(_snowfall(Vector3(0, 6, 0), Vector3(8, 0.5, 8), 900, 7.0, Color(0.7, 0.75, 0.9, 0.6)))
	var shed := _snowfall(Vector3(-0.9, 2.65, -1.2), Vector3(1.1, 0.05, 0.05), 160, 1.6, Color(0.8, 0.85, 1.0, 0.8))
	shed.name = "Shed"
	shed.emitting = false
	shed.one_shot = true
	shed.explosiveness = 0.7
	add_child(shed)
	if ResourceLoader.exists(WOLF):
		var wolf := (load(WOLF) as PackedScene).instantiate() as Node3D
		wolf.scale = Vector3.ONE * 1.25
		wolf.position = Vector3(0.0, 0.0, -2.4)
		# The glTF faces -z; turn it to look into the lens.
		wolf.rotation_degrees.y = 198.0
		add_child(wolf)
		var dark := MaterialLibrary.surface()
		dark.albedo_color = Color(0.04, 0.04, 0.05)
		dark.roughness = 0.8
		dark.rim_enabled = true
		dark.rim = 0.6
		dark.rim_tint = 0.2
		_dress(wolf, dark)
		var ap := wolf.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap and ap.has_animation(&"idle"):
			ap.play(&"idle")
			ap.speed_scale = 0.4
		eye = _eye(wolf)
		wolf_point = wolf.global_transform * (eye.get_meta(&"model_point") as Vector3)
	camera = Camera3D.new()
	camera.fov = 30.0
	add_child(camera)
	camera.current = true
	_aim(wolf_point if eye else Vector3(0, 1.4, -1.6))


## The full-detail ("near") mesh of a woods_trees model.
func _near_mesh(path: String) -> Mesh:
	var root := (load(path) as PackedScene).instantiate()
	var near := root.find_child("near", true, false) as MeshInstance3D
	var mesh := near.mesh if near else null
	root.free()
	return mesh


func _tree(mesh: Mesh, bark: Material, at: Vector3, yaw: float, s: float) -> void:
	var trunk := MeshInstance3D.new()
	trunk.mesh = mesh
	trunk.material_override = bark
	trunk.position = at
	trunk.rotation.y = yaw
	trunk.scale = Vector3.ONE * s
	add_child(trunk)


## Frames the eyes: from where the head really is once the idle has posed it.
func _aim(head: Vector3) -> void:
	_from = Transform3D(Basis(), head + Vector3(0.55, 0.12, 2.2)).looking_at(head + Vector3(-0.1, -0.05, 0), Vector3.UP)
	_to = Transform3D(Basis(), head + Vector3(0.35, 0.06, 1.25)).looking_at(head, Vector3.UP)
	camera.global_transform = _from


func _dress(n: Node, m: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = m
	for c in n.get_children():
		_dress(c, m)


## The yellow eye: an emissive almond on the head bone, closed (scale.y 0).
## Both eyes on the wolf's head bone, opened by `wake()` (scale.y 0 to 1).
## Placed in the model's own frame from the rest pose (the glTF faces -z),
## so it never depends on which way the bone's axes point. Returns the pair's
## frame, which is level and faces the way the wolf does.
func _eye(wolf: Node3D) -> Node3D:
	var frame := Node3D.new()
	frame.name = "Eyes"
	var at_model := Vector3(0.0, 1.35, -1.0)
	var holder: Node3D = wolf
	for s in wolf.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var bi := sk.find_bone("head")
		if bi < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = "head"
		sk.add_child(att)
		holder = att
		var rest := sk.get_bone_global_rest(bi)
		# Skeleton space to the wolf's own space (both fixed at build time).
		var sk_in_wolf := wolf.global_transform.affine_inverse() * sk.global_transform
		at_model = sk_in_wolf * rest.origin + Vector3(0.0, 0.05, -0.54)
		frame.transform = rest.affine_inverse() * sk_in_wolf.affine_inverse() * Transform3D(Basis(), at_model)
		break
	if holder == wolf:
		frame.position = at_model
	holder.add_child(frame)
	frame.set_meta(&"model_point", at_model)
	var m := MaterialLibrary.surface()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.12)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.72, 0.08)
	m.emission_energy_multiplier = 5.0
	var pm := MaterialLibrary.surface()
	pm.albedo_color = Color.BLACK
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		e.name = "Eye%s" % ("L" if side < 0.0 else "R")
		var sph := SphereMesh.new()
		sph.radius = 0.026
		sph.height = 0.038
		e.mesh = sph
		e.material_override = m
		e.position = Vector3(side * 0.085, 0.0, 0.0)
		e.rotation_degrees.y = side * 28.0
		e.scale = Vector3(1.5, 0.0, 1.0)
		frame.add_child(e)
		var pupil := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.007, 0.042, 0.02)
		pupil.mesh = pb
		pupil.material_override = pm
		pupil.position = Vector3(0, 0, -0.026)
		e.add_child(pupil)
	return frame


func _snowfall(at: Vector3, box: Vector3, amount: int, life: float, color: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = at
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.gravity = Vector3(0.05, -0.9, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var sm := MaterialLibrary.surface()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = color
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = sm
	p.draw_pass_1 = q
	return p


func _process(delta: float) -> void:
	# Track the eyes where the idle has really put the head (it breathes).
	if eye:
		wolf_point = eye.global_position if _aimed else wolf_point
		_aimed = true
		_aim(wolf_point)
	_t = minf(1.0, _t + delta / 4.0)
	var k := _t * _t * (3.0 - 2.0 * _t)
	camera.global_transform = _from.interpolate_with(_to, k)


## Snow slides off the branch; a beat later the eye opens.
func wake() -> void:
	(get_node("Shed") as GPUParticles3D).restart()
	if eye == null:
		return
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_method(func(v: float) -> void:
		for e in eye.get_children():
			(e as Node3D).scale.y = v, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## The living mural (lane L33): the history every human child is told, painted
## in gold leaf and ink by an unseen brush. Each tableau is a small diorama of
## real models in silhouette (mural_paint: ink bodies, gilt rims) in front of
## a painted backdrop, built in code and laid out along +x, so the camera can
## cut from one to the next. Lives in a FilmInsert's own world.
##
## The director calls `play(id, seconds)` (cut to the tableau, paint it on,
## move along its rail) and tweens parameters with `tween_param`. Tableaux:
## land (the island, later the Wall), court (the High Fae over the beasts),
## slaves, war, treaty; memory flashes: mother, house, ships.
## Built from fixed seeds; nothing here depends on the game world.
## Script: /mnt/project-files/plans/film/scripts.md §1.
class_name MuralStage
extends Node3D

const SEED := 20261102
const SPACING := 80.0
const PAINT := preload("res://story/film/mural/mural_paint.gdshader")
const MAP := preload("res://story/film/mural/mural_map.gdshader")
const SKY := preload("res://story/film/mural/mural_sky.gdshader")
const PEOPLE := "res://creatures/models/people/%s.gltf"
const FAE := "res://creatures/models/fae/%s.gltf"
const CAST := "res://characters/%s/%s_model.tscn"
const WOLF := "res://creatures/models/great_wolf.gltf"
const IDS: Array[StringName] = [&"land", &"court", &"slaves", &"war", &"treaty",
		&"mother", &"house", &"ships"]

const INK := Color(0.045, 0.035, 0.085)
const GOLD := Color(1.0, 0.82, 0.45)
const SILVER := Color(0.86, 0.9, 1.0)
const SICK := Color(0.78, 0.86, 0.35)
const ROSE := Color(1.0, 0.62, 0.72)

var camera: Camera3D
var environment: Environment
## id -> {root: Node3D, mats: Array[ShaderMaterial], rail: [Transform3D, Transform3D], fov: float}
var tableaux: Dictionary = {}
var current: StringName = &""

var _rng := RandomNumberGenerator.new()
var _rail_t: float = 1.0
var _rail_len: float = 1.0
var _shake: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	_rng.seed = SEED
	var we := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.015, 0.04)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.1
	environment.glow_strength = 1.15
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 0.85
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	we.environment = environment
	add_child(we)
	camera = Camera3D.new()
	camera.name = "MuralCamera"
	camera.fov = 40.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true
	for i in IDS.size():
		_build(IDS[i], Vector3(SPACING * i, 0.0, 0.0))


func _process(delta: float) -> void:
	_clock += delta
	var t: Dictionary = tableaux.get(current, {})
	if t.is_empty():
		return
	_rail_t = minf(1.0, _rail_t + delta / _rail_len)
	var k := _rail_t * _rail_t * _rail_t * (_rail_t * (_rail_t * 6.0 - 15.0) + 10.0)
	var rail: Array = t.rail
	var a: Transform3D = rail[0]
	var b: Transform3D = rail[1]
	var x := a.interpolate_with(b, k)
	if _shake > 0.0:
		x.origin += Vector3(sin(_clock * 23.0), cos(_clock * 19.0), 0.0) * 0.02 * _shake
	# A painter's breath: the slightest drift, never still.
	x = x.rotated_local(Vector3.UP, sin(_clock * 0.31) * 0.004)
	camera.global_transform = x
	camera.fov = float(t.fov)


## Cuts to tableau `id`, paints it on over `reveal_seconds`, and moves along
## its rail for `seconds`.
func play(id: StringName, seconds: float, reveal_seconds: float = 2.6) -> void:
	if not tableaux.has(id):
		return
	current = id
	_rail_t = 0.0
	_rail_len = maxf(seconds, 0.1)
	_shake = 0.0
	for m: ShaderMaterial in (tableaux[id] as Dictionary).mats:
		if m.shader != MAP:
			m.set_shader_parameter(&"reveal", 0.0)
	if reveal_seconds <= 0.0:
		set_param(id, &"reveal", 1.0)
	else:
		tween_param(id, &"reveal", 0.0, 1.0, reveal_seconds)
	_process(0.0)


## Sets `param` on every paint material of tableau `id` (map shader included
## when it has the uniform).
func set_param(id: StringName, param: StringName, value: Variant, only: String = "") -> void:
	for m: ShaderMaterial in (tableaux.get(id, {}) as Dictionary).get("mats", []):
		if only != "" and String(m.resource_name) != only:
			continue
		if _has_uniform(m, param):
			m.set_shader_parameter(param, value)


func tween_param(id: StringName, param: StringName, from: float, to: float, seconds: float,
		only: String = "") -> Tween:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: set_param(id, param, v, only), from, to, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


func shake(amount: float) -> void:
	_shake = amount


func root_of(id: StringName) -> Node3D:
	return (tableaux.get(id, {}) as Dictionary).get("root") as Node3D


static func _has_uniform(m: ShaderMaterial, param: StringName) -> bool:
	for u in m.shader.get_shader_uniform_list():
		if StringName(u.name) == param:
			return true
	return false


# --- building blocks ------------------------------------------------------------

func _mat(t: Dictionary, ink: Color, gold: Color, rim_gain: float = 1.6, mat_name: String = "") -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT
	m.resource_name = mat_name
	m.set_shader_parameter(&"ink", ink)
	m.set_shader_parameter(&"gold", gold)
	m.set_shader_parameter(&"rim_gain", rim_gain)
	var root := t.root as Node3D
	m.set_shader_parameter(&"origin", root.position + Vector3(-12.0, -4.0, 0.0))
	m.set_shader_parameter(&"span", 24.0)
	(t.mats as Array).append(m)
	return m


func _sky(t: Dictionary, at: Vector3, size: Vector2, top: Color, low: Color) -> void:
	var m := ShaderMaterial.new()
	m.shader = SKY
	m.set_shader_parameter(&"top", top)
	m.set_shader_parameter(&"low", low)
	(t.mats as Array).append(m)
	var q := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	q.mesh = quad
	q.material_override = m
	q.position = at
	(t.root as Node3D).add_child(q)


func _paint_all(node: Node, m: ShaderMaterial) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = m
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in node.get_children():
		_paint_all(c, m)


## A model (gltf or scene) in silhouette at `at`, facing `yaw` degrees, with
## clip `clip` held at `clip_at` (0..1 of its length) or looping when < 0.
func _figure(t: Dictionary, path: String, at: Vector3, yaw: float, s: float, m: ShaderMaterial,
		clip: StringName = &"idle", clip_at: float = -1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = at
	n.rotation_degrees.y = yaw
	n.scale = Vector3.ONE * s
	(t.root as Node3D).add_child(n)
	_paint_all(n, m)
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(clip):
		ap.play(clip)
		if clip_at >= 0.0:
			ap.seek(ap.get_animation(clip).length * clip_at, true)
			ap.pause()
		else:
			ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			ap.seek(_rng.randf() * ap.get_animation(clip).length, true)
	return n


func _box(t: Dictionary, size: Vector3, at: Vector3, m: ShaderMaterial, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = at
	mi.rotation_degrees = rot
	mi.material_override = m
	(t.root as Node3D).add_child(mi)
	return mi


func _cone(t: Dictionary, radius: float, height: float, at: Vector3, m: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	mi.mesh = c
	mi.position = at + Vector3.UP * height * 0.5
	mi.material_override = m
	(t.root as Node3D).add_child(mi)
	return mi


## A crown of gilt leaves on a figure's head: a ring sat on the crown of the
## skull (bone "head", height from the figure's own bounds), or `h` up when
## the model has no head bone. `_m` is unused: crowns are always gold leaf.
func _crown(fig: Node3D, _m: ShaderMaterial, h: float, spikes: int = 9, r: float = 0.13) -> void:
	if fig == null:
		return
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaf_mat.albedo_color = GOLD
	leaf_mat.emission_enabled = true
	leaf_mat.emission = GOLD
	leaf_mat.emission_energy_multiplier = 2.2
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var holder: Node3D = fig
	var top := _top_of(fig)
	var base := h
	var scale_k := fig.global_transform.basis.get_scale().y
	for s in fig.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var bi := sk.find_bone("head")
		if bi < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = "head"
		sk.add_child(att)
		holder = att
		var bone_y := (sk.global_transform * sk.get_bone_global_pose(bi)).origin.y
		scale_k = sk.global_transform.basis.get_scale().y
		# Sit the ring just under the top of the skull, in the bone's own units.
		base = (top - bone_y) / maxf(scale_k, 0.001) - 0.06 if top > bone_y else 0.12
		break
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = r * 0.92
	tor.outer_radius = r * 1.05
	ring.mesh = tor
	ring.material_override = leaf_mat
	ring.position = Vector3(0.0, base, 0.0)
	holder.add_child(ring)
	for i in spikes:
		var a := TAU * float(i) / float(spikes)
		var leaf := MeshInstance3D.new()
		var p := PrismMesh.new()
		p.size = Vector3(0.045, 0.1 + 0.07 * float(i % 2), 0.012)
		leaf.mesh = p
		leaf.material_override = leaf_mat
		leaf.position = Vector3(cos(a) * r, base + p.size.y * 0.5, sin(a) * r)
		leaf.rotation.y = -a + PI * 0.5
		holder.add_child(leaf)


## The top of a model in world y, from its meshes' bounds at rest.
static func _top_of(fig: Node3D) -> float:
	var top := -INF
	for n in fig.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		var box := vi.global_transform * vi.get_aabb()
		top = maxf(top, box.end.y)
	return top if top > -INF else fig.global_position.y + 1.8


func _particles(t: Dictionary, at: Vector3, box: Vector3, color: Color, amount: int, size: float,
		gravity: Vector3, life: float, additive: bool = true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.position = at
	p.visibility_aabb = AABB(-box * 2.0, box * 4.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.gravity = gravity
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = color
	sm.albedo_texture = _soft_dot()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.emission_enabled = true
	sm.emission = color
	sm.emission_energy_multiplier = 1.6
	quad.material = sm
	p.draw_pass_1 = quad
	(t.root as Node3D).add_child(p)
	return p


## A soft round dot (white core, clear edge) shared by every particle here.
static var _dot: GradientTexture2D


static func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.75))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 64
		_dot.height = 64
	return _dot


func _rail(t: Dictionary, from_pos: Vector3, from_look: Vector3, to_pos: Vector3, to_look: Vector3, fov: float) -> void:
	var o := (t.root as Node3D).position
	var a := Transform3D(Basis(), o + from_pos).looking_at(o + from_look, Vector3.UP)
	var b := Transform3D(Basis(), o + to_pos).looking_at(o + to_look, Vector3.UP)
	t.rail = [a, b]
	t.fov = fov


# --- tableaux --------------------------------------------------------------------

func _build(id: StringName, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = String(id).capitalize()
	root.position = at
	add_child(root)
	var t := {root = root, mats = [], rail = [Transform3D(), Transform3D()], fov = 40.0}
	tableaux[id] = t
	call("_build_" + String(id), t)


## The island under stars (#1, #2), later the Wall (#8).
func _build_land(t: Dictionary) -> void:
	var m := ShaderMaterial.new()
	m.shader = MAP
	m.set_shader_parameter(&"draw", 0.0)
	m.set_shader_parameter(&"fill", 0.0)
	(t.mats as Array).append(m)
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24.0, 24.0)
	plane.mesh = pm
	plane.material_override = m
	(t.root as Node3D).add_child(plane)
	# Gold dust drifting over the map.
	_particles(t, Vector3(0, 2.0, 0), Vector3(10, 1.5, 10), Color(1.0, 0.85, 0.5, 0.6), 220, 0.05,
			Vector3(0, 0.02, 0), 9.0)
	_rail(t, Vector3(0.0, 15.5, 10.0), Vector3(0.0, 0.0, 0.5), Vector3(0.0, 12.0, 6.0), Vector3(0.0, 0.0, -0.5), 46.0)


## Map plane uniforms, for the director: draw, fill, wall, split, wash.
func land_material() -> ShaderMaterial:
	return ((tableaux[&"land"] as Dictionary).mats as Array)[0] as ShaderMaterial


## The High Fae on a ridge before their glittering cities (#3); under them
## the beasts uncoil from the ink (#4).
func _build_court(t: Dictionary) -> void:
	_sky(t, Vector3(0, 6, -16), Vector2(64, 30), Color(0.07, 0.04, 0.16), Color(0.42, 0.2, 0.36))
	var fae := _mat(t, INK, GOLD, 2.0, "fae")
	var city := _mat(t, Color(0.08, 0.05, 0.13), Color(1.0, 0.86, 0.6), 1.2, "fae")
	city.set_shader_parameter(&"glow", 0.25)
	for i in 13:
		var x := -14.0 + i * 2.4 + _rng.randf_range(-0.6, 0.6)
		_cone(t, _rng.randf_range(0.5, 1.1), _rng.randf_range(5.0, 13.0), Vector3(x, 0.4, -9.0 - _rng.randf() * 3.0), city)
	# The ridge they stand on.
	var ridge := _box(t, Vector3(30, 1.2, 4), Vector3(0, -0.2, -1.5), _mat(t, Color(0.03, 0.025, 0.06), GOLD, 0.8, "fae"))
	ridge.rotation_degrees.z = 1.5
	var who := [[CAST % ["tamlin", "tamlin"], -2.6, 18.0], [CAST % ["lucien", "lucien"], 1.2, -20.0],
		[PEOPLE % "calanmai_1", -5.6, 30.0], [PEOPLE % "reveler_2", 4.4, -32.0], [PEOPLE % "calanmai_3", 7.2, -10.0]]
	for w: Array in who:
		var f := _figure(t, String(w[0]), Vector3(float(w[1]), 0.4, -1.5), float(w[2]), 1.25, fae)
		_crown(f, fae, 2.15)
	_particles(t, Vector3(0, 4, -2), Vector3(12, 3, 3), ROSE, 160, 0.09, Vector3(0.15, -0.25, 0), 10.0, false)
	_particles(t, Vector3(0, 6, -9), Vector3(14, 5, 1), Color(1.0, 0.9, 0.6, 0.8), 260, 0.04, Vector3.ZERO, 6.0)
	# The beasts below, in the ink under the ridge.
	var beast := _mat(t, Color(0.015, 0.015, 0.02), SICK * 0.8, 0.85, "beast")
	beast.set_shader_parameter(&"rim_power", 4.0)
	# The ink under the ridge: no sky down here, only the dark they live in.
	_sky(t, Vector3(0.0, -4.6, -0.6), Vector2(70.0, 8.2), Color(0.01, 0.008, 0.02), Color(0.03, 0.02, 0.025))
	(t.mats.back() as ShaderMaterial).set_shader_parameter(&"stars", 0.0)
	_figure(t, FAE % "bogge", Vector3(-3.2, -4.6, 2.2), 30.0, 1.6, beast, &"idle")
	_figure(t, WOLF, Vector3(0.6, -4.8, 2.8), -25.0, 1.2, beast, &"stalk")
	_figure(t, PEOPLE % "fae_longlimb_true", Vector3(3.8, -4.7, 1.6), -40.0, 1.3, beast)
	_figure(t, FAE % "naga", Vector3(-6.4, -4.8, 1.0), 50.0, 1.3, beast, &"")
	_figure(t, FAE % "attor", Vector3(6.6, -4.4, 0.6), -60.0, 1.2, beast, &"")
	_box(t, Vector3(30, 1.0, 8), Vector3(0, -5.3, 2.5), _mat(t, Color(0.015, 0.012, 0.02), SICK, 0.3, "beast"))
	# One yellow eye in the dark, opened by the director (eye.scale.y 0 → 1).
	var eye := MeshInstance3D.new()
	eye.name = "Eye"
	var sph := SphereMesh.new()
	sph.radius = 0.09
	sph.height = 0.18
	eye.mesh = sph
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.8, 0.15)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.75, 0.1)
	em.emission_energy_multiplier = 6.0
	eye.material_override = em
	eye.position = Vector3(1.5, -3.3, 1.0)
	eye.scale = Vector3(2.2, 0.0, 1.0)
	(t.root as Node3D).add_child(eye)
	_rail(t, Vector3(0.0, 2.4, 13.0), Vector3(0.0, 2.6, -2.0), Vector3(0.0, 2.0, 10.5), Vector3(0.0, 2.4, -2.0), 44.0)
	t[&"rail_beasts"] = [Vector3(0.0, -1.6, 10.0), Vector3(0.0, -3.4, 2.0), Vector3(0.0, -2.4, 7.6), Vector3(0.6, -3.2, 3.0)]


## Switches the court's rail to the beasts below (#4).
func court_to_beasts(seconds: float) -> void:
	var t := tableaux[&"court"] as Dictionary
	var r: Array = t[&"rail_beasts"]
	var from := camera.global_transform
	var o := (t.root as Node3D).position
	var to := Transform3D(Basis(), o + (r[2] as Vector3)).looking_at(o + (r[3] as Vector3), Vector3.UP)
	t.rail = [from, to]
	_rail_t = 0.0
	_rail_len = seconds
	_shake = 0.4


## Humans small and bent in chains at the fae's feet, building their towers (#5).
func _build_slaves(t: Dictionary) -> void:
	_sky(t, Vector3(0, 6, -16), Vector2(64, 30), Color(0.06, 0.03, 0.08), Color(0.36, 0.12, 0.12))
	var fae := _mat(t, INK, GOLD, 2.0, "fae")
	var human := _mat(t, Color(0.07, 0.05, 0.07), Color(1.0, 0.7, 0.45), 1.4, "human")
	_figure(t, CAST % ["tamlin", "tamlin"], Vector3(-4.6, 0.0, -5.0), 25.0, 2.1, fae)
	_figure(t, CAST % ["lucien", "lucien"], Vector3(5.0, 0.0, -5.4), -25.0, 2.1, fae)
	# A temple rising, stone by stone.
	var stone := _mat(t, Color(0.1, 0.07, 0.08), GOLD, 0.9, "human")
	_box(t, Vector3(44, 0.4, 24), Vector3(0, -0.2, -5.0), _mat(t, Color(0.05, 0.03, 0.04), GOLD, 0.6, "human"))
	for i in 5:
		_box(t, Vector3(0.7, 4.0 - i * 0.2, 0.7), Vector3(-2.4 + i * 1.2, 2.0, -8.0), stone)
	_box(t, Vector3(7.0, 0.6, 1.6), Vector3(0, 4.3, -8.0), stone)
	var kinds := ["human_man", "human_woman", "human_youth", "human_elder"]
	var feet: Array[Vector3] = []
	for i in 9:
		var x := -5.2 + i * 1.3
		var p := Vector3(x, 0.0, -0.4 + _rng.randf_range(-0.4, 0.4))
		_figure(t, PEOPLE % kinds[i % 4], p, _rng.randf_range(-30, 30), 0.85, human, &"bow", 0.5)
		if i % 3 == 1:
			_box(t, Vector3(0.5, 0.4, 0.4), p + Vector3(0, 1.05, 0.25), stone)
		feet.append(p + Vector3(0, 0.12, 0.1))
	var chain := _mat(t, Color(0.2, 0.18, 0.2), Color(1.0, 0.9, 0.75), 1.8, "chain")
	for i in feet.size() - 1:
		var a := feet[i]
		var b := feet[i + 1]
		var links := 8
		for k in links:
			var link := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.03
			tor.outer_radius = 0.06
			link.mesh = tor
			link.material_override = chain
			link.position = a.lerp(b, (k + 0.5) / links) - Vector3(0, 0.05 * sin(PI * (k + 0.5) / links), 0)
			link.rotation = Vector3(PI * 0.5 * (k % 2), atan2(b.x - a.x, b.z - a.z), 0)
			(t.root as Node3D).add_child(link)
	_rail(t, Vector3(-2.0, 1.2, 8.5), Vector3(0.0, 2.2, -2.0), Vector3(1.5, 1.6, 7.0), Vector3(0.0, 2.6, -3.0), 42.0)


## They rise: spears, banners and a wave of painted fire against the fae's light (#6).
func _build_war(t: Dictionary) -> void:
	_sky(t, Vector3(0, 6, -16), Vector2(64, 30), Color(0.08, 0.02, 0.03), Color(0.6, 0.18, 0.06))
	var human := _mat(t, Color(0.06, 0.04, 0.05), Color(1.0, 0.55, 0.28), 1.8, "human")
	var fae := _mat(t, Color(0.14, 0.12, 0.18), Color(1.0, 0.95, 0.85), 2.4, "fae")
	fae.set_shader_parameter(&"glow", 0.6)
	_box(t, Vector3(44, 0.4, 24), Vector3(0, -0.2, -4.0), _mat(t, Color(0.05, 0.025, 0.02), Color(1.0, 0.5, 0.25), 0.6, "human"))
	var kinds := ["human_man", "human_youth", "human_woman", "human_man", "human_elder"]
	for i in 11:
		var p := Vector3(-7.0 + i * 0.9, 0.0, 1.0 + _rng.randf_range(-0.8, 0.8))
		_figure(t, PEOPLE % kinds[i % 5], p, 160.0 + _rng.randf_range(-15, 15), 0.95, human, &"walk", _rng.randf())
		var spear := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.02
		cyl.bottom_radius = 0.02
		cyl.height = 2.8
		spear.mesh = cyl
		spear.material_override = human
		spear.position = p + Vector3(0.25, 1.7, -0.2)
		spear.rotation_degrees = Vector3(-28, 0, 6)
		(t.root as Node3D).add_child(spear)
	for i in 3:
		var banner := _box(t, Vector3(0.9, 1.3, 0.02), Vector3(-5.0 + i * 4.0, 3.4, 1.2), human, Vector3(0, 0, 4))
		banner.name = "Banner%d" % i
	for i in 4:
		_figure(t, PEOPLE % ["calanmai_1", "reveler_1", "calanmai_2", "reveler_3"][i],
				Vector3(-3.0 + i * 2.2, 0.0, -6.0), 15.0 - i * 10.0, 1.35, fae)
	_particles(t, Vector3(0, 1.2, -2.0), Vector3(9, 1.2, 1.5), Color(1.0, 0.42, 0.12, 0.85), 220, 0.24,
			Vector3(0, 1.6, 0), 2.2)
	_particles(t, Vector3(0, 3.0, -2.0), Vector3(10, 3.0, 2.0), Color(1.0, 0.7, 0.3, 0.9), 260, 0.05,
			Vector3(0.2, 1.0, 0), 4.0)
	_particles(t, Vector3(0, 4.0, -5.0), Vector3(10, 2.0, 1.0), Color(0.25, 0.2, 0.22, 0.5), 90, 1.6,
			Vector3(0.1, 0.5, 0), 6.0, false)
	_rail(t, Vector3(0.0, 1.0, 9.5), Vector3(0.0, 2.0, -3.0), Vector3(0.0, 1.4, 6.0), Vector3(0.0, 2.4, -4.0), 46.0)


## Six human queens in silver lay their hands on one sheet; a gold seal (#7).
func _build_treaty(t: Dictionary) -> void:
	_sky(t, Vector3(0, 6, -14), Vector2(60, 30), Color(0.05, 0.05, 0.12), Color(0.22, 0.24, 0.4))
	var queen := _mat(t, Color(0.06, 0.06, 0.1), SILVER, 2.2, "queen")
	var table := _mat(t, Color(0.08, 0.06, 0.09), GOLD, 0.8, "queen")
	_box(t, Vector3(3.2, 0.9, 1.6), Vector3(0, 0.45, 0), table)
	var sheet := _box(t, Vector3(1.3, 0.01, 0.9), Vector3(0, 0.91, 0), _mat(t, Color(0.85, 0.82, 0.74), SILVER, 0.5, "queen"))
	sheet.name = "Sheet"
	for i in 6:
		var a := PI * (0.15 + 0.7 * float(i) / 5.0)
		var p := Vector3(cos(a) * -2.4, 0.0, -sin(a) * 1.6 - 0.2)
		var q := _figure(t, PEOPLE % "human_woman", p, rad_to_deg(atan2(-p.x, -p.z)), 1.0, queen, &"talk", 0.3)
		_crown(q, queen, 1.7, 7, 0.1)
	var seal := MeshInstance3D.new()
	seal.name = "Seal"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.14
	cyl.height = 0.5
	seal.mesh = cyl
	var gold := _mat(t, Color(0.6, 0.42, 0.12), GOLD, 2.0, "seal")
	gold.set_shader_parameter(&"glow", 0.8)
	seal.material_override = gold
	seal.position = Vector3(0.0, 2.2, 0.0)
	(t.root as Node3D).add_child(seal)
	var wax := MeshInstance3D.new()
	wax.name = "Wax"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.16
	disc.bottom_radius = 0.16
	disc.height = 0.02
	wax.mesh = disc
	wax.material_override = _mat(t, Color(0.7, 0.05, 0.1), Color(1.0, 0.5, 0.5), 1.0, "seal")
	wax.position = Vector3(0.0, 0.925, 0.0)
	wax.scale = Vector3.ZERO
	(t.root as Node3D).add_child(wax)
	_rail(t, Vector3(0.0, 2.4, 6.8), Vector3(0.0, 1.3, -0.4), Vector3(0.0, 1.9, 4.6), Vector3(0.0, 1.1, -0.2), 40.0)


## The seal presses into the wax (#7).
func press_seal(seconds: float) -> void:
	var root := root_of(&"treaty")
	var seal := root.get_node("Seal") as Node3D
	var wax := root.get_node("Wax") as Node3D
	var tw := create_tween()
	tw.tween_property(seal, ^"position:y", 1.18, seconds * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: wax.scale = Vector3.ONE)
	tw.tween_property(seal, ^"position:y", 1.9, seconds * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A woman and a small girl, hand in hand; the woman dissolves (#12).
func _build_mother(t: Dictionary) -> void:
	_sky(t, Vector3(0, 3, -8), Vector2(40, 20), Color(0.1, 0.06, 0.12), Color(0.5, 0.3, 0.3))
	var mother := _mat(t, Color(0.08, 0.05, 0.08), GOLD, 2.0, "mother")
	var girl := _mat(t, Color(0.08, 0.05, 0.08), Color(1.0, 0.9, 0.7), 2.0, "girl")
	_figure(t, PEOPLE % "human_woman", Vector3(-0.32, 0, 0), 20.0, 1.0, mother, &"idle")
	_figure(t, PEOPLE % "human_youth", Vector3(0.3, 0, 0.1), -20.0, 0.66, girl, &"idle")
	_particles(t, Vector3(-0.3, 1.0, 0), Vector3(0.4, 0.9, 0.3), Color(1.0, 0.85, 0.5, 0.8), 60, 0.03,
			Vector3(0, 0.2, 0), 4.0)
	_rail(t, Vector3(0.0, 1.1, 3.6), Vector3(0.0, 0.9, 0.0), Vector3(0.0, 1.0, 2.7), Vector3(0.0, 0.9, 0.0), 38.0)


## The mother lets go: her paint thins into gold dust.
func mother_fades(seconds: float) -> void:
	tween_param(&"mother", &"alpha_cut", 0.0, 1.05, seconds, "mother")


## A fine house; later men carry its things away (#13).
func _build_house(t: Dictionary) -> void:
	_sky(t, Vector3(0, 4, -10), Vector2(44, 22), Color(0.07, 0.05, 0.12), Color(0.38, 0.26, 0.3))
	var house := _mat(t, Color(0.07, 0.05, 0.09), GOLD, 1.4, "house")
	house.set_shader_parameter(&"glow", 0.1)
	_box(t, Vector3(6, 3.2, 3), Vector3(0, 1.6, -3), house)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(6.6, 1.8, 3.2)
	roof.mesh = pr
	roof.material_override = house
	roof.position = Vector3(0, 4.1, -3)
	(t.root as Node3D).add_child(roof)
	for i in 5:
		_box(t, Vector3(0.6, 0.9, 0.05), Vector3(-2.4 + i * 1.2, 2.0, -1.46), _mat(t, Color(0.6, 0.45, 0.2), GOLD, 1.0, "house"))
	var men := Node3D.new()
	men.name = "Men"
	men.visible = false
	(t.root as Node3D).add_child(men)
	var man := _mat(t, Color(0.03, 0.03, 0.04), Color(0.9, 0.6, 0.4), 1.2, "house")
	for i in 3:
		var f := _figure(t, PEOPLE % "human_man", Vector3(-1.5 + i * 1.4, 0, 0.6), 90.0, 1.0, man, &"walk")
		if f:
			f.reparent(men)
			var crate := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.6, 0.45, 0.45)
			crate.mesh = b
			crate.material_override = man
			crate.position = Vector3(0, 1.2, 0.35)
			f.add_child(crate)
	_rail(t, Vector3(0.0, 2.0, 9.0), Vector3(0.0, 2.2, -2.0), Vector3(0.0, 1.8, 7.4), Vector3(0.0, 2.0, -2.0), 40.0)


## The men walk off with the house's things.
func men_take(seconds: float) -> void:
	var men := root_of(&"house").get_node("Men") as Node3D
	men.visible = true
	var tw := create_tween()
	tw.tween_property(men, ^"position:x", 7.0, seconds)


## Three ships on a dark sea, going down one by one (#13).
func _build_ships(t: Dictionary) -> void:
	_sky(t, Vector3(0, 4, -14), Vector2(60, 24), Color(0.03, 0.04, 0.1), Color(0.14, 0.2, 0.32))
	var sea := _mat(t, Color(0.03, 0.06, 0.12), Color(0.6, 0.75, 1.0), 0.7, "sea")
	var water := _box(t, Vector3(40, 0.2, 20), Vector3(0, -0.1, 0), sea)
	water.name = "Sea"
	var ship := _mat(t, Color(0.05, 0.04, 0.05), GOLD, 1.6, "ship")
	for i in 3:
		var s := Node3D.new()
		s.name = "Ship%d" % i
		s.position = Vector3(-4.0 + i * 4.0, 0.0, -2.0 - i * 0.8)
		(t.root as Node3D).add_child(s)
		var hull := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(2.4, 0.6, 0.7)
		hull.mesh = b
		hull.material_override = ship
		hull.position.y = 0.2
		s.add_child(hull)
		var mast := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.04
		cyl.height = 2.4
		mast.mesh = cyl
		mast.material_override = ship
		mast.position.y = 1.6
		s.add_child(mast)
		var sail := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.4, 1.5)
		sail.mesh = q
		sail.material_override = ship
		sail.position = Vector3(0.05, 1.7, 0)
		sail.rotation_degrees.y = 90.0
		s.add_child(sail)
	_particles(t, Vector3(0, 0.3, -2), Vector3(10, 0.2, 3), Color(0.7, 0.85, 1.0, 0.5), 120, 0.05,
			Vector3(0.3, 0.1, 0), 3.0)
	_rail(t, Vector3(0.0, 1.5, 8.0), Vector3(0.0, 0.8, -2.0), Vector3(0.0, 1.2, 6.4), Vector3(0.0, 0.6, -2.0), 42.0)


## The sea takes the ships one by one over `seconds`.
func sink_ships(seconds: float) -> void:
	var root := root_of(&"ships")
	for i in 3:
		var s := root.get_node("Ship%d" % i) as Node3D
		var tw := create_tween()
		tw.tween_interval(seconds * (0.1 + 0.28 * i))
		tw.tween_property(s, ^"rotation_degrees:z", 25.0 * (1 if i % 2 == 0 else -1), seconds * 0.15)
		tw.parallel().tween_property(s, ^"position:y", -3.2, seconds * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

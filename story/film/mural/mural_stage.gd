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
const LIT := preload("res://story/film/mural/mural_lit.gdshader")
const PEOPLE := "res://creatures/models/people/%s.gltf"
const FAE := "res://creatures/models/fae/%s.gltf"
const CAST := "res://characters/%s/%s_model.tscn"
const WOLF := "res://creatures/models/great_wolf.gltf"
## The mural's Blender props (tools/blender/film/mural_props.py).
const PROP := "res://art/film/mural/%s.glb"
const IDS: Array[StringName] = [&"land", &"court", &"slaves", &"war", &"treaty",
		&"mother", &"house", &"ships"]

const INK := Color(0.045, 0.035, 0.085)
const GOLD := Color(1.0, 0.82, 0.45)
const SILVER := Color(0.86, 0.9, 1.0)
const SICK := Color(0.78, 0.86, 0.35)
const ROSE := Color(1.0, 0.62, 0.72)
## Aerial haze (depth fog) from the lens, in metres, and how much at most.
const HAZE_BEGIN := 14.0
const HAZE_END := 40.0
const HAZE := 0.4

## The tableaux to build, set before the stage enters the tree; empty builds
## the opening film's IDS. A subclass adds its own `_build_<id>` (MuralDark).
var build_only: Array[StringName] = []
## How far a figure's own colours lean into its tableau's ink (0 = its own
## colours, 1 = a silhouette). A material's "ink_mix" meta overrides it.
var figure_ink: float = 0.18
var camera: Camera3D
var environment: Environment
var lens: CameraAttributesPractical
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
	# Glow only on the gold itself, kept tight: the Mac's Forward+ glow (far
	# stronger than the Compatibility renderer's) hazed whole tableaux pale.
	environment.glow_intensity = 0.45
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.05
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in 7:
		environment.set_glow_level(level, 1.0 if level in [1, 2, 3] else 0.0)
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	we.environment = environment
	add_child(we)
	# Depth: the far paint hazes into the backdrop's own colour, and the lens
	# holds the figures sharp with the cities and sky soft behind them, so a
	# tableau reads as a deep painted stage, not cut-outs in a row.
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = HAZE_BEGIN
	environment.fog_depth_end = HAZE_END
	environment.fog_depth_curve = 1.0
	environment.fog_sky_affect = 0.0
	camera = Camera3D.new()
	camera.name = "MuralCamera"
	camera.fov = 40.0
	camera.near = 0.05
	# The painter's light: a warm key from high front-left, a cool rim from
	# behind, and the backdrop's own colour as the fill (set per tableau).
	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.light_color = Color(1.0, 0.9, 0.76)
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	add_child(key)
	var back := DirectionalLight3D.new()
	back.name = "Rim"
	back.light_color = Color(0.72, 0.78, 1.0)
	back.light_energy = 0.7
	back.rotation_degrees = Vector3(-20.0, 160.0, 0.0)
	add_child(back)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.45, 0.6)
	environment.ambient_light_energy = 0.55
	lens = CameraAttributesPractical.new()
	lens.dof_blur_amount = 0.045
	lens.dof_blur_far_transition = 9.0
	camera.attributes = lens
	add_child(camera)
	camera.current = true
	var ids: Array[StringName] = IDS if build_only.is_empty() else build_only
	for i in ids.size():
		_build(ids[i], Vector3(SPACING * i, 0.0, 0.0))


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
	_look(tableaux[id] as Dictionary)
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


## The tableau's haze and focus: haze in its backdrop's low colour (none
## when it has no backdrop, like the map), focus `focus` metres out (0: all sharp).
func _look(t: Dictionary) -> void:
	var haze: Variant = t.get(&"haze")
	environment.fog_enabled = haze is Color
	if haze is Color:
		environment.fog_light_color = haze
		environment.fog_density = HAZE
		# Fill from the backdrop, lifted so the shadow side keeps its colour.
		environment.ambient_light_color = (haze as Color).lerp(Color(0.8, 0.78, 0.85), 0.45)
	var focus := float(t.get(&"focus", 0.0))
	lens.dof_blur_far_enabled = focus > 0.0
	lens.dof_blur_far_distance = maxf(focus, 0.1)


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


## Gold leaf (crowns, seals): a bright gilt paint that glows a little.
func _gilt(t: Dictionary, mat_name: String) -> ShaderMaterial:
	var m := _mat(t, Color(0.62, 0.44, 0.16), GOLD, 1.4, mat_name)
	m.set_shader_parameter(&"glow", 0.9)
	return m


func _sky(t: Dictionary, at: Vector3, size: Vector2, top: Color, low: Color) -> void:
	var m := ShaderMaterial.new()
	m.shader = SKY
	m.set_shader_parameter(&"top", top)
	m.set_shader_parameter(&"low", low)
	(t.mats as Array).append(m)
	# The first backdrop sets the tableau's haze and a focus just past its figures.
	if not t.has(&"haze"):
		t[&"haze"] = low.lerp(top, 0.35)
		t[&"focus"] = 17.0
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


## Paints a model in its own colours: every surface gets a mural_lit material
## with the model's albedo and the tableau paint `m`'s ink, gold, rim and
## stroke settings, and joins the tableau's materials (so reveal, drain,
## rust and crack reach it), under `m`'s name.
func _dress(t: Dictionary, node: Node, m: ShaderMaterial) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = null
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in (mi.mesh.get_surface_count() if mi.mesh else 0):
			var vcol: bool = (mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
			mi.set_surface_override_material(i, _lit(t, m, mi.get_active_material(i), vcol))
	elif node is GeometryInstance3D:
		_paint_all(node, m)
		return
	for c in node.get_children():
		_dress(t, c, m)


func _lit(t: Dictionary, m: ShaderMaterial, own: Material, vcol: bool = false) -> ShaderMaterial:
	var l := ShaderMaterial.new()
	l.shader = LIT
	l.resource_name = m.resource_name
	for param: StringName in [&"ink", &"gold", &"rim_gain", &"rim_power", &"glow", &"origin", &"span"]:
		var v: Variant = m.get_shader_parameter(param)
		if v != null:
			l.set_shader_parameter(param, v)
	l.set_shader_parameter(&"ink_mix", float(m.get_meta(&"ink_mix", figure_ink)))
	var rough: float = m.get_meta(&"roughness", -1.0)
	if own is CandyMaterial:
		var b := own as CandyMaterial
		l.set_shader_parameter(&"albedo_col", b.albedo_color)
		if b.albedo_texture:
			l.set_shader_parameter(&"albedo_tex", b.albedo_texture)
		# The Blender props (prop_kit) carry their colours per vertex on
		# "opaque" and "glow"; "glow" is a lit window, a lantern or a flame.
		var kit := b.resource_name in ["opaque", "glow", "clear"]
		l.set_shader_parameter(&"use_vcol", b.vertex_color_use_as_albedo or (kit and vcol))
		if b.resource_name == "glow":
			l.set_shader_parameter(&"glow", 1.4)
		l.set_shader_parameter(&"roughness", clampf(b.roughness, 0.45, 1.0))
		if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			l.set_shader_parameter(&"alpha_scissor", 0.5)
	elif own is ShaderMaterial:
		var sm := own as ShaderMaterial
		# A shader of its own (fur, skin): its main colour if it names one,
		# else a mid grey, never the shader default white.
		l.set_shader_parameter(&"albedo_col", Color(0.3, 0.28, 0.3))
		for c: StringName in [&"albedo", &"albedo_color", &"base_color", &"coat", &"color"]:
			var v: Variant = sm.get_shader_parameter(c)
			if v is Color:
				l.set_shader_parameter(&"albedo_col", v)
				break
		for c: StringName in [&"albedo_texture", &"texture_albedo", &"albedo_tex", &"base_texture"]:
			var v: Variant = sm.get_shader_parameter(c)
			if v is Texture2D:
				l.set_shader_parameter(&"albedo_tex", v)
				break
	if rough >= 0.0:
		l.set_shader_parameter(&"roughness", rough)
	(t.mats as Array).append(l)
	return l


## A model (gltf or scene) in silhouette at `at`, facing `yaw` degrees, with
## clip `clip` held at `clip_at` (0..1 of its length) or looping when < 0.
func _figure(t: Dictionary, path: String, at: Vector3, yaw: float, s: float, m: ShaderMaterial,
		clip: StringName = &"idle", clip_at: float = -1.0) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = at
	# yaw 0 faces the lens (+z). Every model here faces -z as built (the
	# cast after its own half turn, the people and creature glTFs natively).
	n.rotation_degrees.y = yaw + 180.0
	n.scale = Vector3.ONE * s
	(t.root as Node3D).add_child(n)
	_dress(t, n, m)
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


## A Blender prop from art/film/mural (PROP), placed like a figure.
func _prop(t: Dictionary, id: String, at: Vector3, yaw: float, s: float, m: ShaderMaterial) -> Node3D:
	return _figure(t, PROP % id, at, yaw, s, m, &"")


## A prop held in a figure's right hand (a sword, a bow), or nothing when the
## figure has no hand bone. `rot` turns it in the bone's own frame.
func _hold(t: Dictionary, fig: Node3D, id: String, m: ShaderMaterial, rot: Vector3, off := Vector3.ZERO) -> void:
	if fig == null:
		return
	for s in fig.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var bi := sk.find_bone("hand_r")
		if bi < 0:
			bi = sk.find_bone("RightHand")
		if bi < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(bi)
		sk.add_child(att)
		var n := (load(PROP % id) as PackedScene).instantiate() as Node3D
		n.position = off
		n.rotation_degrees = rot
		att.add_child(n)
		_dress(t, n, m)
		return


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
## the model has no head bone. `gilt` is a paint material of the tableau, so
## the crown is brushed on with the figure that wears it.
func _crown(fig: Node3D, gilt: ShaderMaterial, h: float, spikes: int = 9, r: float = 0.13) -> void:
	if fig == null:
		return
	var leaf_mat := gilt
	var holder: Node3D = fig
	var top := _top_of(fig)
	var base := h
	var scale_k := fig.global_transform.basis.get_scale().y
	for s in fig.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var bi := sk.find_bone("head")
		if bi < 0:
			bi = sk.find_bone("Head")
		if bi < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(bi)
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
	var sm := MaterialLibrary.surface()
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
	# Their palaces behind them, spires lit, falling back into the haze.
	var city := _mat(t, Color(0.08, 0.05, 0.13), Color(1.0, 0.86, 0.6), 1.2, "fae")
	city.set_meta(&"ink_mix", 0.3)
	for c: Array in [["fae_palace_c", -12.5, -13.0, 18.0, 1.2], ["fae_palace_b", -5.5, -10.5, 6.0, 1.0],
			["fae_palace_a", 2.5, -12.0, -8.0, 1.25], ["fae_palace_b", 9.0, -10.0, -20.0, 1.1],
			["fae_palace_c", 16.0, -14.0, -28.0, 1.0]]:
		_prop(t, String(c[0]), Vector3(float(c[1]), 0.0, float(c[2])), float(c[3]), float(c[4]), city)
	# The marble terrace they stand on, blind arches under it toward the beasts.
	var marble := _mat(t, Color(0.03, 0.025, 0.06), GOLD, 0.8, "fae")
	marble.set_meta(&"ink_mix", 0.32)
	_prop(t, "court_terrace", Vector3(0.0, -0.8, -1.5), 0.0, 1.0, marble)
	var gilt := _gilt(t, "fae")
	# Not a row: one lord forward, the court staggered back along the terrace.
	# The rulers before the Wall (the ch 13 mural's "ornate" beings), unmasked.
	# [model, x, z, yaw, scale]
	var who := [[PEOPLE % "old_court_lord", -0.6, -0.8, 8.0, 1.12],
		[PEOPLE % "old_court_lady", 2.7, -1.9, -24.0, 1.18],
		[PEOPLE % "calanmai_1", -3.9, -2.5, 30.0, 1.1], [PEOPLE % "old_court_lady_2", 5.4, -2.9, -34.0, 1.16],
		[PEOPLE % "calanmai_3", -6.9, -1.5, 42.0, 1.12]]
	for w: Array in who:
		var f := _figure(t, String(w[0]), Vector3(float(w[1]), 0.4, float(w[2])), float(w[3]), float(w[4]), fae)
		_crown(f, gilt, 2.15)
	_particles(t, Vector3(0, 4, -2), Vector3(12, 3, 3), ROSE, 160, 0.09, Vector3(0.15, -0.25, 0), 10.0, false)
	_particles(t, Vector3(0, 6, -9), Vector3(14, 5, 1), Color(1.0, 0.9, 0.6, 0.8), 260, 0.04, Vector3.ZERO, 6.0)
	# The beasts below, in the ink under the ridge.
	var beast := _mat(t, Color(0.012, 0.012, 0.016), SICK * 0.7, 0.95, "beast")
	beast.set_meta(&"ink_mix", 0.62)
	beast.set_shader_parameter(&"rim_power", 4.0)
	# The ink under the ridge: no sky down here, only the dark they live in.
	# A sick glow low in it, so their shapes show against it and stay half-seen.
	_sky(t, Vector3(0.0, -4.6, -0.6), Vector2(70.0, 8.2), Color(0.01, 0.008, 0.02), Color(0.085, 0.07, 0.03))
	(t.mats.back() as ShaderMaterial).set_shader_parameter(&"stars", 0.0)
	_figure(t, FAE % "bogge", Vector3(-3.2, -4.6, 2.2), 30.0, 1.6, beast, &"idle")
	_figure(t, WOLF, Vector3(0.6, -4.8, 2.8), -25.0, 1.2, beast, &"stalk")
	_figure(t, PEOPLE % "fae_longlimb_true", Vector3(3.8, -4.7, 1.6), -40.0, 1.3, beast)
	_figure(t, FAE % "naga", Vector3(-6.4, -4.8, 1.0), 50.0, 1.3, beast, &"")
	_figure(t, FAE % "attor", Vector3(6.6, -4.4, 0.6), -60.0, 1.2, beast, &"")
	var under := _mat(t, Color(0.012, 0.01, 0.016), SICK, 0.04, "beast")
	under.set_meta(&"ink_mix", 0.8)
	var floor_ := _prop(t, "ground_mud", Vector3(0, -4.8, 2.5), 0.0, 1.0, under)
	floor_.scale = Vector3(0.7, 1.0, 0.35)
	# One yellow eye in the dark, opened by the director (eye.scale.y 0 → 1).
	var eye := MeshInstance3D.new()
	eye.name = "Eye"
	var sph := SphereMesh.new()
	sph.radius = 0.085
	sph.height = 0.17
	eye.mesh = sph
	var em := MaterialLibrary.surface()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.8, 0.15)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.75, 0.1)
	em.emission_energy_multiplier = 6.0
	eye.material_override = em
	eye.position = Vector3(2.4, -2.9, 0.3)
	eye.scale = Vector3(2.4, 0.0, 1.0)
	(t.root as Node3D).add_child(eye)
	var slit := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.012, 0.11, 0.02)
	slit.mesh = sb
	var sm := MaterialLibrary.surface()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color.BLACK
	slit.material_override = sm
	slit.position = Vector3(0.0, 0.0, 0.055)
	eye.add_child(slit)
	# Close enough to see faces and crowns: a slow push in on the lord.
	_rail(t, Vector3(-0.6, 2.2, 8.8), Vector3(0.2, 2.3, -2.0), Vector3(-0.2, 2.0, 6.4), Vector3(-0.4, 2.2, -1.5), 42.0)
	t[&"focus"] = 11.5
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
	_figure(t, PEOPLE % "old_court_lord", Vector3(-4.6, 0.0, -5.0), 25.0, 1.9, fae)
	_figure(t, PEOPLE % "calanmai_2", Vector3(5.0, 0.0, -5.4), -25.0, 1.85, fae)
	# A temple to their feral gods rising, stone by stone (ch 3).
	var stone := _mat(t, Color(0.1, 0.07, 0.08), GOLD, 0.9, "human")
	_prop(t, "ground_dust", Vector3(0, -0.04, -5.0), 0.0, 1.0, _mat(t, Color(0.05, 0.03, 0.04), GOLD, 0.6, "human"))
	_prop(t, "feral_temple", Vector3(0.0, 0.0, -10.0), 0.0, 1.0, stone)
	var kinds := ["mortal_man", "mortal_woman", "mortal_youth", "mortal_elder"]
	var feet: Array[Vector3] = []
	for i in 9:
		var x := -5.2 + i * 1.3
		var p := Vector3(x, 0.0, -0.4 + _rng.randf_range(-0.4, 0.4))
		_figure(t, PEOPLE % kinds[i % 4], p, _rng.randf_range(-30, 30), 0.85, human, &"bow", 0.5)
		if i % 3 == 1:
			_prop(t, "stone_block", p + Vector3(0, 0.85, 0.25), _rng.randf_range(-20, 20), 1.0, stone)
		feet.append(p + Vector3(0, 0.12, 0.1))
	var chain := _mat(t, Color(0.2, 0.18, 0.2), Color(1.0, 0.9, 0.75), 1.8, "chain")
	for i in feet.size() - 1:
		var a := feet[i]
		var b := feet[i + 1]
		# A metre of chain along its own +x, stretched from ankle to ankle.
		var d := b - a
		var c := _prop(t, "chain_span", a.lerp(b, 0.5), rad_to_deg(atan2(-d.z, d.x)) - 180.0, 1.0, chain)
		if c:
			c.scale = Vector3(Vector2(d.x, d.z).length(), 1.0, 1.0)
	_rail(t, Vector3(-2.0, 1.2, 8.5), Vector3(0.0, 2.2, -2.0), Vector3(1.5, 1.6, 7.0), Vector3(0.0, 2.6, -3.0), 42.0)


## They rise: spears, banners and a wave of painted fire against the fae's light (#6).
func _build_war(t: Dictionary) -> void:
	_sky(t, Vector3(0, 6, -16), Vector2(64, 30), Color(0.08, 0.02, 0.03), Color(0.6, 0.18, 0.06))
	var human := _mat(t, Color(0.06, 0.04, 0.05), Color(1.0, 0.55, 0.28), 1.8, "human")
	var fae := _mat(t, Color(0.14, 0.12, 0.18), Color(1.0, 0.95, 0.85), 2.4, "fae")
	# Against the fire they stay half in shadow: colour, but dark and backlit.
	human.set_meta(&"ink_mix", 0.45)
	fae.set_meta(&"ink_mix", 0.3)
	# Their armour glimmers (ch 13) in the rim; a glow over the whole body
	# washed the armour out to white.
	fae.set_shader_parameter(&"glow", 0.12)
	# "Bloodied mud" (ch 13).
	_prop(t, "ground_mud", Vector3(0, -0.04, -4.0), 0.0, 1.0, _mat(t, Color(0.05, 0.025, 0.02), Color(1.0, 0.5, 0.25), 0.6, "human"))
	# Humans shoulder to shoulder with swords and bows (ch 13), and one faerie
	# fighting at their side (ch 18).
	var kinds := ["mortal_man", "mortal_youth", "mortal_woman", "mortal_man", "mortal_elder"]
	for i in 11:
		var p := Vector3(-7.0 + i * 0.9, 0.0, 1.0 + _rng.randf_range(-0.8, 0.8))
		var who := PEOPLE % ("fae_satyr" if i == 8 else kinds[i % 5])
		var f := _figure(t, who, p, 160.0 + _rng.randf_range(-15, 15), 0.95, human, &"walk", _rng.randf())
		if i % 3 == 2:
			_hold(t, f, "longbow", human, Vector3(0, 0, 90))
		else:
			_hold(t, f, "sword", human, Vector3(90, 0, 0), Vector3(0, 0.06, 0))
	for i in 3:
		var banner := _prop(t, "war_banner", Vector3(-5.0 + i * 4.0, 0.0, 1.9), 170.0 + i * 8.0, 1.0, human)
		banner.name = "Banner%d" % i
	# High Fae in their glimmering armour, and faeries bristling with claws
	# and fangs (ch 13).
	for i in 4:
		_figure(t, PEOPLE % ["war_fae_1", "war_fae_2", "war_fae_1", "war_fae_2"][i],
				Vector3(-3.0 + i * 2.2, 0.0, -6.0), 15.0 - i * 10.0, 1.3, fae)
	var claws := _mat(t, Color(0.05, 0.04, 0.06), Color(1.0, 0.9, 0.7), 1.4, "fae")
	claws.set_meta(&"ink_mix", 0.5)
	_figure(t, FAE % "naga", Vector3(-6.2, 0.0, -5.2), 30.0, 1.4, claws, &"")
	_figure(t, FAE % "attor", Vector3(6.4, 0.6, -5.4), -30.0, 1.3, claws, &"")
	_figure(t, FAE % "bogge", Vector3(3.6, 0.0, -4.6), -10.0, 1.2, claws, &"idle")
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
	var crowns := _gilt(t, "queen")
	var table := _mat(t, Color(0.08, 0.06, 0.09), GOLD, 0.8, "queen")
	_prop(t, "treaty_table", Vector3.ZERO, 0.0, 1.0, table)
	var sheet := _prop(t, "treaty_parchment", Vector3(0, 0.905, 0), 0.0, 1.0,
			_mat(t, Color(0.85, 0.82, 0.74), SILVER, 0.5, "queen"))
	sheet.name = "Sheet"
	# Six mortal queens (ch 3), three of a kind each side, in silver.
	for i in 6:
		var a := PI * (0.15 + 0.7 * float(i) / 5.0)
		var p := Vector3(cos(a) * -2.4, 0.0, -sin(a) * 1.6 - 0.2)
		var q := _figure(t, PEOPLE % ("mortal_queen_%d" % [1, 2, 3, 3, 1, 2][i]), p,
				rad_to_deg(atan2(-p.x, -p.z)), 1.0, queen, &"talk", 0.3)
		_crown(q, crowns, 1.7, 7, 0.1)
	var gold := _mat(t, Color(0.6, 0.42, 0.12), GOLD, 2.0, "seal")
	gold.set_shader_parameter(&"glow", 0.3)
	var seal := _prop(t, "treaty_seal", Vector3(0.0, 2.2, 0.0), 0.0, 1.4, gold)
	seal.name = "Seal"
	var wax := _prop(t, "treaty_wax", Vector3(0.0, 0.91, 0.0), 0.0, 1.0,
			_mat(t, Color(0.7, 0.05, 0.1), Color(1.0, 0.5, 0.5), 1.0, "seal"))
	wax.name = "Wax"
	wax.scale = Vector3.ZERO
	_rail(t, Vector3(0.0, 2.4, 6.8), Vector3(0.0, 1.3, -0.4), Vector3(0.0, 1.9, 4.6), Vector3(0.0, 1.1, -0.2), 40.0)


## The seal presses into the wax (#7).
func press_seal(seconds: float) -> void:
	var root := root_of(&"treaty")
	var seal := root.get_node("Seal") as Node3D
	var wax := root.get_node("Wax") as Node3D
	var tw := create_tween()
	tw.tween_property(seal, ^"position:y", 0.93, seconds * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: wax.scale = Vector3.ONE)
	tw.tween_property(seal, ^"position:y", 1.9, seconds * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## A woman and a small girl, hand in hand; the woman dissolves (#12).
func _build_mother(t: Dictionary) -> void:
	_sky(t, Vector3(0, 3, -8), Vector2(40, 20), Color(0.1, 0.06, 0.12), Color(0.5, 0.3, 0.3))
	var mother := _mat(t, Color(0.08, 0.05, 0.08), GOLD, 2.0, "mother")
	var girl := _mat(t, Color(0.08, 0.05, 0.08), Color(1.0, 0.9, 0.7), 2.0, "girl")
	# Nesta's cold face and blue-grey eyes, dressed for the peerage (ch 2, 4, 30).
	_figure(t, PEOPLE % "archeron_mother", Vector3(-0.32, 0, 0), 20.0, 1.0, mother, &"idle")
	_figure(t, PEOPLE % "young_feyre", Vector3(0.3, 0, 0.1), -20.0, 0.82, girl, &"idle")
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
	# "Our manor home" (ch 2): a merchant's country manor lit for a party.
	_prop(t, "archeron_manor", Vector3(0, 0, -5.0), 0.0, 0.85, house)
	var men := Node3D.new()
	men.name = "Men"
	men.visible = false
	(t.root as Node3D).add_child(men)
	var man := _mat(t, Color(0.03, 0.03, 0.04), Color(0.9, 0.6, 0.4), 1.2, "house")
	# The creditors ransack it (ch 2): a chest, a gilt frame, a chair.
	for i in 3:
		var f := _figure(t, PEOPLE % ["mortal_man", "mortal_elder", "mortal_youth"][i], Vector3(-1.5 + i * 1.4, 0, 0.6),
				90.0, 1.0, man, &"walk")
		if f:
			f.reparent(men)
			var thing := (load(PROP % ["carried_chest", "carried_frame", "carried_chair"][i]) as PackedScene).instantiate() as Node3D
			thing.position = Vector3(0, 1.05, 0.3)
			f.add_child(thing)
			_dress(t, thing, man)
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
	sea.set_meta(&"ink_mix", 0.55)
	sea.set_meta(&"roughness", 1.0)
	sea.set_shader_parameter(&"rim_gain", 0.25)
	# Lost at sea in a storm, kept ambiguous (ch 19; ch 28 has them found).
	var water := _prop(t, "storm_sea", Vector3.ZERO, 0.0, 1.0, sea)
	water.name = "Sea"
	var ship := _mat(t, Color(0.05, 0.04, 0.05), GOLD, 1.6, "ship")
	for i in 3:
		_ship(t, Vector3(-4.0 + i * 4.0, 0.0, -2.0 - i * 0.8), ship).name = "Ship%d" % i
	_particles(t, Vector3(0, 0.3, -2), Vector3(10, 0.2, 3), Color(0.7, 0.85, 1.0, 0.5), 120, 0.05,
			Vector3(0.3, 0.1, 0), 3.0)
	_rail(t, Vector3(0.0, 1.5, 8.0), Vector3(0.0, 0.8, -2.0), Vector3(0.0, 1.2, 6.4), Vector3(0.0, 0.6, -2.0), 42.0)


## A merchant ship for Bharat (ch 19), broadside to the lens.
func _ship(t: Dictionary, at: Vector3, ship: ShaderMaterial) -> Node3D:
	var s := Node3D.new()
	s.position = at
	(t.root as Node3D).add_child(s)
	var hull := (load(PROP % "merchant_ship") as PackedScene).instantiate() as Node3D
	hull.scale = Vector3.ONE * 0.9
	hull.rotation_degrees.y = 180.0 + _rng.randf_range(-12.0, 12.0)
	s.add_child(hull)
	_dress(t, hull, ship)
	return s


## The sea takes the ships one by one over `seconds`.
func sink_ships(seconds: float) -> void:
	var root := root_of(&"ships")
	for i in 3:
		var s := root.get_node("Ship%d" % i) as Node3D
		var tw := create_tween()
		tw.tween_interval(seconds * (0.1 + 0.28 * i))
		tw.tween_property(s, ^"rotation_degrees:z", 25.0 * (1 if i % 2 == 0 else -1), seconds * 0.15)
		tw.parallel().tween_property(s, ^"position:y", -3.2, seconds * 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

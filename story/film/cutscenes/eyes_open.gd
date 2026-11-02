## Cutscene A "Eyes Open" (lane L33; scripts.md section 2, ch 23): noon in
## the glen under the weeping willow. Tamlin offers to open her human senses,
## the price is a kiss on each eyelid, and the glamour lifts: the sound opens
## first, then the world blooms richer, with gold on every leaf edge and a
## rainbow on the brook. She glimpses his true form and pulls at his mask,
## and he hides himself again. She keeps the world.
##
## Played by the glamour_lift moment (anchor glamour_lift_glade, Blossom
## Vale), which raises glamour_lifted on fact.film_eyes_open_lift, under the
## black while her eyes are closed. Points are in the anchor's frame.
extends CutsceneDirector

const WILLOW := "res://world/spring_court/wider/assets/flora/flora_tree_weeping_willow.gltf"
const BROOK_SHADER := preload("res://story/film/cutscenes/brook.gdshader")
const NOON := 0.5

## Where they lounge (both facing the brook, +z), then kneel facing each other.
const TAMLIN_SIT := Vector3(-0.85, 0.0, -0.1)
const FEYRE_SIT := Vector3(0.55, 0.0, 0.05)
const TAMLIN_KNEEL := Vector3(-0.38, 0.0, 0.25)
const FEYRE_KNEEL := Vector3(0.2, 0.0, 0.25)
const WILLOW_AT := Vector3(-4.8, 0.0, -6.2)
const BROOK_FROM := Vector3(-11.0, 0.0, 4.6)
const BROOK_TO := Vector3(11.0, 0.0, 2.6)

var tamlin: Node3D
var brook_mat: ShaderMaterial
var circlet: Node3D
var glow_light: OmniLight3D
var motes: GPUParticles3D


func _setup() -> void:
	Clock.from_dict({"time_of_day": NOON, "day": Clock.day})
	_build_set()
	tamlin = bring(&"tamlin", TAMLIN_SIT, TAMLIN_SIT + Vector3(0.0, 0.0, 3.0))
	_quiet(tamlin)
	put_feyre(FEYRE_SIT, FEYRE_SIT + Vector3(0.0, 0.0, 3.0))
	pose(tamlin, &"sit_ground", 0.0)
	pose(feyre_model(), &"sit_ground", 0.0)
	grade.to_param(&"veil", 1.0, 0.0)
	player.veil_to(1.0, 0.0)


func _end_mark() -> Transform3D:
	var p := ground(FEYRE_KNEEL)
	return Transform3D(Basis.looking_at((at(TAMLIN_KNEEL) - at(FEYRE_KNEEL)) * Vector3(1, 0, 1), Vector3.UP), p)


func _teardown() -> void:
	if tamlin and is_instance_valid(tamlin):
		put(tamlin, TAMLIN_KNEEL, FEYRE_KNEEL)


## Tamlin looks where the scene says, not at the player.
func _quiet(who: Node3D) -> void:
	var n: Variant = who.get(&"notice") if who else null
	if n is Object and &"enabled" in (n as Object):
		(n as Object).set(&"enabled", false)


## The willow and the brook stay after the film: play resumes in the same glen.
func _build_set() -> void:
	var willow := load_prop(WILLOW, ground(WILLOW_AT), 35.0, 1.0, true)
	if willow:
		willow.name = "FilmWillow"
	brook_mat = ShaderMaterial.new()
	brook_mat.shader = BROOK_SHADER
	var brook := MeshInstance3D.new()
	brook.name = "FilmBrook"
	brook.mesh = _brook_mesh()
	brook.material_override = brook_mat
	brook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_set(brook, Vector3.ZERO)
	# Gold motes in the noon air, waiting for the world to bloom.
	motes = GPUParticles3D.new()
	motes.amount = 160
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emitting = false
	motes.visibility_aabb = AABB(Vector3(-12, -3, -12), Vector3(24, 10, 24))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 2.0, 7)
	pm.gravity = Vector3(0.05, 0.03, 0.0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.12
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_color = Color(1.0, 0.85, 0.5, 0.8)
	sm.albedo_texture = MuralStage._soft_dot()
	q.material = sm
	motes.draw_pass_1 = q
	add_prop(motes, ground(Vector3(0.0, 0.0, 0.5), 1.6))


## A ribbon of water a step in front of them, laid on the ground point by point.
func _brook_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 44
	var width := 0.95
	var dist := 0.0
	var prev := Vector3.ZERO
	var rows: Array = []
	for i in n + 1:
		var k := float(i) / float(n)
		var c := BROOK_FROM.lerp(BROOK_TO, k) + Vector3(0.0, 0.0, sin(k * TAU * 1.3) * 0.7)
		var tangent := (BROOK_TO - BROOK_FROM).normalized()
		var side := tangent.cross(Vector3.UP).normalized() * width * 0.5
		var w := ground(c)
		if i > 0:
			dist += w.distance_to(prev)
		prev = w
		rows.append([ground(c - side, 0.04), ground(c + side, 0.04), dist])
	for i in n:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		for v: Array in [[a[0], a[2], 0.0], [b[0], b[2], 0.0], [b[1], b[2], 1.0],
				[a[0], a[2], 0.0], [b[1], b[2], 1.0], [a[1], a[2], 1.0]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(float(v[1]), float(v[2])))
			st.add_vertex(v[0])
	return st.commit()


# --- beats -----------------------------------------------------------------------

## #1 Noon in the glen; they lounge in the grass; he opens an eye at the willow.
func _b_open() -> void:
	player.veil_to(0.0, 1.6)
	shot(Vector3(2.8, 1.15, 6.2), Vector3(-1.2, 0.9, -1.8), 40.0, 0.7, 9.0)


## #2 He props himself up and studies her.
func _b_study() -> void:
	close(tamlin, 1.5, -0.35, 34.0, 0.15, 10.0, -0.05)


## #3 She is wary.
func _b_wary() -> void:
	close(feyre, 1.35, 0.35, 34.0, 0.12, 3.0, -0.05)


func _b_price() -> void:
	over(feyre, tamlin, 36.0, -0.4, 0.15, 5.5)


func _b_fine() -> void:
	close(feyre, 1.2, 0.3, 32.0, 0.1, 2.5, -0.05)


## #4 They kneel facing each other in the grass, knees touching.
func _b_kneel() -> void:
	put(tamlin, TAMLIN_KNEEL, FEYRE_KNEEL)
	put_feyre(FEYRE_KNEEL, TAMLIN_KNEEL)
	pose(tamlin, &"kneel", 0.0)
	pose(feyre_model(), &"kneel", 0.0)
	var mid := (TAMLIN_KNEEL + FEYRE_KNEEL) * 0.5
	shot(mid + Vector3(0.15, 0.95, 2.6), mid + Vector3(0.0, 0.95, 0.0), 32.0, 0.35, 5.0)


## Close on her face (over his shoulder): "Close your eyes."
func _b_close_eyes() -> void:
	over(tamlin, feyre, 30.0, 0.32, 0.12, 3.5)


## #5 He kisses one eyelid, then the other.
func _b_kiss() -> void:
	var h := head_of(feyre)
	var side := (at(FEYRE_KNEEL) - at(TAMLIN_KNEEL)).normalized().cross(Vector3.UP)
	shot_world(h + side * 0.95 + Vector3.UP * 0.02, h + (at(TAMLIN_KNEEL) - at(FEYRE_KNEEL)) * 0.25, 30.0, 0.1, 5.0)
	var tw := create_tween()
	tw.tween_callback(func() -> void: pose(tamlin, &"kneel_lean", 0.9))
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void: pose(tamlin, &"kneel", 0.5))
	tw.tween_interval(0.7)
	tw.tween_callback(func() -> void: pose(tamlin, &"kneel_lean", 0.7))
	tw.tween_interval(1.4)
	tw.tween_callback(func() -> void: pose(tamlin, &"kneel", 0.6))


## #6 Black: her eyes are closed. The sound changes first.
func _b_dark() -> void:
	player.veil_to(1.0, 0.6)


## Under the black the moment raises glamour_lifted: the world swaps unseen.
func _b_film_eyes_open_lift() -> void:
	grade.to_param(&"veil", 0.0, 0.0)


## #7 She opens her eyes: the world blooms out from where they kneel.
func _b_open_eyes() -> void:
	var f := at(FEYRE_KNEEL)
	var away := (f - at(TAMLIN_KNEEL)).normalized()
	var across := away.cross(Vector3.UP)
	# Low behind her shoulder, out over the glen to the willow and the brook.
	shot_world(head_of(feyre) - across * 0.5 + away * 0.35 + Vector3.UP * 0.05,
			at(WILLOW_AT * 0.55 + Vector3(0.0, 1.2, 4.5)), 44.0, -0.8, 7.0)
	player.veil_to(0.0, 2.2)
	grade.to_param(&"bloom", 1.0, 3.5)
	grade.to_param(&"edge_gold", 0.55, 4.5)
	motes.emitting = true
	create_tween().tween_method(func(v: float) -> void: brook_mat.set_shader_parameter(&"rainbow", v),
			0.0, 1.0, 4.0)


func _b_whisper() -> void:
	close(feyre, 1.1, 0.3, 30.0, 0.1, 3.4, -0.04)


## #8 Tamlin as he truly is: golden skin, a circlet of sunshine on his brow.
func _b_true_form() -> void:
	circlet = _circlet()
	glow_light = OmniLight3D.new()
	glow_light.light_color = Color(1.0, 0.82, 0.45)
	glow_light.light_energy = 0.0
	glow_light.omni_range = 2.2
	add_prop(glow_light, head_of(tamlin) + (at(FEYRE_KNEEL) - at(TAMLIN_KNEEL)).normalized() * 0.6)
	create_tween().tween_property(glow_light, ^"light_energy", 2.4, 1.5)
	grade.to_param(&"edge_gold", 0.8, 1.5)
	over(feyre, tamlin, 28.0, -0.3, 0.2, 4.5)


## A ring of light on his brow, on the head bone.
func _circlet() -> Node3D:
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.105
	tor.outer_radius = 0.118
	ring.mesh = tor
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.86, 0.5, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.4)
	m.emission_energy_multiplier = 3.0
	ring.material_override = m
	for s in tamlin.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var i := sk.find_bone("Head")
		if i < 0:
			continue
		var att := BoneAttachment3D.new()
		att.bone_name = "Head"
		sk.add_child(att)
		props.append(att)
		att.add_child(ring)
		# Level on the brow, in the skeleton's frame (head bone axes vary).
		var rest := sk.get_bone_global_rest(i)
		ring.transform = rest.affine_inverse() * Transform3D(Basis(), rest.origin + Vector3(0.0, 0.1, 0.02))
		create_tween().tween_property(m, ^"albedo_color:a", 1.0, 1.2)
		return ring
	ring.queue_free()
	return null


## #9 Without thinking she reaches up and pulls at his mask. It will not move.
func _b_reach() -> void:
	pose(feyre_model(), &"kneel_reach", 0.7)
	var mid := (at(TAMLIN_KNEEL) + at(FEYRE_KNEEL)) * 0.5
	var across := (at(FEYRE_KNEEL) - at(TAMLIN_KNEEL)).normalized().cross(Vector3.UP)
	shot_world(mid + across * 1.7 + Vector3.UP * 1.0, mid + Vector3.UP * 0.95, 30.0, 0.15, 3.0)


## #10 He smiles, and his true form is gone, glamoured back into place.
func _b_hide() -> void:
	pose(feyre_model(), &"kneel", 0.8)
	if circlet and is_instance_valid(circlet):
		var m := (circlet as MeshInstance3D).material_override as StandardMaterial3D
		create_tween().tween_property(m, ^"albedo_color:a", 0.0, 0.8)
		create_tween().tween_property(circlet, ^"scale", Vector3.ONE * 0.01, 0.9)
	if glow_light:
		create_tween().tween_property(glow_light, ^"light_energy", 0.0, 0.9)
	grade.to_param(&"edge_gold", 0.55, 1.0)
	close(tamlin, 1.2, -0.3, 30.0, 0.1, 1.0, -0.04)


func _b_why() -> void:
	close(feyre, 1.15, 0.3, 30.0, 0.08, 2.5, -0.04)


func _b_normal() -> void:
	over(feyre, tamlin, 30.0, -0.35, 0.1, 3.0)


## #11 Hold on the glen: the rainbow on the brook, every leaf edge gold.
## He hides himself; she keeps the world. They get up; ease into her camera.
func _b_hold() -> void:
	shot(Vector3(3.6, 1.8, 7.4), Vector3(-1.4, 1.4, -2.4), 46.0, -1.6, 8.0)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func() -> void:
		pose(tamlin, &"", 1.4)
		pose(feyre_model(), &"", 1.4))


func _b_handover() -> void:
	grade.to_param(&"bloom", 0.0, 3.0)
	grade.to_param(&"edge_gold", 0.0, 3.0)

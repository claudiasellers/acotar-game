## Probe for the colour grade (render program T3b, L63). Renders one small
## sunlit set under every GradePreset through GradeDirector.apply, the way the
## World shows it, and measures per preset:
##   lit   five sunlit samples (blush top, blush side, mint top, white top at the
##         0.85 albedo cap, ground): the lit band
##   sky   top and horizon sky pixels, and the frame's brightest channel (clip check)
## Modes (GRADE_PROBE env var):
##   ref    write the lit band of every preset to REFERENCE (run on the state to hold)
##   check  compare against REFERENCE; print per-preset delta, clip and boundary rows
##   solve  like check, then search each preset's exposure until its lit band is
##          within 1% of REFERENCE; prints "SOLVE <id> <exposure>" and its sky
## The sky samples look toward the sun (it stands behind the blocks, 35° up):
## the worst case for the clip check.
## Needs a renderer (xvfb + lavapipe in the cloud, the GPU on a Mac):
##   xvfb-run -a <godot> --rendering-driver vulkan --path . res://tools/env/grade_probe.tscn
## Optional GRADE_PROBE_ONLY=<id,id> limits the presets.
extends Node3D

const REFERENCE := "res://tools/env/grade_reference_t3a.json"
const SIZE := Vector2i(480, 270)
const SKY_SHADER := "res://world/shared/grades/painted_sky.gdshader"
const GROUND := Color(0.523, 0.548, 0.545)
const BLUSH := Color(0.92, 0.72, 0.76)
const MINT := Color(0.62, 0.85, 0.74)
const WHITE := Color(0.85, 0.85, 0.85)
const LIT := {
	&"blush_top": Vector3(-6.0, 1.01, 0.5),
	&"blush_side": Vector3(-6.0, 0.5, 1.52),
	&"mint_top": Vector3(-1.5, 1.01, 0.5),
	&"white_top": Vector3(3.0, 1.01, 0.5),
	&"ground": Vector3(7.5, 0.0, 4.0),
}
## The estate boundary: the same prop under the manor grade and the open world's.
const BOUNDARY := [[&"manor", &"spring"]]

var _view: SubViewport
var _env: Environment
var _sun: DirectionalLight3D
var _cam: Camera3D
var _director: GradeDirector


func _ready() -> void:
	_build()
	for i in 6:
		await RenderingServer.frame_post_draw
	var mode := OS.get_environment("GRADE_PROBE")
	if mode.is_empty():
		mode = "check"
	var ref := {}
	if mode != "ref":
		ref = JSON.parse_string(FileAccess.get_file_as_string(REFERENCE))
	var only := OS.get_environment("GRADE_PROBE_ONLY").split(",", false)
	var lit_now := {}
	var out := {}
	for id in _preset_ids():
		if not only.is_empty() and not only.has(id):
			continue
		var p := GradeDirector.load_preset(StringName(id))
		var m := await _measure(p, p.exposure)
		lit_now[id] = m.lit
		out[id] = m.lit
		if mode == "ref":
			continue
		var target: float = ref[id]
		var delta: float = m.lit / target - 1.0
		print("CHECK %-28s lit %+6.2f%%  sky_top %.3f  sky_hor %.3f  max %.3f  white px %.2f%%  exp %.3f" % [
			id, delta * 100.0, m.sky_top, m.sky_horizon, m.max, m.clipped * 100.0, p.exposure])
		if mode == "solve" and absf(delta) > 0.01:
			var e := await _solve(p, target)
			var sky := await _measure(p, e)
			print("SOLVE %s %.4f  sky %.3f / %.3f" % [id, e, sky.sky_top, sky.sky_horizon])
	if mode == "ref":
		var f := FileAccess.open(REFERENCE, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "\t", true))
		print("REF wrote %d presets to %s" % [out.size(), REFERENCE])
	for pair in BOUNDARY:
		if lit_now.has(String(pair[0])) and lit_now.has(String(pair[1])):
			var a: float = lit_now[String(pair[0])]
			var b: float = lit_now[String(pair[1])]
			print("BOUNDARY %s -> %s  prop luma delta %.2f%%" % [pair[0], pair[1], absf(a / b - 1.0) * 100.0])
	get_tree().quit()


## Exposure that brings the lit band to `target`: bracket by stops, then
## bisect in log space (the lit band is monotonic in exposure, but AgX's toe
## is too steep for secant steps on the darkest grades).
func _solve(p: GradePreset, target: float) -> float:
	var lo := p.exposure
	var hi := p.exposure
	var lit: float = (await _measure(p, lo)).lit
	if absf(lit / target - 1.0) < 0.01:
		return lo
	var step := 0.5 if lit > target else 2.0
	for i in 8:
		var e := (lo if step < 1.0 else hi) * step
		var l: float = (await _measure(p, e)).lit
		if step < 1.0:
			hi = lo
			lo = e
			if l <= target:
				break
		else:
			lo = hi
			hi = e
			if l >= target:
				break
	for i in 14:
		var mid := sqrt(lo * hi)
		var l: float = (await _measure(p, mid)).lit
		if OS.has_environment("GRADE_PROBE_VERBOSE"):
			print("  %s exposure %.4f lit %.4f (target %.4f)" % [p.id, mid, l, target])
		if absf(l / target - 1.0) < 0.01:
			return mid
		if l < target:
			lo = mid
		else:
			hi = mid
	return sqrt(lo * hi)


func _measure(p: GradePreset, exposure: float) -> Dictionary:
	var q := GradePreset.mix(p, p, 0.0)
	q.exposure = exposure
	_director.apply(q)
	_sun.light_energy = q.sun_energy
	_sun.light_color = q.sun_color
	for i in 10:
		await RenderingServer.frame_post_draw
	var img := _view.get_texture().get_image()
	var dump := OS.get_environment("GRADE_PROBE_PNG")
	if not dump.is_empty():
		img.save_png(dump % String(p.id))
	var lit := 0.0
	for key: StringName in LIT:
		lit += _luma(_sample(img, Vector2i(_cam.unproject_position(LIT[key]))))
	lit /= LIT.size()
	var top := _peak(_sample(img, Vector2i(SIZE.x / 2, 6)))
	var hor_px := Vector2i(_cam.unproject_position(Vector3(0.0, 2.2, -4000.0))) - Vector2i(0, 6)
	var hor := _peak(_sample(img, hor_px))
	var mx := 0.0
	var clipped := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var c := img.get_pixel(x, y)
			var m := maxf(c.r, maxf(c.g, c.b))
			mx = maxf(mx, m)
			if c.r >= 0.98 and c.g >= 0.98 and c.b >= 0.98:
				clipped += 1
	return {lit = lit, sky_top = top, sky_horizon = hor, max = mx, clipped = float(clipped) / (SIZE.x * SIZE.y)}


func _preset_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for f in DirAccess.get_files_at(GradeDirector.PRESET_DIR):
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
	ids.sort()
	return ids


func _build() -> void:
	_view = SubViewport.new()
	_view.size = SIZE
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	# The World's environment (world.tscn), so glow, fog and SSAO match the game.
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load(SKY_SHADER)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.ssao_enabled = true
	_env.glow_enabled = true
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_env.fog_enabled = true
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_length = 96.0
	# No temporal accumulation: each grade's fog settles in a few frames instead
	# of carrying the previous grade's fog into its samples.
	_env.volumetric_fog_temporal_reprojection_enabled = false
	var we := WorldEnvironment.new()
	we.environment = _env
	_view.add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-35.0, 165.0, 0.0)
	_view.add_child(_sun)
	_director = GradeDirector.new()
	_director.environment = we
	_director.sun = _sun
	_view.add_child(_director)
	# Keep it from driving the sun off the Clock: the probe holds a fixed sun.
	_director.process_mode = Node.PROCESS_MODE_DISABLED

	_box(Vector3(400.0, 0.2, 400.0), Vector3(0.0, -0.1, -150.0), GROUND)
	_box(Vector3(3.0, 1.0, 3.0), Vector3(-6.0, 0.5, 0.0), BLUSH)
	_box(Vector3(3.0, 1.0, 3.0), Vector3(-1.5, 0.5, 0.0), MINT)
	_box(Vector3(3.0, 1.0, 3.0), Vector3(3.0, 0.5, 0.0), WHITE)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_view.add_child(_cam)
	_cam.look_at_from_position(Vector3(0.0, 2.6, 9.0), Vector3(0.0, 1.0, 0.0))


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := CandyMaterial.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	_view.add_child(mi)


static func _peak(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Mean of a 5x5 block, so one noisy pixel doesn't decide a check.
static func _sample(img: Image, at: Vector2i) -> Color:
	var s := Vector3.ZERO
	var n := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p := at + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
				continue
			var c := img.get_pixelv(p)
			s += Vector3(c.r, c.g, c.b)
			n += 1
	s /= maxf(n, 1)
	return Color(s.x, s.y, s.z)

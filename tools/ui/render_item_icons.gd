## Renders a satchel icon for every catalogue item that has a real model
## (SatchelModel): a soft three-point studio light, transparent background,
## a 3/4 view from above, and a thin painted ink line round the silhouette so
## the cut-out reads like an illustration on the cloak.
##
## Needs a renderer (not --headless). In the cloud:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan \
##     --audio-driver Dummy --path . -s tools/ui/render_item_icons.gd [-- ids...]
## Output: ui/theme/icons/items/<id>.webp (256 px, lossless alpha).
extends SceneTree

const OUT_DIR := "res://ui/theme/icons/items/"
const RENDER_PX := 512
const ICON_PX := 256
## Elevation and turn of the camera round the model, degrees.
const ELEVATION := 38.0
const YAW := 28.0
const FOV := 22.0
## Painted ink line: width in render pixels and colour (the satchel ink, plum).
const LINE_PX := 5
const LINE_COLOR := Color(0.29, 0.18, 0.26, 0.62)
## No lit pixel above this (keeps the R3 bloom from blowing icons out).
const LUMA_CAP := 0.92

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _report: Array[String] = []


func _initialize() -> void:
	_build_stage()
	_run.call_deferred()


func _build_stage() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(RENDER_PX, RENDER_PX)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.94, 0.95)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	# Key: warm, upper left front. Fill: cool lilac, right. Rim: pale gold, behind.
	_light(Vector3(-48, -35, 0), Color(1.0, 0.92, 0.82), 0.7, true)
	_light(Vector3(-18, 70, 0), Color(0.84, 0.82, 1.0), 0.22, false)
	_light(Vector3(-30, 165, 0), Color(1.0, 0.93, 0.74), 0.45, false)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_vp.add_child(_cam)
	_stage = Node3D.new()
	_vp.add_child(_stage)


func _light(rot: Vector3, color: Color, energy: float, shadow: bool) -> void:
	var l := DirectionalLight3D.new()
	l.rotation_degrees = rot
	l.light_color = color
	l.light_energy = energy
	l.shadow_enabled = shadow
	l.shadow_blur = 2.0
	_vp.add_child(l)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ids: Array[StringName] = []
	var asked := OS.get_cmdline_user_args()
	for id in ItemCatalog.all_ids():
		if SatchelModel.has_model(id) and (asked.is_empty() or String(id) in asked):
			ids.append(id)
	var done := 0
	for id in ids:
		if await _render(id):
			done += 1
	var missing: Array[String] = []
	for id in ItemCatalog.all_ids():
		var item := ItemCatalog.get_item(id)
		if (item is IngredientData or item is CollectibleData) and not SatchelModel.has_model(id):
			missing.append(String(id))
	print("icons: rendered %d of %d modelled items" % [done, ids.size()])
	print("icons: forage/keepsakes with no model (drawn icon kept): %s" % ", ".join(missing))
	for line in _report:
		print(line)
	quit(0 if done == ids.size() else 1)


func _render(id: StringName) -> bool:
	var model := SatchelModel.instance(id)
	if model == null:
		_report.append("FAIL %s: could not load %s" % [id, SatchelModel.path_for(id)])
		return false
	_stage.add_child(model)
	model.rotation_degrees.y = YAW
	await process_frame
	var box := SatchelModel.bounds(_stage)
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.01)
	var dist := radius / sin(deg_to_rad(FOV * 0.5)) * 1.02
	var dir := Vector3(0, sin(deg_to_rad(ELEVATION)), cos(deg_to_rad(ELEVATION)))
	_cam.look_at_from_position(centre + dir * dist, centre, Vector3.UP)
	_cam.near = maxf(dist - radius * 2.0, 0.001)
	_cam.far = dist + radius * 2.0
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	model.queue_free()
	await process_frame
	img.convert(Image.FORMAT_RGBA8)
	var clipped := _cap_luma(img)
	img = _crop_square(img)
	_ink_line(img)
	img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
	var path := OUT_DIR + String(id) + ".webp"
	var err := img.save_webp(ProjectSettings.globalize_path(path), false)
	if err != OK:
		_report.append("FAIL %s: save error %d" % [id, err])
		return false
	if clipped > 0:
		_report.append("note %s: %d pixels pulled under the luma cap" % [id, clipped])
	return true


## Crops to the silhouette and pads back to a square with a small margin
## (room for the ink line), so every thing fills its icon the same way.
func _crop_square(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return img
	var side := int(maxf(used.size.x, used.size.y) * 1.12) + LINE_PX * 4
	var out := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, used, Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2))
	out.resize(RENDER_PX, RENDER_PX, Image.INTERPOLATE_LANCZOS)
	return out


## Soft-clamps any over-bright lit pixel down to LUMA_CAP (keeps hue).
func _cap_luma(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var l := c.get_luminance()
			if l > LUMA_CAP:
				var k := LUMA_CAP / l
				img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k, c.a))
				n += 1
	return n


## A painted outline: the silhouette grown by LINE_PX with soft edges, laid
## under the model in ink.
func _ink_line(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var alpha := PackedFloat32Array()
	alpha.resize(w * h)
	for y in h:
		for x in w:
			alpha[y * w + x] = img.get_pixel(x, y).a
	# Separable max filter (square), then the disc is approximated by its corners' falloff.
	var horiz := PackedFloat32Array()
	horiz.resize(w * h)
	for y in h:
		for x in w:
			var m := 0.0
			for d in range(-LINE_PX, LINE_PX + 1):
				var xx := x + d
				if xx >= 0 and xx < w:
					m = maxf(m, alpha[y * w + xx])
			horiz[y * w + x] = m
	for y in h:
		for x in w:
			var m := 0.0
			for d in range(-LINE_PX, LINE_PX + 1):
				var yy := y + d
				if yy >= 0 and yy < h:
					m = maxf(m, horiz[yy * w + x])
			var a := alpha[y * w + x]
			if m <= a:
				continue
			var c := img.get_pixel(x, y)
			var line := Color(LINE_COLOR, LINE_COLOR.a * m)
			# Model over line.
			var out_a := a + line.a * (1.0 - a)
			if out_a <= 0.0:
				continue
			var rgb := (Color(c.r, c.g, c.b) * a + Color(line.r, line.g, line.b) * line.a * (1.0 - a)) / out_a
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_a))

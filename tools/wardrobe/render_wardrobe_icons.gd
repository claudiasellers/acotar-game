## Renders a thumbnail for every wardrobe piece (L64): its own glTF, tinted the
## way WardrobeApplier tints it on her (the "fabric" surface takes the variant
## colour, trims keep theirs), in the satchel icons' studio light and ink line
## (tools/ui/render_item_icons.gd), seen from the front.
##
## Needs a renderer (not --headless). In the cloud:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
##     --rendering-method gl_compatibility --audio-driver Dummy --path . -s tools/wardrobe/render_wardrobe_icons.gd [-- ids...]
## Output: ui/theme/icons/wardrobe/<id>.webp (THUMB_PX, lossy), or into the folder
## named by an "out=<dir>" argument (the Mac shots runner: out={out}).
## The game look needs Forward+, so render on the Mac (docs/SHOTS.md); the
## cloud's compatibility renderer washes the pastels out.
extends "res://tools/ui/render_item_icons.gd"

const WARDROBE_DIR := "res://ui/theme/icons/wardrobe/"
const THUMB_PX := 192
const QUALITY := 0.9
## Front, a little from above, turned a touch so a gown has depth.
const THUMB_ELEVATION := 12.0
const THUMB_YAW := 14.0
## Paired small things (earrings, gloves, bracelets) sit far apart on her rest
## pose; frame the one on her left instead of two specks.
const ONE_OF_A_PAIR: Array[StringName] = [&"ears", &"hands", &"wrist"]

var _out_dir := WARDROBE_DIR


func _run() -> void:
	var asked: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			_out_dir = a.trim_prefix("out=").path_join("")
		else:
			asked.append(a)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	var done := 0
	var todo := 0
	# Straight from the data (WardrobeCatalog also loads hair, which needs autoloads).
	var pieces: Array[WardrobePiece] = []
	for file in ResourceLoader.list_directory("res://data/wardrobe/pieces"):
		if file.ends_with(".tres"):
			pieces.append(load("res://data/wardrobe/pieces/" + file) as WardrobePiece)
	for p in pieces:
		if not asked.is_empty() and not String(p.id) in asked:
			continue
		todo += 1
		if await _render_piece(p):
			done += 1
	print("wardrobe icons: rendered %d of %d" % [done, todo])
	for line in _report:
		print(line)
	quit(0 if done == todo else 1)


func _render_piece(p: WardrobePiece) -> bool:
	var scene := load(p.mesh_path) as PackedScene if ResourceLoader.exists(p.mesh_path) else null
	if scene == null:
		_report.append("FAIL %s: no mesh %s" % [p.id, p.mesh_path])
		return false
	var model := scene.instantiate() as Node3D
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		_tint(mi as MeshInstance3D, p.color)
	_stage.add_child(model)
	model.rotation_degrees.y = THUMB_YAW
	await process_frame
	var box := SatchelModel.bounds(_stage)
	if p.slots.any(func(s: StringName) -> bool: return ONE_OF_A_PAIR.has(s)) and box.size.x > box.size.y * 2.5:
		box = AABB(box.position, Vector3(box.size.x * 0.3, box.size.y, box.size.z))
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.01)
	var dist := radius / sin(deg_to_rad(FOV * 0.5)) * 1.02
	var dir := Vector3(0, sin(deg_to_rad(THUMB_ELEVATION)), cos(deg_to_rad(THUMB_ELEVATION)))
	_cam.look_at_from_position(centre + dir * dist, centre, Vector3.UP)
	_cam.near = maxf(dist - radius * 2.0, 0.001)
	_cam.far = dist + radius * 2.0
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	model.queue_free()
	await process_frame
	img.convert(Image.FORMAT_RGBA8)
	_cap_luma(img)
	if img.get_used_rect().size.x <= 0:
		_report.append("FAIL %s: nothing in frame" % p.id)
		return false
	img = _crop_square(img)
	_ink_line(img)
	img.resize(THUMB_PX, THUMB_PX, Image.INTERPOLATE_LANCZOS)
	var err := img.save_webp(ProjectSettings.globalize_path(_out_dir + String(p.id) + ".webp"), true, QUALITY)
	if err != OK:
		_report.append("FAIL %s: save error %d" % [p.id, err])
		return false
	return true


## Same rule as WardrobeApplier._tint: the "fabric" surface, else the first.
func _tint(mi: MeshInstance3D, color: Color) -> void:
	var target := 0
	for s in mi.mesh.get_surface_count():
		if (mi.mesh as ArrayMesh) and (mi.mesh as ArrayMesh).surface_get_name(s) == "fabric":
			target = s
	var base := mi.mesh.surface_get_material(target)
	var m: CandyMaterial = base.duplicate() if base is CandyMaterial else MaterialLibrary.surface()
	m.albedo_color = color
	mi.set_surface_override_material(target, m)

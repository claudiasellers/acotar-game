## Renders one icon per brew (lane L62): the stoppered bottle from
## tools/chemistry/blender_brew_bottle.py, its body tinted the brew's colour,
## on the same studio stage, crop and ink line as the satchel's item icons
## (tools/ui/render_item_icons.gd), so they sit in the same set.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver vulkan \
##     --audio-driver Dummy --path . -s tools/chemistry/render_brew_icons.gd
## Output: ui/theme/icons/brews/<brew id>.webp (256 px).
extends "res://tools/ui/render_item_icons.gd"

const BOTTLE := "res://ui/chemistry/models/brew_bottle.glb"
const BREW_DIR := "res://ui/theme/icons/brews/"
const CORK := Color(0.55, 0.38, 0.24)
const GILT := Color(0.86, 0.68, 0.33)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BREW_DIR))
	var done := 0
	for rule in BrewBook.rules():
		if await _render_brew(rule):
			done += 1
	print("brew icons: rendered %d of %d" % [done, BrewBook.rules().size()])
	quit(0 if done == BrewBook.rules().size() else 1)


func _render_brew(rule: BrewRule) -> bool:
	var model := (load(BOTTLE) as PackedScene).instantiate() as Node3D
	_stage.add_child(model)
	model.rotation_degrees.y = YAW
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		if n.begins_with("cork"):
			mi.material_override = MaterialLibrary.surface(CORK, 0.9)
		elif n.begins_with("band"):
			mi.material_override = MaterialLibrary.surface(GILT, 0.35, 0.8)
		else:
			mi.material_override = MaterialLibrary.surface(glass_tint(rule.color), 0.18)
	await process_frame
	var box := SatchelModel.bounds(_stage)
	var centre := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.01)
	var dist := radius / sin(deg_to_rad(FOV * 0.5)) * 1.02
	var dir := Vector3(0, sin(deg_to_rad(ELEVATION * 0.5)), cos(deg_to_rad(ELEVATION * 0.5)))
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
	img = _crop_square(img)
	_ink_line(img)
	img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_LANCZOS)
	return img.save_webp(ProjectSettings.globalize_path(BREW_DIR + String(rule.id) + ".webp"), false) == OK


## Pale brews (snowdrop, rime) would render white: deepen them into a candy
## glass that still reads as their colour.
static func glass_tint(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(maxf(c.s, 0.42), 0.0, 0.8), clampf(c.v, 0.45, 0.86))

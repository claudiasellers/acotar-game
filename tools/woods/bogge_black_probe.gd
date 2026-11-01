## Temporary bisection probe (act1 render bug: the Bogge heart renders pure
## black at look quality). Mac only, via tools/mq/shots_request.sh:
##   shot bogge res://tools/woods/bogge_black_probe.tscn {out}
## Builds the eastern_bogge view, then turns off one look feature or one
## region child at a time (from the full look each time, TAA history reset)
## and writes the mean luma and black-pixel share of each to {out}/luma.txt.
extends Node

const EYE := Vector3(1500, 0, -380)
const AT := Vector3(1560, 0, -430)

var world: World
var out_dir := "user://bogge_probe"
var lines: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	Clock.paused = true
	Clock.time_of_day = 0.45
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	world = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	var cam := Camera3D.new()
	var eye := EYE
	var at := AT
	eye.y = WorldHeight.height_at(eye.x, eye.z) + 1.7
	at.y = WorldHeight.height_at(at.x, at.z) + 1.2
	cam.position = eye
	cam.far = 1200.0
	cam.fov = 70.0
	world.add_child(cam)
	cam.look_at(at)
	cam.make_current()
	world.grade.swap_to(&"spring", 0.0)
	for def in WorldStreamer.find_region_defs("res://data/regions"):
		if Vector2(def.center.x - eye.x, def.center.z - eye.z).length() < def.radius + 400.0:
			world.regions.add_child((load(def.scene_path) as PackedScene).instantiate())
	await _wait_built(180.0)
	await _frames(90)
	await _shot("baseline", true)
	print("PROBE mood ", world.grade.mood, " ", world.grade.mood_amount)
	# Dread preset candidates, applied to the live director.
	var base: GradePreset = GradeDirector.load_preset(&"dread")
	var variants := {
		"vol012_exp19": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.012},
		"vol012_exp30": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.012, "exposure": 0.30},
		"vol020_exp30": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.020, "exposure": 0.30},
		"vol012_exp30_vlight1": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.012, "exposure": 0.30, "volumetric_light_energy": 1.0},
		"vol012_exp30_amb12": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.012, "exposure": 0.30, "ambient_energy": 1.2},
		"vol012_exp40_amb12": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.012, "exposure": 0.40, "ambient_energy": 1.2},
		"novol_exp30": {"fog_height": -1.0, "fog_color": Color(0.42, 0.44, 0.44), "volumetric_albedo": Color(0.55, 0.56, 0.58), "volumetric_density": 0.0, "exposure": 0.30},
	}
	for label: String in variants:
		var p := base.duplicate() as GradePreset
		for k: String in variants[label]:
			p.set(k, variants[label][k])
		GradeDirector._dread_preset = p
		world.grade.apply(world.grade.current)
		await _shot(label, true)
	GradeDirector._dread_preset = base
	FileAccess.open(out_dir.path_join("luma.txt"), FileAccess.WRITE).store_string("\n".join(lines) + "\n")
	get_tree().quit(0)


## Every MultiMeshInstance3D under the region's scatter fields is named after its layer.
func _layer_names(region: Node) -> Array:
	var names := {}
	for m in region.find_children("*", "MultiMeshInstance3D", true, false):
		names[_layer_of(m)] = true
	return names.keys()


func _layer_of(m: Node) -> String:
	var re := RegEx.create_from_string("_-?\\d+_-?\\d+(_far)?$")
	return re.sub(String(m.name), "")


func _set_layer_visible(region: Node, layer: String, on: bool) -> int:
	var n := 0
	for m in region.find_children("*", "MultiMeshInstance3D", true, false):
		if _layer_of(m) == layer:
			(m as Node3D).visible = on
			n += 1
	return n


func _wait_built(cap_s: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(cap_s * 1000.0):
		var pending := 0
		for r in world.regions.get_children():
			if &"is_built" in r and not bool(r.get(&"is_built")):
				pending += 1
		if pending == 0:
			return
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Resets TAA history (a NaN stays in it otherwise), settles, measures.
func _shot(label: String, full: bool = false) -> void:
	var vp := get_viewport()
	var taa := vp.use_taa
	vp.use_taa = not taa
	await _frames(2)
	vp.use_taa = taa
	await _frames(40)
	var img := vp.get_texture().get_image()
	var sum := 0.0
	var black := 0
	var step := 4
	var count := 0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			sum += l
			if l < 0.004:
				black += 1
			count += 1
	var line := "%s luma %.1f black %.3f" % [label, sum / count * 255.0, float(black) / count]
	print("PROBE ", line)
	lines.append(line)
	if not full:
		img.resize(480, 270)
	img.save_png(out_dir.path_join("%s.png" % label))

extends SceneTree
## Render program T2 acceptance: loads N imported glbs (fixed seed) and counts
## surfaces still on a stock BaseMaterial3D. Pass "all" to check every glb/gltf.
##   godot --headless -s tools/render/glb_material_probe.gd [-- 20|all]

const SEED := 58


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	var pick: Array[String] = files
	if args.is_empty() or args[0] != "all":
		var n := int(args[0]) if not args.is_empty() else 20
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		pick = []
		while pick.size() < mini(n, files.size()):
			var f := files[rng.randi_range(0, files.size() - 1)]
			if not pick.has(f):
				pick.append(f)
	var stock := 0
	var candy := 0
	var other := 0
	for f in pick:
		var ps := load(f) as PackedScene
		if ps == null:
			continue
		var root := ps.instantiate()
		var s := 0
		var c := 0
		for n in root.find_children("*", "MeshInstance3D", true, false) + [root]:
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m is BaseMaterial3D:
					s += 1
				elif m is CandyMaterial:
					c += 1
				else:
					other += 1
		stock += s
		candy += c
		if args.is_empty() or args[0] != "all" or s > 0:
			print("GLB %s stock=%d candy=%d" % [f, s, c])
		root.free()
	print("GLB_PROBE files=%d stock_surfaces=%d candy_surfaces=%d other=%d" % [pick.size(), stock, candy, other])
	quit()


func _collect(dir: String, out: Array[String]) -> void:
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "addons":
			continue
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") or f.ends_with(".gltf"):
			out.append(dir.path_join(f))

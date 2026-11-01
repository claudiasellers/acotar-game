## L21 look shots of the Spring forest's new Blender flora (Mac GPU probe,
## docs/contracts/shots.md):
##   godot res://tools/woods/spring_flora_shot.tscn -- <out_dir>
## Builds the Border Woods, finds the spot where the most L21 species grow
## together, and takes three pictures in one run: eye level across that
## clearing, a low look at the ground flowers, and a raised view.
extends Node

const NEW_TREES := [&"candyfloss_tree", &"wisteria_tree", &"golden_chain", &"magnolia"]
const NEW_SHRUBS := [&"peony_bush", &"hydrangea", &"azalea", &"lavender_mound", &"iris_clump",
		&"goldenrod", &"lupin_clump", &"sugarberry_bush"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	var root := get_tree().root
	root.size = Vector2i(1920, 1080)
	Clock.paused = true
	Clock.time_of_day = 0.45
	var world: World = load("res://world/shared/world/world.tscn").instantiate()
	root.add_child(world)
	world.grade.swap_to(&"spring", 0.0)
	var cam := Camera3D.new()
	cam.far = 1500.0
	cam.fov = 60.0
	world.add_child(cam)
	cam.make_current()
	var woods := (load("res://world/spring_court/border_woods/border_woods.tscn") as PackedScene).instantiate() as WoodsRegion
	world.regions.add_child(woods)
	await get_tree().process_frame
	woods.build_now()
	var spot := _best_spot(woods)
	var p: Vector2 = spot[0]
	var dir: Vector2 = spot[1]
	print("SPOT %s species %d" % [p, spot[2]])
	var views := {
		"flora_clearing": [p - dir * 16.0, p, 1.7, 2.0],
		"flora_ground": [p - dir * 5.0 + dir.orthogonal() * 3.0, p - dir * 1.0 + dir.orthogonal() * 3.0, 1.1, -0.6],
		"flora_raised": [p - dir * 60.0, p, 22.0, 0.0],
	}
	for id: String in views:
		var v: Array = views[id]
		var eye: Vector2 = v[0]
		var at: Vector2 = v[1]
		cam.position = Vector3(eye.x, WorldHeight.height_at(eye.x, eye.y) + v[2], eye.y)
		cam.look_at(Vector3(at.x, WorldHeight.height_at(at.x, at.y) + v[3], at.y))
		for i in 60:
			await get_tree().process_frame
		if OS.get_environment("SHOTS_QUALITY") == "look":
			await get_tree().create_timer(4.0).timeout
		var path := "%s/%s.png" % [out, id]
		var img := root.get_texture().get_image()
		if img == null:
			push_error("no frame to save (headless?)")
			break
		img.save_png(path)
		var draw := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("SHOT %s -> %s | draw_calls %d" % [id, path, draw])
	get_tree().quit(0)


## [centre xz, view direction xz, distinct L21 species within ~30 m] of the
## new tree with the most L21 species around it; the camera comes from the
## side with the fewest trunks in the way. Grid lookups keep it fast.
func _best_spot(woods: WoodsRegion) -> Array:
	const CELL := 15.0
	var kinds_at := {}   # Vector2i -> {species: true}
	var trunks_at := {}  # Vector2i -> count
	var candidates: Array[Vector2] = []
	for l in woods.layers:
		var lid := String(l.id)
		var sp := StringName(lid.trim_prefix("tree_").trim_prefix("shrub_"))
		var is_new := sp in NEW_TREES or sp in NEW_SHRUBS
		for j in l.count():
			var r := l.position_of(j)
			var key := Vector2i(floori(r.x / CELL), floori(r.z / CELL))
			if is_new:
				if not kinds_at.has(key):
					kinds_at[key] = {}
				kinds_at[key][sp] = true
				if lid.begins_with("tree_") and j % 2 == 0:
					candidates.append(Vector2(r.x, r.z))
			if lid.begins_with("tree_"):
				trunks_at[key] = trunks_at.get(key, 0) + 1
	var best := [Vector2.ZERO, Vector2(0, -1), -1]
	for c in candidates:
		var k0 := Vector2i(floori(c.x / CELL), floori(c.y / CELL))
		var seen := {}
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				for sp in kinds_at.get(k0 + Vector2i(dx, dz), {}):
					seen[sp] = true
		if seen.size() > best[2]:
			best = [c, Vector2(0, -1), seen.size()]
	var centre: Vector2 = best[0]
	var fewest := 1 << 30
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0)
		var blocked := 0
		for step in range(1, 16):
			var q := centre - d * float(step)
			blocked += int(trunks_at.get(Vector2i(floori(q.x / CELL), floori(q.y / CELL)), 0))
		if blocked < fewest:
			fewest = blocked
			best[1] = d
	return best

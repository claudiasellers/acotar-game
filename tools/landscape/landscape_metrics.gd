## Composition metrics and a plan drawing for the Spring Court tree/shrub
## layout (the landscape pass's numeric "done when" list):
##   godot --headless --path . -s res://tools/landscape/landscape_metrics.gd -- [out_dir]
## Per region: tree count, close pairs (< 3 m), same-species neighbour share,
## open share of wooded ground (20 m cells with no tree), clumping (variance /
## mean of 20 m cell counts; 1 = random, > 1 = groves), a placement hash
## (determinism) and a 1 px = 1 m plan PNG.
extends SceneTree

const CELL := 20.0
const WOODS := ["border_woods", "eastern_woods", "suriel_glade"]
const COURT := ["autumn_foothills", "blighted_reaches", "blossom_vale", "fae_village", "hill_of_the_rite",
		"rosewild", "solstice_meadow", "starlight_glen", "western_fells"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else ""
	var only := args.slice(1)
	for r in WOODS + COURT:
		if not only.is_empty() and not only.has(r):
			continue
		var trees := {}
		var shrubs := {}
		var bounds: Rect2
		if r in WOODS:
			var def: WoodsRegionDef = load("res://data/regions/spring_court/%s_biomes.tres" % r)
			bounds = def.provider.BOUNDS
			trees = WoodsScatter.place(def, bounds, "tree")
			shrubs = WoodsScatter.place(def, bounds, "shrub")
		else:
			var content: CourtRegionContent = load("res://data/regions/spring_court/content/%s.tres" % r)
			bounds = content.bounding_rect()
			for layer in CourtScatterGenerator.decor_layers(content):
				var key := String(layer.id).substr(9)
				var target := trees if layer.tags.has("tree") else (shrubs if layer.cast_shadow and not key.begins_with("rock") else {})
				if not target.has(key):
					target[key] = PackedFloat32Array()
				for i in layer.count():
					var p := layer.position_of(i)
					target[key].append_array(PackedFloat32Array([p.x, p.y, p.z, 0.0, 1.0]))
		_report(r, bounds, trees, shrubs, out)
	quit(0)


func _report(region: String, bounds: Rect2, trees: Dictionary, shrubs: Dictionary, out: String) -> void:
	var pts: Array = []  # [Vector2, species index]
	var names := trees.keys()
	names.sort()
	var h := 0
	for si in names.size():
		var inst: PackedFloat32Array = trees[names[si]]
		h = hash([h, inst])
		for o in range(0, inst.size(), 5):
			pts.append([Vector2(inst[o], inst[o + 2]), si])
	var grid := {}
	for i in pts.size():
		var k := Vector2i(floori(pts[i][0].x / 6.0), floori(pts[i][0].y / 6.0))
		if not grid.has(k):
			grid[k] = []
		grid[k].append(i)
	var close := 0
	var same := 0
	var with_nn := 0
	for i in pts.size():
		var p: Vector2 = pts[i][0]
		var k := Vector2i(floori(p.x / 6.0), floori(p.y / 6.0))
		var best := INF
		var best_s := -1
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				for j: int in grid.get(k + Vector2i(dx, dz), []):
					if j == i:
						continue
					var d := p.distance_to(pts[j][0])
					if d < best:
						best = d
						best_s = pts[j][1]
		if best < 3.0:
			close += 1
		if best_s >= 0:
			with_nn += 1
			if best_s == pts[i][1]:
				same += 1
	# 20 m cells: count trees; "wooded" cells are those within 60 m of a tree.
	var counts := {}
	for e in pts:
		var c := Vector2i(floori(e[0].x / CELL), floori(e[0].y / CELL))
		counts[c] = counts.get(c, 0) + 1
	var cells: Array = []
	for cz in range(floori(bounds.position.y / CELL), ceili(bounds.end.y / CELL)):
		for cx in range(floori(bounds.position.x / CELL), ceili(bounds.end.x / CELL)):
			var near := false
			for dz in range(-3, 4):
				for dx in range(-3, 4):
					if counts.has(Vector2i(cx + dx, cz + dz)):
						near = true
			if near:
				cells.append(counts.get(Vector2i(cx, cz), 0))
	var mean := 0.0
	for n in cells:
		mean += n
	mean /= maxf(cells.size(), 1.0)
	var var_ := 0.0
	var empty := 0
	for n in cells:
		var_ += (n - mean) * (n - mean)
		if n == 0:
			empty += 1
	var_ /= maxf(cells.size(), 1.0)
	var shrub_n := 0
	for k2 in shrubs:
		shrub_n += (shrubs[k2] as PackedFloat32Array).size() / 5
	print("METRICS %s | trees %d | species %d | close_pairs %.1f%% | same_species_nn %.0f%% | open_cells %.0f%% | clumping %.2f | shrubs %d | hash %d" % [
		region, pts.size(), names.size(), 100.0 * close / maxf(pts.size(), 1.0), 100.0 * same / maxf(with_nn, 1.0),
		100.0 * empty / maxf(cells.size(), 1.0), var_ / maxf(mean, 0.001), shrub_n, h])
	if out != "":
		_plan(region, bounds, trees, shrubs, out)


func _plan(region: String, bounds: Rect2, trees: Dictionary, shrubs: Dictionary, out: String) -> void:
	var img := Image.create(int(bounds.size.x), int(bounds.size.y), false, Image.FORMAT_RGB8)
	img.fill(Color(0.93, 0.95, 0.88))
	var palette := [Color("2f6b3a"), Color("c2507a"), Color("7a5cc2"), Color("2b7fa8"), Color("b8862b"),
			Color("4f9a5a"), Color("8a2f2f"), Color("5a5a5a"), Color("d07a2a"), Color("1f4f2a"), Color("9a4fb0")]
	for layer_set in [[shrubs, 1, 0.55], [trees, 3, 1.0]]:
		var names: Array = layer_set[0].keys()
		names.sort()
		for si in names.size():
			var col: Color = palette[(si * 3 + (0 if layer_set[1] == 3 else 5)) % palette.size()]
			col = col.lerp(Color.WHITE, 1.0 - layer_set[2])
			var inst: PackedFloat32Array = layer_set[0][names[si]]
			for o in range(0, inst.size(), 5):
				var c := Vector2i(int(inst[o] - bounds.position.x), int(inst[o + 2] - bounds.position.y))
				var r: int = layer_set[1]
				for dz in range(-r, r + 1):
					for dx in range(-r, r + 1):
						if dx * dx + dz * dz <= r * r:
							var q := c + Vector2i(dx, dz)
							if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
								img.set_pixelv(q, col)
	img.save_png("%s/plan_%s.png" % [out, region])

## Paints the world map from the world's own data (no hand painting): ground
## height and the terrain bake's texture rule (TerrainBaker), the Thornwater,
## the Wall, and tree scatter as canopy. The look is Feyre's sketchbook: soft
## pastel watercolour washes on warm paper, a pale hillshade, faint gold
## contour lines and ink edges where water meets land (R3).
##
## Deterministic (fixed seeds). tools/generators/world_map.gd bakes it at
## BAKE_METRES_PER_PIXEL into ui/map/_generated/world_map.res (a MapBake;
## git-ignored, R15); when that
## cache is missing the game builds a coarse copy on a thread instead.
class_name MapArt
extends RefCounted

const OUT_DIR := "res://ui/map/_generated"
const BAKE_PATH := OUT_DIR + "/world_map.res"
const BAKE_METRES_PER_PIXEL := 4.0
const FALLBACK_METRES_PER_PIXEL := 16.0
const SEED := 1723
const STREAMER := preload("res://core/streaming/world_streamer.gd")
## Scatter ids that read as trees on the map (hedges and saplings included).
const TREE_WORDS: Array[String] = ["tree", "oak", "birch", "pine", "willow", "hawthorn",
	"holly", "hazel", "blackthorn", "juniper", "hedge", "yew", "rowan", "alder", "beech", "elm",
	"orchard", "cherry", "apple", "blossom", "grove", "canopy", "trunk", "snag"]
const SCATTER_ROOTS: Array[String] = ["res://world"]
const COURT_CONTENT_DIR := "res://data/regions/spring_court/content"
const CONTOUR_METRES := 20.0

## Watercolour washes per Terrain3D texture slot (WorldHeight.Tex order).
const GROUND: Array[Color] = [
	Color(0.93, 0.92, 0.99),  # SNOW: pearl
	Color(0.84, 0.78, 0.89),  # FROZEN_EARTH: lilac grey
	Color(0.76, 0.74, 0.90),  # ROCK: periwinkle stone
	Color(0.80, 0.87, 0.84),  # WINTER_GRASS: frosted sage
	Color(0.70, 0.92, 0.72),  # SPRING_GRASS: mint
	Color(0.58, 0.86, 0.70),  # MOSS: deep mint
	Color(0.64, 0.83, 0.74),  # FOREST_FLOOR
	Color(1.00, 0.91, 0.72),  # PATH: butter
	Color(0.66, 0.77, 0.98),  # RIVERBED: periwinkle water
	Color(0.64, 0.52, 0.66),  # BLIGHT: dusky plum
	Color(0.82, 0.91, 1.00),  # ICE
]
const PAPER := Color(1.0, 0.97, 0.93)
const WATER := Color(0.62, 0.74, 0.98)
const WATER_LIGHT := Color(0.86, 0.92, 1.0)
const INK := Color(0.42, 0.30, 0.46)
const GOLD := Color(0.88, 0.70, 0.36)
const CANOPY_SPRING := Color(0.40, 0.76, 0.62)
const CANOPY_WINTER := Color(0.76, 0.81, 0.92)
const CANOPY_BLIGHT := Color(0.46, 0.33, 0.48)
const HIGH_GROUND := Color(0.78, 0.76, 0.96)
const SUNLIT := Color(1.0, 0.96, 0.84)
const SHADOW := Color(0.58, 0.52, 0.76)
const LIGHT := Vector3(-0.5, 0.72, -0.48)
## LIGHT.y normalised: how lit flat ground is (no tint there).
const FLAT_LIT := 0.73
const CROWN_CELL := 18.0
const CANOPY_M2 := 60.0
const BLOSSOM := Color(1.0, 0.80, 0.88)
const FROST := Color(1.0, 1.0, 1.0)
const WALL := Color(1.0, 0.96, 0.99)


## Pixel size of the map image at a given resolution.
static func image_size(metres_per_pixel: float) -> Vector2i:
	var rect := WorldMap.MAP_RECT
	return Vector2i(int(rect.size.x / metres_per_pixel), int(rect.size.y / metres_per_pixel))


## World XZ to 0-1 map UV (u east, v south).
static func world_to_uv(x: float, z: float) -> Vector2:
	var rect := WorldMap.MAP_RECT
	return Vector2((x - rect.position.x) / rect.size.x, (z - rect.position.y) / rect.size.y)


static func uv_to_world(uv: Vector2) -> Vector2:
	var rect := WorldMap.MAP_RECT
	return rect.position + uv * rect.size


## Paints the whole map. threaded = false for callers already on a thread.
static func build(metres_per_pixel: float, threaded: bool = true) -> Image:
	var size := image_size(metres_per_pixel)
	var w := size.x
	var h := size.y
	var origin := WorldMap.MAP_RECT.position
	var step := metres_per_pixel
	WorldHeight.warm_up()

	# 1. Height and ground texture per pixel (rows go into a pre-sized Array,
	#    as in TerrainBaker: captured packed arrays would be copies).
	var rows := []
	rows.resize(h)
	var height_task := func(row: int) -> void:
		var z := origin.y + (row + 0.5) * step
		var line := PackedFloat32Array()
		line.resize(w)
		for col in w:
			line[col] = WorldHeight.height_at(origin.x + (col + 0.5) * step, z)
		rows[row] = line
	_run_rows(height_task, h, threaded, "map heights")
	var heights := PackedFloat32Array()
	for line: PackedFloat32Array in rows:
		heights.append_array(line)

	var trows := []
	trows.resize(h)
	var texture_task := func(row: int) -> void:
		var z := origin.y + (row + 0.5) * step
		var line := PackedInt32Array()
		line.resize(w * 3)
		for col in w:
			var x := origin.x + (col + 0.5) * step
			var t := TerrainBaker.decode_control(TerrainBaker._control_at(x, z, heights, w, row, col, step))
			line[col * 3] = t.x
			line[col * 3 + 1] = t.y
			line[col * 3 + 2] = t.z
		trows[row] = line
	_run_rows(texture_task, h, threaded, "map ground")

	# 2. Tree canopy density from scatter, softened.
	var canopy := _canopy_density(w, h, step)

	# 3. Paint.
	var paper := _noise(SEED, 0.004 * step, 3)
	var grain := _noise(SEED + 1, 0.35 * step, 2)
	var dots := _noise(SEED + 2, 0.22 * step, 1)
	var wash := _noise(SEED + 3, 0.02 * step, 2)
	var crows := []
	crows.resize(h)
	var paint_task := func(row: int) -> void:
		var line := PackedByteArray()
		line.resize(w * 3)
		var tex_line: PackedInt32Array = trows[row]
		var z := origin.y + (row + 0.5) * step
		for col in w:
			var x := origin.x + (col + 0.5) * step
			var c := _paint(col, row, x, z, w, h, step, heights, tex_line, canopy, paper, grain, dots, wash)
			line[col * 3] = c.r8
			line[col * 3 + 1] = c.g8
			line[col * 3 + 2] = c.b8
		crows[row] = line
	_run_rows(paint_task, h, threaded, "map paint")
	var bytes := PackedByteArray()
	for line: PackedByteArray in crows:
		bytes.append_array(line)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)


static func _paint(col: int, row: int, x: float, z: float, w: int, h: int, step: float,
		heights: PackedFloat32Array, tex_line: PackedInt32Array, canopy: PackedFloat32Array,
		paper: FastNoiseLite, grain: FastNoiseLite, dots: FastNoiseLite, wash: FastNoiseLite) -> Color:
	var i := row * w + col
	var hc := heights[i]
	var base := tex_line[col * 3]
	var over := tex_line[col * 3 + 1]
	var blend := tex_line[col * 3 + 2] / 255.0
	var c := GROUND[base].lerp(GROUND[over], blend)
	var winter := z >= WorldMap.WALL_Z

	# Height tint: lilac-periwinkle peaks over mint lowlands.
	c = c.lerp(HIGH_GROUND, clampf((hc - 30.0) / 160.0, 0.0, 0.45))
	# North-west hillshade, warm on the lit side, lilac in shadow.
	var hx := heights[row * w + mini(col + 1, w - 1)] - heights[row * w + maxi(col - 1, 0)]
	var hz := heights[mini(row + 1, h - 1) * w + col] - heights[maxi(row - 1, 0) * w + col]
	var n := Vector3(-hx, 2.0 * step, -hz).normalized()
	var lit := n.dot(LIGHT) - FLAT_LIT
	if lit > 0.0:
		c = c.lerp(SUNLIT, clampf(lit * 1.6, 0.0, 0.45))
	else:
		c = c.lerp(SHADOW, clampf(-lit * 1.8, 0.0, 0.6))

	# Gold contour lines, faint, on land only.
	var water := MacroHeight.distance_to_river(x, z)
	if water > MacroHeight.RIVER_HALF_WIDTH + step:
		var band := floorf(hc / CONTOUR_METRES)
		var right := floorf(heights[row * w + mini(col + 1, w - 1)] / CONTOUR_METRES)
		var down := floorf(heights[mini(row + 1, h - 1) * w + col] / CONTOUR_METRES)
		if band != right or band != down:
			c = c.lerp(GOLD, 0.22)

	# Canopy: round storybook crowns with a lit cap and an ink rim.
	var d := canopy[i]
	if d > 0.12 and base != WorldHeight.Tex.RIVERBED:
		var leaf := CANOPY_WINTER if winter else CANOPY_SPRING
		if base == WorldHeight.Tex.BLIGHT:
			leaf = CANOPY_BLIGHT
		if step > 6.0:
			c = c.lerp(leaf, clampf((d - 0.12) * 2.5, 0.0, 0.8))
		else:
			c = _crowns(c, x, z, d, leaf, winter, dots)

	# Water: periwinkle with a pearly middle and an ink edge.
	var half := MacroHeight.RIVER_HALF_WIDTH + step * 0.5
	if water < half:
		c = WATER.lerp(WATER_LIGHT, clampf(1.0 - water / half, 0.0, 1.0) * 0.6)
	elif water < half + step * 1.2:
		c = c.lerp(INK, 0.6)
	elif base == WorldHeight.Tex.RIVERBED or base == WorldHeight.Tex.ICE:
		c = c.lerp(WATER, 0.5)

	# The Wall: a pearly shimmer band edged in gold, open at the gap.
	var wall := absf(z - WorldMap.WALL_Z)
	if absf(x - WorldMap.WALL_GAP_X) > 14.0:
		if wall < WorldMap.WALL_SEAM_HALF_DEPTH + step * 0.5:
			c = WALL
		elif wall < WorldMap.WALL_SEAM_HALF_DEPTH + step * 1.5:
			c = c.lerp(GOLD, 0.8)

	# Paper: big watercolour wash variation, fine grain, a breath of warmth.
	c = c * (1.0 + wash.get_noise_2d(x, z) * 0.07)
	c = c * (1.0 - absf(grain.get_noise_2d(x, z)) * 0.05)
	c = c.lerp(PAPER, 0.05)
	return Color(clampf(c.r, 0.0, 1.0), clampf(c.g, 0.0, 1.0), clampf(c.b, 0.0, 1.0))


## Jittered crowns on a CROWN_CELL grid, present where the canopy is dense.
static func _crowns(c: Color, x: float, z: float, d: float, leaf: Color, winter: bool, dots: FastNoiseLite) -> Color:
	var gx := floori(x / CROWN_CELL)
	var gz := floori(z / CROWN_CELL)
	var best := 2.0
	var best_hash := 0
	var best_off := Vector2.ZERO
	for oz in range(-1, 2):
		for ox in range(-1, 2):
			var hsh := _hash(gx + ox, gz + oz)
			if float(hsh & 1023) / 1023.0 > d * 2.2:
				continue
			var jx := float((hsh >> 10) & 255) / 255.0
			var jz := float((hsh >> 18) & 255) / 255.0
			var centre := Vector2((gx + ox + 0.2 + 0.6 * jx) * CROWN_CELL, (gz + oz + 0.2 + 0.6 * jz) * CROWN_CELL)
			var radius := CROWN_CELL * (0.42 + 0.22 * float((hsh >> 26) & 31) / 31.0)
			var off := Vector2(x, z) - centre
			var t := off.length() / radius
			if t < best:
				best = t
				best_hash = hsh
				best_off = off / radius
	if best > 1.0:
		# Ground between crowns sits in their shade.
		return c.lerp(SHADOW, clampf(d * 0.5, 0.0, 0.3))
	if best > 0.84:
		return c.lerp(leaf.darkened(0.3), 0.6)
	var crown := leaf.lerp(leaf.lightened(0.1), float(best_hash & 7) / 7.0)
	# Lit cap toward the north-west light.
	var cap := clampf(1.0 - (best_off - Vector2(-0.35, -0.35)).length() * 1.4, 0.0, 1.0)
	crown = crown.lerp(Color(1, 1, 1), cap * 0.35)
	crown = crown.lerp(leaf.darkened(0.25), clampf(best - 0.55, 0.0, 0.3))
	if (best_hash >> 7) & 3 == 0 and best < 0.6:
		var bloom := dots.get_noise_2d(x * 4.0, z * 4.0)
		if bloom > 0.25:
			crown = crown.lerp(FROST if winter else BLOSSOM, 0.8)
	return crown


static func _hash(a: int, b: int) -> int:
	var hsh := (a * 73856093) ^ (b * 19349663) ^ SEED
	hsh = (hsh ^ (hsh >> 13)) * 1274126177
	return (hsh ^ (hsh >> 16)) & 0x7fffffff


static func _run_rows(task: Callable, count: int, threaded: bool, label: String) -> void:
	if threaded:
		var id := WorkerThreadPool.add_group_task(task, count, -1, true, label)
		WorkerThreadPool.wait_for_group_task_completion(id)
	else:
		for row in count:
			task.call(row)


static func _noise(seed: int, frequency: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n


static func _canopy_density(w: int, h: int, step: float) -> PackedFloat32Array:
	var grid := PackedFloat32Array()
	grid.resize(w * h)
	var rect := WorldMap.MAP_RECT
	for inst in tree_points():
		for k in range(0, inst.size() - 4, 5):
			var col := int((inst[k] - rect.position.x) / step)
			var row := int((inst[k + 2] - rect.position.y) / step)
			if col >= 0 and col < w and row >= 0 and row < h:
				grid[row * w + col] += 1.0
	# Two box blurs about 12 m wide turn trunks into canopy.
	var radius := maxi(1, int(round(12.0 / step)))
	for pass_i in 2:
		grid = _blur(grid, w, h, radius)
	# Full canopy at one tree per CANOPY_M2 square metres.
	var scale := CANOPY_M2 / (step * step)
	for i in grid.size():
		grid[i] = clampf(grid[i] * scale, 0.0, 1.0)
	return grid


static func _blur(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	var inv := 1.0 / float(2 * r + 1)
	for row in h:
		var acc := 0.0
		for col in range(-r, r + 1):
			acc += src[row * w + clampi(col, 0, w - 1)]
		for col in w:
			tmp[row * w + col] = acc * inv
			acc += src[row * w + mini(col + r + 1, w - 1)] - src[row * w + maxi(col - r, 0)]
	var out := PackedFloat32Array()
	out.resize(w * h)
	for col in w:
		var acc := 0.0
		for row in range(-r, r + 1):
			acc += tmp[clampi(row, 0, h - 1) * w + col]
		for row in h:
			out[row * w + col] = acc * inv
			acc += tmp[mini(row + r + 1, h - 1) * w + col] - tmp[maxi(row - r, 0) * w + col]
	return out


static func is_tree_layer(layer: ScatterLayer) -> bool:
	var id := String(layer.id).to_lower()
	if id.begins_with("ing_") or not String(layer.ingredient_id).is_empty():
		return false
	if layer.tags.has("collectible"):
		return false
	if layer.tags.has("tree"):
		return true
	var path := layer.mesh_path.to_lower()
	for word in TREE_WORDS:
		if id.contains(word) or path.get_file().contains(word):
			return true
	return false


## Tree positions (x, y, z, yaw, scale per tree) from every source of scatter:
## layer files, region scenes' embedded layers and the woods' baked caches.
static func tree_points() -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	var layers := scatter_layers()
	layers.append_array(scene_layers())
	for content in court_contents():
		layers.append_array(CourtScatterGenerator.decor_layers(content))
	var seen := {}
	for layer in layers:
		if is_tree_layer(layer) and not seen.has(layer):
			seen[layer] = true
			out.append(layer.instances)
	var caches: Array[String] = []
	for root in SCATTER_ROOTS:
		_find_files(root, ".res", caches)
	for path in caches:
		if not path.contains("/_generated/"):
			continue
		var cache := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if cache is WoodsScatterCache:
			var trees: Dictionary = (cache as WoodsScatterCache).placements.get("tree", {})
			for id: Variant in trees:
				out.append(trees[id] as PackedFloat32Array)
	return out


## The wider court's region content (its scatter is generated at load).
static func court_contents() -> Array[CourtRegionContent]:
	var out: Array[CourtRegionContent] = []
	var paths: Array[String] = []
	_find_files(COURT_CONTENT_DIR, ".tres", paths)
	paths.sort()
	for path in paths:
		var res := ResourceLoader.load(path)
		if res is CourtRegionContent:
			out.append(res)
	return out


## ScatterLayers embedded in region scenes (read from the packed scene state,
## nothing is instanced).
static func scene_layers() -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	for def: RegionDef in STREAMER.find_region_defs("res://data/regions"):
		if def.scene_path.is_empty() or not ResourceLoader.exists(def.scene_path):
			continue
		var scene := ResourceLoader.load(def.scene_path) as PackedScene
		if scene == null:
			continue
		var state := scene.get_state()
		for n in state.get_node_count():
			for p in state.get_node_property_count(n):
				var value: Variant = state.get_node_property_value(n, p)
				if value is ScatterLayer:
					out.append(value)
				elif value is Array:
					for item: Variant in value:
						if item is ScatterLayer:
							out.append(item)
	return out


## Every ScatterLayer resource on disk (committed and generated).
static func scatter_layers() -> Array[ScatterLayer]:
	var out: Array[ScatterLayer] = []
	var paths: Array[String] = []
	for root in SCATTER_ROOTS:
		_find_files(root, ".tres", paths)
	paths.sort()
	for path in paths:
		if not path.contains("/scatter/"):
			continue
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is ScatterLayer:
			out.append(res)
	return out


static func _find_files(dir_path: String, ext: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not sub.begins_with("."):
			_find_files(dir_path.path_join(sub), ext, out)
	for file in dir.get_files():
		if file.ends_with(ext):
			out.append(dir_path.path_join(file))


## Landmark-tagged scatter (village buildings, the waiting oak...) and the
## wider court's authored landmarks: {id, label, x, z} each. Node landmarks (group "landmark") are
## found at runtime as their regions stream in.
static func scatter_landmarks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for layer in scatter_layers():
		if not layer.tags.has("landmark"):
			continue
		var inst: PackedFloat32Array = layer.instances
		var count := inst.size() / 5
		for k in count:
			var key := String(layer.id) if count == 1 else "%s:%d" % [layer.id, k]
			out.append({"id": key, "label": label_for(String(layer.id)),
				"x": snappedf(inst[k * 5], 0.1), "z": snappedf(inst[k * 5 + 2], 0.1)})
	for content in court_contents():
		for lm in content.landmarks:
			if lm.display_name == content.display_name:
				continue  # the region's own name: a place, not a landmark
			out.append({"id": "%s:%s" % [content.region_id, lm.id], "label": lm.display_name,
				"x": snappedf(lm.position.x, 0.1), "z": snappedf(lm.position.y, 0.1),
				"height": lm.height_m, "kind": String(lm.kind)})
	return out


## "barn_abandoned" -> "Barn abandoned"; "WaitingOak" -> "Waiting oak".
static func label_for(raw: String) -> String:
	var s := raw.get_slice(":", 0).to_snake_case().replace("_", " ").strip_edges()
	return s.substr(0, 1).to_upper() + s.substr(1)

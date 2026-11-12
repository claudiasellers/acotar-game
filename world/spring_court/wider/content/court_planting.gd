## Planting that follows the land (finish plan P2). A region's recipe names the
## landforms (CourtLandHabitats) that take over from its default habitat for
## trees: the wood thickens in the hollows, lines the banks and the road
## verges, leaves the hummocks open, stands one big tree on each knoll. The
## authored habitats (a copse, an orchard, the green) keep their own planting.
##
## It also holds the frame-time ceiling (T7): no grove is planted denser than
## CEILING. A habitat asked for more trees than its groves may hold spreads
## them over more of its ground instead (open_share).
class_name CourtPlanting
extends RefCounted

const LandscapeLayout := preload("res://world/spring_court/shared/landscape_layout.gd")
## Trees per m2 in a grove: about 80 per hectare held 16.6 ms on the Mac (T7).
const CEILING := 0.0080
## The landform grid's pitch (m): the ground's shape is read from heights
## cached on this grid (one height per cell, where CourtLandHabitats.form_at
## reads twenty a point); the bands by water and paths are read exactly.
const STEP := 8.0
const BANDS: Array[StringName] = [&"verge", &"brook_bank", &"river_bank", &"shore", &"water"]
## Knoll tops closer than this are one knoll.
const KNOLL_GAP := 45.0

static var _mutex := Mutex.new()
static var _grids := {}


## Hedgerows and bank-side lines are narrow, so a hectare in view never holds
## many: a band's own ground may be planted this much denser (a hedge bush
## every 5 m or so along each side of a road).
const BAND_CEILING := 0.05


static func ceiling(tag: StringName) -> float:
	var s := String(tag)
	for band in BANDS:
		if s.ends_with("@" + band):
			return BAND_CEILING
	return CEILING


## The share of a habitat's ground left open at a tree density (per m2):
## LandscapeLayout's, lowered until the groves are no denser than the ceiling.
static func open_share(density: float, tag: StringName = &"") -> float:
	return clampf(minf(LandscapeLayout.open_share(density), 1.0 - density / ceiling(tag)), 0.04, 0.78)


## A habitat's tree density (per m2) held to the ceiling.
static func capped(density: float, tag: StringName = &"") -> float:
	return minf(density, ceiling(tag) * 0.96)


## The habitat a tree at p grows in. On the region's default ground, the
## landform there if the recipe names it: "@<form>". On an authored habitat,
## "<habitat>@<form>" if the recipe names that. Else the authored habitat.
## &"" inside a bare disc.
static func tree_tag(content: CourtRegionContent, authored: StringName, p: Vector2) -> StringName:
	for b in content.bare:
		if Vector2(b.x, b.y).distance_to(p) < b.z:
			return &""
	if content.land.is_empty():
		return authored
	var prefix := "" if authored == content.default_habitat else String(authored)
	if prefix != "" and not _names_habitat(content, prefix):
		return authored
	var form := String(form_name(content, p))
	var key := prefix + "@" + form
	return StringName(key) if content.land.has(form if prefix == "" else key) else authored


static func _names_habitat(content: CourtRegionContent, tag: String) -> bool:
	for l in content.land:
		if l.begins_with(tag + "@"):
			return true
	return false


## The landform at p as the planting reads it: the bands by water and paths
## exactly (with `bands`, or where the recipe names one), else the ground's
## shape from the grid.
static func form_name(content: CourtRegionContent, p: Vector2, bands: bool = false) -> StringName:
	if bands or _names_a_band(content):
		var w := CourtLandHabitats._water_form(p.x, p.y, CourtHeight.height_at(p.x, p.y))
		if w >= 0:
			if bands or content.land.has(String(CourtLandHabitats.NAMES[w])):
				return CourtLandHabitats.NAMES[w]
		elif (bands or content.land.has("verge")) and CourtLandHabitats.path_distance(p.x, p.y) < CourtLandHabitats.VERGE_BAND:
			return &"verge"
	var g := grid(content)
	var r: Rect2 = g["rect"]
	var ix := clampi(floori((p.x - r.position.x) / STEP), 0, int(g["nx"]) - 1)
	var iz := clampi(floori((p.y - r.position.y) / STEP), 0, int(g["nz"]) - 1)
	return CourtLandHabitats.NAMES[(g["forms"] as PackedByteArray)[iz * int(g["nx"]) + ix]]


static func _names_a_band(content: CourtRegionContent) -> bool:
	for band in BANDS:
		for l in content.land:
			if l == String(band) or l.ends_with("@" + band):
				return true
	return false


## The region's landform grid, built once: { rect, nx, nz, forms }. Shapes
## only (FLOOR .. KNOLL), from a grid of heights with a margin for the rings.
static func grid(content: CourtRegionContent) -> Dictionary:
	_mutex.lock()
	var g: Dictionary = _grids.get(content.region_id, {})
	_mutex.unlock()
	if not g.is_empty():
		return g
	var r := content.bounding_rect()
	var nx := ceili(r.size.x / STEP)
	var nz := ceili(r.size.y / STEP)
	var m := ceili(CourtLandHabitats.WIDE_RING / STEP) + 1
	var w := nx + 2 * m
	var heights := PackedFloat32Array()
	heights.resize(w * (nz + 2 * m))
	for iz in nz + 2 * m:
		for ix in w:
			heights[iz * w + ix] = CourtHeight.height_at(r.position.x + (ix - m + 0.5) * STEP, r.position.y + (iz - m + 0.5) * STEP)
	# ring offsets in cells
	var near: Array[Vector2i] = []
	var far: Array[Vector2i] = []
	for k in 8:
		var a := TAU * float(k) / 8.0
		near.append(Vector2i(roundi(cos(a) * CourtLandHabitats.RING / STEP), roundi(sin(a) * CourtLandHabitats.RING / STEP)))
		a = TAU * (float(k) + 0.5) / 8.0
		far.append(Vector2i(roundi(cos(a) * CourtLandHabitats.WIDE_RING / STEP), roundi(sin(a) * CourtLandHabitats.WIDE_RING / STEP)))
	var forms := PackedByteArray()
	forms.resize(nx * nz)
	var ring := PackedFloat32Array()
	ring.resize(8)
	for iz in nz:
		for ix in nx:
			if not content.owns(Vector2(r.position.x + (ix + 0.5) * STEP, r.position.y + (iz + 0.5) * STEP)):
				continue
			var c := (iz + m) * w + ix + m
			for k in 8:
				ring[k] = heights[c + near[k].y * w + near[k].x]
			var dx := (heights[c + 1] - heights[c - 1]) / (2.0 * STEP)
			var dz := (heights[c + w] - heights[c - w]) / (2.0 * STEP)
			var wide := func() -> float:
				var sum := 0.0
				for o in far:
					sum += heights[c + o.y * w + o.x]
				return sum / 8.0
			forms[iz * nx + ix] = CourtLandHabitats.shape_of(heights[c], ring, rad_to_deg(atan(sqrt(dx * dx + dz * dz))), wide)
	g = {"rect": r, "nx": nx, "nz": nz, "forms": forms}
	_mutex.lock()
	_grids[content.region_id] = g
	_mutex.unlock()
	return g


## The top of every knoll on the region's default ground, highest first: from
## each knoll cell, uphill to the summit; summits within KNOLL_GAP are one.
static func knoll_tops(content: CourtRegionContent) -> PackedVector2Array:
	var g := grid(content)
	var r: Rect2 = g["rect"]
	var nx: int = g["nx"]
	var forms: PackedByteArray = g["forms"]
	var found: Array[Vector3] = []
	for i in forms.size():
		if forms[i] != CourtLandHabitats.Form.KNOLL:
			continue
		var p := Vector2(r.position.x + (i % nx + 0.5) * STEP, r.position.y + (i / nx + 0.5) * STEP)
		var h := CourtHeight.height_at(p.x, p.y)
		var stride := 6.0
		while stride > 0.7:
			var moved := false
			for k in 8:
				var q := p + Vector2.from_angle(TAU * k / 8.0) * stride
				var hq := CourtHeight.height_at(q.x, q.y)
				if hq > h + 0.01:
					p = q
					h = hq
					moved = true
			if not moved:
				stride *= 0.5
		found.append(Vector3(p.x, h, p.y))
	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	var out := PackedVector2Array()
	for f in found:
		var p := Vector2(f.x, f.z)
		var near := false
		for q in out:
			if q.distance_to(p) < KNOLL_GAP:
				near = true
				break
		if not near and content.owns(p) and content.habitat_at(p) == content.default_habitat:
			out.append(p)
	return out


## How the region's trees sit on the land, as the planting reads it
## (form_name with the bands): { trees, area_ha, per_ha,
## form_trees, form_ha, form_per_ha (by CourtLandHabitats.Form), kinds:
## { decor id: count }, densest_ha: the most trees in any 100 m square }.
static func report(content: CourtRegionContent, layers: Array[ScatterLayer] = [], step: float = STEP) -> Dictionary:
	if layers.is_empty():
		layers = tree_layers(content)
	var n := CourtLandHabitats.NAMES.size()
	var cells := PackedInt32Array()
	cells.resize(n)
	var r := content.bounding_rect()
	var x := r.position.x + step * 0.5
	while x < r.end.x:
		var z := r.position.y + step * 0.5
		while z < r.end.y:
			if content.owns(Vector2(x, z)):
				cells[CourtLandHabitats.NAMES.find(form_name(content, Vector2(x, z), true))] += 1
			z += step
		x += step
	var trees := PackedInt32Array()
	trees.resize(n)
	var kinds := {}
	var squares := {}
	var total := 0
	for layer in layers:
		var id := String(layer.id).substr(9)   # "decor_NN_<decor id>"
		kinds[id] = int(kinds.get(id, 0)) + layer.count()
		for i in layer.count():
			var p := layer.position_of(i)
			trees[CourtLandHabitats.NAMES.find(form_name(content, Vector2(p.x, p.z), true))] += 1
			var k := Vector2i(floori(p.x / 100.0), floori(p.z / 100.0))
			squares[k] = int(squares.get(k, 0)) + 1
			total += 1
	var form_ha: Array[float] = []
	var form_per_ha: Array[float] = []
	var area := 0.0
	for f in n:
		var ha := cells[f] * step * step / 10000.0
		area += ha
		form_ha.append(ha)
		form_per_ha.append(trees[f] / ha if ha > 0.05 else 0.0)
	var densest := 0
	for k: Vector2i in squares:
		densest = maxi(densest, squares[k])
	return {"trees": total, "area_ha": area, "per_ha": total / maxf(area, 0.01), "form_trees": trees,
		"form_ha": form_ha, "form_per_ha": form_per_ha, "kinds": kinds, "densest_ha": densest}


## The region's tree layers, one per tree entry, before they are split over builds.
static func tree_layers(content: CourtRegionContent) -> Array[ScatterLayer]:
	var trees := {}
	for di in content.decor.size():
		var e := content.decor[di]
		if e.is_tree:
			var layer := ScatterLayer.new()
			layer.id = StringName("decor_%02d_%s" % [di, e.mesh_id])
			trees[di] = layer
	var places := PlaceComposer.in_rect(PlaceComposer.table(), content.bounding_rect())
	CourtScatterGenerator._tree_layers(content, trees, places)
	var out: Array[ScatterLayer] = []
	out.assign(trees.values())
	return out

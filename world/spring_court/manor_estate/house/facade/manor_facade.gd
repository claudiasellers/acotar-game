## Dresses the manor's outer walls (L42, audit A8): ashlar stone, pilasters,
## plinth, string courses and crowning cornices, a surround on every outer
## window (arched below, pediments on the piano nobile, eared and shuttered
## above), balconies, climbing roses, ivy and wisteria, and window panes that
## glow warm at dusk.
##
## Canon (ch 6): "alabaster, veiled in roses and ivy, with patios and balconies
## and staircases sprouting from its alabaster sides". Roofline and storeys are
## canon:"X" (keeper: lilac slate, never emerald; the Archerons' ch28 chateau
## has emerald roofs).
##
## Everything is derived from the house layouts, so rooms, doors and windows
## stay where the layout puts them. ManorHouseBuilder records each outer
## window through note_window() while it cuts the walls; dress() then places
## the kit (tools/blender/manor_facade.py) as one MultiMesh per piece.
class_name ManorFacade
extends RefCounted

const MODEL_DIR := "res://world/spring_court/manor_estate/house/facade/models/"
const STONE_SHADER := preload("res://world/spring_court/manor_estate/house/facade/facade_stone.gdshader")
const SLATE_SHADER := preload("res://world/spring_court/manor_estate/house/facade/facade_slate.gdshader")
const WINDOW_SHADER := preload("res://world/spring_court/manor_estate/house/facade/facade_window.gdshader")
const VIEW_SHADER := preload("res://world/spring_court/manor_estate/house/facade/facade_view.gdshader")

const PIECES: Array[StringName] = [&"facade_pilaster", &"facade_string_course", &"facade_cornice",
	&"facade_plinth", &"facade_surround_arch", &"facade_surround_pediment", &"facade_surround_segment",
	&"facade_surround_simple", &"facade_shutters", &"facade_balcony", &"facade_climber_rose",
	&"facade_ivy", &"facade_wisteria", &"facade_inner_reveal"]

const KIT_STOREY := 4.8      # pilaster model height
const KIT_WIN_H := 2.6       # window opening the surrounds are modelled for
const TILE := 2.0            # course and cornice tile length
const BAY := 4.2             # pilaster rhythm on blank walls
const SAMPLE := 0.25         # wall sampling step when finding outer runs
const OUTSIDE := 0.8         # how far out a point is tested for "outside"
const STRING_DROP := 0.4     # string course foot below the next floor
const CORNICE_DROP := 0.9    # crowning cornice foot below the roof line
const MAX_ALBEDO := 0.85     # L18-4 glare rule

## L35's wisteria trellises under Feyre's window (garden face, z = -72):
## keep x 17-29 clear up to 6.1 m above the terrace; above it is ours.
const TRELLIS_X := Vector2(17.0, 29.0)
const TRELLIS_TOP := 6.1
const FEYRE_WINDOW_X := 23.0

static var _stone: ShaderMaterial
static var _window: ShaderMaterial
static var _view: ShaderMaterial
static var _glass: StandardMaterial3D
static var _slates: Dictionary = {}
static var _plan_cache: Dictionary = {}


# --- Materials ----------------------------------------------------------------

## The shared alabaster ashlar for wall skins and parapets.
static func stone() -> ShaderMaterial:
	if _stone == null:
		_stone = ShaderMaterial.new()
		_stone.shader = STONE_SHADER
		_stone.resource_name = "facade_stone"
		_stone.set_shader_parameter(&"rustic_top", ManorHouseBuilder.floor_y(1) - STRING_DROP)
	return _stone


## Lilac fish-scale slate for lilac/blue roofs; gilt and butter roofs keep a plain finish.
static func roof_material(color: Color) -> Material:
	if not (color.b > color.r and color.b > color.g):
		return EstateKit.mat(color, 0.35)
	var key := color.to_html(false)
	if not _slates.has(key):
		var m := ShaderMaterial.new()
		m.shader = SLATE_SHADER
		m.resource_name = "facade_slate"
		m.set_shader_parameter(&"slate", Color(minf(color.r, MAX_ALBEDO), minf(color.g, MAX_ALBEDO), minf(color.b, MAX_ALBEDO)))
		_slates[key] = m
	return _slates[key]


## Outer window panes (shared; ManorFacadeGlow drives `glow` from the clock).
static func window_material() -> ShaderMaterial:
	if _window == null:
		_window = ShaderMaterial.new()
		_window.shader = WINDOW_SHADER
		_window.resource_name = "facade_window"
	return _window


## The view out of every window, seen from inside (audit D2).
static func view_material() -> ShaderMaterial:
	if _view == null:
		_view = ShaderMaterial.new()
		_view.shader = VIEW_SHADER
		_view.resource_name = "facade_view"
	return _view


## Clear window glass with a faint sheen (was a flat light-blue sheet).
static func glass() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.resource_name = "facade_glass"
		_glass.albedo_color = Color(0.92, 0.95, 1.0, 0.08)
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.roughness = 0.04
		_glass.metallic_specular = 0.9
		_glass.rim_enabled = true
		_glass.rim = 0.25
	return _glass


# --- Windows, as the builder cuts them ------------------------------------------

## Called by ManorHouseBuilder._build_walls for each window it cuts in an outer
## wall. `edge` is the window centre on the room's rect edge, `outward` the
## unit normal pointing out of the house, `bottom`/`top` world heights.
static func note_window(room_node: Node3D, room: ManorRoomDef, edge: Vector2, outward: Vector2,
		width: float, bottom: float, top: float) -> void:
	var house := room_node.get_parent()
	if house == null:
		return
	var list: Array = house.get_meta(&"facade_windows", [])
	list.append({"at": edge, "out": outward, "width": width, "bottom": bottom, "top": top,
		"level": room.level, "room": room.id})
	house.set_meta(&"facade_windows", list)


# --- Dressing -------------------------------------------------------------------

## Adds the "Facade" node (one MultiMesh per kit piece, plus the window panes)
## under `house`. With `cache`, the placements are computed once per session.
static func dress(house: Node3D, all: ManorHouseIndex, cache: bool = false) -> Node3D:
	var windows: Array = house.get_meta(&"facade_windows", [])
	var plan: Dictionary
	if cache and _plan_cache.has("house"):
		plan = _plan_cache["house"]
	else:
		plan = placements(all, windows)
		if cache:
			_plan_cache["house"] = plan
	var root := Node3D.new()
	root.name = "Facade"
	house.add_child(root)
	for id: StringName in PIECES:
		var xforms: Array = plan.get(id, [])
		if xforms.is_empty():
			continue
		var meshes := PropModels.pair(MODEL_DIR + String(id) + ".glb", String(id))
		if meshes.is_empty():
			push_warning("ManorFacade: missing model %s" % id)
			continue
		root.add_child(_multimesh(String(id), meshes[0], xforms))
	var panes: Array = plan.get(&"panes", [])
	if not panes.is_empty():
		root.add_child(_pane_multimesh(panes, window_material(), "facade_panes"))
	var views: Array = plan.get(&"views", [])
	if not views.is_empty():
		root.add_child(_pane_multimesh(views, view_material(), "facade_views"))
	for r: Dictionary in step_ramps(all):
		root.add_child(_ramp_body(r))
	var glow := ManorFacadeGlow.new()
	glow.name = "Glow"
	glow.materials.append(window_material())
	glow.materials.append(view_material())
	root.add_child(glow)
	return root


static func _multimesh(id: String, mesh: Mesh, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = id
	mmi.multimesh = mm
	mmi.layers = EstateKit.WORLD_LAYER
	return mmi


static func _pane_multimesh(panes: Array, material: Material, id: String) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = panes.size()
	for i in panes.size():
		mm.set_instance_transform(i, panes[i][0])
		mm.set_instance_custom_data(i, Color(panes[i][1], panes[i][2], 0.0, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = id
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.layers = EstateKit.WORLD_LAYER
	return mmi


# --- Placement plan (pure: no nodes) --------------------------------------------

## Piece id -> Array[Transform3D], plus &"panes" -> [[Transform3D, seed], ...]
## and &"runs" -> the outer wall runs (for tests and reports).
static func placements(all: ManorHouseIndex, windows: Array) -> Dictionary:
	var plan := {}
	for id in PIECES:
		plan[id] = []
	plan[&"panes"] = []
	plan[&"views"] = []
	var runs := outer_runs(all)
	plan[&"runs"] = runs
	var keep_out := _exterior_prop_spots(all)
	for run: Dictionary in runs:
		_dress_run(plan, all, run, _windows_on(run, windows), _doors_on(run, all), keep_out)
	for w: Dictionary in windows:
		_dress_window(plan, w)
	return plan


## Outer wall runs per level: {level, a, b (on the rect edge), dir (a->b), out}.
## Collinear stretches from neighbouring rooms merge into one run.
static func outer_runs(all: ManorHouseIndex) -> Array:
	var lines := {}
	for level in range(0, 4):
		var rects := _rects_on(all, level)
		for room in all.interior_rooms():
			if not ManorHouseIndex.occupies(room, level):
				continue
			var r := room.rect
			var sides := [
				[Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Vector2(0, -1)],
				[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(0, 1)],
				[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y), Vector2(-1, 0)],
				[Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y), Vector2(1, 0)],
			]
			for s in sides:
				var a: Vector2 = s[0]
				var b: Vector2 = s[1]
				var out: Vector2 = s[2]
				var length := a.distance_to(b)
				var dir := (b - a) / length
				var steps := int(length / SAMPLE)
				var start := -1.0
				for i in steps + 1:
					var t := minf((i + 0.5) * SAMPLE, length)
					var outside := i < steps and not _inside(rects, a + dir * t + out * OUTSIDE)
					if outside and start < 0.0:
						start = i * SAMPLE
					elif not outside and start >= 0.0:
						var coord := a.y if out.y != 0.0 else a.x
						var key := "%d|%d|%d|%.2f" % [level, int(out.x), int(out.y), coord]
						var p0 := a + dir * start
						var p1 := a + dir * minf(i * SAMPLE, length)
						var along0 := p0.x if out.y != 0.0 else p0.y
						var along1 := p1.x if out.y != 0.0 else p1.y
						if not lines.has(key):
							lines[key] = {"level": level, "out": out, "coord": coord, "spans": []}
						lines[key].spans.append(Vector2(minf(along0, along1), maxf(along0, along1)))
						start = -1.0
	var runs: Array = []
	var keys := lines.keys()
	keys.sort()
	for key: String in keys:
		var line: Dictionary = lines[key]
		var level: int = line.level
		var out: Vector2 = line.out
		var coord: float = line.coord
		var spans: Array = line.spans
		spans.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var merged: Array = []
		for sp: Vector2 in spans:
			if not merged.is_empty() and sp.x <= (merged[-1] as Vector2).y + 0.3:
				merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, sp.y))
			else:
				merged.append(sp)
		for sp: Vector2 in merged:
			if sp.y - sp.x < 1.0:
				continue
			var a := Vector2(sp.x, coord) if out.y != 0.0 else Vector2(coord, sp.x)
			var b := Vector2(sp.y, coord) if out.y != 0.0 else Vector2(coord, sp.y)
			runs.append({"level": level, "a": a, "b": b, "dir": (b - a).normalized(), "out": out,
				"length": sp.y - sp.x})
	return runs


## Rects of every room filling `level` (double-height rooms count on both).
static func _rects_on(all: ManorHouseIndex, level: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in all.rooms:
		if ManorHouseIndex.occupies(r, level):
			out.append(r.rect)
	return out


static func _inside(rects: Array[Rect2], p: Vector2) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false


## Windows lying on a run, as distances along it (sorted).
static func _windows_on(run: Dictionary, windows: Array) -> Array:
	var out: Array = []
	for w: Dictionary in windows:
		if (w.out as Vector2) != (run.out as Vector2) or not _same_level(run, w):
			continue
		var d: Vector2 = (w.at as Vector2) - (run.a as Vector2)
		if absf(d.dot(run.out)) > 0.3:
			continue
		var along := d.dot(run.dir)
		if along > -0.5 and along < run.length + 0.5:
			out.append({"along": along, "w": w})
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.along < q.along)
	return out


static func _same_level(run: Dictionary, w: Dictionary) -> bool:
	return int(w.level) == int(run.level)


## Doors in a run's wall line, as [along, half_width, height].
static func _doors_on(run: Dictionary, all: ManorHouseIndex) -> Array:
	var out: Array = []
	for d in all.doors_on_level(run.level):
		var off: Vector2 = d.at - (run.a as Vector2)
		if absf(off.dot(run.out)) > ManorHouseBuilder.DOOR_TOLERANCE:
			continue
		var along := off.dot(run.dir)
		if along > -d.width and along < run.length + d.width:
			out.append([along, d.width * 0.5, d.height])
	return out


## World XZ of props already dressing the outside (portico garlands, urns,
## the gardens lane's tubs): climbers keep clear of them.
static func _exterior_prop_spots(all: ManorHouseIndex) -> Array:
	var out: Array = []
	for room in all.rooms:
		if room.kind != &"exterior":
			continue
		for p in room.props:
			out.append([room.rect.position + Vector2(p.position.x, p.position.z), p.prop_id])
	return out


static func _near_prop(spots: Array, p: Vector2, radius: float, ids: Array = []) -> bool:
	for s: Array in spots:
		if (s[0] as Vector2).distance_to(p) < radius and (ids.is_empty() or ids.has(s[1])):
			return true
	return false


## Outer face of the wall skin at a point on the rect edge.
static func _face(run: Dictionary, along: float) -> Vector2:
	return (run.a as Vector2) + (run.dir as Vector2) * along + (run.out as Vector2) * ManorHouseBuilder.SKIN


static func _basis(out: Vector2, sx: float = 1.0, sy: float = 1.0, sz: float = 1.0) -> Basis:
	var x := Vector3(out.y, 0.0, -out.x)
	var z := Vector3(out.x, 0.0, out.y)
	return Basis(x * sx, Vector3.UP * sy, z * sz)


static func _xf(run: Dictionary, along: float, y: float, proud: float = 0.0, sx: float = 1.0, sy: float = 1.0) -> Transform3D:
	var p := _face(run, along) + (run.out as Vector2) * proud
	return Transform3D(_basis(run.out, sx, sy), Vector3(p.x, y, p.y))


static func _hash(a: float, b: float, salt: int = 0) -> float:
	var h := hash(Vector3i(roundi(a * 10.0), roundi(b * 10.0), salt))
	return float(posmod(h, 10007)) / 10007.0


static func _in_trellis(run: Dictionary, along: float, y_top: float) -> bool:
	if (run.out as Vector2) != Vector2(0, -1):
		return false
	var x := _face(run, along).x
	return x > TRELLIS_X.x - 0.6 and x < TRELLIS_X.y + 0.6 \
			and y_top < ManorSitePlan.base_y() + TRELLIS_TOP + 0.2


static func _dress_run(plan: Dictionary, all: ManorHouseIndex, run: Dictionary, wins: Array, doors: Array,
		spots: Array) -> void:
	var level: int = run.level
	var y0 := ManorHouseBuilder.floor_y(level)
	var y1 := ManorHouseBuilder.floor_y(level + 1)
	var length: float = run.length
	var above := _rects_on(all, level + 1)
	var inside_up := func(along: float) -> bool:
		return _inside(above, (run.a as Vector2) + (run.dir as Vector2) * along - (run.out as Vector2) * OUTSIDE)
	# Plinth along the foot of the ground storey.
	if level == 0:
		_tiles(plan[&"facade_plinth"], run, ManorSitePlan.base_y() - 0.05, func(_a: float) -> bool: return true)
	# String course where a storey sits above, crowning cornice where the roof begins.
	_tiles(plan[&"facade_string_course"], run, y1 - STRING_DROP, func(a: float) -> bool: return inside_up.call(a))
	_tiles(plan[&"facade_cornice"], run, y1 - CORNICE_DROP, func(a: float) -> bool: return not inside_up.call(a))
	# Obstacles along the run: [from, to] (windows with surrounds, doors).
	var blocked: Array = []
	for w: Dictionary in wins:
		blocked.append(Vector2(w.along - 1.15, w.along + 1.15))
	for d: Array in doors:
		blocked.append(Vector2(d[0] - d[1] - 0.45, d[0] + d[1] + 0.45))
	# Pilasters: both ends, midway between neighbouring windows, and on long blank stretches.
	var spots_along: Array = [0.55, length - 0.55]
	for i in range(1, wins.size()):
		spots_along.append((wins[i - 1].along + wins[i].along) * 0.5)
	var gaps := _gaps(blocked, length)
	for g: Vector2 in gaps:
		var n := int((g.y - g.x) / BAY)
		for k in range(1, n + 1):
			spots_along.append(g.x + (g.y - g.x) * k / (n + 1))
	spots_along.sort()
	var pil: Array[float] = []
	for s: float in spots_along:
		if s < 0.4 or s > length - 0.4 or _hits(blocked, s, 0.57):
			continue
		if not pil.is_empty() and s - pil[-1] < 1.6:
			continue
		if _near_prop(spots, _face(run, s), 1.0, [&"pilaster"]):
			continue
		pil.append(s)
	for s in pil:
		var top := y1 - (STRING_DROP if inside_up.call(s) else CORNICE_DROP)
		plan[&"facade_pilaster"].append(_xf(run, s, y0, 0.0, 1.0, (top - y0) / KIT_STOREY))
		# Climbing roses veil about a third of the ground-floor pilasters; some climb on.
		var h := _hash(_face(run, s).x, _face(run, s).y, level)
		if level <= 1 and h < (0.5 if level == 0 else 0.3) and not _in_trellis(run, s, y0 + 4.6) \
				and not _near_prop(spots, _face(run, s), 1.2):
			var base := y0 - (0.2 if level == 0 else 0.4)
			plan[&"facade_climber_rose"].append(_xf(run, s, base, 0.12, 1.2 + 0.2 * h, (top - base) / 4.4))
	# Ivy on blank stretches (no window, door or pilaster).
	for p in pil:
		blocked.append(Vector2(p - 0.5, p + 0.5))
	for g: Vector2 in _gaps(blocked, length):
		var w := g.y - g.x
		var mid := (g.x + g.y) * 0.5
		if w < 1.6 or level > 1 or _hash(mid, run.a.y + run.a.x, 7 + level) > 0.7:
			continue
		if _in_trellis(run, mid, y0 + 3.6) or _near_prop(spots, _face(run, mid), 1.0):
			continue
		var base := y0 + (0.0 if level == 0 else -0.6)
		plan[&"facade_ivy"].append(_xf(run, mid, base, 0.04, minf(w - 0.2, 2.6) / 2.4, (y1 - STRING_DROP - base) / 3.4 * 0.95))
	# Wisteria swags under the garden cornice, and over L35's trellis tops to her window.
	if (run.out as Vector2) == Vector2(0, -1):
		var k := 1.6
		while k < length - 1.4:
			if not inside_up.call(k) and _hash(k, run.a.y, 11) < 0.7:
				plan[&"facade_wisteria"].append(_xf(run, k, y1 - CORNICE_DROP, 0.25))
			k += 3.2
		if level == 0:
			for x in [TRELLIS_X.x + 2.4, FEYRE_WINDOW_X, TRELLIS_X.y - 2.4]:
				var along: float = x - (run.a as Vector2).x
				if along > 1.0 and along < length - 1.0:
					plan[&"facade_wisteria"].append(_xf(run, along, ManorSitePlan.base_y() + TRELLIS_TOP + 0.95, 0.3))
	# Balconies: the drive front's piano nobile (every other window from the middle out).
	if level == 1 and (run.out as Vector2) == Vector2(0, 1):
		var mid_x := 0.0
		for w: Dictionary in wins:
			var x := _face(run, w.along).x
			var bay := roundi(absf(x - mid_x) / 4.2)
			if bay % 2 == 0:
				plan[&"facade_balcony"].append(_xf(run, w.along, y0, 0.0))
	# Two on the garden side, clear of her window and the trellis.
	if level == 1 and (run.out as Vector2) == Vector2(0, -1):
		for w: Dictionary in wins:
			var x := _face(run, w.along).x
			if absf(x) < 1.2 or (absf(x + FEYRE_WINDOW_X) < 1.2):
				plan[&"facade_balcony"].append(_xf(run, w.along, y0, 0.0))


## Course tiles along a run at height y where `want(along)` holds.
static func _tiles(list: Array, run: Dictionary, y: float, want: Callable) -> void:
	var length: float = run.length
	var n := maxi(1, ceili(length / TILE))
	var step := length / n
	for i in n:
		var c := (i + 0.5) * step
		if want.call(c):
			list.append(_xf(run, c, y, 0.0, step / TILE * 1.001, 1.0))


static func _gaps(blocked: Array, length: float) -> Array:
	var b := blocked.duplicate()
	b.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var out: Array = []
	var cur := 0.0
	for s: Vector2 in b:
		if s.x > cur:
			out.append(Vector2(cur, minf(s.x, length)))
		cur = maxf(cur, s.y)
	if cur < length:
		out.append(Vector2(cur, length))
	return out.filter(func(g: Vector2) -> bool: return g.y - g.x > 0.05)


static func _hits(blocked: Array, s: float, half: float) -> bool:
	for b: Vector2 in blocked:
		if s + half > b.x and s - half < b.y:
			return true
	return false


static func _dress_window(plan: Dictionary, w: Dictionary) -> void:
	var out: Vector2 = w.out
	var at: Vector2 = (w.at as Vector2) + out * ManorHouseBuilder.SKIN
	var bottom: float = w.bottom
	var top: float = w.top
	var sx: float = w.width / 1.5
	var sy := (top - bottom) / KIT_WIN_H
	var level: int = w.level
	var id := &"facade_surround_simple"
	if level == 0:
		id = &"facade_surround_arch"
	elif level == 1:
		var bay := roundi((at.x + at.y) / 4.2)
		id = &"facade_surround_pediment" if bay % 2 == 0 else &"facade_surround_segment"
	var basis := _basis(out, sx, sy)
	plan[id].append(Transform3D(basis, Vector3(at.x, bottom, at.y)))
	if level >= 2:
		plan[&"facade_shutters"].append(Transform3D(_basis(out, sx, sy), Vector3(at.x, bottom, at.y)))
	# The lit pane sits just outside the wall, inside the skin's reveal.
	var pane_at: Vector2 = (w.at as Vector2) + out * 0.02
	var pane := Transform3D(_basis(out, w.width, top - bottom), Vector3(pane_at.x, (bottom + top) * 0.5, pane_at.y))
	var seed := _hash(at.x, at.y, 3 + level)
	plan[&"panes"].append([pane, seed, level / 3.0])
	# Room side: lined reveal, sill, mullions, and the painted view behind the glass.
	var inner: Vector2 = (w.at as Vector2) - out * ManorHouseBuilder.WALL
	plan[&"facade_inner_reveal"].append(Transform3D(_basis(-out, sx, sy), Vector3(inner.x, bottom, inner.y)))
	var view_at: Vector2 = (w.at as Vector2) - out * 0.06
	var view := Transform3D(_basis(-out, w.width, top - bottom), Vector3(view_at.x, (bottom + top) * 0.5, view_at.y))
	plan[&"views"].append([view, seed, level / 3.0])


# --- Walk-in ramps over the outside steps (F39) ------------------------------------

const STEP_DEPTH := 3.0      # stone_steps catalogue size (4 x 1.8 x 3)
const STEP_WIDTH := 4.0
const STEP_HEIGHT := 1.8
const RAMP_THICK := 0.4

## One invisible ramp collider per outside flight of stone_steps, its surface
## laid along the step nosings, so a capsule walks up instead of catching on a
## riser (her capsule can't climb a 0.15 m edge: the contact is steeper than
## the 45 degree floor limit). The steps still draw; only the walking surface
## is smoothed. Each: {from: Vector3 (foot, on the ground), to: Vector3 (top
## nosing), x0, x1 (or z0, z1 for flights descending along x), axis}.
static func step_ramps(all: ManorHouseIndex) -> Array:
	var out: Array = []
	for room in all.rooms:
		if room.kind != &"exterior":
			continue
		var steps: Array = []
		for p in room.props:
			if p.prop_id != &"stone_steps":
				continue
			var along_x := absf(sin(deg_to_rad(p.yaw_deg))) > 0.5
			steps.append({"x": room.rect.position.x + p.position.x, "z": room.rect.position.y + p.position.z,
				"top": ManorHouseBuilder.floor_y(room.level) + p.position.y + STEP_HEIGHT, "ax": along_x})
		for flight: Array in _flights(steps):
			var r := _ramp(flight)
			if not r.is_empty():
				out.append(r)
	return out


static func _flights(steps: Array) -> Array:
	var groups: Array = []
	var seen := {}
	for i in steps.size():
		if seen.has(i):
			continue
		var group: Array = [steps[i]]
		seen[i] = true
		var k := 0
		while k < group.size():
			for j in steps.size():
				if not seen.has(j) and absf(steps[j].x - group[k].x) <= STEP_WIDTH + 0.1 \
						and absf(steps[j].z - group[k].z) <= STEP_WIDTH + 0.1 and steps[j].ax == group[k].ax:
					seen[j] = true
					group.append(steps[j])
			k += 1
		groups.append(group)
	return groups


static func _ramp(flight: Array) -> Dictionary:
	var tops: Array = []
	for s: Dictionary in flight:
		var t := snappedf(s.top, 0.01)
		if not tops.has(t):
			tops.append(t)
	tops.sort()
	if tops.size() < 2:
		return {}
	var along_x: bool = flight[0].ax
	var key := "x" if along_x else "z"
	var side := "z" if along_x else "x"
	var low: float = tops[0]
	var high: float = tops[-1]
	# Descent direction: from the high steps toward the low ones.
	var mean := func(t: float) -> float:
		var sum := 0.0
		var n := 0
		for s: Dictionary in flight:
			if absf(s.top - t) < 0.02:
				sum += s[key]
				n += 1
		return sum / n
	var dir := signf(mean.call(low) - mean.call(high))
	var edge := func(t: float) -> float:   # outermost nosing of the steps at top t
		var best := -INF
		for s: Dictionary in flight:
			if absf(s.top - t) < 0.02:
				best = maxf(best, dir * (s[key] + dir * STEP_DEPTH * 0.5))
		return best * dir
	var e_low: float = edge.call(low)
	var e_next: float = edge.call(tops[1])
	var riser: float = tops[1] - low
	var run := absf(e_low - e_next)
	var foot := e_low + dir * run          # one run out, on the ground
	var ground := low - riser
	var e_high: float = edge.call(high)
	var lo := INF
	var hi := -INF
	for s: Dictionary in flight:
		lo = minf(lo, s[side] - STEP_WIDTH * 0.5)
		hi = maxf(hi, s[side] + STEP_WIDTH * 0.5)
	var a := Vector3(0, ground, 0)
	var b := Vector3(0, high, 0)
	var mid_side := (lo + hi) * 0.5
	if along_x:
		a.x = foot; b.x = e_high; a.z = mid_side; b.z = mid_side
	else:
		a.z = foot; b.z = e_high; a.x = mid_side; b.x = mid_side
	return {"from": a, "to": b, "width": hi - lo - 0.1, "along_x": along_x}


static func _ramp_body(r: Dictionary) -> StaticBody3D:
	var a: Vector3 = r.from
	var b: Vector3 = r.to
	var along := (b - a).normalized()
	var side := Vector3(0, 0, 1) if r.along_x else Vector3(1, 0, 0)
	var normal := along.cross(side)
	if normal.y < 0.0:
		side = -side
		normal = -normal
	# Extend 0.4 m past the foot (buried) and 0.1 m onto the landing.
	var start := a - along * 0.4
	var end := b + along * 0.1
	var length := start.distance_to(end)
	var shape := BoxShape3D.new()
	shape.size = Vector3(r.width, RAMP_THICK, length)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	var body := StaticBody3D.new()
	body.name = "StepRamp"
	body.collision_layer = EstateKit.WORLD_LAYER
	body.collision_mask = 0
	var centre := (start + end) * 0.5 - normal * (RAMP_THICK * 0.5 - 0.01)
	body.transform = Transform3D(Basis(side, normal, along), centre)
	body.add_child(cs)
	return body

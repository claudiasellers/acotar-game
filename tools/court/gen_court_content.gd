## Generates the wider court's committed data from CourtContentTable and CourtMap:
##   data/regions/spring_court/content/<id>.tres   CourtRegionContent
##   data/regions/spring_court/<id>.tres           RegionDef (streaming)
##   world/spring_court/<id>/<id>.tscn             region scene (CourtRegion root)
##   world/spring_court/<id>/<id>_report.json      coverage report (R1, world smoke)
##   world/shared/terrain/height_providers.tres    our HeightProviders (ids court_*)
##
##   godot --headless --path . -s tools/court/gen_court_content.gd [-- --no-report]
extends SceneTree

const CONTENT_DIR := "res://data/regions/spring_court/content"
const DEF_DIR := "res://data/regions/spring_court"
const PROVIDERS := "res://world/shared/terrain/height_providers.tres"
const HEIGHT_SCRIPT := "res://world/spring_court/wider/court_height.gd"
const REGION_SCRIPT := "res://world/spring_court/wider/court_region.gd"
const COMMON_DECOR := ["flora_grass_clump_a||2.2|", "flora_grass_clump_b||1.6|", "flora_grass_clump_c||1.0|", "rock_mossy_a||0.03|s w0", "rock_pebble_cluster||0.08|w0"]

## Height providers: CourtHeight.DOMAIN, the map north of the Wall minus every
## other lane's ground, registered with fade 0 (CourtHeight blends to
## MacroHeight at other lanes' edges itself, so our own seams never dip).
const PROVIDER_IDS := [
	&"court_west", &"court_glen_east", &"court_foot_east", &"court_estate_west", &"court_north",
	&"court_north_east", &"court_east_rim", &"court_vale", &"court_vale_corner",
]


## The models are laid back onto the rebuilt terrain (CourtHeight): each
## landmark stands on the ground shaped for it (CourtHeight.SITES, same id),
## the habitats round it move with it, and the water habitats sit on the
## lakes. Waterfalls keep their crest on the lip and land in the water:
## id -> offsets (first offset = where the water lands).
const FALL_OFFSETS := {
	&"glimmerfall": [Vector2(56.0, 0.0)],
	&"rainbow_cascade": [Vector2(-46.0, 0.0)],
}
## Water habitat tags snapped to the nearest CourtHeight lake.
const WATER_TAGS := [&"looking_lake", &"willow_mere", &"starlight_pool", &"lakeshore", &"pool_rim"]


func _initialize() -> void:
	var with_report := not OS.get_cmdline_user_args().has("--no-report")
	DirAccess.make_dir_recursive_absolute(CONTENT_DIR)
	_write_providers()
	WorldHeight.set_providers(null)
	var table := CourtContentTable.regions()
	for id: StringName in table:
		var content := _content(id, table[id])
		_save(content, "%s/%s.tres" % [CONTENT_DIR, id])
		_write_scene(id, content)
		_save(_region_def(id, content), "%s/%s.tres" % [DEF_DIR, id])
		if with_report:
			var forage := CourtScatterGenerator.forage_layers(content)
			var decor := CourtScatterGenerator.decor_layers(content)
			var report := CourtScatterGenerator.report(content, forage, decor)
			ScatterReport.save(report, _report_path(id))
			print("%s: %d types, %d placements (%d/km²), %d/%d empty cells, %d landmarks, %d draw calls, %d decor" % [
				id, report["types"], report["placements"], report["placements_per_km2"], report["empty_cells"],
				report["cells"], report["landmarks"], report["draw_calls"], report["decor_instances"]])
	quit(0)


func _content(id: StringName, d: Dictionary) -> CourtRegionContent:
	var c := CourtRegionContent.new()
	c.region_id = id
	c.display_name = d["name"]
	c.canon = d.get("canon", "X")
	c.seed = d["seed"]
	c.bounds = CourtMap.rects(id)
	c.holes = CourtMap.holes_for(id)
	c.skirts = CourtMap.skirts(id)
	c.default_habitat = d["default"]
	c.grade = d.get("grade", &"spring")
	c.ambient_fx = PackedStringArray(d.get("fx", []))
	c.blight = d.get("blight", 0.0)
	c.sealed = d.get("sealed", false)
	c.notes = d.get("notes", "")
	var moved := {}
	for l: Array in d["landmarks"]:
		if CourtHeight.SITES.has(StringName(l[0])):
			moved[Vector2(l[2], l[3])] = CourtHeight.site(StringName(l[0])) - Vector2(l[2], l[3])
	for h: Array in d["habitats"]:
		c.habitats.append(_reseat_habitat(_habitat(h), moved))
	for spec: String in d["forage"]:
		c.forage.append(_forage(spec))
	var decor_specs: Array = d["decor"].duplicate()
	if id != &"blighted_reaches":
		decor_specs = COMMON_DECOR + decor_specs
	for spec: String in decor_specs:
		c.decor.append(_decor(spec, c))
	for a: Array in d.get("anchors", []):
		c.anchors.append({"id": StringName(a[0]), "position": Vector2(a[1], a[2]), "yaw_degrees": a[3], "clear_radius": a[4]})
	for g: Array in d.get("gates", []):
		c.gates.append({"region_id": StringName(g[0]), "position": Vector2(g[1], g[2]), "width": g[3], "yaw_degrees": g[4]})
	# The terrain's own gates on the ways out, locked until the CourtMap phase
	# of the region they lead into.
	for g in CourtHeight.gates_for(id):
		c.gates.append({"region_id": CourtMap.gate_lock(g["target"]), "position": g["position"], "width": g["width"], "yaw_degrees": g["yaw_degrees"]})
	for l: Array in d["landmarks"]:
		c.landmarks.append(_landmark(l))
	return c


## A habitat centred on a landmark that moved moves with it; lake habitats
## sit on the nearest lake (water exactly on it, its shore ringing it).
func _reseat_habitat(hab: CourtHabitat, moved: Dictionary) -> CourtHabitat:
	if hab.shape != CourtHabitat.Shape.CIRCLE and hab.shape != CourtHabitat.Shape.RING:
		return hab
	if hab.tag in WATER_TAGS:
		var best: Dictionary = {}
		for lake in CourtHeight.lakes():
			if best.is_empty() or hab.center.distance_to(lake["center"]) < hab.center.distance_to(best["center"]):
				best = lake
		if not best.is_empty() and hab.center.distance_to(best["center"]) < 120.0:
			var r: float = best["radius"]
			hab.center = best["center"]
			if hab.shape == CourtHabitat.Shape.CIRCLE:
				hab.radius = r
			elif hab.tag == &"pool_rim":
				hab.inner_radius = r
				hab.radius = r + 24.0
			else:
				hab.inner_radius = r
				hab.radius = r * 1.4
		return hab
	for old: Vector2 in moved:
		if hab.center.distance_to(old) < 30.0:
			hab.center += moved[old]
			break
	return hab


func _habitat(h: Array) -> CourtHabitat:
	var hab := CourtHabitat.new()
	hab.tag = StringName(h[0])
	hab.priority = h[6]
	hab.exclusive = h[7]
	match h[1]:
		"circle":
			hab.shape = CourtHabitat.Shape.CIRCLE
			hab.center = Vector2(h[2], h[3])
			hab.radius = h[4]
		"ring":
			hab.shape = CourtHabitat.Shape.RING
			hab.center = Vector2(h[2], h[3])
			hab.radius = h[4]
			hab.inner_radius = h[5]
		"rect":
			hab.shape = CourtHabitat.Shape.RECT
			hab.rect = Rect2(h[2], h[3], h[4] - h[2], h[5] - h[3])
		"river":
			hab.shape = CourtHabitat.Shape.RIVER_BAND
			hab.band_min = h[5]
			hab.band_max = h[4]
	return hab


func _forage(spec: String) -> CourtForageEntry:
	var f := spec.split("|")
	var e := CourtForageEntry.new()
	e.item_id = StringName(f[0])
	e.habitats = PackedStringArray(f[1].split(",", false))
	e.weight = float(f[2])
	var cl := f[3].split("-")
	e.cluster_min = int(cl[0])
	e.cluster_max = int(cl[1])
	var flags := f[4] if f.size() > 4 else ""
	e.collectible = flags.contains("c")
	e.night_only = flags.contains("n")
	e.canon = "C?" if flags.contains("?") else ("C" if flags.contains("C") else "X")
	if e.collectible:
		e.cluster_radius = 1.5
	return e


func _decor(spec: String, c: CourtRegionContent) -> CourtDecorEntry:
	var f := spec.split("|")
	var e := CourtDecorEntry.new()
	e.mesh_id = StringName(f[0])
	e.habitats = PackedStringArray(f[1].split(",", false))
	if e.habitats.is_empty():
		# Common decor grows on every non-exclusive habitat of the region.
		e.habitats.append(String(c.default_habitat))
		for h in c.habitats:
			if not h.exclusive and not e.habitats.has(String(h.tag)):
				e.habitats.append(String(h.tag))
	e.density = float(f[2])
	var flags := f[3] if f.size() > 3 else ""
	e.is_tree = flags.contains("t")
	e.cast_shadow = flags.contains("s")
	e.wind = 0.0 if flags.contains("w0") else (0.25 if e.is_tree else 0.6)
	if e.is_tree:
		e.scale_min = 0.8
		e.scale_max = 1.3
		e.max_slope = 30.0
	return e


func _landmark(l: Array) -> CourtLandmark:
	var m := CourtLandmark.new()
	m.id = StringName(l[0])
	m.display_name = l[1]
	m.position = Vector2(l[2], l[3])
	if CourtHeight.SITES.has(m.id):
		m.position = CourtHeight.site(m.id)
	m.height_m = l[4]
	m.kind = StringName(l[5])
	m.asset_ids = PackedStringArray(String(l[6]).split(",", false))
	m.canon = l[7]
	m.notes = l[8]
	if l.size() > 9:
		for pair: String in String(l[9]).split(";", false):
			var xz := pair.split(":")
			m.offsets.append(Vector2(float(xz[0]), float(xz[1])))
	if FALL_OFFSETS.has(m.id):
		var fo: Array = FALL_OFFSETS[m.id]
		for i in fo.size():
			if i < m.offsets.size():
				m.offsets[i] = fo[i]
			else:
				m.offsets.append(fo[i])
	if m.id == &"rainbow_cascade":
		m.position.x = CourtHeight.west_lip_x(m.position.y) + 1.5
	# Recognisable from this far: tall things and things on hills (R1 wants >= 200 m).
	m.visible_from_m = maxf(200.0, m.height_m * 25.0)
	return m


func _region_def(id: StringName, c: CourtRegionContent) -> RegionDef:
	var def := RegionDef.new()
	def.id = id
	def.scene_path = "res://world/spring_court/%s/%s.tscn" % [id, id]
	var r := c.bounding_rect()
	var centre := r.get_center()
	def.center = Vector3(centre.x, WorldHeight.height_at(centre.x, centre.y), centre.y)
	def.radius = r.size.length() * 0.5
	def.report_path = _report_path(id)
	var neighbors := PackedStringArray()
	for other in CourtMap.region_ids():
		if other == id:
			continue
		var touching := false
		for a in CourtMap.rects(id):
			for b in CourtMap.rects(other):
				if a.grow(1.0).intersects(b):
					touching = true
		if touching:
			neighbors.append(String(other))
	def.neighbors = neighbors
	return def


func _write_scene(id: StringName, c: CourtRegionContent) -> void:
	var dir := "res://world/spring_court/%s" % id
	DirAccess.make_dir_recursive_absolute(dir)
	var root := Node3D.new()
	root.name = String(id).to_pascal_case()
	root.set_script(load(REGION_SCRIPT))
	root.set("content", load("%s/%s.tres" % [CONTENT_DIR, id]))
	var packed := PackedScene.new()
	packed.pack(root)
	_save(packed, "%s/%s.tscn" % [dir, id])
	root.free()


func _write_providers() -> void:
	var set_res := load(PROVIDERS)
	var kept: Array[HeightProvider] = []
	for p: HeightProvider in set_res.providers:
		if not String(p.id).begins_with("court_"):
			kept.append(p)
	var script := load(HEIGHT_SCRIPT)
	var rects := CourtHeight.domain_rects()
	for i in rects.size():
		var p := HeightProvider.new()
		p.id = PROVIDER_IDS[i]
		p.bounds = rects[i]
		p.fade = 0.0
		p.height_script = script
		p.priority = 10
		kept.append(p)
	set_res.providers = kept
	_save(set_res, PROVIDERS)


func _report_path(id: StringName) -> String:
	return "res://world/spring_court/%s/%s_report.json" % [id, id]


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("gen_court_content: cannot save %s (%d)" % [path, err])

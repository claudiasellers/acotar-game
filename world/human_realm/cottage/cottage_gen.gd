## Generator for the `cottage` region: the Archeron cottage (exterior, yard,
## enterable interior), Elain's garden, and the frozen fields south of it
## (HumanRealmLayout.COTTAGE_FIELDS). Deterministic (seeded). Writes
##   world/human_realm/cottage/scatter/*.tres   ScatterLayers
##   world/human_realm/cottage/cottage_report.json
##   world/human_realm/cottage/cottage.tscn
##
##   godot --headless -s res://world/human_realm/cottage/cottage_gen.gd
##
## Meshes come from tools/blender/human_realm/cottage_*.py (cottage assets) and
## the shared flora library (world/human_realm/shared/assets/flora/).
extends SceneTree

const Builder := preload("res://world/human_realm/cottage/region_builder.gd")
const DIR := "res://world/human_realm/cottage/"
const A := DIR + "assets/"
const AI := DIR + "assets/interior/"
const AS := DIR + "assets/small/"
const SEED := 0xC077A6E

## Field features (world x, z).
const POND := Vector2(-280.0, 2360.0)
const POND_R := 15.0
const SCARECROW := Vector2(-130.0, 2362.0)
const HUT := Vector2(-300.0, 2478.0)
const FIELD_OAKS := [Vector2(-40.0, 2330.0), Vector2(-330.0, 2318.0), Vector2(20.0, 2470.0), Vector2(-190.0, 2440.0)]

## Hedgerows and dry-stone walls dividing the fields (world x, z).
static var HEDGES: Array = [
	PackedVector2Array([Vector2(-348.0, 2302.0), Vector2(-200.0, 2304.0), Vector2(-60.0, 2300.0), Vector2(48.0, 2303.0)]),
	PackedVector2Array([Vector2(-120.0, 2412.0), Vector2(-118.0, 2498.0)]),
	PackedVector2Array([Vector2(-348.0, 2196.0), Vector2(-292.0, 2250.0), Vector2(-240.0, 2296.0)]),
	PackedVector2Array([Vector2(-10.0, 2232.0), Vector2(20.0, 2262.0), Vector2(48.0, 2290.0)]),
	PackedVector2Array([Vector2(-60.0, 2120.0), Vector2(-20.0, 2150.0), Vector2(30.0, 2170.0)]),
]
static var WALLS: Array = [
	PackedVector2Array([Vector2(-346.0, 2410.0), Vector2(46.0, 2410.0)]),
	PackedVector2Array([Vector2(-210.0, 2308.0), Vector2(-210.0, 2498.0)]),
	PackedVector2Array([Vector2(-60.0, 2308.0), Vector2(-60.0, 2408.0)]),
	PackedVector2Array([Vector2(-346.0, 2455.0), Vector2(-212.0, 2455.0)]),
	PackedVector2Array([Vector2(46.0, 2310.0), Vector2(46.0, 2498.0)]),
]

var b: Builder


func _initialize() -> void:
	var rects: Array[Rect2] = [HumanRealmLayout.REGION_RECTS[&"cottage"], HumanRealmLayout.COTTAGE_FIELDS]
	b = Builder.new(&"cottage", rects, SEED)
	_reserve()
	_layers()
	var added := b.cover_empty([&"ing_flint", &"ing_crow_feather", &"fox_tracks", &"ing_snail_shell"])
	b.save_layers(DIR + "scatter")
	var root := _build_scene()
	var meshes := Builder.count_meshes(root)
	var draw_calls := b.estimate_draw_calls(meshes)
	var report := ScatterReport.compute(b.layers, b.area, landmark_count(), draw_calls)
	ScatterReport.save(report, DIR + "cottage_report.json")
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, DIR + "cottage.tscn")
	# Neighbours that exist on this branch; the world lane adds hunting_forest
	# and village at integration.
	b.save_region_def(DIR + "cottage.tscn", DIR + "cottage_report.json", PackedStringArray(["workshop", "hunting_forest", "village"]))
	var total := 0
	for l in b.layers:
		total += l.count()
	print("cottage: %d layers, %d instances (%d cover fill), report %s" % [b.layers.size(), total, added, JSON.stringify(report)])
	root.free()
	quit()


static func landmark_count() -> int:
	return LANDMARKS.size()


## Named landmark nodes in the scene (counted in the report).
const LANDMARKS := ["ArcheronCottage", "ElainGarden", "FrozenPond", "Scarecrow", "ShepherdHutRuin", "Outhouse"]


func _reserve() -> void:
	b.reserve(HumanRealmLayout.COTTAGE, 12.0)
	b.reserve(HumanRealmLayout.ELAIN_GARDEN, 4.5)
	b.reserve(POND, POND_R + 1.0)
	b.reserve(SCARECROW, 2.0)
	b.reserve(HUT, 5.0)
	b.reserve(_cottage_world(Vector3(9.0, 0, 11.0)), 2.0)  # outhouse


# --- Zones (weights 0..1) ----------------------------------------------------------

static func forest_edge(p: Vector2) -> float:
	var w := clampf((2150.0 - p.y) / 70.0, 0.0, 1.0)
	return maxf(w, clampf((-290.0 - p.x) / 50.0, 0.0, 1.0) * clampf((2300.0 - p.y) / 100.0, 0.0, 1.0))


static func commons(p: Vector2) -> float:
	return 1.0 if p.y >= 2110.0 and p.y < 2300.0 else 0.0


static func fields(p: Vector2) -> float:
	return 1.0 if p.y >= 2300.0 else 0.0


static func hedge(p: Vector2) -> float:
	return 1.0 if Builder.dist_lines(p, HEDGES) < 3.5 else 0.0


static func walls(p: Vector2) -> float:
	return 1.0 if Builder.dist_lines(p, WALLS) < 2.5 else 0.0


static func pond_edge(p: Vector2) -> float:
	var d := p.distance_to(POND)
	return 1.0 if d > POND_R - 1.0 and d < POND_R + 10.0 else 0.0


static func yard(p: Vector2) -> float:
	return 1.0 if p.distance_to(HumanRealmLayout.COTTAGE) < 45.0 else 0.0


static func anywhere(_p: Vector2) -> float:
	return 1.0


static func any_of(fns: Array) -> Callable:
	return func(p: Vector2) -> float:
		var w := 0.0
		for f: Callable in fns:
			w = maxf(w, f.call(p))
		return w


func _layers() -> void:
	var fe := Callable(self, "forest_edge")
	var cm := Callable(self, "commons")
	var fd := Callable(self, "fields")
	var hg := Callable(self, "hedge")
	var wl := Callable(self, "walls")
	var pe := Callable(self, "pond_edge")
	var yd := Callable(self, "yard")
	var aw := Callable(self, "anywhere")
	var along_hedges := Builder.along(HEDGES, 2.5)
	var along_walls := Builder.along(WALLS, 1.6)
	var pond_ring := Builder.near(POND, POND_R + 7.0, POND_R + 0.5)
	var trunk := {"type": "trunk", "r": 0.35, "h": 5.0}

	# --- Trees and large decoration (not counted) ---
	b.add_layer({id = "tree_oak_bare", mesh = "tree_oak_bare", count = 40, zone = fe, scale = [0.9, 1.3], wind = 0.15, draw = 160.0, far = true, spacing = 9.0, clearance = 3.0, collider = {"type": "trunk", "r": 0.5, "h": 5.0}})
	b.add_layer({id = "tree_birch", mesh = "tree_birch", count = 45, zone = fe, scale = [0.8, 1.2], wind = 0.3, draw = 160.0, far = true, spacing = 5.0, clearance = 2.5, collider = {"type": "trunk", "r": 0.2, "h": 5.0}})
	b.add_layer({id = "tree_pine", mesh = "tree_pine", count = 55, zone = fe, scale = [0.8, 1.3], wind = 0.15, draw = 160.0, far = true, spacing = 6.0, clearance = 2.5, collider = trunk})
	b.add_layer({id = "tree_spruce", mesh = "tree_spruce", count = 45, zone = fe, scale = [0.8, 1.3], wind = 0.15, draw = 160.0, far = true, spacing = 6.0, clearance = 2.5, collider = trunk})
	b.add_layer({id = "tree_dead_snag", mesh = "tree_dead_snag", count = 12, zone = any_of([fe, hg]), scale = [0.8, 1.1], draw = 160.0, far = true, spacing = 10.0, clearance = 2.5, collider = {"type": "trunk", "r": 0.3, "h": 4.0}})
	b.add_layer({id = "tree_willow_pollard", mesh = "tree_willow_pollard", count = 9, sampler = Builder.near(POND, POND_R + 9.0, POND_R + 3.0), allow_reserved = true, scale = [0.9, 1.2], wind = 0.2, draw = 160.0, far = true, spacing = 6.0, clearance = 1.5, collider = {"type": "trunk", "r": 0.45, "h": 3.0}})
	var oaks := b.add_layer({id = "tree_field_oak", mesh = "tree_oak_bare", count = 0, scale = [1.2, 1.5], draw = 200.0, far = true, collider = {"type": "trunk", "r": 0.6, "h": 6.0}})
	for p: Vector2 in FIELD_OAKS:
		if b.free_at(p, 2.0):
			b.place(oaks, p, b.specs[oaks.id])
	for sp in [["hedge_hawthorn", "hawthorn"], ["hedge_blackthorn", "blackthorn_sloe"], ["hedge_hazel", "hazel_shrub"], ["hedge_holly", "holly_bush"]]:
		b.add_layer({id = sp[0], mesh = sp[1], count = 110, sampler = along_hedges, scale = [0.9, 1.4], wind = 0.25, clearance = 1.0})
	b.add_layer({id = "winter_grass_tuft", mesh = "winter_grass_tuft", count = 600, zone = any_of([cm, fd]), scale = [0.7, 1.3], wind = 0.6, draw = 70.0, shadow = false})
	b.add_layer({id = "dead_bracken", mesh = "dead_bracken", count = 260, zone = any_of([fe, hg]), scale = [0.8, 1.3], wind = 0.4, draw = 80.0, shadow = false})
	b.add_layer({id = "snow_mound", mesh = "snow_mound", count = 160, zone = aw, scale = [0.8, 2.0], draw = 120.0, shadow = false})
	b.add_layer({id = "rock_boulder_a", mesh = "rock_boulder_a", count = 14, zone = any_of([fe, fd]), scale = [0.8, 1.4], spacing = 8.0, clearance = 1.5, collider = {"type": "sphere", "r": 0.9}})
	b.add_layer({id = "rock_boulder_b", mesh = "rock_boulder_b", count = 12, zone = any_of([fe, cm]), scale = [0.8, 1.4], spacing = 8.0, clearance = 1.5, collider = {"type": "sphere", "r": 0.9}})
	b.add_layer({id = "rock_boulder_c", mesh = "rock_boulder_c", count = 10, zone = fd, scale = [0.7, 1.2], spacing = 8.0, clearance = 1.5, collider = {"type": "sphere", "r": 0.8}})
	b.add_layer({id = "rock_flat", mesh = "rock_flat", count = 30, zone = aw, scale = [0.7, 1.3]})
	b.add_layer({id = "log_fallen", mesh = "log_fallen", count = 16, zone = fe, scale = [0.8, 1.2], spacing = 6.0, clearance = 2.0})
	b.add_layer({id = "stump", mesh = "stump", count = 24, zone = any_of([fe, yd]), scale = [0.8, 1.2]})
	var wall := b.add_layer({id = "drystone_wall", mesh = A + "drystone_wall.glb", count = 0, collider = {"type": "box", "size": Vector3(4.0, 1.0, 0.6)}})
	b.tile_along(wall, WALLS, 4.0, b.specs[wall.id])

	# --- Forage (one layer per ingredient; ids are the ingredient ids) ---
	var forage := [
		# [ingredient, mesh, count, zone/sampler, scale, canon]
		["ing_snowdrop", "snowdrop_cluster", 70, {zone = any_of([hg, yd, fe])}, [0.8, 1.2]],
		["ing_blackberry", "blackberry_bramble", 45, {zone = any_of([hg, fe])}, [0.8, 1.3]],
		["ing_pine_resin", "pine_resin_blob", 30, {zone = fe}, [0.9, 1.2]],
		["ing_willow_bark", "willow_withies", 22, {sampler = pond_ring}, [0.9, 1.3]],
		["ing_oak_gall", "oak_gall_twig", 30, {zone = fe}, [0.9, 1.2]],
		["ing_woad", "woad_rosette", 40, {zone = any_of([fd, cm])}, [0.8, 1.2]],
		["ing_madder", "madder_patch", 35, {zone = any_of([fd, hg])}, [0.8, 1.2]],
		["ing_rose_hip", "wild_rose_briar", 40, {sampler = along_hedges}, [0.8, 1.2]],
		["ing_holly_berry", "holly_bush", 35, {zone = any_of([hg, fe])}, [0.7, 1.0]],
		["ing_juniper_berry", "juniper_shrub", 35, {zone = any_of([fe, cm])}, [0.8, 1.2]],
		["ing_sloe", "blackthorn_sloe", 35, {sampler = along_hedges}, [0.7, 1.0]],
		["ing_hawthorn_haw", "hawthorn", 35, {sampler = along_hedges}, [0.7, 1.0]],
		["ing_birch_bark", "log_fallen", 22, {zone = fe}, [0.5, 0.7]],
		["ing_chaga", "chaga_growth", 22, {zone = fe}, [0.9, 1.2]],
		["ing_tinder_fungus", "tinder_fungus", 26, {zone = fe}, [0.9, 1.2]],
		["ing_old_mans_beard", "old_mans_beard", 30, {zone = any_of([fe, hg])}, [0.9, 1.2]],
		["ing_acorn", "acorn_scatter", 40, {zone = fe}, [0.9, 1.2]],
		["ing_hazelnut", "hazelnut_scatter", 35, {sampler = along_hedges}, [0.9, 1.2]],
		["ing_pine_needles", "pine_cone_scatter", 40, {zone = fe}, [0.9, 1.2]],
		["ing_frozen_reed", "frozen_reeds", 40, {sampler = pond_ring}, [0.9, 1.3]],
		["ing_mistletoe", "mistletoe_clump", 18, {zone = fe}, [0.9, 1.2]],
		["ing_wintergreen", "wintergreen_patch", 45, {zone = any_of([fe, cm])}, [0.8, 1.2]],
		["ing_crow_feather", "feather_crow", 45, {zone = fd}, [0.9, 1.2]],
		["ing_shed_antler", "shed_antler", 12, {zone = any_of([fe, cm])}, [0.9, 1.1]],
		["ing_flint", "flint_nodule", 50, {zone = any_of([fd, wl])}, [0.9, 1.3]],
		["ing_chalk", "chalk_lump", 35, {zone = fd}, [0.9, 1.3]],
		["ing_red_ochre", "red_ochre_rock", 16, {sampler = Builder.near(HUT, 30.0, 5.5)}, [0.9, 1.2]],
		["ing_charcoal", "charcoal_lump", 14, {sampler = Builder.near(HumanRealmLayout.COTTAGE, 30.0, 12.5)}, [0.9, 1.2]],
		["ing_clay", "clay_lump", 24, {sampler = pond_ring}, [0.9, 1.2]],
		["ing_snowmelt_water", "icicle_cluster", 30, {zone = any_of([wl, fe])}, [0.9, 1.3]],
		["ing_ice_moss", "ice_moss", 50, {zone = any_of([wl, fe])}, [0.9, 1.3]],
		["ing_owl_feather", "feather_owl", 14, {zone = any_of([fe, Callable(self, "_hut_zone")])}, [0.9, 1.1]],
		["ing_hawk_feather", "feather_hawk", 16, {zone = fd}, [0.9, 1.1]],
		["ing_snail_shell", "snail_shells", 40, {zone = any_of([wl, hg])}, [0.9, 1.2]],
	]
	for f in forage:
		var spec := {id = f[0], mesh = f[1], ingredient = f[0], count = f[2], scale = f[4], wind = 0.2, draw = 90.0, clearance = 0.4, canon = "X"}
		spec.merge(f[3])
		if f[0] == "ing_snowdrop":
			spec.canon = "C"  # Elain's flowers
		b.add_layer(spec)
	# Snowdrops in Elain's garden itself (the ones she coaxed up).
	var sd := b.layer_by_id(&"ing_snowdrop")
	for i in 6:
		var p: Vector2 = Builder.near(HumanRealmLayout.ELAIN_GARDEN + Vector2(0, 6.0), 2.0).call(b.rng)
		if b.free_at(p, 0.2):
			b.place(sd, p, b.specs[&"ing_snowdrop"])

	# --- Collectibles (keepsakes) and looks ---
	var col := [
		["lost_button", 8, aw], ["bone_token", 6, any_of([fe, fd])], ["blessed_pamphlet", 6, any_of([cm, yd])],
		["frozen_ribbon", 5, any_of([hg, cm])], ["clay_pipe", 5, fd], ["horseshoe", 6, any_of([cm, fd])],
		["lost_mitten", 5, any_of([cm, fe])], ["copper_coin", 8, aw], ["tin_soldier", 4, any_of([cm, yd])],
		["paint_tin_empty", 3, yd],
	]
	for c in col:
		b.add_layer({id = c[0], mesh = AS + c[0] + ".glb", tags = ["collectible"], count = c[1], zone = c[2], scale = [1.0, 1.0], draw = 60.0, clearance = 0.5, shadow = false, canon = "C" if c[0] == "paint_tin_empty" else "X"})
	var looks := [
		["fox_tracks", 14, any_of([fd, cm, fe])], ["deer_tracks", 10, any_of([fe, cm])], ["hare_tracks", 12, any_of([fd, hg])],
		["frozen_bird", 6, any_of([hg, yd, fd])], ["robin_post", 8, any_of([wl, hg, yd])], ["crow_flock", 8, fd],
		["hare_crouched", 6, any_of([fd, hg])],
	]
	for c in looks:
		b.add_layer({id = c[0], mesh = AS + c[0] + ".glb", tags = ["look"], count = c[1], zone = c[2], scale = [1.0, 1.0], draw = 90.0, clearance = 0.8, spacing = 12.0, shadow = c[0] != "fox_tracks"})
	# Feyre's paint tin: one is always by the woodpile.
	var tin := b.layer_by_id(&"paint_tin_empty")
	b.place(tin, _cottage_world(Vector3(-6.5, 0, 3.0)), b.specs[tin.id])


static func _hut_zone(p: Vector2) -> float:
	return 1.0 if p.distance_to(HUT) < 25.0 else 0.0




# --- Scene ------------------------------------------------------------------------

## The cottage's world transform: pad centre, floor 0.12 m above the ground.
static func cottage_transform() -> Transform3D:
	var c := HumanRealmLayout.COTTAGE
	return Transform3D(Basis(Vector3.UP, HumanRealmLayout.COTTAGE_YAW), Vector3(c.x, WorldHeight.height_at(c.x, c.y) + 0.12, c.y))


static func _cottage_world(local: Vector3) -> Vector2:
	var w := cottage_transform() * local
	return Vector2(w.x, w.z)


func _glb(path: String, node_name: String, parent: Node, owner: Node, pos := Vector3.ZERO, yaw_deg := 0.0, extra_rot := Vector3.ZERO, scale := Vector3.ONE) -> Node3D:
	var scene := load(path) as PackedScene
	var n: Node3D
	if scene == null:
		push_warning("cottage_gen: missing %s" % path)
		n = Node3D.new()
	else:
		n = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	n.name = node_name
	n.position = pos
	n.rotation_degrees = Vector3(extra_rot.x, yaw_deg, extra_rot.z)
	n.scale = scale
	parent.add_child(n)
	n.owner = owner
	return n


func _node(cls: Variant, node_name: String, parent: Node, owner: Node, pos := Vector3.ZERO, yaw_deg := 0.0) -> Node3D:
	var n: Node3D = cls.new()
	n.name = node_name
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	parent.add_child(n)
	n.owner = owner
	return n


## Ground-level world position for a world (x, z).
static func ground(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.y) + lift, p.y)


func _build_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "Cottage"
	var field := ScatterField.new()
	field.name = "ScatterField"
	field.region_id = &"cottage"
	field.layers = b.layers
	root.add_child(field)
	field.owner = root
	var cols := _node(Node3D, "Colliders", root, root)
	b.build_colliders(cols, root)

	# --- The cottage ---
	var cot := _node(Node3D, "ArcheronCottage", root, root)
	cot.transform = cottage_transform()
	cot.add_to_group(&"landmark", true)
	cot.set_meta(&"location_id", "loc_archeron_cottage")
	_glb(A + "cottage_shell.glb", "Shell", cot, root)

	# The door the beast breaks: the story lane's StateVisibility swaps the
	# intact door for the broken one once fact.cottage_door_broken is set.
	var door := _node(Node3D, "CottageDoor", cot, root, Vector3(-1.9, 0.0, -2.95))
	door.set_meta(&"state_flag", "fact.cottage_door_broken")
	var intact_state := _node(Node3D, "IntactState", door, root)
	intact_state.set_script(load("res://story/framework/state_visibility.gd"))
	intact_state.set(&"hide_when_flag", "fact.cottage_door_broken")
	_glb(A + "cottage_door_intact.glb", "Intact", intact_state, root)
	var broken_state := _node(Node3D, "BrokenState", door, root)
	broken_state.set_script(load("res://story/framework/state_visibility.gd"))
	broken_state.set(&"show_when_flag", "fact.cottage_door_broken")
	_glb(A + "cottage_door_broken.glb", "Broken", broken_state, root)

	var inside := _node(Node3D, "Interior", cot, root)
	var hearth := _node(Node3D, "Hearth", inside, root, Vector3(3.62, 0.0, 0.0))
	hearth.add_to_group(&"hearth", true)
	_node(Marker3D, "HearthSpot", hearth, root, Vector3(-0.9, 0.0, 0.0), 90.0)
	_glb(AI + "hearth_embers_glow.glb", "Embers", hearth, root, Vector3(0.0, 0.08, 0.0))
	_glb(AI + "iron_pot.glb", "IronPot", hearth, root, Vector3(0.0, 0.08, 0.0))
	var fire := OmniLight3D.new()
	fire.name = "FireLight"
	fire.position = Vector3(-0.2, 0.55, 0.0)
	fire.light_color = Color(1.0, 0.62, 0.32)
	fire.light_energy = 1.8
	fire.omni_range = 8.0
	fire.omni_attenuation = 1.2
	fire.shadow_enabled = true
	fire.set_script(load(DIR + "fire_flicker.gd"))
	hearth.add_child(fire)
	fire.owner = root

	var props := [
		# [node name, glb, local position, yaw, extra rotation]
		["SistersBed", AI + "bed.glb", Vector3(-2.95, 0, 1.85), 180.0],
		["FathersChair", AI + "father_chair.glb", Vector3(2.3, 0, 0.9), -100.0],
		["FathersCane", AI + "cane.glb", Vector3(2.62, 0, 1.25), 0.0, Vector3(0, 0, 14)],
		["CarvingStool", AI + "carving_stool.glb", Vector3(2.0, 0, 1.75), 20.0],
		["CarvingKnifeAndFigures", AI + "wooden_figures.glb", Vector3(2.0, 0.44, 1.75), 20.0],
		["WoodShavings", AI + "wood_shavings.glb", Vector3(2.2, 0.0, 1.35), 0.0],
		["Table", AI + "table.glb", Vector3(0.0, 0, -0.2), 0.0],
		["Dresser", AI + "dresser.glb", Vector3(0.4, 0, 2.42), 0.0],
		["WallCabinet", AI + "wall_cabinet.glb", Vector3(1.95, 1.35, 2.7), 0.0],
		["PegsWithClothes", AI + "pegs_clothes.glb", Vector3(-4.0, 0, -0.9), -90.0],
		["FeyresBowAndQuiver", AI + "bow_quiver.glb", Vector3(-3.35, 0, -2.62), 180.0],
		["PaintCorner", AI + "paint_corner.glb", Vector3(2.75, 0, -2.3), 0.0],
		["NestasRibbonAndComb", AI + "nesta_ribbon_comb.glb", Vector3(0.05, 1.12, 2.42), 10.0],
		["ElainsSeedPackets", AI + "elain_seed_packets.glb", Vector3(0.6, 1.12, 2.45), -15.0],
		["PressedFlowerCup", AI + "pressed_flower_cup.glb", Vector3(0.35, 0.77, -0.1), 0.0],
		["HiddenCoin", AI + "hidden_coin.glb", Vector3(2.9, 0.0, -0.95), 30.0],
		["DishShelf", AI + "dish_shelf.glb", Vector3(2.2, 1.5, -2.7), 180.0],
		["ShutterFrostFront", AI + "shutter_frost.glb", Vector3(1.4, 0.9, -3.12), 180.0],
		["ShutterFrostBack", AI + "shutter_frost.glb", Vector3(-0.6, 0.9, 3.12), 0.0],
	]
	for p in props:
		_glb(p[1], p[0], inside, root, p[2], p[3], p[4] if p.size() > 4 else Vector3.ZERO)
	var tally := _node(Node3D, "FoodTally", inside, root, Vector3(-0.115, 2.56, 0.0), 90.0)
	_glb(AI + "food_tally_marks.glb", "Marks", tally, root, Vector3.ZERO, -90.0)
	_node(Marker3D, "Counter", tally, root, Vector3(0.0, 0.0, -0.05))
	# Feyre's painted motifs: the only saturated colour in the room.
	var motifs := _node(Node3D, "PaintedMotifs", inside, root)
	_glb(AI + "motif_dresser.glb", "DresserDrawers", motifs, root, Vector3(0.4, 0, 2.42), 0.0)
	_glb(AI + "motif_table_foxglove.glb", "TableFoxglove", motifs, root, Vector3(0.0, 0, -0.2), 0.0)
	_glb(AI + "motif_cabinet_daffodils.glb", "CabinetDaffodils", motifs, root, Vector3(1.95, 1.35, 2.7), 0.0)
	_glb(AI + "motif_wall_vines.glb", "WallVinesByWindow", motifs, root, Vector3(0.85, 0, -2.7), 180.0)
	_glb(AI + "motif_wall_vines.glb", "WallVinesOverBed", motifs, root, Vector3(-4.0, 0, 0.3), -90.0)
	_glb(AI + "motif_wall_vines.glb", "WallVinesByDoor", motifs, root, Vector3(-1.05, 0.15, -2.7), 180.0)
	var cold := OmniLight3D.new()
	cold.name = "WindowColdFill"
	cold.position = Vector3(0.0, 2.0, 0.0)
	cold.light_color = Color(0.62, 0.7, 0.85)
	cold.light_energy = 0.25
	cold.omni_range = 6.0
	inside.add_child(cold)
	cold.owner = root

	# --- Yard ---
	var yard_n := _node(Node3D, "Yard", cot, root)
	_glb(A + "snares_hanging.glb", "SnaresByDoor", yard_n, root, Vector3(-3.1, 0, -3.22), 0.0)
	_glb(A + "woodpile.glb", "Woodpile", yard_n, root, Vector3(-5.15, 0, 0.6), 90.0)
	_glb(A + "chopping_block.glb", "ChoppingBlock", yard_n, root, Vector3(-6.6, 0, -1.9), 40.0)
	_glb(A + "rain_barrel.glb", "RainBarrelFrozen", yard_n, root, Vector3(4.0, 0, 3.75), 0.0)
	_glb(A + "drying_rack.glb", "DryingRack", yard_n, root, Vector3(-3.0, 0, 5.4), 10.0)
	_glb(A + "outhouse.glb", "Outhouse", yard_n, root, Vector3(9.0, 0, 11.0), 200.0)
	var smoke := CPUParticles3D.new()
	smoke.name = "ChimneySmoke"
	smoke.position = Vector3(4.95, 6.35, 0.0)
	smoke.amount = 24
	smoke.lifetime = 7.0
	smoke.direction = Vector3(0.15, 1.0, 0.0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.25, 0.15, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(1.0, 2.6))
	smoke.scale_amount_curve = curve
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 8
	puff.rings = 4
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.7, 0.72, 0.76, 0.35)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = smat
	smoke.mesh = puff
	cot.add_child(smoke)
	smoke.owner = root

	# --- Elain's garden ---
	var g := _glb(A + "elain_garden.glb", "ElainGarden", root, root, ground(HumanRealmLayout.ELAIN_GARDEN, 0.0), rad_to_deg(HumanRealmLayout.COTTAGE_YAW))
	g.add_to_group(&"landmark", true)

	# --- Fields ---
	var fields_n := _node(Node3D, "Fields", root, root)
	var pond_y := 0.0
	for i in 12:
		var a := TAU * i / 12.0
		pond_y += WorldHeight.height_at(POND.x + cos(a) * POND_R, POND.y + sin(a) * POND_R)
	pond_y = pond_y / 12.0 + 0.05
	var pond := _glb(A + "frozen_pond.glb", "FrozenPond", fields_n, root, Vector3(POND.x, pond_y, POND.y), 0.0, Vector3.ZERO, Vector3(POND_R, 1.0, POND_R))
	pond.add_to_group(&"landmark", true)
	var mist := FogVolume.new()
	mist.name = "PondMist"
	mist.position = Vector3(POND.x, pond_y + 1.0, POND.y)
	mist.size = Vector3(POND_R * 2.6, 2.5, POND_R * 2.6)
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	var fm := FogMaterial.new()
	fm.density = 0.12
	fm.albedo = Color(0.82, 0.86, 0.92)
	mist.material = fm
	fields_n.add_child(mist)
	mist.owner = root
	var sc := _glb(A + "scarecrow.glb", "Scarecrow", fields_n, root, ground(SCARECROW, -0.3), 25.0)
	sc.add_to_group(&"landmark", true)
	var hut := _glb(A + "shepherd_hut_ruin.glb", "ShepherdHutRuin", fields_n, root, ground(HUT, -0.2), 70.0)
	hut.add_to_group(&"landmark", true)
	_build_opening(root)
	return root


# --- The opening (experience bar §1.1) ------------------------------------------
# Dawn at the cottage: the camera sits south-east, so the lit back window, the
# smoking chimney and the dark treeline stack up in one frame. Feyre starts by
# the door, where a fresh deer trail leads off to the treeline: the first deed.

## Composed opening vantage (world): camera position and look-at point.
static func opening_camera() -> Array[Vector3]:
	var eye := _cottage_world(Vector3(-12.0, 0.0, 19.0))
	var look := _cottage_world(Vector3(-1.0, 0.0, -30.0))
	return [ground(eye, 1.5), ground(look, 3.2)]


## The deer trail, door to treeline (world XZ), a curve that slips out of sight
## between the trees.
static func deer_trail_points() -> PackedVector2Array:
	var start := _cottage_world(Vector3(-7.5, 0.0, 3.5))
	var end := Vector2(-205.0, 2088.0)
	var bend := start.lerp(end, 0.5) + Vector2(18.0, -4.0)
	var pts := PackedVector2Array()
	var n := 56
	for i in n + 1:
		var t := float(i) / n
		pts.append(start.lerp(bend, t).lerp(bend.lerp(end, t), t))
	return pts


func _build_opening(root: Node3D) -> void:
	var op := _node(Node3D, "Opening", root, root)
	var cam := opening_camera()
	var shot := _node(Marker3D, "OpeningCamera", op, root)
	shot.transform = Transform3D.IDENTITY.looking_at(cam[1] - cam[0], Vector3.UP).translated(cam[0])
	shot.set_meta(&"fov", 50.0)
	shot.set_meta(&"time_of_day", 0.262)
	shot.set_meta(&"shot", "opening_dawn")
	shot.add_to_group(&"shot_frame", true)
	var trail := deer_trail_points()
	# Where Feyre stands at the start: in the yard by the woodpile, in the
	# opening frame, facing up the trail.
	var start := _node(Marker3D, "opening_cottage_dawn", op, root)
	var s0 := ground(trail[0], 0.0)
	start.transform = Transform3D.IDENTITY.looking_at(ground(trail[4], 0.0) - s0, Vector3.UP).translated(s0)
	start.add_to_group(&"story_anchor", true)
	var end := _node(Marker3D, "first_deed_treeline", op, root)
	var e0 := ground(trail[trail.size() - 1], 0.0)
	end.transform = Transform3D.IDENTITY.looking_at(e0 - ground(trail[trail.size() - 4], 0.0), Vector3.UP).translated(e0)
	end.add_to_group(&"story_anchor", true)
	op.add_child(_trail_prints(trail))
	op.get_child(op.get_child_count() - 1).owner = root
	# Act I anchors inside (docs/contracts/world.md): -Z faces the action.
	var cot := root.get_node("ArcheronCottage") as Node3D
	var inside := cot.get_node("Interior") as Node3D
	var room := _node(Marker3D, "act1_cottage_interior", inside, root, Vector3(-0.5, 0.0, 0.0), 0.0)
	room.set_meta(&"size", Vector3(10.5, 3.0, 6.0))
	room.add_to_group(&"story_anchor", true)
	_node(Marker3D, "act1_cottage_door", inside, root, Vector3(-1.9, 0.0, -2.85), 180.0).add_to_group(&"story_anchor", true)
	_node(Marker3D, "act1_food_tally_beam", inside, root, Vector3(-0.115, 2.56, 0.0), 90.0).add_to_group(&"story_anchor", true)
	# Warmth only where Feyre makes it: the hearth behind the back window.
	var glow := MeshInstance3D.new()
	glow.name = "WindowGlow"
	var q := QuadMesh.new()
	q.size = Vector2(0.82, 0.78)
	glow.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.66, 0.34)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.58, 0.26)
	gm.emission_energy_multiplier = 9.0
	glow.material_override = gm
	glow.position = Vector3(-0.6, 1.3, 3.1)
	cot.add_child(glow)
	glow.owner = root
	var spill := OmniLight3D.new()
	spill.name = "WindowSpill"
	spill.position = Vector3(-0.6, 1.2, 3.9)
	spill.light_color = Color(1.0, 0.64, 0.34)
	spill.light_energy = 4.2
	spill.omni_range = 9.0
	spill.set_script(load(DIR + "fire_flicker.gd"))
	cot.add_child(spill)
	spill.owner = root
	# Feyre's vines climb out round the back window and over the door.
	var ext := _node(Node3D, "PaintedOutside", cot, root)
	_glb(AI + "motif_wall_vines.glb", "VinesWindowLeft", ext, root, Vector3(-1.1, 0.0, 3.2), 180.0)
	_glb(AI + "motif_wall_vines.glb", "VinesWindowRight", ext, root, Vector3(1.0, 0.0, 3.2), 180.0)
	_glb(AI + "motif_wall_vines.glb", "VinesDoor", ext, root, Vector3(-1.4, 0.2, -3.2), 0.0)
	# A bare branch in the foreground of the opening frame.
	var eye_local := Vector3(-12.0, 0.0, 19.0)
	var branch := _glb("res://world/human_realm/shared/assets/flora/tree_dead_snag.glb", "OpeningFrameBranch", op, root,
		ground(_cottage_world(eye_local + Vector3(-3.4, 0.0, -4.6)), -0.2), 30.0)
	branch.scale = Vector3.ONE * 1.3


## Fresh hoof prints along the trail: pairs, alternating sides, as one MultiMesh.
static func _trail_prints(trail: PackedVector2Array) -> MultiMeshInstance3D:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for half in [-0.035, 0.035]:
		var c := Vector3(half, 0.0, 0.0)
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			st.set_normal(Vector3.UP)
			st.add_vertex(c)
			st.add_vertex(c + Vector3(cos(a1) * 0.03, 0.0, sin(a1) * 0.06))
			st.add_vertex(c + Vector3(cos(a0) * 0.03, 0.0, sin(a0) * 0.06))
	st.commit(mesh)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.42, 0.56)
	mat.roughness = 1.0
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xforms: Array[Transform3D] = []
	var walked := 0.0
	var side := 1.0
	for i in range(1, trail.size()):
		var a := trail[i - 1]
		var b2 := trail[i]
		var seg := a.distance_to(b2)
		var dir := (b2 - a) / maxf(seg, 0.001)
		var right := Vector2(-dir.y, dir.x)
		while walked <= seg:
			var p := a + dir * walked + right * 0.13 * side
			var yaw := atan2(-dir.x, -dir.y)
			xforms.append(Transform3D(Basis(Vector3.UP, yaw), ground(p, 0.025)))
			side = -side
			walked += 0.7
		walked -= seg
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "DeerTrail"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.add_to_group(&"track_trail", true)
	mmi.set_meta(&"track_kind", "deer")
	return mmi

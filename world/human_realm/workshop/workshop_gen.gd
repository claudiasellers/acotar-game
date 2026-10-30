## Generator for the `workshop` region: the burnt Archeron estate on the hill
## (gutted house, dead formal garden, broken fountain, toppled statue, frozen
## ornamental pond, rose briar, gates and an avenue of bare trees), the
## father's workshop shed beside the road, the dead orchard, the family plot,
## and the forest edge and hill meadows around them. Story-free, beautiful-
## melancholy; pays off later. Deterministic (seeded). Writes
##   world/human_realm/workshop/scatter/*.tres, workshop_report.json,
##   workshop.tscn and data/regions/human_realm/workshop.tres.
##
##   godot --headless -s res://world/human_realm/workshop/workshop_gen.gd
extends SceneTree

const Builder := preload("res://world/human_realm/cottage/region_builder.gd")
const DIR := "res://world/human_realm/workshop/"
const A := DIR + "assets/"
const AK := DIR + "assets/small/"
const AC := "res://world/human_realm/cottage/assets/"
const AS := "res://world/human_realm/cottage/assets/small/"
const SEED := 0xE57A7E

## The house faces north-east down the drive toward the village road.
const ESTATE_YAW := -0.72
const ORCHARD := Rect2(-830.0, 2150.0, 64.0, 56.0)
const FAMILY_PLOT := Vector2(-735.0, 2420.0)
const GROUNDS_R := 95.0
## Workshop shed: beside the road below the estate, back to the hill.
const SHED := Vector2(-556.0, 2223.0)
const SHED_YAW := 180.0

var b: Builder


static func estate() -> Vector2:
	return HumanRealmLayout.BURNT_ESTATE


## Estate-local (x, z) -> world (x, z).
static func ew(x: float, z: float) -> Vector2:
	var v := Basis(Vector3.UP, ESTATE_YAW) * Vector3(x, 0.0, z)
	return estate() + Vector2(v.x, v.z)


static func garden() -> Vector2:
	return ew(0.0, 32.0)


static func pond() -> Vector2:
	return ew(0.0, 55.0)


static func statue() -> Vector2:
	return ew(15.0, 40.0)


static func gate() -> Vector2:
	var r: PackedVector2Array = HumanRealmLayout.ROADS[2]
	return r[2].lerp(r[3], 0.45)


## Old boundary wall round the grounds, in broken runs.
static func boundary_walls() -> Array:
	var out: Array = []
	var runs := [[0.15, 0.95], [1.1, 1.9], [2.05, 2.9], [3.3, 4.2], [4.4, 5.3], [5.5, 6.1]]
	for run in runs:
		var line := PackedVector2Array()
		var a: float = run[0]
		while a <= run[1]:
			line.append(estate() + Vector2(cos(a), sin(a)) * GROUNDS_R)
			a += 0.08
		out.append(line)
	return out


## The drive avenue: bare trees either side of the last stretch of road.
static func avenue_points() -> Array:
	var r: PackedVector2Array = HumanRealmLayout.ROADS[2]
	var a := r[2]
	var c := r[3]
	var n := (c - a).orthogonal().normalized()
	var out := []
	for i in range(1, 12):
		var p := a.lerp(c, i / 12.0)
		out.append(p + n * 7.0)
		out.append(p - n * 7.0)
	return out


func _initialize() -> void:
	var rects: Array[Rect2] = [HumanRealmLayout.REGION_RECTS[&"workshop"]]
	b = Builder.new(&"workshop", rects, SEED)
	_reserve()
	_layers()
	var added := b.cover_empty([&"ing_flint", &"ing_crow_feather", &"fox_tracks", &"ing_ice_moss"])
	b.save_layers(DIR + "scatter")
	var root := _build_scene()
	var draw_calls := b.estimate_draw_calls(Builder.count_meshes(root))
	var report := ScatterReport.compute(b.layers, b.area, LANDMARKS.size(), draw_calls)
	ScatterReport.save(report, DIR + "workshop_report.json")
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed, DIR + "workshop.tscn")
	b.save_region_def(DIR + "workshop.tscn", DIR + "workshop_report.json", PackedStringArray(["cottage", "hunting_forest"]))
	var total := 0
	for l in b.layers:
		total += l.count()
	print("workshop: %d layers, %d instances (%d cover fill), report %s" % [b.layers.size(), total, added, JSON.stringify(report)])
	root.free()
	quit()


const LANDMARKS := ["BurntEstate", "FathersWorkshop", "FamilyPlot", "BrokenFountain", "ToppledStatue", "OrnamentalPond", "DeadOrchard", "EstateGates"]


func _reserve() -> void:
	b.reserve(estate(), 17.0)
	b.reserve(ew(-12.0, -4.0), 3.0)  # chimney stack ends
	b.reserve(ew(12.0, -4.0), 3.0)
	b.reserve(ew(0.0, -9.0), 4.0)  # front steps
	b.reserve(garden(), 13.0)
	b.reserve(pond(), 7.0)
	b.reserve(statue(), 3.5)
	b.reserve(SHED, 5.0)
	b.reserve(FAMILY_PLOT, 4.0)


# --- Zones -------------------------------------------------------------------------

static func forest_edge(p: Vector2) -> float:
	return clampf((2150.0 - p.y) / 70.0, 0.0, 1.0)


static func grounds(p: Vector2) -> float:
	return 1.0 if p.distance_to(estate()) < GROUNDS_R else 0.0


static func hill(p: Vector2) -> float:
	var d := p.distance_to(estate())
	return 1.0 if d >= GROUNDS_R and d < HumanRealmLayout.ESTATE_HILL_RADIUS else 0.0


static func ruin(p: Vector2) -> float:
	return 1.0 if p.distance_to(estate()) < 40.0 else 0.0


static func orchard(p: Vector2) -> float:
	return 1.0 if ORCHARD.grow(6.0).has_point(p) else 0.0


static func meadow(p: Vector2) -> float:
	return 1.0 if forest_edge(p) < 0.5 and p.distance_to(estate()) >= GROUNDS_R else 0.0


static func walls(p: Vector2) -> float:
	return 1.0 if Builder.dist_lines(p, boundary_walls()) < 2.5 else 0.0


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
	var gr := Callable(self, "grounds")
	var hl := Callable(self, "hill")
	var rn := Callable(self, "ruin")
	var oc := Callable(self, "orchard")
	var md := Callable(self, "meadow")
	var wl := Callable(self, "walls")
	var aw := Callable(self, "anywhere")
	var pond_ring := Builder.near(pond(), 13.0, 6.5)
	var garden_ring := Builder.near(garden(), 24.0, 12.0)
	var trunk := {"type": "trunk", "r": 0.35, "h": 5.0}

	# --- Trees and large decoration ---
	b.add_layer({id = "tree_oak_bare", mesh = "tree_oak_bare", count = 60, zone = any_of([fe, hl]), scale = [0.9, 1.4], wind = 0.15, draw = 160.0, far = true, spacing = 10.0, clearance = 3.0, collider = {"type": "trunk", "r": 0.5, "h": 5.0}})
	b.add_layer({id = "tree_birch", mesh = "tree_birch", count = 50, zone = fe, scale = [0.8, 1.2], wind = 0.3, draw = 160.0, far = true, spacing = 5.0, clearance = 2.5, collider = {"type": "trunk", "r": 0.2, "h": 5.0}})
	b.add_layer({id = "tree_pine", mesh = "tree_pine", count = 70, zone = any_of([fe, Callable(self, "_west")]), scale = [0.8, 1.3], wind = 0.15, draw = 160.0, far = true, spacing = 6.0, clearance = 2.5, collider = trunk})
	b.add_layer({id = "tree_spruce", mesh = "tree_spruce", count = 60, zone = any_of([fe, Callable(self, "_west")]), scale = [0.8, 1.3], wind = 0.15, draw = 160.0, far = true, spacing = 6.0, clearance = 2.5, collider = trunk})
	b.add_layer({id = "tree_dead_snag", mesh = "tree_dead_snag", count = 20, zone = any_of([gr, hl]), scale = [0.8, 1.2], draw = 160.0, far = true, spacing = 10.0, clearance = 2.5, collider = {"type": "trunk", "r": 0.3, "h": 4.0}})
	b.add_layer({id = "tree_willow_pollard", mesh = "tree_willow_pollard", count = 5, sampler = Builder.near(pond(), 16.0, 9.0), scale = [0.9, 1.2], wind = 0.2, draw = 160.0, far = true, spacing = 6.0, clearance = 1.5, collider = {"type": "trunk", "r": 0.45, "h": 3.0}})
	var avenue := b.add_layer({id = "tree_avenue", mesh = "tree_oak_bare", count = 0, scale = [1.0, 1.25], draw = 200.0, far = true, collider = {"type": "trunk", "r": 0.5, "h": 6.0}})
	for p: Vector2 in avenue_points():
		if b.free_at(p, 2.0):
			b.place(avenue, p, b.specs[avenue.id])
	var fruit := b.add_layer({id = "dead_fruit_tree", mesh = A + "dead_fruit_tree.glb", count = 0, scale = [0.85, 1.15], draw = 160.0, collider = {"type": "trunk", "r": 0.18, "h": 2.0}})
	for i in 8:
		for j in 7:
			var p := ORCHARD.position + Vector2(i * 8.0 + (j % 2) * 4.0, j * 8.0) + Vector2(b.rng.randf_range(-0.8, 0.8), b.rng.randf_range(-0.8, 0.8))
			if b.free_at(p, 1.0) and b.rng.randf() > 0.08:  # a few gaps where trees have fallen
				b.place(fruit, p, b.specs[fruit.id])
	b.add_layer({id = "rubble_pile", mesh = A + "rubble_pile.glb", count = 40, zone = rn, scale = [0.8, 1.5], clearance = 0.5, collider = {"type": "sphere", "r": 0.6}})
	for sp in [["shrub_hawthorn", "hawthorn"], ["shrub_blackthorn", "blackthorn_sloe"], ["shrub_hazel", "hazel_shrub"], ["shrub_holly", "holly_bush"], ["shrub_rose_briar", "wild_rose_briar"]]:
		b.add_layer({id = sp[0], mesh = sp[1], count = 70, zone = any_of([wl, hl, gr]), scale = [0.9, 1.4], wind = 0.25, clearance = 1.0})
	b.add_layer({id = "winter_grass_tuft", mesh = "winter_grass_tuft", count = 700, zone = any_of([md, hl, gr]), scale = [0.7, 1.3], wind = 0.6, draw = 70.0, shadow = false})
	b.add_layer({id = "dead_bracken", mesh = "dead_bracken", count = 320, zone = any_of([fe, hl]), scale = [0.8, 1.3], wind = 0.4, draw = 80.0, shadow = false})
	b.add_layer({id = "snow_mound", mesh = "snow_mound", count = 200, zone = aw, scale = [0.8, 2.0], shadow = false})
	b.add_layer({id = "rock_boulder_a", mesh = "rock_boulder_a", count = 18, zone = any_of([hl, md]), scale = [0.8, 1.4], spacing = 8.0, clearance = 1.5, collider = {"type": "sphere", "r": 0.9}})
	b.add_layer({id = "rock_boulder_b", mesh = "rock_boulder_b", count = 14, zone = any_of([fe, hl]), scale = [0.8, 1.4], spacing = 8.0, clearance = 1.5, collider = {"type": "sphere", "r": 0.9}})
	b.add_layer({id = "rock_boulder_c", mesh = "rock_boulder_c", count = 12, zone = md, scale = [0.7, 1.2], spacing = 8.0, clearance = 1.5, collider = {"type": "sphere", "r": 0.8}})
	b.add_layer({id = "rock_scree", mesh = "rock_scree", count = 20, zone = hl, scale = [0.8, 1.3]})
	b.add_layer({id = "log_fallen", mesh = "log_fallen", count = 18, zone = any_of([fe, oc]), scale = [0.8, 1.2], spacing = 6.0, clearance = 2.0})
	b.add_layer({id = "stump", mesh = "stump", count = 30, zone = any_of([fe, oc, hl]), scale = [0.8, 1.2]})
	var wall := b.add_layer({id = "boundary_wall", mesh = AC + "drystone_wall.glb", count = 0, collider = {"type": "box", "size": Vector3(4.0, 1.0, 0.6)}})
	b.tile_along(wall, boundary_walls(), 4.0, b.specs[wall.id])

	# --- Forage ---
	var forage := [
		["ing_snowdrop", "snowdrop_cluster", 60, {zone = any_of([gr, oc])}, [0.8, 1.2]],
		["ing_blackberry", "blackberry_bramble", 45, {zone = any_of([wl, hl, fe])}, [0.8, 1.3]],
		["ing_pine_resin", "pine_resin_blob", 30, {zone = any_of([fe, Callable(self, "_west")])}, [0.9, 1.2]],
		["ing_willow_bark", "willow_withies", 16, {sampler = Builder.near(pond(), 18.0, 7.0)}, [0.9, 1.3]],
		["ing_oak_gall", "oak_gall_twig", 30, {zone = any_of([fe, hl])}, [0.9, 1.2]],
		["ing_woad", "woad_rosette", 35, {zone = md}, [0.8, 1.2]],
		["ing_madder", "madder_patch", 35, {zone = any_of([md, gr])}, [0.8, 1.2]],
		["ing_rose_hip", "wild_rose_briar", 55, {sampler = garden_ring}, [0.8, 1.2]],
		["ing_holly_berry", "holly_bush", 35, {zone = any_of([wl, fe])}, [0.7, 1.0]],
		["ing_juniper_berry", "juniper_shrub", 35, {zone = any_of([hl, md])}, [0.8, 1.2]],
		["ing_sloe", "blackthorn_sloe", 30, {zone = any_of([wl, hl])}, [0.7, 1.0]],
		["ing_hawthorn_haw", "hawthorn", 30, {zone = any_of([wl, md])}, [0.7, 1.0]],
		["ing_birch_bark", "log_fallen", 22, {zone = fe}, [0.5, 0.7]],
		["ing_chaga", "chaga_growth", 22, {zone = fe}, [0.9, 1.2]],
		["ing_tinder_fungus", "tinder_fungus", 30, {zone = any_of([fe, oc])}, [0.9, 1.2]],
		["ing_old_mans_beard", "old_mans_beard", 30, {zone = any_of([fe, oc])}, [0.9, 1.2]],
		["ing_acorn", "acorn_scatter", 40, {zone = any_of([fe, hl])}, [0.9, 1.2]],
		["ing_hazelnut", "hazelnut_scatter", 30, {zone = any_of([wl, fe])}, [0.9, 1.2]],
		["ing_pine_needles", "pine_cone_scatter", 40, {zone = any_of([fe, Callable(self, "_west")])}, [0.9, 1.2]],
		["ing_frozen_reed", "frozen_reeds", 30, {sampler = pond_ring}, [0.9, 1.3]],
		["ing_mistletoe", "mistletoe_clump", 30, {zone = any_of([oc, fe])}, [0.9, 1.2]],
		["ing_wintergreen", "wintergreen_patch", 40, {zone = any_of([fe, hl])}, [0.8, 1.2]],
		["ing_crow_feather", "feather_crow", 45, {zone = any_of([md, rn, oc])}, [0.9, 1.2]],
		["ing_shed_antler", "shed_antler", 14, {zone = any_of([fe, oc, md])}, [0.9, 1.1]],
		["ing_flint", "flint_nodule", 40, {zone = any_of([md, hl])}, [0.9, 1.3]],
		["ing_chalk", "chalk_lump", 35, {zone = any_of([hl, md])}, [0.9, 1.3]],
		["ing_red_ochre", "red_ochre_rock", 20, {zone = hl}, [0.9, 1.2]],
		["ing_charcoal", "charcoal_lump", 70, {sampler = Builder.near(estate(), 30.0, 0.0), allow_reserved = true}, [0.9, 1.3]],
		["ing_clay", "clay_lump", 20, {sampler = pond_ring}, [0.9, 1.2]],
		["ing_snowmelt_water", "icicle_cluster", 30, {zone = any_of([rn, wl])}, [0.9, 1.3]],
		["ing_ice_moss", "ice_moss", 50, {zone = any_of([wl, rn, hl])}, [0.9, 1.3]],
		["ing_owl_feather", "feather_owl", 22, {zone = any_of([rn, oc, fe])}, [0.9, 1.1]],
		["ing_hawk_feather", "feather_hawk", 18, {zone = any_of([md, hl])}, [0.9, 1.1]],
		["ing_snail_shell", "snail_shells", 40, {zone = any_of([wl, gr])}, [0.9, 1.2]],
	]
	for f in forage:
		var spec := {id = f[0], mesh = f[1], ingredient = f[0], count = f[2], scale = f[4], wind = 0.2, draw = 90.0, clearance = 0.4, canon = "X"}
		spec.merge(f[3])
		b.add_layer(spec)

	# --- Keepsakes of the family's old life, and looks ---
	var inside_ruin := Builder.near(estate(), 10.0, 0.0)
	var col := [
		["scorched_page", AK, 8, {sampler = Builder.near(estate(), 26.0, 0.0), allow_reserved = true}],
		["silver_spoon", AK, 5, {sampler = inside_ruin, allow_reserved = true}],
		["porcelain_shard", AK, 9, {sampler = Builder.near(estate(), 30.0, 0.0), allow_reserved = true}],
		["carved_bird", AK, 5, {sampler = Builder.near(SHED, 30.0, 5.5)}],
		["brass_key", AK, 4, {zone = gr}],
		["ledger_page", AK, 6, {sampler = Builder.near(estate(), 40.0, 0.0), allow_reserved = true}],
		["figurehead_fragment", AK, 3, {sampler = inside_ruin, allow_reserved = true}],
		["cameo_brooch", AK, 3, {zone = gr}],
		["melted_candlestick", AK, 5, {sampler = inside_ruin, allow_reserved = true}],
		["lost_button", AS, 6, {zone = aw}],
		["copper_coin", AS, 6, {zone = aw}],
	]
	for c in col:
		var spec := {id = c[0], mesh = c[1] + c[0] + ".glb", tags = ["collectible"], count = c[2], scale = [1.0, 1.0], draw = 60.0, clearance = 0.5, shadow = false}
		spec.merge(c[3])
		b.add_layer(spec)
	var looks := [
		["fox_tracks", 14, any_of([md, hl, fe])], ["deer_tracks", 12, any_of([fe, oc, md])], ["hare_tracks", 10, any_of([md, oc])],
		["frozen_bird", 6, any_of([gr, oc])], ["robin_post", 7, any_of([wl, oc])], ["crow_on_post", 6, any_of([hl, md])],
		["crow_flock", 6, any_of([md, oc])], ["hare_crouched", 5, any_of([md, hl])],
	]
	for c in looks:
		b.add_layer({id = c[0], mesh = AS + c[0] + ".glb", tags = ["look"], count = c[1], zone = c[2], scale = [1.0, 1.0], draw = 90.0, clearance = 0.8, spacing = 12.0, shadow = c[0] != "fox_tracks" and c[0] != "deer_tracks" and c[0] != "hare_tracks"})
	# A barn owl in the ruin, on a fallen beam end.
	var owl := b.add_layer({id = "owl_in_ruin", mesh = AS + "owl_perched.glb", tags = ["look"], count = 0, scale = [1.0, 1.0], draw = 90.0})
	b.place(owl, ew(-6.0, 3.0), b.specs[owl.id])
	_lift_onto_ruin_floor()


## Things inside the gutted shell sit on its charred floor (0.13 m up).
func _lift_onto_ruin_floor() -> void:
	var inv := Basis(Vector3.UP, ESTATE_YAW).inverse()
	for layer in b.layers:
		for i in layer.count():
			var pos := layer.position_of(i)
			var local := inv * (pos - Vector3(estate().x, pos.y, estate().y))
			if absf(local.x) < 11.3 and absf(local.z) < 6.3:
				layer.instances[i * ScatterLayer.STRIDE + 1] = pos.y + 0.13


static func _west(p: Vector2) -> float:
	return 1.0 if p.x < -840.0 else 0.0


# --- Scene ------------------------------------------------------------------------

func _glb(path: String, node_name: String, parent: Node, owner: Node, pos := Vector3.ZERO, yaw_deg := 0.0, scale := Vector3.ONE) -> Node3D:
	var scene := load(path) as PackedScene
	var n: Node3D
	if scene == null:
		push_warning("workshop_gen: missing %s" % path)
		n = Node3D.new()
	else:
		n = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	n.name = node_name
	n.position = pos
	n.rotation_degrees.y = yaw_deg
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


static func ground(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x, WorldHeight.height_at(p.x, p.y) + lift, p.y)


## Lowest ground under a footprint: buildings sit on plinths down to it.
static func min_ground(p: Vector2, r: float) -> float:
	var h := WorldHeight.height_at(p.x, p.y)
	for i in 8:
		var a := TAU * i / 8.0
		h = minf(h, WorldHeight.height_at(p.x + cos(a) * r, p.y + sin(a) * r))
	return h


static func max_ground(p: Vector2, r: float) -> float:
	var h := WorldHeight.height_at(p.x, p.y)
	for i in 8:
		var a := TAU * i / 8.0
		h = maxf(h, WorldHeight.height_at(p.x + cos(a) * r, p.y + sin(a) * r))
	return h


func _landmark(n: Node3D) -> void:
	n.add_to_group(&"landmark", true)


func _build_scene() -> Node3D:
	var root := Node3D.new()
	root.name = "Workshop"
	var field := ScatterField.new()
	field.name = "ScatterField"
	field.region_id = &"workshop"
	field.layers = b.layers
	root.add_child(field)
	field.owner = root
	var cols := _node(Node3D, "Colliders", root, root)
	b.build_colliders(cols, root)
	var yaw := rad_to_deg(ESTATE_YAW)

	# --- The burnt estate ---
	var est := _node(Node3D, "BurntEstate", root, root, ground(estate()), yaw)
	_landmark(est)
	_glb(A + "estate_ruin.glb", "RuinShell", est, root)
	_glb(A + "estate_beams.glb", "FallenRoofBeams", est, root)
	_glb(A + "estate_staircase.glb", "CharredStaircase", est, root, Vector3(5.0, 0.05, -2.5))
	_glb(A + "rose_briar_overgrown.glb", "RoseBriarOnBackWall", est, root, Vector3(-6.0, 0.0, 8.6))
	_glb(A + "rose_briar_overgrown.glb", "RoseBriarOnChimney", est, root, Vector3(13.5, 0.0, 4.5), 90.0)
	var ember := FogVolume.new()  # cold ash haze hanging in the shell
	ember.name = "AshHaze"
	ember.position = Vector3(0.0, 1.5, 0.0)
	ember.size = Vector3(26.0, 3.0, 16.0)
	var fm := FogMaterial.new()
	fm.density = 0.06
	fm.albedo = Color(0.7, 0.7, 0.72)
	ember.material = fm
	est.add_child(ember)
	ember.owner = root

	# --- The dead formal garden behind the house ---
	var g := _node(Node3D, "DeadGarden", root, root, ground(garden()), yaw)
	_glb(A + "parterre_dead.glb", "Parterre", g, root)
	var fountain := _glb(A + "fountain_broken.glb", "BrokenFountain", g, root)
	_landmark(fountain)
	var st := _glb(A + "statue_toppled.glb", "ToppledStatue", root, root, ground(statue(), -0.1), yaw + 35.0)
	_landmark(st)
	var p := pond()
	var pond_y := min_ground(p, 5.5) + 0.05
	var pd := _glb(A + "ornamental_pond.glb", "OrnamentalPond", root, root, Vector3(p.x, pond_y, p.y), yaw)
	_landmark(pd)
	var gt := _glb(A + "estate_gateposts.glb", "EstateGates", root, root, ground(gate()), rad_to_deg(-0.726))
	_landmark(gt)

	# --- The father's workshop ---
	var floor_y := max_ground(SHED, 3.0) + 0.05
	var shed := _node(Node3D, "FathersWorkshop", root, root, Vector3(SHED.x, floor_y, SHED.y), SHED_YAW)
	_landmark(shed)
	_glb(A + "workshop_shed.glb", "Shed", shed, root)
	_glb(A + "workbench.glb", "Workbench", shed, root, Vector3(-0.3, 0.1, 1.3))
	_glb(A + "carving_tools.glb", "CarvingTools", shed, root, Vector3(-0.6, 0.1, 1.82))
	_glb(A + "unfinished_carvings.glb", "UnfinishedCarvings", shed, root, Vector3(-0.3, 1.03, 1.3), 10.0)
	_glb(A + "cold_stove.glb", "ColdStove", shed, root, Vector3(1.6, 0.1, 1.1))
	_glb(A + "workshop_shavings.glb", "WoodShavings", shed, root, Vector3(-0.2, 0.1, 0.3))
	_glb(A + "woodstack_seasoning.glb", "SeasoningBlanks", shed, root, Vector3(3.5, min_ground(SHED, 4.0) - floor_y, 0.6), 90.0)
	var lamp := OmniLight3D.new()  # grey daylight through the open door
	lamp.name = "DoorDaylight"
	lamp.position = Vector3(0.0, 1.8, -0.8)
	lamp.light_color = Color(0.75, 0.8, 0.9)
	lamp.light_energy = 0.4
	lamp.omni_range = 4.5
	shed.add_child(lamp)
	lamp.owner = root

	# --- Family plot and the orchard marker ---
	var plot := _glb(A + "family_plot.glb", "FamilyPlot", root, root, ground(FAMILY_PLOT, -0.05), rad_to_deg(atan2(-(estate() - FAMILY_PLOT).x, -(estate() - FAMILY_PLOT).y)))
	_landmark(plot)
	var orch := _node(Node3D, "DeadOrchard", root, root, ground(ORCHARD.get_center()))
	_landmark(orch)
	orch.set_meta(&"note", "Dead orchard: trees are the dead_fruit_tree scatter layer.")
	return root

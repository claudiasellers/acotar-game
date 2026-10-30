## Procedural meshes for every plant, fungus, rock and small find in the
## Spring Court woods, built once and cached.
##
## Each species has a near mesh and (for trees and big shrubs) a cheaper far
## mesh. `SPECIES` holds the placement rules the scatter uses.
## Trees come from Blender models (tools/woods/blender/woods_trees.py ->
## models/<species>.glb); every other species is still procedural. Dropping
## a <species>.glb into models/ swaps that species with no code change.
class_name FloraLibrary
extends RefCounted

const FOLIAGE_SHADER := preload("res://world/spring_court/shared/woods_foliage.gdshader")
## Blender models that replace a procedural builder (tools/woods/blender/).
const MODELS := "res://world/spring_court/shared/models/%s.glb"

## layer: tree | shrub | ground | detail | find
## scale: random uniform scale range; radius: trunk collision radius (m) at
## scale 1, 0 for none; range: visibility end distance in metres.
## shadow: false for small trees and props that skip the shadow pass.
## canon: "C" for flora the book names (lore 05-foraging-chemistry, "Canon
## flora named in the book"), "X" for everything invented (R7).
const SPECIES := {
	# Trees
	&"ancient_oak": {"layer": "tree", "scale": Vector2(0.85, 1.25), "radius": 1.5, "range": 900.0, "canon": "C"},
	&"oak": {"layer": "tree", "scale": Vector2(0.8, 1.2), "radius": 0.5, "range": 750.0, "canon": "C"},
	&"beech": {"layer": "tree", "scale": Vector2(0.85, 1.2), "radius": 0.45, "range": 750.0, "canon": "C"},
	&"silver_birch": {"layer": "tree", "scale": Vector2(0.8, 1.15), "radius": 0.22, "range": 650.0, "canon": "C"},
	&"willow": {"layer": "tree", "scale": Vector2(0.85, 1.15), "radius": 0.45, "range": 650.0, "canon": "C"},
	&"alder": {"layer": "tree", "scale": Vector2(0.8, 1.1), "radius": 0.3, "range": 600.0, "canon": "X"},
	&"elm": {"layer": "tree", "scale": Vector2(0.85, 1.2), "radius": 0.45, "range": 750.0, "canon": "C"},
	&"hawthorn": {"layer": "tree", "scale": Vector2(0.8, 1.2), "radius": 0.25, "range": 500.0, "canon": "X", "shadow": false},
	&"wild_cherry": {"layer": "tree", "scale": Vector2(0.8, 1.15), "radius": 0.3, "range": 650.0, "canon": "X"},
	&"elder": {"layer": "tree", "scale": Vector2(0.8, 1.1), "radius": 0.2, "range": 450.0, "canon": "X", "shadow": false},
	&"twisted_dead": {"layer": "tree", "scale": Vector2(0.8, 1.3), "radius": 0.4, "range": 650.0, "canon": "X"},
	&"blighted_tree": {"layer": "tree", "scale": Vector2(0.8, 1.15), "radius": 0.4, "range": 650.0, "canon": "X"},
	&"crab_apple": {"layer": "tree", "scale": Vector2(0.85, 1.2), "radius": 0.3, "range": 650.0, "canon": "C"},
	&"lilac_tree": {"layer": "tree", "scale": Vector2(0.85, 1.2), "radius": 0.2, "range": 500.0, "canon": "C", "shadow": false},
	&"yew": {"layer": "tree", "scale": Vector2(0.8, 1.25), "radius": 0.55, "range": 700.0, "canon": "X"},
	&"leaning_trunk": {"layer": "tree", "scale": Vector2(0.8, 1.3), "radius": 0.4, "range": 500.0, "canon": "X"},
	# Shrubs and big ground features
	&"fern": {"layer": "shrub", "scale": Vector2(0.7, 1.4), "radius": 0.0, "range": 140.0, "canon": "X"},
	&"bracken": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 140.0, "canon": "X"},
	&"rose_bush_red": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 220.0, "canon": "C"},
	&"rose_bush_white": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 220.0, "canon": "C"},
	&"bramble": {"layer": "shrub", "scale": Vector2(0.8, 1.4), "radius": 0.0, "range": 180.0, "canon": "X"},
	&"honeysuckle_bush": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 180.0, "canon": "X"},
	&"hazel": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.15, "range": 260.0, "canon": "X"},
	&"thornbriar": {"layer": "shrub", "scale": Vector2(0.8, 1.4), "radius": 0.0, "range": 200.0, "canon": "X"},
	&"foxglove": {"layer": "shrub", "scale": Vector2(0.7, 1.3), "radius": 0.0, "range": 140.0, "canon": "C"},
	&"reed_clump": {"layer": "shrub", "scale": Vector2(0.8, 1.5), "radius": 0.0, "range": 160.0, "canon": "X"},
	&"cattail": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 150.0, "canon": "X"},
	&"boulder": {"layer": "shrub", "scale": Vector2(0.6, 2.2), "radius": 0.9, "range": 500.0, "canon": "X"},
	&"mossy_rock": {"layer": "shrub", "scale": Vector2(0.6, 1.6), "radius": 0.5, "range": 300.0, "canon": "X"},
	&"standing_stone": {"layer": "shrub", "scale": Vector2(0.9, 1.3), "radius": 0.45, "range": 600.0, "canon": "X"},
	&"stump": {"layer": "shrub", "scale": Vector2(0.8, 1.4), "radius": 0.55, "range": 250.0, "canon": "X", "shadow": false},
	&"fallen_log": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 300.0, "canon": "X"},
	&"root_arch": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 300.0, "canon": "X"},
	&"moss_mound": {"layer": "shrub", "scale": Vector2(0.6, 1.6), "radius": 0.0, "range": 160.0, "canon": "X"},
	&"pale_fungus": {"layer": "shrub", "scale": Vector2(0.7, 1.4), "radius": 0.0, "range": 140.0, "canon": "X"},
	&"withered_bush": {"layer": "shrub", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 200.0, "canon": "X"},
	# Ground cover (near the player only, see DetailScatter)
	&"grass_tuft": {"layer": "detail", "scale": Vector2(0.7, 1.4), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"tall_grass": {"layer": "detail", "scale": Vector2(0.8, 1.4), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"crocus": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "C"},
	&"snowdrop": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 60.0, "canon": "C"},
	&"bluebell": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 80.0, "canon": "C"},
	&"wood_anemone": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"primrose": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"violet": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 60.0, "canon": "C"},
	&"buttercup": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "C"},
	&"daisy": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"cowslip": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"wild_garlic": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"clover": {"layer": "detail", "scale": Vector2(0.8, 1.4), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"moss_patch": {"layer": "detail", "scale": Vector2(0.7, 1.8), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"leaf_litter": {"layer": "detail", "scale": Vector2(0.7, 1.6), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"faelight_dandelion": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 110.0, "canon": "X"},
	&"glowcap": {"layer": "detail", "scale": Vector2(0.7, 1.4), "radius": 0.0, "range": 110.0, "canon": "X"},
	&"toadstools": {"layer": "detail", "scale": Vector2(0.7, 1.4), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"lily_pad": {"layer": "detail", "scale": Vector2(0.7, 1.5), "radius": 0.0, "range": 80.0, "canon": "X"},
	&"pebbles": {"layer": "detail", "scale": Vector2(0.7, 1.5), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"grey_grass": {"layer": "detail", "scale": Vector2(0.7, 1.4), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"dead_leaves": {"layer": "detail", "scale": Vector2(0.7, 1.6), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"meadowsweet": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"water_mint": {"layer": "detail", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 60.0, "canon": "X"},
	# Finds (forage visuals that are not plants)
	&"feather_hawk": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"feather_owl": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"feather_jay": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"snail_shell": {"layer": "find", "scale": Vector2(1.0, 1.3), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"odd_stone": {"layer": "find", "scale": Vector2(1.0, 1.3), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"painted_pebble": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"river_glass": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"shed_antler": {"layer": "find", "scale": Vector2(0.9, 1.2), "radius": 0.0, "range": 80.0, "canon": "X"},
	&"egg_shell": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 40.0, "canon": "X"},
	&"acorn_caps": {"layer": "find", "scale": Vector2(1.0, 1.3), "radius": 0.0, "range": 40.0, "canon": "X"},
	&"old_arrowhead": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 40.0, "canon": "X"},
	&"mask_ribbon": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"wild_hive": {"layer": "find", "scale": Vector2(0.9, 1.2), "radius": 0.0, "range": 90.0, "canon": "X"},
	&"bark_strip": {"layer": "find", "scale": Vector2(0.9, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"oak_gall_twig": {"layer": "find", "scale": Vector2(1.0, 1.3), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"silt_patch": {"layer": "find", "scale": Vector2(0.8, 1.3), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"sap_briar": {"layer": "find", "scale": Vector2(0.9, 1.2), "radius": 0.0, "range": 80.0, "canon": "X"},
	&"strawberry_patch": {"layer": "find", "scale": Vector2(0.9, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"madder_root": {"layer": "find", "scale": Vector2(0.9, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"hollow_root": {"layer": "find", "scale": Vector2(0.9, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"hazelnuts": {"layer": "find", "scale": Vector2(1.0, 1.3), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"rose_hips": {"layer": "find", "scale": Vector2(0.9, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"blighted_bloom": {"layer": "find", "scale": Vector2(0.9, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"wood_sorrel": {"layer": "find", "scale": Vector2(0.9, 1.3), "radius": 0.0, "range": 50.0, "canon": "X"},
	&"elderflower_sprig": {"layer": "find", "scale": Vector2(0.9, 1.3), "radius": 0.0, "range": 70.0, "canon": "X"},
	&"starmoss": {"layer": "find", "scale": Vector2(0.8, 1.4), "radius": 0.0, "range": 90.0, "canon": "X"},
	&"trout_pool": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 60.0, "canon": "X"},
	&"bone_charm": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 40.0, "canon": "X"},
	&"rusted_iron": {"layer": "find", "scale": Vector2(1.0, 1.2), "radius": 0.0, "range": 40.0, "canon": "X"},
}

# Palette (sRGB): plans/experience-bar.md §2.2 (no lime anywhere in the
# court). Horror biomes use the GREY/dark entries instead.
const BARK := Color("8E6A6E")
const BARK_DARK := Color(0.40, 0.30, 0.31)
const BARK_GREY := Color(0.78, 0.74, 0.76)
const LEAF := Color("7CC29A")
const LEAF_GOLD := Color("B5E3C0")
const LEAF_DEEP := Color("4F9A82")
const MOSS := Color("8DBF7A")
const ROSE := Color("F4A6C0")
const CREAM := Color("FBF7F2")
const LILAC := Color("C8A8E9")
const BLUEBELL := Color("A7B5F2")
const GOLD := Color("F2D27A")
const GREY_LEAF := Color("5A4F5E")
const FAELIGHT := Color(0.85, 0.95, 1.0)

## Material looks: plain (trunks, rocks), bloom (flowers, leaves: a little
## sparkle), magic (glowing species: lots), dread (horror biomes: no rim, no
## sparkle, colour drained).
const MAGIC_SPECIES := [&"faelight_dandelion", &"glowcap", &"starmoss"]
const DREAD_SPECIES := [&"twisted_dead", &"blighted_tree", &"pale_fungus", &"withered_bush",
		&"grey_grass", &"dead_leaves", &"bone_charm", &"rusted_iron", &"blighted_bloom"]
const PLAIN_SPECIES := [&"boulder", &"mossy_rock", &"standing_stone", &"fallen_log", &"root_arch", &"stump", &"leaning_trunk",
		&"pebbles", &"odd_stone", &"silt_patch", &"old_arrowhead", &"trout_pool", &"bark_strip"]

static var _near: Dictionary = {}
static var _far: Dictionary = {}
static var _materials: Dictionary = {}
static var _arrays: Dictionary = {}
static var _arrays_lock := Mutex.new()


static func look_of(species: StringName) -> StringName:
	if species in DREAD_SPECIES:
		return &"dread"
	if species in MAGIC_SPECIES:
		return &"magic"
	if species in PLAIN_SPECIES:
		return &"plain"
	if info(species).get("layer", "") == "tree":
		return &"tree"
	return &"bloom"


static func material(look: StringName = &"bloom") -> ShaderMaterial:
	if not _materials.has(look):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE_SHADER
		match look:
			&"plain":
				m.set_shader_parameter(&"wind_amount", 0.0)
				m.set_shader_parameter(&"translucency", 0.05)
				m.set_shader_parameter(&"roughness_value", 0.9)
				m.set_shader_parameter(&"rim_strength", 0.3)
			&"tree":
				m.set_shader_parameter(&"wind_amount", 0.35)
				m.set_shader_parameter(&"sparkle", 0.0)
			&"bloom":
				m.set_shader_parameter(&"wind_amount", 0.6)
				m.set_shader_parameter(&"sparkle", 0.3)
			&"magic":
				m.set_shader_parameter(&"sparkle", 0.8)
				m.set_shader_parameter(&"glow_energy", 3.5)
			&"dread":
				m.set_shader_parameter(&"wind_amount", 0.25)
				m.set_shader_parameter(&"rim_strength", 0.0)
				m.set_shader_parameter(&"saturation", 0.55)
				m.set_shader_parameter(&"shade_tint", Color(0.30, 0.32, 0.36))
				m.set_shader_parameter(&"translucency", 0.1)
		_materials[look] = m
	return _materials[look]


static func has(species: StringName) -> bool:
	return SPECIES.has(species)


static func info(species: StringName) -> Dictionary:
	return SPECIES.get(species, {})


## The full-detail mesh for a species. Main thread (creates GPU resources).
static func mesh(species: StringName) -> Mesh:
	if not _near.has(species):
		_near[species] = _to_mesh(species, arrays_for(species, 1))
	return _near[species]


## A cheaper mesh for distance; trees and big shrubs only, null otherwise.
static func far_mesh(species: StringName) -> Mesh:
	if info(species).get("layer", "") != "tree":
		return null
	if not _far.has(species):
		_far[species] = _to_mesh(species, arrays_for(species, 0))
	return _far[species]


## True once mesh() for this species costs no more than an ArrayMesh upload.
static func has_mesh(species: StringName) -> bool:
	return _near.has(species)


## Surface arrays for a species at a detail level. Safe on worker threads:
## region builders call this off the main thread so mesh() is cheap later
## (species with a Blender model return [] there; they load on the main thread).
static func arrays_for(species: StringName, detail: int) -> Array:
	var key := "%s:%d" % [species, detail]
	_arrays_lock.lock()
	var cached: Variant = _arrays.get(key)
	_arrays_lock.unlock()
	if cached != null:
		return cached
	var arrays := []
	if has_model(species):
		# Loading a scene off the main thread deadlocks when the main thread
		# is waiting on that worker, so models load on the main thread only
		# (mesh() does it); a worker call is just a no-op warm-up.
		if OS.get_thread_caller_id() != OS.get_main_thread_id():
			return []
		arrays = _model_arrays(species, detail)
	if arrays.is_empty():
		var kit := MeshKit.new(hash(species))
		var builder := "_b_" + String(species)
		assert(_has_builder(builder), "No mesh builder for %s" % species)
		Callable(FloraLibrary, builder).call(kit, detail)
		arrays = kit.commit_arrays()
	_arrays_lock.lock()
	_arrays[key] = arrays
	_arrays_lock.unlock()
	return arrays


## Surface arrays from the species' Blender model (tools/woods/blender/),
## mesh "near" for detail 1 and "far" for 0; empty when there is no model.
static func _model_arrays(species: StringName, detail: int) -> Array:
	var path := MODELS % species
	if not ResourceLoader.exists(path):
		return []
	var root := (load(path) as PackedScene).instantiate()
	var mi := root.find_child("near" if detail > 0 else "far", true, false) as MeshInstance3D
	var arrays: Array = mi.mesh.surface_get_arrays(0) if mi != null else []
	root.free()
	return arrays


static func has_model(species: StringName) -> bool:
	return ResourceLoader.exists(MODELS % species)


static func _to_mesh(species: StringName, arrays: Array) -> ArrayMesh:
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	m.surface_set_material(0, material(look_of(species)))
	return m


static func _has_builder(builder: String) -> bool:
	for method in (FloraLibrary as Script).get_script_method_list():
		if method["name"] == builder:
			return true
	return false


# ---------------------------------------------------------------- helpers --

static func _canopy(kit: MeshKit, center: Vector3, spread: Vector3, blobs: int, size: float,
		col_top: Color, col_bottom: Color, detail: int, sway: float = 0.35) -> void:
	var n := blobs if detail > 0 else maxi(2, blobs / 3)
	for i in n:
		var off := Vector3(kit.rng.randf_range(-1, 1), kit.rng.randf_range(-0.5, 0.7), kit.rng.randf_range(-1, 1)) * spread
		var r := size * kit.rng.randf_range(0.75, 1.2) * (1.0 if detail > 0 else 1.5)
		var tint := kit.rng.randf_range(-0.05, 0.05)
		kit.blob(center + off, Vector3(r, r * 0.72, r), col_top.lightened(tint), col_bottom,
				0.22, 4 if detail > 0 else 3, 7 if detail > 0 else 5, sway)


static func _branches(kit: MeshKit, base: Vector3, count: int, length: float, radius: float,
		rise: float, col: Color, detail: int) -> Array[Vector3]:
	var tips: Array[Vector3] = []
	for i in count:
		var a := TAU * i / count + kit.rng.randf_range(-0.4, 0.4)
		var dir := Vector3(cos(a), rise + kit.rng.randf_range(-0.15, 0.25), sin(a)).normalized()
		var tip := base + dir * length * kit.rng.randf_range(0.75, 1.15)
		if detail > 0:
			kit.tube(base, tip, radius, radius * 0.35, 5, col, col, 0.0, 0.15)
		tips.append(tip)
	return tips


static func _bent_trunk(kit: MeshKit, height: float, r0: float, r1: float, col: Color, col_top: Color,
		detail: int, lean: float = 0.25) -> Vector3:
	var segs := 3 if detail > 0 else 1
	var p := Vector3.ZERO
	var dir := Vector3(kit.rng.randf_range(-lean, lean), 1.0, kit.rng.randf_range(-lean, lean)).normalized()
	for i in segs:
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var next := p + dir * height / segs
		kit.tube(p, next, lerpf(r0, r1, t0), lerpf(r0, r1, t1), 7 if detail > 0 else 5,
				col.lerp(col_top, t0), col.lerp(col_top, t1), 0.0, t1 * 0.08)
		p = next
		dir = (dir + Vector3(kit.rng.randf_range(-lean, lean), 0.0, kit.rng.randf_range(-lean, lean))).normalized()
	return p


static func _stem_flowers(kit: MeshKit, count: int, spread: float, height: Vector2, petal: Color,
		heart: Color, petals: int, radius: float, leaf_col: Color = LEAF) -> void:
	for i in count:
		var base := Vector3(kit.rng.randf_range(-spread, spread), 0.0, kit.rng.randf_range(-spread, spread))
		var h := kit.rng.randf_range(height.x, height.y)
		var top := base + Vector3(kit.rng.randf_range(-0.03, 0.03), h, kit.rng.randf_range(-0.03, 0.03))
		kit.blade(base, h, 0.012, top - base - Vector3.UP * h, leaf_col.darkened(0.15), leaf_col)
		kit.flower(top, petals, radius * kit.rng.randf_range(0.8, 1.2), petal, heart)
	for i in 3:
		kit.blade(Vector3(kit.rng.randf_range(-spread, spread), 0, kit.rng.randf_range(-spread, spread)),
				height.x * 0.6, 0.05, Vector3(kit.rng.randf_range(-0.05, 0.05), 0, 0.05), leaf_col.darkened(0.2), leaf_col)


static func _bush(kit: MeshKit, size: float, leaf: Color, bloom: Color, bloom_count: int,
		bloom_radius: float, detail: int, petals: int = 5) -> void:
	for i in 5:
		var off := Vector3(kit.rng.randf_range(-0.6, 0.6), kit.rng.randf_range(0.35, 0.75), kit.rng.randf_range(-0.6, 0.6)) * size
		var r := size * kit.rng.randf_range(0.35, 0.55)
		kit.blob(off, Vector3(r, r * 0.8, r), leaf, leaf.darkened(0.35), 0.25, 3, 6, 0.25)
	for i in bloom_count:
		var a := kit.rng.randf() * TAU
		var y := kit.rng.randf_range(0.3, 1.0)
		var p := Vector3(cos(a) * size * 0.75 * (1.1 - y * 0.4), y * size * 1.05, sin(a) * size * 0.75 * (1.1 - y * 0.4))
		kit.flower(p, petals, bloom_radius, bloom, bloom.darkened(0.3), (p - Vector3(0, size * 0.4, 0)).normalized(), 0.3)


# --------------------------------------------------------------- trees ----

static func _b_ancient_oak(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 7.5, 1.6, 1.0, BARK_DARK, BARK, detail, 0.1)
	if detail > 0:
		for i in 6:  # buttress roots, wide enough to walk along
			var a := TAU * i / 6 + kit.rng.randf_range(-0.3, 0.3)
			var out := Vector3(cos(a), 0.0, sin(a))
			kit.tube(out * 0.6 + Vector3.UP * 1.2, out * kit.rng.randf_range(3.5, 5.5) + Vector3.DOWN * 0.4,
					0.75, 0.2, 6, BARK_DARK, MOSS.darkened(0.3))
	var tips := _branches(kit, top, 6, 8.5, 0.65, 0.35, BARK, detail)
	for tip in tips:
		_canopy(kit, tip + Vector3.UP * 1.2, Vector3(2.8, 1.2, 2.8), 4, 3.4, LEAF_GOLD, LEAF_DEEP, detail)
	_canopy(kit, top + Vector3.UP * 4.0, Vector3(4.0, 1.5, 4.0), 5, 4.0, LEAF_GOLD, LEAF, detail)


static func _b_oak(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 5.0, 0.55, 0.35, BARK_DARK, BARK, detail)
	for tip in _branches(kit, top, 4, 4.5, 0.3, 0.5, BARK, detail):
		_canopy(kit, tip + Vector3.UP * 0.8, Vector3(1.6, 0.8, 1.6), 3, 2.3, LEAF.lightened(0.08), LEAF_DEEP, detail)
	_canopy(kit, top + Vector3.UP * 3.0, Vector3(2.0, 1.0, 2.0), 3, 2.6, LEAF_GOLD, LEAF, detail)


static func _b_beech(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 9.0, 0.45, 0.25, BARK_GREY, BARK_GREY.lightened(0.1), detail, 0.08)
	for tip in _branches(kit, top - Vector3.UP * 2.0, 5, 3.5, 0.2, 0.7, BARK_GREY, detail):
		_canopy(kit, tip + Vector3.UP * 0.5, Vector3(1.4, 1.0, 1.4), 3, 2.0, Color(0.49, 0.76, 0.60), LEAF, detail)
	_canopy(kit, top + Vector3.UP * 1.5, Vector3(1.8, 1.4, 1.8), 4, 2.4, Color(0.49, 0.76, 0.60), LEAF, detail)


static func _b_silver_birch(kit: MeshKit, detail: int) -> void:
	var white := Color(0.90, 0.88, 0.84)
	var h := 9.0
	var p := Vector3.ZERO
	var rings := 6 if detail > 0 else 2
	for i in rings:
		var next := p + Vector3(kit.rng.randf_range(-0.12, 0.12), h / rings, kit.rng.randf_range(-0.12, 0.12))
		var band := white if i % 2 == 0 or detail == 0 else white.darkened(0.55)
		kit.tube(p, next, lerpf(0.22, 0.08, float(i) / rings), lerpf(0.22, 0.08, float(i + 1) / rings),
				6 if detail > 0 else 4, band, white, 0.0, 0.1 * i / rings)
		p = next
	_canopy(kit, p - Vector3.UP * 2.0, Vector3(1.2, 2.0, 1.2), 6, 1.4, Color(0.71, 0.89, 0.75), Color(0.31, 0.60, 0.51), detail, 0.6)


static func _b_willow(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 4.0, 0.5, 0.35, BARK, BARK, detail, 0.3)
	var tips := _branches(kit, top, 5, 3.5, 0.22, 0.55, BARK, detail)
	for tip in tips:
		_canopy(kit, tip, Vector3(1.0, 0.5, 1.0), 2, 1.9, Color(0.49, 0.76, 0.60), LEAF, detail, 0.5)
		if detail > 0:
			for j in 7:  # hanging fronds
				var start := tip + Vector3(kit.rng.randf_range(-1.6, 1.6), -0.3, kit.rng.randf_range(-1.6, 1.6))
				var length := kit.rng.randf_range(2.5, 4.5)
				var yaw := kit.rng.randf() * TAU
				var right := Vector3(cos(yaw), 0, sin(yaw)) * 0.25
				kit.quad(start - right + Vector3.DOWN * length, start + right + Vector3.DOWN * length,
						start + right, start - right, Color(0.49, 0.76, 0.60), Color(0.55, 0.75, 0.48), 1.0, 0.3)


static func _b_alder(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 7.0, 0.3, 0.15, BARK_DARK, BARK_GREY, detail, 0.12)
	_canopy(kit, top - Vector3.UP * 1.5, Vector3(1.2, 2.2, 1.2), 6, 1.6, LEAF_DEEP.lightened(0.1), LEAF_DEEP, detail)


static func _b_elm(kit: MeshKit, detail: int) -> void:
	# Tall, vase-shaped: the trunk forks high and the crown spreads wide.
	var top := _bent_trunk(kit, 7.0, 0.45, 0.3, BARK_DARK, BARK, detail, 0.08)
	for tip in _branches(kit, top, 4, 5.0, 0.22, 0.85, BARK, detail):
		_canopy(kit, tip + Vector3.UP * 0.6, Vector3(1.8, 0.9, 1.8), 3, 2.0, LEAF.lightened(0.05), LEAF_DEEP, detail)


static func _b_hawthorn(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 2.6, 0.22, 0.14, BARK_DARK, BARK, detail, 0.4)
	for tip in _branches(kit, top, 4, 1.8, 0.1, 0.45, BARK_DARK, detail):
		_canopy(kit, tip, Vector3(0.7, 0.4, 0.7), 2, 1.1, LEAF.darkened(0.1), LEAF_DEEP, detail)
		if detail > 0:
			for j in 10:
				var p := tip + Vector3(kit.rng.randf_range(-1, 1), kit.rng.randf_range(0.2, 0.8), kit.rng.randf_range(-1, 1))
				kit.flower(p, 5, 0.09, CREAM if j % 3 else Color(0.95, 0.72, 0.78), GOLD, Vector3.UP, 0.4)
		else:
			kit.blob(tip + Vector3.UP * 0.6, Vector3(0.9, 0.5, 0.9), CREAM, CREAM.darkened(0.2), 0.2, 3, 5, 0.3)


static func _b_wild_cherry(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 4.0, 0.3, 0.2, Color(0.38, 0.22, 0.20), Color(0.42, 0.26, 0.22), detail, 0.2)
	var pink := Color(0.98, 0.76, 0.84)
	for tip in _branches(kit, top, 5, 3.0, 0.15, 0.45, Color(0.38, 0.22, 0.20), detail):
		_canopy(kit, tip + Vector3.UP * 0.4, Vector3(1.0, 0.5, 1.0), 3, 1.5, pink, pink.darkened(0.25), detail, 0.4)


static func _b_elder(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 2.4, 0.15, 0.1, BARK, BARK, detail, 0.35)
	for tip in _branches(kit, top, 4, 1.6, 0.08, 0.4, BARK, detail):
		_canopy(kit, tip, Vector3(0.6, 0.3, 0.6), 2, 0.9, LEAF, LEAF_DEEP, detail)
		if detail > 0:
			for j in 4:  # flat cream umbels: elderflower
				kit.flower(tip + Vector3(kit.rng.randf_range(-0.8, 0.8), 0.6, kit.rng.randf_range(-0.8, 0.8)),
						9, 0.16, CREAM, CREAM.darkened(0.1), Vector3.UP, 0.4)


static func _b_twisted_dead(kit: MeshKit, detail: int) -> void:
	# Bogge territory: black, leafless, too many joints.
	var col := Color(0.16, 0.15, 0.15)
	var top := _bent_trunk(kit, 6.5, 0.5, 0.2, col, Color(0.24, 0.23, 0.23), detail, 0.55)
	var tips := _branches(kit, top, 6, 3.5, 0.18, 0.15, col, detail)
	if detail > 0:
		for tip in tips:
			for j in 2:
				var to := tip + Vector3(kit.rng.randf_range(-1.5, 1.5), kit.rng.randf_range(-0.8, 1.2), kit.rng.randf_range(-1.5, 1.5))
				kit.tube(tip, to, 0.07, 0.02, 4, col, col, 0.1, 0.3)
	else:
		for tip in tips:
			kit.tube(top, tip, 0.15, 0.04, 3, col, col)


static func _b_blighted_tree(kit: MeshKit, detail: int) -> void:
	var top := _bent_trunk(kit, 5.5, 0.45, 0.28, BARK_GREY.darkened(0.2), BARK_GREY, detail, 0.25)
	for tip in _branches(kit, top, 4, 3.5, 0.22, 0.4, BARK_GREY, detail):
		_canopy(kit, tip, Vector3(1.2, 0.5, 1.2), 2, 1.3, GREY_LEAF, GREY_LEAF.darkened(0.3), detail)


# -------------------------------------------------------------- shrubs ----

static func _b_fern(kit: MeshKit, _detail: int) -> void:
	for i in 9:
		var a := TAU * i / 9 + kit.rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(a), 0, sin(a))
		var length := kit.rng.randf_range(0.7, 1.1)
		var mid := out * length * 0.5 + Vector3.UP * length * 0.55
		var tip := out * length + Vector3.UP * length * 0.25
		var side := out.cross(Vector3.UP) * 0.16
		var c0 := Color(0.24, 0.44, 0.47)
		var c1 := Color(0.55, 0.75, 0.48)
		kit.quad(Vector3.ZERO - side * 0.2, Vector3.ZERO + side * 0.2, mid + side, mid - side, c0, c1, 0.0, 0.6)
		kit.quad(mid - side, mid + side, tip + side * 0.1, tip - side * 0.1, c1, c1.lightened(0.1), 0.6, 1.0)


static func _b_bracken(kit: MeshKit, _detail: int) -> void:
	for i in 5:
		var base := Vector3(kit.rng.randf_range(-0.3, 0.3), 0, kit.rng.randf_range(-0.3, 0.3))
		var h := kit.rng.randf_range(0.9, 1.3)
		kit.blade(base, h, 0.02, Vector3(kit.rng.randf_range(-0.1, 0.1), 0, 0.1), Color(0.40, 0.42, 0.16), Color(0.31, 0.60, 0.51))
		var top := base + Vector3.UP * h
		for j in 3:
			var a := kit.rng.randf() * TAU
			var out := Vector3(cos(a), -0.2, sin(a)) * 0.5
			var side := Vector3(-sin(a), 0, cos(a)) * 0.18
			kit.quad(top - side * 0.3, top + side * 0.3, top + out + side, top + out - side,
					Color(0.31, 0.60, 0.51), Color(0.49, 0.76, 0.60), 0.7, 1.0)


static func _b_rose_bush_red(kit: MeshKit, detail: int) -> void:
	_bush(kit, 0.9, LEAF_DEEP, ROSE, 16, 0.07, detail, 6)


static func _b_rose_bush_white(kit: MeshKit, detail: int) -> void:
	_bush(kit, 0.9, LEAF_DEEP, CREAM, 16, 0.07, detail, 6)


static func _b_bramble(kit: MeshKit, detail: int) -> void:
	_bush(kit, 0.8, Color(0.24, 0.44, 0.47), CREAM.lerp(ROSE, 0.15), 8, 0.04, detail)
	for i in 12:  # blackberries
		var a := kit.rng.randf() * TAU
		var p := Vector3(cos(a) * 0.6, kit.rng.randf_range(0.3, 0.8), sin(a) * 0.6)
		kit.blob(p, Vector3.ONE * 0.035, Color(0.12, 0.06, 0.15), Color(0.25, 0.05, 0.12), 0.1, 2, 4, 0.3)


static func _b_honeysuckle_bush(kit: MeshKit, detail: int) -> void:
	_bush(kit, 0.85, LEAF, Color(0.99, 0.88, 0.62), 18, 0.05, detail, 4)


static func _b_hazel(kit: MeshKit, detail: int) -> void:
	for i in 6:
		var to := Vector3(kit.rng.randf_range(-0.8, 0.8), kit.rng.randf_range(2.2, 3.2), kit.rng.randf_range(-0.8, 0.8))
		kit.tube(Vector3.ZERO, to, 0.06, 0.03, 4, BARK, BARK.lightened(0.1), 0.0, 0.3)
		kit.blob(to, Vector3(0.7, 0.5, 0.7), LEAF.lightened(0.05), LEAF_DEEP, 0.25, 3, 6, 0.4)
	if detail > 0:
		for i in 10:  # catkins
			var p := Vector3(kit.rng.randf_range(-1, 1), kit.rng.randf_range(1.6, 2.8), kit.rng.randf_range(-1, 1))
			kit.tube(p, p + Vector3.DOWN * 0.12, 0.012, 0.008, 3, GOLD, GOLD, 0.6, 0.8)


static func _b_thornbriar(kit: MeshKit, _detail: int) -> void:
	var dark := Color(0.18, 0.20, 0.12)
	for i in 14:
		var from := Vector3(kit.rng.randf_range(-0.5, 0.5), 0, kit.rng.randf_range(-0.5, 0.5))
		var to := from + Vector3(kit.rng.randf_range(-1.2, 1.2), kit.rng.randf_range(0.5, 1.6), kit.rng.randf_range(-1.2, 1.2))
		kit.tube(from, to, 0.04, 0.015, 4, dark, dark.lightened(0.1), 0.0, 0.25)
		for j in 4:  # thorns
			var p := from.lerp(to, kit.rng.randf())
			kit.tube(p, p + Vector3(kit.rng.randf_range(-1, 1), kit.rng.randf_range(-0.2, 0.6), kit.rng.randf_range(-1, 1)).normalized() * 0.07,
					0.012, 0.0, 3, dark, Color(0.5, 0.42, 0.3), 0.2, 0.25)
	for i in 4:
		kit.flower(Vector3(kit.rng.randf_range(-0.8, 0.8), kit.rng.randf_range(0.6, 1.3), kit.rng.randf_range(-0.8, 0.8)),
				5, 0.06, ROSE.lightened(0.25), GOLD, Vector3.UP, 0.25)


static func _b_foxglove(kit: MeshKit, _detail: int) -> void:
	for s in 3:
		var base := Vector3(kit.rng.randf_range(-0.2, 0.2), 0, kit.rng.randf_range(-0.2, 0.2))
		var h := kit.rng.randf_range(0.9, 1.4)
		kit.tube(base, base + Vector3.UP * h, 0.015, 0.008, 4, LEAF, LEAF, 0.0, 1.0)
		var col: Color = [Color(0.80, 0.42, 0.72), Color(0.92, 0.70, 0.86), CREAM][s % 3]
		for b in 9:
			var t := 0.45 + 0.55 * b / 9.0
			var a := kit.rng.randf() * TAU
			kit.bell(base + Vector3.UP * h * t + Vector3(cos(a), 0, sin(a)) * 0.03, 0.06, 0.03, col, col.darkened(0.4), t)
	for i in 6:
		kit.blade(Vector3.ZERO, 0.25, 0.12, Vector3(kit.rng.randf_range(-0.3, 0.3), 0, kit.rng.randf_range(-0.3, 0.3)), LEAF_DEEP, LEAF)


static func _b_reed_clump(kit: MeshKit, _detail: int) -> void:
	for i in 22:
		var base := Vector3(kit.rng.randf_range(-0.5, 0.5), 0, kit.rng.randf_range(-0.5, 0.5))
		kit.blade(base, kit.rng.randf_range(1.4, 2.4), 0.035, Vector3(kit.rng.randf_range(-0.3, 0.3), 0, kit.rng.randf_range(-0.3, 0.3)),
				Color(0.24, 0.44, 0.47), Color(0.70, 0.66, 0.40))


static func _b_cattail(kit: MeshKit, _detail: int) -> void:
	for i in 8:
		var base := Vector3(kit.rng.randf_range(-0.35, 0.35), 0, kit.rng.randf_range(-0.35, 0.35))
		var h := kit.rng.randf_range(1.5, 2.1)
		kit.tube(base, base + Vector3.UP * h, 0.012, 0.008, 3, LEAF, LEAF, 0.0, 1.0)
		kit.tube(base + Vector3.UP * (h - 0.35), base + Vector3.UP * (h - 0.05), 0.035, 0.03, 5,
				Color(0.36, 0.22, 0.12), Color(0.36, 0.22, 0.12), 0.85, 1.0)
		kit.blade(base, h * 0.9, 0.03, Vector3(0.2, 0, 0.1), LEAF_DEEP, LEAF)


static func _b_boulder(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 0.35, 0), Vector3(1.0, 0.75, 0.85), Color(0.58, 0.56, 0.50), Color(0.40, 0.38, 0.34), 0.25, 5, 8)
	kit.blob(Vector3(0.1, 0.9, 0.0), Vector3(0.75, 0.22, 0.6), MOSS.lightened(0.1), MOSS.darkened(0.2), 0.3, 3, 7)


static func _b_mossy_rock(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 0.15, 0), Vector3(0.6, 0.4, 0.5), MOSS, Color(0.42, 0.40, 0.36), 0.3, 4, 7)


static func _b_standing_stone(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 1.4, 0), Vector3(0.45, 1.6, 0.3), Color(0.62, 0.60, 0.56), Color(0.45, 0.48, 0.38), 0.12, 5, 6)
	kit.blob(Vector3(0, 0.3, 0), Vector3(0.55, 0.35, 0.4), MOSS, MOSS.darkened(0.3), 0.3, 3, 6)


static func _b_fallen_log(kit: MeshKit, _detail: int) -> void:
	var a := Vector3(-2.2, 0.35, 0)
	var b := Vector3(2.2, 0.3, 0.2)
	kit.tube(a, b, 0.4, 0.33, 8, BARK_DARK, BARK, 0.0, 0.0)
	kit.blob((a + b) * 0.5 + Vector3.UP * 0.32, Vector3(1.8, 0.14, 0.35), MOSS.lightened(0.1), MOSS, 0.3, 3, 7)
	for i in 5:
		var p := a.lerp(b, kit.rng.randf()) + Vector3(0, 0.1, 0.38)
		kit.blob(p, Vector3(0.09, 0.03, 0.09), Color(0.85, 0.66, 0.40), Color(0.6, 0.42, 0.25), 0.1, 2, 5)


static func _b_root_arch(kit: MeshKit, _detail: int) -> void:
	# Exposed roots looping out of the ground: the "roots as paths" motif.
	for i in 4:
		var z := kit.rng.randf_range(-1.0, 1.0)
		var span := kit.rng.randf_range(2.5, 4.0)
		var h := kit.rng.randf_range(0.6, 1.4)
		var pts := [Vector3(-span, -0.3, z), Vector3(-span * 0.4, h, z + 0.2), Vector3(span * 0.4, h * 0.8, z - 0.2), Vector3(span, -0.3, z)]
		for j in 3:
			kit.tube(pts[j], pts[j + 1], 0.22, 0.2, 6, BARK_DARK, BARK_DARK.lerp(MOSS, 0.4))


static func _b_moss_mound(kit: MeshKit, _detail: int) -> void:
	for i in 3:
		var off := Vector3(kit.rng.randf_range(-0.4, 0.4), 0, kit.rng.randf_range(-0.4, 0.4))
		kit.blob(off, Vector3(0.55, 0.25, 0.5), MOSS.lightened(0.12), MOSS.darkened(0.2), 0.25, 3, 7)


static func _b_pale_fungus(kit: MeshKit, _detail: int) -> void:
	var pale := Color(0.82, 0.80, 0.74)
	for i in 7:
		var base := Vector3(kit.rng.randf_range(-0.4, 0.4), 0, kit.rng.randf_range(-0.4, 0.4))
		var h := kit.rng.randf_range(0.08, 0.3)
		kit.tube(base, base + Vector3.UP * h, 0.02, 0.025, 5, pale, pale)
		kit.blob(base + Vector3.UP * h, Vector3(0.09, 0.03, 0.09) * kit.rng.randf_range(0.8, 1.8), pale, pale.darkened(0.4), 0.1, 2, 6)


static func _b_withered_bush(kit: MeshKit, detail: int) -> void:
	_bush(kit, 0.8, Color(0.42, 0.42, 0.36), Color(0.62, 0.60, 0.60), 8, 0.06, detail, 5)


# ------------------------------------------------------- ground cover -----

static func _b_grass_tuft(kit: MeshKit, _detail: int) -> void:
	for i in 9:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		kit.blade(base, kit.rng.randf_range(0.25, 0.45), 0.05, Vector3(kit.rng.randf_range(-0.1, 0.1), 0, kit.rng.randf_range(-0.1, 0.1)),
				Color(0.24, 0.44, 0.47), Color(0.49, 0.76, 0.60))


static func _b_tall_grass(kit: MeshKit, _detail: int) -> void:
	for i in 10:
		var base := Vector3(kit.rng.randf_range(-0.2, 0.2), 0, kit.rng.randf_range(-0.2, 0.2))
		kit.blade(base, kit.rng.randf_range(0.6, 0.95), 0.04, Vector3(kit.rng.randf_range(-0.2, 0.2), 0, kit.rng.randf_range(-0.2, 0.2)),
				Color(0.24, 0.44, 0.47), Color(0.74, 0.74, 0.40))


static func _b_bluebell(kit: MeshKit, _detail: int) -> void:
	for s in 5:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		var h := kit.rng.randf_range(0.22, 0.34)
		var top := base + Vector3(0.05, h, 0)
		kit.blade(base, h, 0.01, Vector3(0.05, 0, 0), LEAF, LEAF)
		for b in 4:
			kit.bell(top + Vector3(0.0, -0.035 * b, 0.02 * (b % 2)), 0.035, 0.018, BLUEBELL, BLUEBELL.darkened(0.3))
		kit.blade(base, h * 0.8, 0.03, Vector3(-0.1, 0, 0.05), LEAF_DEEP, LEAF)


static func _b_crocus(kit: MeshKit, _detail: int) -> void:
	for s in 5:
		var base := Vector3(kit.rng.randf_range(-0.12, 0.12), 0, kit.rng.randf_range(-0.12, 0.12))
		var col: Color = [LILAC, Color(0.98, 0.86, 0.40), CREAM, Color(0.62, 0.42, 0.90)][s % 4]
		kit.blade(base, 0.08, 0.015, Vector3.ZERO, LEAF, LEAF)
		kit.flower(base + Vector3.UP * 0.09, 6, 0.025, col, GOLD, Vector3(0.0, 1.0, 0.25), 0.8)
	for i in 4:
		kit.blade(Vector3.ZERO, 0.12, 0.012, Vector3(kit.rng.randf_range(-0.05, 0.05), 0, 0.03), LEAF_DEEP, LEAF)


static func _b_snowdrop(kit: MeshKit, _detail: int) -> void:
	for s in 4:
		var base := Vector3(kit.rng.randf_range(-0.1, 0.1), 0, kit.rng.randf_range(-0.1, 0.1))
		var h := kit.rng.randf_range(0.12, 0.18)
		kit.blade(base, h, 0.01, Vector3(0.03, 0, 0), LEAF, LEAF)
		kit.bell(base + Vector3(0.03, h, 0), 0.03, 0.016, Color(1.0, 1.0, 0.98), Color(0.75, 0.95, 0.80))


static func _b_wood_anemone(kit: MeshKit, _detail: int) -> void:
	_stem_flowers(kit, 5, 0.15, Vector2(0.1, 0.18), Color(0.99, 0.97, 0.95), GOLD, 6, 0.03)


static func _b_primrose(kit: MeshKit, _detail: int) -> void:
	for i in 6:
		kit.blade(Vector3.ZERO, 0.1, 0.07, Vector3(kit.rng.randf_range(-0.12, 0.12), 0, kit.rng.randf_range(-0.12, 0.12)), LEAF_DEEP, LEAF)
	_stem_flowers(kit, 5, 0.06, Vector2(0.08, 0.12), Color(0.98, 0.93, 0.62), Color(0.95, 0.70, 0.25), 5, 0.03)


static func _b_violet(kit: MeshKit, _detail: int) -> void:
	_stem_flowers(kit, 5, 0.1, Vector2(0.06, 0.1), Color(0.50, 0.32, 0.78), CREAM, 5, 0.022, LEAF_DEEP)


static func _b_buttercup(kit: MeshKit, _detail: int) -> void:
	_stem_flowers(kit, 6, 0.18, Vector2(0.2, 0.35), Color(1.0, 0.86, 0.15), Color(0.9, 0.7, 0.1), 5, 0.025)


static func _b_daisy(kit: MeshKit, _detail: int) -> void:
	_stem_flowers(kit, 7, 0.2, Vector2(0.06, 0.12), Color(1.0, 1.0, 0.98), GOLD, 10, 0.022)


static func _b_cowslip(kit: MeshKit, _detail: int) -> void:
	for s in 3:
		var base := Vector3(kit.rng.randf_range(-0.1, 0.1), 0, kit.rng.randf_range(-0.1, 0.1))
		var h := kit.rng.randf_range(0.18, 0.26)
		kit.blade(base, h, 0.012, Vector3.ZERO, LEAF, LEAF)
		for b in 5:
			kit.bell(base + Vector3(0.02 * cos(b * 1.3), h, 0.02 * sin(b * 1.3)), 0.03, 0.014, GOLD, GOLD.darkened(0.2))


static func _b_wild_garlic(kit: MeshKit, _detail: int) -> void:
	for i in 7:
		kit.blade(Vector3.ZERO, 0.22, 0.07, Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15)), LEAF, LEAF.lightened(0.15))
	for i in 3:
		var p := Vector3(kit.rng.randf_range(-0.08, 0.08), 0.3, kit.rng.randf_range(-0.08, 0.08))
		kit.tube(p * Vector3(1, 0, 1), p, 0.008, 0.006, 3, LEAF, LEAF, 0.0, 1.0)
		for j in 6:
			kit.flower(p + Vector3(kit.rng.randf_range(-0.03, 0.03), 0.01, kit.rng.randf_range(-0.03, 0.03)), 6, 0.015, Color.WHITE, CREAM)


static func _b_clover(kit: MeshKit, _detail: int) -> void:
	for i in 10:
		var p := Vector3(kit.rng.randf_range(-0.2, 0.2), kit.rng.randf_range(0.02, 0.06), kit.rng.randf_range(-0.2, 0.2))
		kit.flower(p, 3, 0.03, Color(0.31, 0.60, 0.51), Color(0.24, 0.44, 0.47), Vector3.UP, 0.4)
	kit.flower(Vector3(0, 0.1, 0), 12, 0.02, Color(0.95, 0.80, 0.90), Color(0.9, 0.6, 0.75), Vector3.UP, 0.6)


static func _b_moss_patch(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3.ZERO, Vector3(0.45, 0.06, 0.4), MOSS.lightened(0.15), MOSS.darkened(0.2), 0.3, 2, 7)


static func _b_leaf_litter(kit: MeshKit, _detail: int) -> void:
	for i in 10:
		var p := Vector3(kit.rng.randf_range(-0.35, 0.35), 0.02, kit.rng.randf_range(-0.35, 0.35))
		var col: Color = [Color(0.55, 0.38, 0.18), Color(0.62, 0.50, 0.24), Color(0.42, 0.30, 0.16)][i % 3]
		kit.flower(p, 2, 0.05, col, col.darkened(0.2), Vector3(kit.rng.randf_range(-0.3, 0.3), 1, kit.rng.randf_range(-0.3, 0.3)), 0.0)


static func _b_faelight_dandelion(kit: MeshKit, _detail: int) -> void:
	# Seed heads that glow: the Border Woods' signature at dusk.
	for s in 4:
		var base := Vector3(kit.rng.randf_range(-0.12, 0.12), 0, kit.rng.randf_range(-0.12, 0.12))
		var h := kit.rng.randf_range(0.25, 0.4)
		kit.tube(base, base + Vector3.UP * h, 0.008, 0.006, 3, LEAF, LEAF, 0.0, 1.0)
		kit.blob(base + Vector3.UP * h, Vector3.ONE * 0.045, FAELIGHT, Color(0.7, 0.85, 0.95), 0.15, 3, 6, 1.0, 1.0)
	for i in 5:
		kit.blade(Vector3.ZERO, 0.12, 0.05, Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15)), LEAF_DEEP, LEAF)


static func _b_glowcap(kit: MeshKit, _detail: int) -> void:
	for i in 6:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		var h := kit.rng.randf_range(0.05, 0.14)
		var cap := Color(0.55, 0.95, 0.80)
		kit.tube(base, base + Vector3.UP * h, 0.012, 0.012, 4, CREAM, CREAM, 0.0, 0.0)
		kit.blob(base + Vector3.UP * h, Vector3(0.045, 0.025, 0.045), cap, cap.darkened(0.3), 0.1, 2, 6, 0.0, 0.8)


static func _b_toadstools(kit: MeshKit, _detail: int) -> void:
	for i in 4:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		var h := kit.rng.randf_range(0.06, 0.15)
		kit.tube(base, base + Vector3.UP * h, 0.015, 0.012, 4, CREAM, CREAM)
		kit.blob(base + Vector3.UP * h, Vector3(0.06, 0.035, 0.06), Color(0.82, 0.20, 0.15), Color(0.95, 0.9, 0.8), 0.1, 2, 6)


static func _b_lily_pad(kit: MeshKit, _detail: int) -> void:
	for i in 4:
		var c := Vector3(kit.rng.randf_range(-0.4, 0.4), 0.02, kit.rng.randf_range(-0.4, 0.4))
		kit.flower(c, 8, 0.18, Color(0.24, 0.44, 0.47), Color(0.24, 0.44, 0.47), Vector3.UP, 0.2)
	kit.flower(Vector3(0, 0.06, 0), 8, 0.08, Color(0.98, 0.86, 0.92), GOLD, Vector3.UP, 0.2)


static func _b_pebbles(kit: MeshKit, _detail: int) -> void:
	for i in 6:
		var p := Vector3(kit.rng.randf_range(-0.3, 0.3), 0.02, kit.rng.randf_range(-0.3, 0.3))
		var g := kit.rng.randf_range(0.45, 0.7)
		kit.blob(p, Vector3(0.06, 0.03, 0.05) * kit.rng.randf_range(0.7, 1.6), Color(g, g * 0.97, g * 0.92), Color(g, g, g).darkened(0.3), 0.15, 2, 5)


static func _b_grey_grass(kit: MeshKit, _detail: int) -> void:
	for i in 8:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		kit.blade(base, kit.rng.randf_range(0.2, 0.4), 0.05, Vector3(kit.rng.randf_range(-0.2, 0.2), -0.05, kit.rng.randf_range(-0.2, 0.2)),
				Color(0.36, 0.36, 0.32), Color(0.60, 0.58, 0.52))


static func _b_dead_leaves(kit: MeshKit, _detail: int) -> void:
	for i in 12:
		var p := Vector3(kit.rng.randf_range(-0.4, 0.4), 0.02, kit.rng.randf_range(-0.4, 0.4))
		var col := Color(0.30, 0.27, 0.24).lightened(kit.rng.randf_range(0.0, 0.15))
		kit.flower(p, 2, 0.05, col, col.darkened(0.2), Vector3(kit.rng.randf_range(-0.3, 0.3), 1, kit.rng.randf_range(-0.3, 0.3)), 0.0)


static func _b_meadowsweet(kit: MeshKit, _detail: int) -> void:
	for s in 4:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		var h := kit.rng.randf_range(0.6, 0.9)
		kit.tube(base, base + Vector3.UP * h, 0.01, 0.006, 3, LEAF, LEAF, 0.0, 1.0)
		kit.blob(base + Vector3.UP * h, Vector3(0.08, 0.06, 0.08), CREAM, CREAM.darkened(0.15), 0.3, 2, 6, 1.0)


static func _b_water_mint(kit: MeshKit, _detail: int) -> void:
	for s in 5:
		var base := Vector3(kit.rng.randf_range(-0.15, 0.15), 0, kit.rng.randf_range(-0.15, 0.15))
		var h := kit.rng.randf_range(0.2, 0.35)
		kit.blade(base, h, 0.06, Vector3.ZERO, LEAF_DEEP, LEAF)
		kit.blob(base + Vector3.UP * h, Vector3(0.03, 0.04, 0.03), LILAC, LILAC.darkened(0.2), 0.2, 2, 5, 1.0)


# ---------------------------------------------------------------- finds ---

static func _feather(kit: MeshKit, base: Color, tip: Color, banded: bool) -> void:
	var length := 0.22
	var root := Vector3(-length * 0.5, 0.012, 0)
	kit.tube(root, root + Vector3(length, 0.0, 0.0), 0.004, 0.002, 3, CREAM, CREAM)
	for i in 6:
		var t0 := 0.1 + 0.9 * i / 6.0
		var t1 := 0.1 + 0.9 * (i + 1) / 6.0
		var w0 := 0.03 * sin(PI * t0 * 0.9 + 0.2)
		var w1 := 0.03 * sin(PI * t1 * 0.9 + 0.2)
		var col := base.lerp(tip, t0)
		if banded and i % 2 == 1:
			col = col.darkened(0.45)
		var a := root + Vector3(length * t0, 0, 0)
		var b := root + Vector3(length * t1, 0, 0)
		kit.quad(a + Vector3(0, 0, -w0), b + Vector3(0, 0, -w1), b + Vector3(0, 0, w1), a + Vector3(0, 0, w0), col, col, 0.0, 0.0)


static func _b_feather_hawk(kit: MeshKit, _detail: int) -> void:
	_feather(kit, Color(0.55, 0.38, 0.22), Color(0.80, 0.68, 0.50), true)


static func _b_feather_owl(kit: MeshKit, _detail: int) -> void:
	_feather(kit, Color(0.80, 0.74, 0.62), Color(0.62, 0.52, 0.40), true)


static func _b_feather_jay(kit: MeshKit, _detail: int) -> void:
	_feather(kit, Color(0.20, 0.40, 0.85), Color(0.95, 0.97, 1.0), true)


static func _b_snail_shell(kit: MeshKit, _detail: int) -> void:
	for i in 4:
		var r := 0.025 * (1.0 - i * 0.2)
		kit.blob(Vector3(i * 0.008, 0.02 + i * 0.008, 0), Vector3(r, r, r), Color(0.95, 0.90, 0.78), Color(0.65, 0.48, 0.30), 0.05, 3, 6)


static func _b_odd_stone(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 0.03, 0), Vector3(0.05, 0.03, 0.04), Color(0.40, 0.62, 0.66), Color(0.30, 0.40, 0.48), 0.1, 3, 6)
	kit.tube(Vector3(-0.05, 0.035, 0), Vector3(0.05, 0.035, 0), 0.031, 0.031, 6, CREAM, CREAM)


static func _b_painted_pebble(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 0.025, 0), Vector3(0.05, 0.025, 0.04), Color(0.92, 0.88, 0.80), Color(0.6, 0.58, 0.52), 0.05, 3, 6)
	kit.flower(Vector3(0, 0.05, 0), 5, 0.025, ROSE, GOLD, Vector3.UP, 0.0)


static func _b_river_glass(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 0.015, 0), Vector3(0.035, 0.015, 0.025), Color(0.55, 0.85, 0.70), Color(0.40, 0.70, 0.60), 0.1, 2, 5, 0.0, 0.25)


static func _b_shed_antler(kit: MeshKit, _detail: int) -> void:
	var bone := Color(0.85, 0.78, 0.64)
	var a := Vector3(-0.3, 0.05, 0)
	var b := Vector3(0.1, 0.08, 0.1)
	var c := Vector3(0.4, 0.12, 0.0)
	kit.tube(a, b, 0.03, 0.025, 5, bone.darkened(0.2), bone)
	kit.tube(b, c, 0.025, 0.012, 5, bone, bone)
	kit.tube(b, b + Vector3(0.05, 0.25, 0.08), 0.02, 0.008, 4, bone, bone)
	kit.tube(a.lerp(b, 0.4), a.lerp(b, 0.4) + Vector3(0.0, 0.2, -0.05), 0.02, 0.008, 4, bone, bone)


static func _b_egg_shell(kit: MeshKit, _detail: int) -> void:
	var blue := Color(0.62, 0.82, 0.86)
	kit.blob(Vector3(0, 0.02, 0), Vector3(0.018, 0.022, 0.018), blue, blue.darkened(0.15), 0.05, 3, 6)
	kit.blob(Vector3(0.04, 0.012, 0.01), Vector3(0.016, 0.012, 0.016), blue, blue.darkened(0.15), 0.1, 2, 5)


static func _b_acorn_caps(kit: MeshKit, _detail: int) -> void:
	for i in 5:
		var p := Vector3(kit.rng.randf_range(-0.06, 0.06), 0.012, kit.rng.randf_range(-0.06, 0.06))
		kit.blob(p, Vector3(0.014, 0.01, 0.014), Color(0.55, 0.42, 0.25), Color(0.40, 0.30, 0.18), 0.15, 2, 6)
		if i % 2 == 0:
			kit.blob(p + Vector3(0, 0.012, 0), Vector3(0.011, 0.016, 0.011), Color(0.62, 0.50, 0.22), Color(0.5, 0.4, 0.2), 0.05, 2, 6)


static func _b_old_arrowhead(kit: MeshKit, _detail: int) -> void:
	var iron := Color(0.36, 0.32, 0.30)
	kit.tri(Vector3(-0.03, 0.01, -0.02), Vector3(0.05, 0.01, 0), Vector3(-0.03, 0.01, 0.02), iron, iron.lightened(0.2), iron)
	kit.tube(Vector3(-0.03, 0.01, 0), Vector3(-0.2, 0.012, 0.01), 0.005, 0.005, 3, BARK, BARK)


static func _b_mask_ribbon(kit: MeshKit, _detail: int) -> void:
	# A strip of court ribbon caught on a twig: the masked court's trace.
	var green := Color(0.15, 0.55, 0.38)
	kit.tube(Vector3(0, 0, 0), Vector3(0.05, 0.4, 0.02), 0.01, 0.006, 3, BARK, BARK)
	var p := Vector3(0.04, 0.35, 0.02)
	for i in 4:
		var q := p + Vector3(0.08, -0.05 - 0.03 * i, 0.02 * sin(i))
		kit.quad(p, q, q + Vector3(0, 0.025, 0), p + Vector3(0, 0.025, 0), green, GOLD.lerp(green, 0.6), 0.5, 1.0)
		p = q


static func _b_wild_hive(kit: MeshKit, _detail: int) -> void:
	kit.tube(Vector3(0, 0, 0), Vector3(0.1, 1.2, 0.0), 0.12, 0.08, 6, BARK_DARK, BARK)
	kit.blob(Vector3(0.18, 0.9, 0), Vector3(0.16, 0.24, 0.14), Color(0.88, 0.68, 0.30), Color(0.62, 0.42, 0.18), 0.12, 4, 7)


static func _b_bark_strip(kit: MeshKit, _detail: int) -> void:
	kit.tube(Vector3(0, 0, 0), Vector3(0.0, 1.2, 0.1), 0.28, 0.22, 7, Color(0.48, 0.42, 0.32), Color(0.45, 0.40, 0.30))
	kit.quad(Vector3(0.25, 0.4, -0.1), Vector3(0.3, 0.4, 0.12), Vector3(0.32, 0.9, 0.12), Vector3(0.27, 0.9, -0.1),
			Color(0.78, 0.62, 0.42), Color(0.80, 0.66, 0.44), 0.0, 0.0)


static func _b_oak_gall_twig(kit: MeshKit, _detail: int) -> void:
	kit.tube(Vector3(0, 0, 0), Vector3(0.1, 0.6, 0), 0.015, 0.008, 4, BARK, BARK, 0.0, 0.6)
	for i in 3:
		kit.blob(Vector3(0.03 * i, 0.2 + 0.15 * i, 0.02), Vector3.ONE * 0.025, Color(0.70, 0.55, 0.32), Color(0.5, 0.38, 0.2), 0.08, 3, 6, 0.4)
	for i in 4:
		kit.blade(Vector3(0.04, 0.3 + 0.07 * i, 0), 0.08, 0.05, Vector3(0.06, 0, 0.02), LEAF_DEEP, LEAF)


static func _b_silt_patch(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3(0, 0.0, 0), Vector3(0.5, 0.03, 0.4), Color(0.62, 0.48, 0.28), Color(0.45, 0.34, 0.20), 0.2, 2, 7)


static func _b_sap_briar(kit: MeshKit, detail: int) -> void:
	_b_thornbriar(kit, detail)
	for i in 6:
		var p := Vector3(kit.rng.randf_range(-0.5, 0.5), kit.rng.randf_range(0.3, 1.0), kit.rng.randf_range(-0.5, 0.5))
		kit.blob(p, Vector3(0.025, 0.035, 0.025), Color(0.95, 0.62, 0.12), Color(0.7, 0.35, 0.05), 0.05, 2, 5, 0.25, 0.3)


static func _b_strawberry_patch(kit: MeshKit, _detail: int) -> void:
	for i in 8:
		kit.flower(Vector3(kit.rng.randf_range(-0.2, 0.2), 0.05, kit.rng.randf_range(-0.2, 0.2)), 3, 0.05, LEAF, LEAF_DEEP, Vector3.UP, 0.3)
	for i in 6:
		kit.blob(Vector3(kit.rng.randf_range(-0.18, 0.18), 0.04, kit.rng.randf_range(-0.18, 0.18)), Vector3(0.015, 0.02, 0.015),
				Color(0.92, 0.12, 0.15), Color(0.7, 0.08, 0.1), 0.1, 2, 5)
	for i in 3:
		kit.flower(Vector3(kit.rng.randf_range(-0.15, 0.15), 0.08, kit.rng.randf_range(-0.15, 0.15)), 5, 0.015, Color.WHITE, GOLD)


static func _b_madder_root(kit: MeshKit, _detail: int) -> void:
	for i in 5:
		kit.blade(Vector3.ZERO, 0.45, 0.03, Vector3(kit.rng.randf_range(-0.2, 0.2), 0, kit.rng.randf_range(-0.2, 0.2)), LEAF, LEAF.lightened(0.1))
	for i in 3:
		var a := kit.rng.randf() * TAU
		kit.tube(Vector3(0, 0.02, 0), Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2), 0.012, 0.006, 4, Color(0.75, 0.22, 0.15), Color(0.6, 0.15, 0.1))


static func _b_hollow_root(kit: MeshKit, _detail: int) -> void:
	for i in 3:
		var a := TAU * i / 3.0
		var p := Vector3(cos(a) * 0.25, 0.15, sin(a) * 0.25)
		kit.tube(Vector3(0, 0.05, 0), p, 0.05, 0.04, 6, Color(0.70, 0.62, 0.50), Color(0.55, 0.46, 0.36))
		kit.tube(p, p + Vector3(cos(a) * 0.2, -0.17, sin(a) * 0.2), 0.04, 0.03, 6, Color(0.55, 0.46, 0.36), BARK)


static func _b_hazelnuts(kit: MeshKit, _detail: int) -> void:
	for i in 6:
		kit.blob(Vector3(kit.rng.randf_range(-0.06, 0.06), 0.012, kit.rng.randf_range(-0.06, 0.06)), Vector3(0.012, 0.014, 0.012),
				Color(0.62, 0.42, 0.22), Color(0.45, 0.30, 0.16), 0.05, 2, 6)


static func _b_rose_hips(kit: MeshKit, detail: int) -> void:
	_bush(kit, 0.7, Color(0.24, 0.44, 0.47), CREAM, 0, 0.0, detail)
	for i in 14:
		var a := kit.rng.randf() * TAU
		var y := kit.rng.randf_range(0.25, 0.85)
		kit.blob(Vector3(cos(a) * 0.55, y, sin(a) * 0.55), Vector3(0.025, 0.035, 0.025), Color(0.88, 0.30, 0.12), Color(0.6, 0.15, 0.05), 0.05, 2, 5, 0.3)


static func _b_blighted_bloom(kit: MeshKit, _detail: int) -> void:
	_stem_flowers(kit, 5, 0.15, Vector2(0.15, 0.3), Color(0.70, 0.68, 0.68), Color(0.4, 0.4, 0.42), 6, 0.04, Color(0.40, 0.42, 0.34))


static func _b_wood_sorrel(kit: MeshKit, _detail: int) -> void:
	for i in 8:
		kit.flower(Vector3(kit.rng.randf_range(-0.12, 0.12), 0.06, kit.rng.randf_range(-0.12, 0.12)), 3, 0.03, Color(0.49, 0.76, 0.60), LEAF, Vector3.UP, 0.4)
	_stem_flowers(kit, 3, 0.08, Vector2(0.06, 0.1), Color(0.98, 0.92, 0.95), Color(0.8, 0.6, 0.8), 5, 0.018)


static func _b_elderflower_sprig(kit: MeshKit, _detail: int) -> void:
	kit.tube(Vector3.ZERO, Vector3(0.05, 0.5, 0), 0.012, 0.008, 4, LEAF, LEAF, 0.0, 0.8)
	for i in 3:
		kit.flower(Vector3(0.05 + 0.04 * (i - 1), 0.5 + 0.02 * i, 0.03 * i), 10, 0.09, CREAM, CREAM.darkened(0.08), Vector3.UP, 0.8)


static func _b_starmoss(kit: MeshKit, _detail: int) -> void:
	kit.blob(Vector3.ZERO, Vector3(0.35, 0.08, 0.3), MOSS.lightened(0.1), MOSS, 0.25, 2, 7)
	for i in 10:
		kit.flower(Vector3(kit.rng.randf_range(-0.28, 0.28), 0.08, kit.rng.randf_range(-0.22, 0.22)), 4, 0.018,
				Color(0.80, 0.95, 1.0), Color(0.9, 1.0, 1.0), Vector3.UP, 0.0, 0.9)


static func _b_trout_pool(kit: MeshKit, _detail: int) -> void:
	# A dark, still eddy marked by a ring of stones: where trout hold.
	for i in 7:
		var a := TAU * i / 7.0
		kit.blob(Vector3(cos(a) * 0.6, 0.02, sin(a) * 0.5), Vector3(0.12, 0.06, 0.1), Color(0.55, 0.55, 0.50), Color(0.35, 0.36, 0.32), 0.2, 2, 5)
	kit.blob(Vector3(0.1, 0.0, 0), Vector3(0.12, 0.02, 0.04), Color(0.60, 0.55, 0.48), Color(0.45, 0.40, 0.36), 0.05, 2, 6)


static func _b_bone_charm(kit: MeshKit, _detail: int) -> void:
	var bone := Color(0.88, 0.84, 0.74)
	kit.tube(Vector3(0, 0, 0), Vector3(0.0, 0.35, 0), 0.01, 0.006, 3, BARK_DARK, BARK_DARK)
	kit.tube(Vector3(0, 0.33, 0), Vector3(0.0, 0.18, 0.02), 0.002, 0.002, 3, CREAM, CREAM)
	kit.blob(Vector3(0, 0.16, 0.02), Vector3(0.02, 0.03, 0.01), bone, bone.darkened(0.2), 0.1, 2, 5, 0.6)


static func _b_rusted_iron(kit: MeshKit, _detail: int) -> void:
	var rust := Color(0.50, 0.26, 0.14)
	kit.tube(Vector3(-0.08, 0.01, 0), Vector3(0.08, 0.01, 0.02), 0.008, 0.008, 4, rust, rust.lightened(0.1))
	kit.tube(Vector3(0.0, 0.01, -0.05), Vector3(0.02, 0.01, 0.05), 0.006, 0.006, 4, rust, rust)

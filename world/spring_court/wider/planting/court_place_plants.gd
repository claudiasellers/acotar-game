class_name CourtPlacePlants
extends RefCounted
## The plants the court's places are planted from (docs/lanes/
## court-planting-by-place.md), by name, each ready to draw: its mesh with
## its materials on. Three families:
##   glade plants  tools/grove: the sward, the flower patches and their far
##                 cushions, ferns (one "soft" surface, the woods' foliage)
##   trees         the court's great trees (CourtGreatTrees) and the estate's
##                 (EstateTrees), near, and every one's far form
##                 (tools/blender/estate_tree.py --far)
##   woods plants  FloraLibrary's, as they come
## A region's worker thread may ask for any of them, so prewarm() loads them
## all on the main thread first (CourtRegion.prewarm).

const GLADE := "res://world/spring_court/wider/assets/flora/glade/%s.glb"
const FAR := "res://world/spring_court/wider/assets/trees/far/tree_%s_%s_far.glb"
const LETTERS := "abcdefgh"
## Flowers take a little of the woods' rim light; grass and the far cushions
## none (a blade seen along the ground is all rim, and the rim is warm cream:
## a floor of straw). Nothing here twinkles: the twinkle lights a whole 14 cm
## cell, a white shard on a blade or a bell at your feet.
const FLOWER_RIM := 0.12
const GLADE_PLANTS := [
	"grass_sward_a", "grass_sward_b", "grass_sward_c", "grass_sward_far_a", "grass_sward_far_b", "grass_sward_far_c",
	"grass_glade_a", "grass_glade_b", "grass_glade_c", "grass_tall_a", "grass_tall_b",
	"bluebell_patch_a", "bluebell_patch_c", "bluebell_white", "snowdrop_patch_a", "snowdrop_patch_b", "crocus_patch_a",
	"crocus_patch_c", "kingcup_patch_a", "kingcup_patch_b", "petals_white", "petals_pink", "fern_a", "fern_b", "fern_c",
]
## The trees a place may plant: the court's own and the estate's that have a far form.
const ESTATE_TREES: Array[StringName] = [&"willow", &"birch", &"oak", &"cherry_blossom"]
const WOODS_PLANTS: Array[StringName] = [
	&"iris_clump", &"reed_clump", &"cattail", &"water_mint", &"mossy_rock", &"moss_mound", &"foxglove", &"daisy", &"starmoss",
	&"glowcap", &"faelight_dandelion",
]

static var _lock := Mutex.new()
static var _meshes := {}
static var _looks := {}
static var _far_materials := {}


## Everything a planting worker can ask for, loaded on the main thread.
static func prewarm() -> void:
	for plant: String in GLADE_PLANTS:
		glade(plant)
		if plant.contains("_patch_") or plant == "bluebell_white":
			glade(plant + "_mid")
			glade(plant + "_far")
	for species: StringName in tree_species():
		for b in builds(species):
			tree(species, b)
			tree_far(species, b)
	for plant in WOODS_PLANTS:
		FloraLibrary.mesh(plant)


static func tree_species() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in CourtGreatTrees.TREES:
		if not CourtGreatTrees.TREES[s].has("faces"):   # a landmark's own tree is not planted
			out.append(s)
	out.append_array(ESTATE_TREES)
	return out


static func is_great(species: StringName) -> bool:
	return CourtGreatTrees.TREES.has(species)


static func builds(species: StringName) -> int:
	return CourtGreatTrees.builds(species) if is_great(species) else EstateTrees.builds(species)


## A tree's near mesh.
static func tree(species: StringName, build: int) -> Mesh:
	return CourtGreatTrees.mesh(species, build) if is_great(species) else EstateTrees.mesh(species, build)


## A tree's far form: the same outline at a twentieth of the triangles, its
## crown one solid in the crown's lit colour.
static func tree_far(species: StringName, build: int) -> Mesh:
	var path := FAR % [species, LETTERS[posmod(build, builds(species))]]
	_lock.lock()
	if not _meshes.has(path):
		var found := _first_mesh(path)
		if found != null:
			for i in found.get_surface_count():
				var src := found.surface_get_material(i)
				var part := StringName(String(src.resource_name).trim_prefix("tree_")) if src != null else &"core"
				found.surface_set_material(i, _far_material(species, part))
		_meshes[path] = found
	var m: Mesh = _meshes[path]
	_lock.unlock()
	return m


static func _far_material(species: StringName, part: StringName) -> Material:
	var near: ShaderMaterial = CourtGreatTrees.material(species, part) if is_great(species) else EstateTrees.material(species, part)
	if part != &"core":
		return near   # the bark, and a willow's fronds, as the near tree's
	var key := "%s/far" % species
	if not _far_materials.has(key):
		# The near crown is leaf cards banded shadow -> mid -> light, mostly mid and
		# light; its heart alone is the shade under them. The far crown is the heart's
		# shape in the cards' colours.
		var m := near.duplicate() as ShaderMaterial
		var shadow: Color = near.get_shader_parameter(&"shadow_col")
		var mid: Color = near.get_shader_parameter(&"mid_col")
		var light: Color = near.get_shader_parameter(&"light_col")
		if not is_great(species) and bool(EstateTrees.LOOKS[species][3]):
			# a blossom tree's cards are painted, not banded: its far crown takes the blossom's own colour
			mid = EstateTrees.LOOKS[species][1]
			light = EstateTrees.LOOKS[species][2]
			shadow = EstateTrees.LOOKS[species][0]
		m.set_shader_parameter(&"shadow_col", shadow.lerp(mid, 0.75))
		m.set_shader_parameter(&"mid_col", mid.lerp(light, 0.7))
		_far_materials[key] = m
	return _far_materials[key]


## A glade plant's mesh (tools/grove) under the woods' foliage material.
static func glade(plant: String) -> Mesh:
	_lock.lock()
	if not _meshes.has(plant):
		var found := _first_mesh(GLADE % plant)
		if found != null:
			found.surface_set_material(0, _look(0.0 if plant.begins_with("grass") or plant.begins_with("petals") or plant.ends_with("_far") else FLOWER_RIM))
			# (one material for all the grass and cushions, one for all the flowers: they batch)
		_meshes[plant] = found
	var m: Mesh = _meshes[plant]
	_lock.unlock()
	return m


static func _look(rim: float) -> ShaderMaterial:
	if not _looks.has(rim):
		var m := FloraLibrary.material(&"bloom").duplicate() as ShaderMaterial
		m.set_shader_parameter(&"rim_strength", rim)
		m.set_shader_parameter(&"sparkle", 0.0)
		_looks[rim] = m
	return _looks[rim]


static func _first_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		push_warning("CourtPlacePlants: missing %s" % path)
		return null
	var scene := (load(path) as PackedScene).instantiate()
	var found: Mesh = null
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		found = mi.mesh
		break
	scene.free()
	return found

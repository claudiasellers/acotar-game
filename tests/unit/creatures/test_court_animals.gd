extends GutTest
## Slice 1b definition of done: every wider-court animal loads with its Blender
## model under budget scale, and the five wider-court tables name the right species.

const ANIMALS := ["lark", "hen", "owl", "hawk", "crow", "fox", "cat", "squirrel", "sheep"]
const REGIONS := {
	"western_fells": ["rabbit", "hawk", "sheep", "deer"],
	"fae_village": ["cat", "hen", "butterflies"],
	"autumn_foothills": ["fox", "deer", "owl", "squirrel"],
	"hill_of_the_rite": ["rabbit", "lark", "fireflies"],
	"blighted_reaches": ["crow"],
}


func test_every_animal_spawns_with_its_model() -> void:
	for name in ANIMALS:
		var scene := load("res://creatures/ambient/scenes/%s.tscn" % name) as PackedScene
		var animal := scene.instantiate() as Creature
		add_child_autofree(animal)
		assert_not_null(animal.data.model_scene, "%s has a Blender model" % name)
		assert_gt(animal.model.find_children("*", "MeshInstance3D", true, false).size(), 0, name)


func test_model_scale_grows_the_shared_bodies() -> void:
	var hawk := (load("res://creatures/ambient/scenes/hawk.tscn") as PackedScene).instantiate() as Creature
	add_child_autofree(hawk)
	assert_almost_eq(hawk.model.scale.x, 1.9, 0.001)
	var sheep := load("res://data/creatures/spring/sheep.tres") as CreatureData
	assert_eq(sheep.model_scene.resource_path, "res://creatures/models/spring/lamb.gltf")
	assert_gt(sheep.model_scale, 1.0)


func test_wider_court_tables_name_their_species() -> void:
	for region in REGIONS:
		var table := load("res://data/creatures/spawn/%s.tres" % region) as CreatureSpawnTable
		var scenes := {}
		for e in table.entries:
			scenes[e.scene.resource_path.get_file().get_basename()] = e
		for want in REGIONS[region]:
			assert_true(scenes.has(want), "%s spawns %s" % [region, want])


func test_blight_is_crows_only_and_sparse() -> void:
	var table := load("res://data/creatures/spawn/blighted_reaches.tres") as CreatureSpawnTable
	var total := 0
	for e in table.entries:
		assert_eq(e.scene.resource_path.get_file(), "crow.tscn")
		total += e.count * e.groups
	assert_lte(total, 6)


func test_owls_by_night_fireflies_at_dusk() -> void:
	var foothills := load("res://data/creatures/spawn/autumn_foothills.tres") as CreatureSpawnTable
	var hill := load("res://data/creatures/spawn/hill_of_the_rite.tres") as CreatureSpawnTable
	for e in foothills.entries:
		if e.id == &"owls":
			assert_true(e.active_at(23.0))
			assert_false(e.active_at(12.0))
	for e in hill.entries:
		if e.id == &"fireflies":
			assert_true(e.active_at(21.0))
			assert_false(e.active_at(14.0))

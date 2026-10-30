extends GutTest
## Definition of done for the secondary cast: 25 people load with Blender
## models; those with a hidden shape swap to it when the glamour lifts;
## 12 distinct lesser-fae designs; spawned NPCs keep their placed home.

const IDS := ["alis", "servant_maid", "servant_footman", "servant_cook", "seamstress", "potion_maker",
	"sentry_1", "sentry_2", "fae_dryad", "fae_mushroom", "fae_moth", "fae_fox", "fae_stag", "fae_nymph",
	"fae_birch", "fae_hedgehog", "fae_pixie", "fae_satyr", "fae_rose", "fae_owl",
	"human_woman", "human_man", "human_elder", "human_youth", "peddler"]
const GLAMOURED := ["alis", "servant_maid", "servant_footman", "servant_cook", "seamstress", "potion_maker",
	"sentry_1", "sentry_2"]


func before_each() -> void:
	WorldState.clear()


func _npc(id: String) -> CourtNpc:
	var npc := (load("res://creatures/people/scenes/%s.tscn" % id) as PackedScene).instantiate() as CourtNpc
	add_child_autofree(npc)
	return npc


func test_every_person_loads_a_model() -> void:
	for id in IDS:
		var npc := _npc(id)
		assert_not_null(npc.current_model(), id)
		assert_eq(npc.npc_id, StringName(id))


func test_twelve_lesser_fae_designs() -> void:
	assert_eq(IDS.filter(func(i: String) -> bool: return i.begins_with("fae_")).size(), 12)


func test_glamour_lift_swaps_to_the_true_form() -> void:
	for id in GLAMOURED:
		var npc := _npc(id)
		assert_not_null(npc.true_layer, "%s has a true form" % id)
		assert_eq(npc.current_model().get_parent(), npc.glamoured_layer)
	WorldState.set_flag(GlamourLayer.FLAG, true)
	for node in get_tree().get_nodes_in_group(CourtNpc.GROUP):
		var npc := node as CourtNpc
		if npc.true_layer:
			assert_eq(npc.current_model().get_parent(), npc.true_layer, "%s shows its true form" % npc.npc_id)


func test_spawned_npc_wanders_round_its_placed_home() -> void:
	var spawner := CreatureSpawner.new()
	spawner.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(spawner)
	var entry := SpawnEntry.new()
	entry.scene = load("res://creatures/people/scenes/fae_fox.tscn")
	entry.count = 1
	var npc := spawner._spawn_entry(entry, 0)[0] as CourtNpc
	assert_almost_eq(npc.home, npc.global_position, Vector3.ONE * 0.01)
	for i in 100:
		npc._process(0.1)
	assert_lte(Vector2(npc.global_position.x - npc.home.x, npc.global_position.z - npc.home.z).length(), npc.wander_radius + 0.01)

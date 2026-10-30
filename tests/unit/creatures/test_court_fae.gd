extends GutTest
## Slice 3 definition of done: the puca, the Summer faerie and the three
## Calanmai faeries answer the story lane's ids and cues; the beast patrols
## by night; water sprites and the unseen shimmer exist and are table-gated.

const PUCA := preload("res://creatures/fae/puca.tscn")
const SUMMER := preload("res://creatures/fae/summer_faerie.tscn")
const CALANMAI := preload("res://creatures/fae/calanmai_faerie.tscn")
const PATROL := preload("res://creatures/beast/beast_patrol.tscn")


func before_each() -> void:
	WorldState.clear()


func test_puca_wears_father_then_cycles_her_desires() -> void:
	var p := PUCA.instantiate() as Puca
	add_child_autofree(p)
	assert_false(p.visible)
	EventBus.story_actor_cue.emit(&"puca", &"looks_like_father")
	assert_true(p.visible)
	assert_eq(p.showing, &"father")
	var seen: Array[StringName] = []
	for i in 4:
		EventBus.story_actor_cue.emit(&"puca", &"shift_image")
		assert_eq(p.showing, Puca.TRUE_FORM, "its own shape flickers between images")
		p._process(p.flicker_time + 0.01)
		seen.append(p.showing)
	assert_eq(seen, [&"bow", &"supplies", &"sisters", &"father"] as Array[StringName])


func test_puca_keeps_out_of_reach() -> void:
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	var p := PUCA.instantiate() as Puca
	add_child_autofree(p)
	p.global_position = Vector3(0, 0, -3)
	EventBus.story_actor_cue.emit(&"puca", &"looks_like_father")
	for i in 30:
		p._process(0.1)
	assert_gt(p.global_position.distance_to(player.global_position), 3.5)


func test_summer_faerie_dies_on_cue() -> void:
	var f := SummerFaerie.new()
	add_child_autofree(f)
	assert_eq(f.find_children("WingStump*", "", true, false).size(), 2, "wings cut to stumps")
	watch_signals(f)
	EventBus.story_actor_cue.emit(&"summer_faerie", &"dies")
	assert_false(f.alive)
	assert_signal_emitted(f, "died")


func test_spawner_answers_the_new_ids() -> void:
	var spawner := StorySpawner.new()
	add_child_autofree(spawner)
	for id in [&"puca", &"summer_faerie", &"high_fae_male", &"high_fae_male_3"]:
		var actor := spawner.spawn(id, Transform3D.IDENTITY)
		assert_not_null(actor, String(id))
		assert_true(actor.is_in_group(StringName("story_actor_%s" % id)))
		autofree(actor)


func test_calanmai_faerie_flees_from_feyre_on_cue() -> void:
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	var f := CALANMAI.instantiate() as CalanmaiFaerie
	f.actor_id = &"high_fae_male_2"
	add_child_autofree(f)
	f.global_position = Vector3(2, 0, 0)
	EventBus.story_actor_cue.emit(&"high_fae_male", &"flee")
	assert_false(f.fleeing, "cues address one faerie by its full id")
	EventBus.story_actor_cue.emit(&"high_fae_male_2", &"flee")
	for i in 10:
		f._process(0.1)
	assert_gt(f.global_position.x, 6.0)


func test_beast_patrols_by_night_only() -> void:
	var patrol := PATROL.instantiate() as BeastPatrol
	for x in [0.0, 20.0]:
		var m := Marker3D.new()
		m.position = Vector3(x, 0, 0)
		patrol.add_child(m)
	add_child_autofree(patrol)
	var none := func(_f: String) -> bool: return false
	assert_true(patrol.on_duty(23.0, none))
	assert_false(patrol.on_duty(12.0, none))
	patrol.forbid_flags = PackedStringArray(["under_the_mountain"])
	assert_false(patrol.on_duty(23.0, func(_f: String) -> bool: return true))
	patrol.beast.patrol(patrol.route())
	assert_eq(patrol.beast.stage, BeastActor.Stage.PATROL)
	for i in 10:
		patrol.beast._process(0.5)
	assert_lt(patrol.beast.intensity, 0.2, "on patrol he is felt, not feared")
	assert_eq(patrol.beast._route_index, 1, "he walks on to the next point")
	assert_gt(patrol.beast.global_position.x, 3.0)


func test_shimmer_and_sprites_are_table_gated() -> void:
	var manor := load("res://data/creatures/spawn/manor_grounds.tres") as CreatureSpawnTable
	var found := false
	for e in manor.entries:
		if e.id == &"unseen_court":
			found = true
			assert_eq(e.glamour, SpawnEntry.Glamour.GLAMOURED_ONLY)
	assert_true(found)
	var waters := load("res://data/creatures/spawn/court_waters.tres") as CreatureSpawnTable
	for e in waters.entries:
		assert_true(e.on_water)
	var shimmer := preload("res://creatures/ambient/scenes/unseen_shimmer.tscn").instantiate() as UnseenShimmer
	add_child_autofree(shimmer)
	assert_eq(shimmer.figures.size(), shimmer.count)

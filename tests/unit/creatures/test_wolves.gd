extends GutTest

const GREAT_WOLF := preload("res://creatures/wolves/great_wolf.tscn")
const GREAT_DATA := preload("res://data/creatures/great_wolf.tres")


func before_each() -> void:
	WorldState.clear()


func test_flank_slots_spread_over_the_arc() -> void:
	var slots := WolfPack.flank_slots(Vector3.ZERO, Vector3(0, 0, 20), 4, 10.0)
	assert_eq(slots.size(), 4)
	for s in slots:
		assert_almost_eq(s.length(), 10.0, 0.01)
	# Outer slots sit 220 degrees apart, wrapping round behind the target.
	var angle := rad_to_deg(slots[0].angle_to(slots[3]))
	assert_almost_eq(angle, 140.0, 0.5, "220-degree arc -> 140 degrees the short way")
	assert_almost_eq(slots[0].distance_to(slots[1]), slots[1].distance_to(slots[2]), 0.01, "evenly spaced")


func test_wood_only_wounds_the_great_wolf() -> void:
	var r := Creature.resolve_arrow(GREAT_DATA, 10.0, &"wood")
	assert_false(r.killed)
	assert_eq(r.health, 1.0)


func test_ash_leaves_a_mortal_wound_and_any_next_arrow_kills() -> void:
	var r := Creature.resolve_arrow(GREAT_DATA, 40.0, &"ash")
	assert_false(r.killed)
	assert_true(r.mortal)
	assert_true(Creature.resolve_arrow(GREAT_DATA, r.health, &"wood", true).killed)


func test_arrow_id_is_read_from_meta() -> void:
	var arrow := Node3D.new()
	autofree(arrow)
	assert_eq(Creature.read_arrow_id(arrow), &"wood")
	arrow.set_meta(&"arrow_id", &"ash")
	assert_eq(Creature.read_arrow_id(arrow), &"ash")


func test_ash_arrow_kills_andras_and_raises_his_flag() -> void:
	var wolf := GREAT_WOLF.instantiate() as GreatWolf
	wolf.kill_flag = "wolf_killed"
	add_child_autofree(wolf)
	var arrow := Node3D.new()
	add_child_autofree(arrow)
	for i in 6:
		wolf.on_arrow_hit(arrow)
	assert_true(wolf.alive, "wood arrows never kill him")
	assert_eq(wolf.state, GreatWolf.State.STARE)
	arrow.set_meta(&"arrow_id", &"ash")
	watch_signals(wolf)
	wolf.on_arrow_hit(arrow)
	assert_true(wolf.alive, "the ash goes into his side; he turns and looks")
	assert_eq(wolf.state, GreatWolf.State.STARE)
	assert_signal_emitted(wolf, "looked_at_player")
	var plain := Node3D.new()
	add_child_autofree(plain)
	wolf.on_arrow_hit(plain)
	assert_false(wolf.alive, "an ordinary arrow finishes him")
	assert_signal_emitted_with_parameters(wolf, "died", [&"arrow_ash"])
	assert_true(WorldState.has_flag("wolf_killed"))
	assert_eq(wolf.harvestable.harvest()[0].item_id, &"obj_wolf_pelt")


func test_andras_without_flag_raises_nothing() -> void:
	var wolf := GREAT_WOLF.instantiate() as GreatWolf
	add_child_autofree(wolf)
	var arrow := Node3D.new()
	add_child_autofree(arrow)
	arrow.set_meta(&"arrow_id", &"ash")
	wolf.on_arrow_hit(arrow)
	wolf._physics_process(GREAT_DATA.lethal_delay + 1.0)
	assert_false(wolf.alive, "ash alone kills him, slowly")
	assert_false(WorldState.has_flag("wolf_killed"))


func test_pack_breaks_after_two_losses() -> void:
	var pack := WolfPack.new()
	add_child_autofree(pack)
	var wolves: Array[Wolf] = []
	for i in 4:
		var w := preload("res://creatures/wolves/wolf.tscn").instantiate() as Wolf
		add_child_autofree(w)
		pack.register(w)
		wolves.append(w)
	wolves[0].die(&"arrow_wood")
	assert_ne(pack.phase, WolfPack.Phase.BREAK)
	wolves[1].die(&"arrow_wood")
	assert_eq(pack.phase, WolfPack.Phase.BREAK)


func test_story_cues_drive_andras() -> void:
	var wolf := GREAT_WOLF.instantiate() as GreatWolf
	add_child_autofree(wolf)
	wolf._on_cue(&"great_wolf", &"seize_doe")
	assert_eq(wolf.state, GreatWolf.State.RUSH)
	wolf._on_cue(&"great_wolf", &"look_at_feyre")
	assert_eq(wolf.state, GreatWolf.State.STARE)
	assert_eq(wolf._hit_part(false), &"side")

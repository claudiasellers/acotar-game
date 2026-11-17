extends GutTest
## Contract test for fast travel by the whorl stones (L74, docs/contracts/fast_travel.md).
# gate: when:systems/fast_travel/*,data/fast_travel/*,art/fast_travel/*,tools/fast_travel/*,tools/blender/whorl_stones.py,story/act1/act1_game.gd,data/map/map_places.tres,data/phases/*,ui/map/full_map.gd,ui/map/minimap.gd,ui/map/map_reveal.gd

const PLACER := preload("res://tools/fast_travel/place_whorl_stones.gd")
## Every open Spring Court region gets one pair; the sealed Autumn border and
## the Suriel's glade (a dread place inside the woods) get none.
const REGIONS: Array[StringName] = [&"manor_estate", &"border_woods", &"eastern_woods", &"starlight_glen",
	&"western_fells", &"fae_village", &"rosewild", &"solstice_meadow", &"hill_of_the_rite", &"blossom_vale",
	&"blighted_reaches"]

var _saved_phase: Dictionary
var _player: CharacterBody3D


func before_each() -> void:
	WorldState.clear()
	WorldDeltas.clear()
	_saved_phase = PhaseManager.to_dict()
	StoryControl.release()
	_player = CharacterBody3D.new()
	_player.add_to_group(&"player")
	add_child_autofree(_player)


func after_each() -> void:
	if WhorlTravelCard.is_open():
		WhorlTravelCard.current().close()
	get_tree().paused = false
	StoryControl.release()
	PhaseManager.from_dict(_saved_phase)
	WorldDeltas.clear()


func _unlock(regions: Array) -> void:
	PhaseManager.from_dict({"phase_set": "", "phase": "p4_wider_court", "unlocked_regions": regions})


func _root() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	return root


func test_one_pair_per_open_region_on_flat_named_ground() -> void:
	var defs := WhorlStones.defs()
	assert_eq(defs.size(), REGIONS.size(), "one data/fast_travel/<id>.tres per open region")
	var regions := {}
	for d in defs:
		assert_false(regions.has(d.region_id), "one pair in %s" % d.region_id)
		regions[d.region_id] = true
		assert_true(REGIONS.has(d.region_id), "%s is an open Spring region" % d.region_id)
		assert_eq(d.canon, "X", "placement tagged canon X (%s)" % d.id)
		var places := (load(WhorlStones.PLACES_PATH) as MapPlaceSet).places.map(func(m: MapPlace) -> StringName: return m.id)
		assert_has(places, d.place_id, "%s names a map place" % d.id)
		assert_lte(PLACER.footprint_slope(d.position, d.yaw_degrees), PLACER.MAX_SLOPE, "%s stands on flat ground" % d.id)
		assert_eq(d.blight, d.region_id == &"blighted_reaches", "only the Reaches' pair is blighted")


func test_models_are_real_and_in_budget() -> void:
	for path in [WhorlStone.MODEL, WhorlStone.MODEL_BLIGHT, WhorlStone.MARK_MODEL]:
		var node := String(path).get_file().get_basename()
		var pair := PropModels.pair(path, node)
		assert_eq(pair.size(), 2, "%s has LOD0 and LOD1" % path)
		if pair.size() == 2:
			var n0 := PropModels.tri_count(pair[0])
			assert_lte(n0, 3000, "%s within the R4 prop cap" % path)
			assert_lt(PropModels.tri_count(pair[1]), n0, "%s LOD1 is lighter" % path)


func test_pairs_spawn_with_their_region_on_the_ground() -> void:
	var root := _root()
	assert_eq(WhorlStones.spawn_for(&"rosewild", root), 1)
	assert_eq(WhorlStones.spawn_for(&"rosewild", root), 0, "never twice")
	var s := root.get_child(0) as WhorlStone
	assert_true(s.is_in_group(&"station"), "Interactor finds it")
	assert_eq(s.station_id, WhorlStone.STATION_ID)
	assert_eq(s.collision_layer, 1, "solid like the rest of the world")
	var p := s.def.position
	assert_almost_eq(s.global_position.y, WorldHeight.height_at(p.x, p.y), 0.01, "on the shared ground")
	assert_false(s.mark_node.visible, "no mark until she paints one")


func test_painting_the_mark_saves_and_celebrates_without_flags() -> void:
	var root := _root()
	WhorlStones.spawn_for(&"rosewild", root)
	var s := root.get_child(0) as WhorlStone
	var flags_before := WorldState.all_flags().duplicate()
	var phase_before := PhaseManager.current_phase
	s.use(_player)
	assert_true(WhorlStones.is_marked(s.def.id), "marked in WorldDeltas")
	assert_true(WorldDeltas.get_region_value(WhorlStones.DELTAS_REGION, String(s.def.id), false), "saved with the world")
	assert_true(s.mark_node.visible, "her mark shows")
	assert_true(Gameplay.sketchbook.has(StringName("whorl_%s" % s.def.id)), "she sketches the whorl")
	assert_eq(WorldState.all_flags(), flags_before, "R2: no story flag")
	assert_eq(PhaseManager.current_phase, phase_before, "R2: no phase change")
	assert_false(WhorlTravelCard.is_open(), "the first E only paints")


func test_destinations_are_marked_and_opened_by_the_story() -> void:
	_unlock(["manor_estate", "rosewild"])
	for id in [&"manor_drive", &"briar_gate", &"drum_field"]:
		WhorlStones.mark(id)
	var ids: Array = WhorlStones.destinations(&"manor_drive").map(func(d: WhorlStoneDef) -> StringName: return d.id)
	assert_eq(ids, [&"briar_gate"], "drum_field's hill isn't open yet; never the stone she's at")
	assert_true(WhorlStones.can_travel())
	StoryControl.set_mode(StoryControl.Mode.WALK)
	assert_false(WhorlStones.can_travel(), "no riding off in a story scene")
	assert_null(WhorlStones.travel(get_tree(), WhorlStones.get_def(&"briar_gate")))


func test_card_lists_rides_and_choosing_one_rides_there() -> void:
	_unlock(["manor_estate", "rosewild", "fae_village"])
	for id in [&"manor_drive", &"briar_gate", &"village_green"]:
		WhorlStones.mark(id)
	var root := _root()
	WhorlStones.spawn_for(&"manor_estate", root)
	(root.get_child(0) as WhorlStone).use(_player)
	assert_true(WhorlTravelCard.is_open(), "E at a marked pair opens the card")
	var card := WhorlTravelCard.current()
	assert_eq(card.buttons.size(), 2, "one button per other marked pair")
	assert_true(get_tree().paused, "the world waits")
	var dest := WhorlStones.get_def(&"briar_gate")
	var ride := card.choose(dest)
	assert_not_null(ride, "choosing rides")
	assert_false(get_tree().paused, "the card is gone")
	await wait_until(func() -> bool: return ride == null or not is_instance_valid(ride) or ride.arrived, 8.0)
	var at := WhorlStone.arrival_point(dest)
	assert_lt(_player.global_position.distance_to(at), 3.0, "put down by the stones")
	assert_true(_player.is_physics_processing(), "free to move again")
	assert_eq(WorldState.all_flags(), {}, "R2: still no flags")


func test_only_mark_says_so_instead_of_an_empty_card() -> void:
	_unlock(["manor_estate"])
	WhorlStones.mark(&"manor_drive")
	var root := _root()
	WhorlStones.spawn_for(&"manor_estate", root)
	(root.get_child(0) as WhorlStone).use(_player)
	assert_false(WhorlTravelCard.is_open(), "nowhere to ride yet")


func test_map_shows_pairs_on_sketched_ground_and_marks_differ() -> void:
	var reveal := MapReveal.new()
	assert_eq(WhorlMapMarks.shown(reveal).size(), 0, "nothing on an unsketched map")
	var briar := WhorlStones.get_def(&"briar_gate")
	reveal.reveal(briar.position.x, briar.position.y)
	var ids: Array = WhorlMapMarks.shown(reveal).map(func(d: WhorlStoneDef) -> StringName: return d.id)
	assert_eq(ids, [&"briar_gate"], "only the pair on ground she has sketched")
	WhorlStones.mark(&"cider_mill")
	ids = WhorlMapMarks.shown(reveal).map(func(d: WhorlStoneDef) -> StringName: return d.id)
	assert_has(ids, &"cider_mill", "a pair she marked always shows")
	var flags_before := WorldState.all_flags().duplicate()
	var c := Control.new()
	add_child_autofree(c)
	var n := WhorlMapMarks.draw_all(c, reveal, func(xz: Vector2) -> Vector2: return xz,
		func(_p: Vector2) -> bool: return true, 10.0, 0.0)
	assert_eq(n, 2, "draws each shown pair")
	assert_eq(WorldState.all_flags(), flags_before, "R2: drawing writes no flag")

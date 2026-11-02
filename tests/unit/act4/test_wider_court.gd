## L44 contract: the wider court (ch 18-19, P4 finish).
## - starlight_pool_found comes only from jumping into the pool, after she has
##   found it herself and Tamlin has said his two lines; no knife.
## - attor_evaded comes only from hiding: in the yew pocket and still while
##   the voice speaks. Out in the open, or rustling, is fact.attor_detected
##   (permanent) and no deed; she can come back and face it again.
## - The fells range scores rings, clears with all three butts, and the
##   sentries' chest gives the warbow once, only after a clear.
## - Tamlin's dusk routine: E at dusk, four strokes, one new road on the map.
## - WiderCourtAnchors puts the p4 anchors in their regions.
extends GutTest

const DT := 0.25

var root: Node3D
var feyre: CharacterBody3D
## Story gifts this test saw (the Interactor that banks them isn't here).
var granted: Dictionary = {}


func _on_granted(item_id: StringName, n: int) -> void:
	granted[item_id] = int(granted.get(item_id, 0)) + n


func before_each() -> void:
	WorldState.clear()
	StoryControl.release()
	Clock.paused = true
	granted.clear()
	if not EventBus.story_item_granted.is_connected(_on_granted):
		EventBus.story_item_granted.connect(_on_granted)
	root = Node3D.new()
	add_child_autofree(root)
	feyre = CharacterBody3D.new()
	feyre.add_to_group(&"player")
	root.add_child(feyre)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = false


func after_each() -> void:
	if EventBus.story_item_granted.is_connected(_on_granted):
		EventBus.story_item_granted.disconnect(_on_granted)
	for global_space in StoryDirector.get_children():
		(global_space as SceneSpace).auto_tick = true
	StoryControl.release()
	Clock.paused = false


func _day() -> void:
	Clock.from_dict({"time_of_day": 0.55, "day": 9})


func _step(space: SceneSpace, seconds: float) -> void:
	var t := 0.0
	while t < seconds - 0.001 and space.running:
		space.tick(DT)
		t += DT


func _until(space: SceneSpace, label: String, limit: float = 90.0) -> bool:
	var t := 0.0
	while space.running and space.current_beat_label() != label and t < limit:
		space.tick(DT)
		t += DT
	return space.current_beat_label() == label


# --- the pool ---------------------------------------------------------------

func _pool() -> StarlightPoolSwim:
	var space := Act2Spaces.space_for(StoryDirector.get_moment(&"starlight_pool")) as StarlightPoolSwim
	assert_not_null(space, "the pool is a coded scene")
	space.auto_tick = false
	space.instant_fades = true
	space.position = Vector3(500, 0, 500)  # far from any court basin: the radius alone decides
	root.add_child(space)
	return space


func test_pool_is_found_then_jumped_into() -> void:
	WorldState.set_flag("summer_faerie_comforted")
	_day()
	var space := _pool()
	assert_gt(space.stage.mark(&"blanket").length(), 120.0, "the blanket is well away from the pool")
	feyre.global_position = space.mark(&"blanket")
	assert_true(space.start(), "walking up to the picnic starts it")
	assert_true(_until(space, "find the pool"), "he dares her and she has to find it")
	_step(space, 20.0)
	assert_false(WorldState.has_flag("starlight_pool_found"), "nothing is given while she looks")
	# She jumps in before he's caught up: it doesn't count until he has spoken.
	feyre.global_position = space.mark(&"pool") + Vector3(3, 0, 0)
	assert_true(space.in_pool())
	_step(space, 2.0)
	assert_true(space.found, "the rim (or the water) is finding it")
	assert_false(WorldState.has_flag("starlight_pool_found"), "the haunt line and the dare come first (canon order)")
	_step(space, 30.0)
	assert_true(space.dared)
	assert_true(WorldState.has_flag("starlight_pool_found"), "in the water after 'Jump in' is the deed")
	_step(space, 60.0)
	assert_false(space.running, "the swim ends in the golden hour")
	assert_false(granted.has(&"obj_lucien_knife"), "no knife in ch18 (Keeper)")


func test_pool_lines_are_canon_ordered() -> void:
	var stage := load("res://data/story/act4/starlight_pool_stage.tres") as Act2Stage
	assert_eq(String(stage.line(&"tamlin_haunt")["text"]), "This was my favorite haunt as a boy.")
	assert_eq(String(stage.line(&"tamlin_jump")["text"]), "Jump in.")
	var moment := StoryDirector.get_moment(&"starlight_pool")
	for step in moment.steps:
		assert_ne(step.get("item", ""), "obj_lucien_knife", "the moment grants no knife")


# --- the Attor ----------------------------------------------------------------

func _attor() -> AttorInTheGarden:
	var space := Act2Spaces.space_for(StoryDirector.get_moment(&"attor")) as AttorInTheGarden
	assert_not_null(space, "the Attor is a coded scene")
	space.auto_tick = false
	space.instant_fades = true
	space.position = Vector3(-40, 0, -105.5)
	root.add_child(space)
	return space


func test_attor_needs_her_to_hide_and_keep_still() -> void:
	WorldState.set_flag("first_painting")
	_day()
	var space := _attor()
	var speed := [0.0]
	space.speed_override = func() -> float: return speed[0]
	feyre.global_position = space.mark(&"tamlin_idle") + Vector3(2, 0, 2)
	assert_true(space.start())
	assert_true(_until(space, "hide"), "Tamlin tells her to stay hidden")
	feyre.global_position = space.mark(&"hide")
	_step(space, 1.0)
	assert_true(space.watching, "in the yew, she's hidden in time")
	_step(space, 200.0)
	assert_false(space.detected)
	assert_true(WorldState.has_flag("attor_evaded"), "still through it all is the deed")
	assert_false(WorldState.has_flag("fact.attor_detected"))


func test_attor_hears_her_rustle() -> void:
	WorldState.set_flag("first_painting")
	_day()
	var space := _attor()
	var speed := [0.0]
	space.speed_override = func() -> float: return speed[0]
	feyre.global_position = space.mark(&"tamlin_idle")
	space.start()
	_until(space, "hide")
	feyre.global_position = space.mark(&"hide")
	_step(space, 1.0)
	speed[0] = 3.2  # walking about in the hedge
	_step(space, 10.0)
	assert_true(WorldState.has_flag("fact.attor_detected"), "moving in the hedge gives her away")
	assert_false(WorldState.has_flag("attor_evaded"), "no deed when found")
	_step(space, 10.0)
	assert_false(space.running, "the scene ends; she can come back")
	assert_true(space.can_start() or not space.running, "it can be faced again")


func test_attor_finds_her_in_the_open() -> void:
	WorldState.set_flag("first_painting")
	_day()
	var space := _attor()
	space.speed_override = func() -> float: return 0.0
	feyre.global_position = space.mark(&"tamlin_idle")
	space.start()
	_until(space, "hide")
	_step(space, AttorInTheGarden.HIDE_WINDOW + 6.0)
	assert_true(WorldState.has_flag("fact.attor_detected"), "out on the walk when it comes")


func test_attor_lines_are_the_keepers() -> void:
	var stage := load("res://data/story/act4/attor_stage.tres") as Act2Stage
	assert_eq(stage.invented.size(), 0, "every Attor line is Keeper-confirmed")
	assert_string_contains(String(stage.line(&"tamlin_stay")["text"]), "Stay hidden")
	assert_string_contains(String(stage.line(&"attor_3")["text"]), "heart of stone")


# --- the fells ------------------------------------------------------------------

func test_range_rings_and_clear_open_the_chest() -> void:
	assert_eq(SentryRange.ring_for(0.1), 0, "gold")
	assert_eq(SentryRange.ring_for(0.5), 3, "pearl")
	assert_eq(SentryRange.ring_for(0.9), -1, "straw")
	var range := SentryRange.new()
	root.add_child(range)
	assert_eq(range.butts.size(), 3)
	assert_ne(range.chest.unavailable_reason(), "", "locked before a clear")
	range.butts[0].register(0.1)
	range.butts[1].register(0.9)
	assert_false(WorldState.has_flag("fact.fells_range_cleared"), "the straw doesn't count")
	range.butts[1].register(0.3)
	range.butts[2].register(0.5)
	assert_true(WorldState.has_flag("fact.fells_range_cleared"))
	assert_eq(int(granted.get(&"arrow_wood", 0)), SentryRange.ARROWS_FOR_CLEAR, "a sheaf of arrows")
	assert_eq(range.chest.unavailable_reason(), "")
	range.chest.use(feyre)
	assert_true(WorldState.has_flag(SentryChest.TAKEN))
	assert_eq(int(granted.get(SentryChest.ITEM, 0)), 1, "the warbow is hers")
	range.chest.use(feyre)
	assert_eq(int(granted.get(SentryChest.ITEM, 0)), 1, "once")


# --- the stables ----------------------------------------------------------------

func test_dusk_brushing_tells_a_road() -> void:
	WorldState.set_flag("summer_faerie_comforted")
	Clock.from_dict({"time_of_day": 18.5 / 24.0, "day": 11})
	var space := StableDusk.new()
	space.auto_tick = false
	space.instant_fades = true
	root.add_child(space)
	feyre.global_position = space.global_position + Vector3(1, 0, 1)
	space._tend()
	assert_not_null(space.actor(&"tamlin"), "Tamlin is in the yard at dusk")
	space.use(feyre)
	assert_true(space.running)
	assert_true(_until(space, "brush"))
	for i in StableDusk.BRUSH_STROKES:
		space.press_interact()
		await get_tree().process_frame
	_step(space, 60.0)
	assert_false(space.running)
	assert_ne(space.told, &"", "he names a road she hasn't mapped")
	space.use(feyre)
	assert_false(space.running, "once a day")


func test_dusk_only() -> void:
	WorldState.set_flag("summer_faerie_comforted")
	Clock.from_dict({"time_of_day": 0.4, "day": 12})
	var space := StableDusk.new()
	space.auto_tick = false
	root.add_child(space)
	feyre.global_position = space.global_position
	space._tend()
	assert_null(space.actor(&"tamlin"), "not at noon")


# --- anchors --------------------------------------------------------------------

func test_anchors_land_in_their_regions() -> void:
	for region: StringName in [&"manor_estate", &"western_fells", &"fae_village"]:
		var r := Node3D.new()
		root.add_child(r)
		assert_eq(WiderCourtAnchors.place(region, r), 1, "%s gets its p4 anchor" % region)
		assert_eq(WiderCourtAnchors.place(region, r), 0, "safe twice")
		var m := r.get_child(0) as Node3D
		assert_true(m.is_in_group(&"story_anchor"))
		assert_true(Act3Anchors.ROWS.has(StringName(m.name)), "Act3Anchors hangs a node on %s" % m.name)
	assert_eq(WiderCourtAnchors.where(&"fells_sentry_range", null), Vector2(-1636.0, -650.0))


func test_potion_room_stands_level_on_its_terrace() -> void:
	var at := WiderCourtAnchors.where(&"fae_potion_room", null)
	var room := PotionRoom.new()
	room.position = Vector3(at.x, WorldHeight.height_at(at.x, at.y), at.y) - root.global_position
	room.rotation.y = deg_to_rad(45.0)
	root.add_child(room)
	var lowest := INF
	var highest := -INF
	for i in 5:
		for j in 5:
			var p := room.to_global(Vector3(lerpf(-4.2, 4.2, i / 4.0), 0.0, lerpf(-3.5, 3.5, j / 4.0)))
			var h := WorldHeight.height_at(p.x, p.z)
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	assert_true(room.floor_y >= highest, "the bank never pokes through the floor")
	assert_lt(room.floor_y - lowest, 2.0, "a low shelf at the green's edge, not a tower")
	var cauldron := room.find_child("Cauldron", true, false) as Node3D
	assert_almost_eq(cauldron.global_position.y, room.floor_y, 0.01, "the cauldron stands on the floor")
	assert_true(room.find_child("TerraceBody", true, false) is StaticBody3D, "the floor and balustrade collide")
	assert_eq(room.station.station.id, &"fae_potion_room")


func test_pool_water_darkens_at_night() -> void:
	assert_eq(StarlightSteep.night_amount(12.0), 0.0, "noon: daylight glitter")
	assert_eq(StarlightSteep.night_amount(23.0), 1.0, "late night: stars")
	assert_eq(StarlightSteep.night_amount(2.0), 1.0)
	var dusk := StarlightSteep.night_amount(20.0)
	assert_true(dusk > 0.0 and dusk < 1.0, "dusk eases")
	var mat := load(StarlightSteep.WATER) as ShaderMaterial
	var keep := Clock.time_of_day
	Clock.time_of_day = 0.0
	var steep := StarlightSteep.new()
	root.add_child(steep)
	assert_eq(float(mat.get_shader_parameter(&"night_amount")), 1.0, "the pool's water is told it is night")
	Clock.time_of_day = 0.5
	steep._process(0.1)
	assert_eq(float(mat.get_shader_parameter(&"night_amount")), 0.0)
	Clock.time_of_day = keep


func test_never_borrows_another_scenes_stand_in() -> void:
	var other := SceneSpace.new()
	root.add_child(other)
	var theirs := Node3D.new()
	theirs.add_to_group(&"story_actor_tamlin")
	other.add_child(theirs)
	var s := _pool()
	var mine := s.cast(&"tamlin", &"tamlin_wait", &"blanket_view")
	assert_ne(mine, theirs, "the pool casts its own Tamlin")
	assert_eq(mine.get_parent(), s)
	mine.free()
	assert_null(s.actor(&"tamlin"), "a freed actor reads as gone, without an error")

extends GutTest
## Act I's opening teaches through the world: tracks, crows, a grazing doe, and
## key prompts that appear only when relevant.

const PROMPTS_CFG := "user://test_prompts.cfg"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROMPTS_CFG))
	WorldState.clear()


func test_doe_tracks_lead_from_the_trail_to_the_clearing() -> void:
	var pts := Act1Wayfinding.track_points()
	assert_gt(pts.size(), 150)
	assert_lt(pts[0].distance_to(Act1Wayfinding.TRAIL_END), 0.01)
	assert_lt(pts[pts.size() - 1].distance_to(HumanRealmLayout.DOE_CLEARING), 2.0)
	for i in range(1, pts.size()):
		assert_lt(pts[i].distance_to(pts[i - 1]), 2.5, "no gaps in the trail")
		if pts[i].distance_to(pts[i - 1]) >= 2.5:
			break


func test_crows_circle_until_the_wolf_is_skinned() -> void:
	var way := Act1Wayfinding.new()
	add_child_autofree(way)
	assert_eq(way.crows.size(), Act1Wayfinding.CROWS)
	assert_not_null(way.tracks)
	assert_true(way.crows[0].visible)
	WorldState.raise_deed("fact.wolf_skinned")
	assert_false(way.crows[0].visible)


func test_the_doe_grazes_before_the_scene_starts() -> void:
	var anchor := Node3D.new()
	add_child_autofree(anchor)
	var kill := WolfKill.new()
	kill.auto_start = false
	anchor.add_child(kill)
	var feyre := Node3D.new()
	feyre.add_to_group(&"player")
	add_child_autofree(feyre)
	feyre.global_position = Vector3(0, 0, 200)
	kill._physics_process(0.1)
	assert_null(kill.doe, "too far")
	feyre.global_position = Vector3(0, 0, 38.5)
	kill._physics_process(0.1)
	assert_not_null(kill.doe, "she is grazing, 60.5 m off")
	assert_false(kill.running, "the scene waits for the 58 m line")


func test_prompts_show_only_when_relevant_and_are_taught_once() -> void:
	var prompts := KeyPrompts.new()
	prompts.settings_path = PROMPTS_CFG
	add_child_autofree(prompts)
	var feyre: Feyre = load("res://characters/feyre/feyre.tscn").instantiate()
	add_child_autofree(feyre)
	var stall := FurStall.new()
	add_child_autofree(stall)
	stall.global_position = Vector3(1, 0, 0)
	Gameplay.inventory.remove(FurStall.PELT, Gameplay.inventory.count(FurStall.PELT))
	assert_eq(prompts.want(), &"", "no pelt, no prompt")
	Gameplay.inventory.add(FurStall.PELT, 1)
	assert_eq(prompts.want(), &"sell")
	stall.global_position = Vector3(10, 0, 0)
	assert_eq(prompts.want(), &"", "out of reach")
	stall.global_position = Vector3(1, 0, 0)
	stall.use(null)
	Gameplay.inventory.add(FurStall.PELT, 1)
	assert_eq(prompts.want(), &"", "taught by the first sale")
	var again := KeyPrompts.new()
	again.settings_path = PROMPTS_CFG
	add_child_autofree(again)
	assert_true(again.taught.get(&"sell", false), "remembered across launches")
	Gameplay.inventory.remove(FurStall.PELT, Gameplay.inventory.count(FurStall.PELT))


func test_doe_prints_walk_at_a_doe_stride() -> void:
	var way := Act1Wayfinding.new()
	add_child_autofree(way)
	var prints := way.tracks.get_children()
	assert_gt(prints.size(), 50)
	assert_true(prints[0] is Decal)
	var gaps: Array[float] = []
	# The cottage's deer trail and the doe's own line, both at her stride.
	var idx: Array = range(1, 40) + range(prints.size() - 40, prints.size())
	for i: int in idx:
		var a := (prints[i - 1] as Node3D).position
		var b := (prints[i] as Node3D).position
		gaps.append(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)))
	gaps.sort()
	var median := gaps[gaps.size() / 2]
	assert_between(median, 0.5, 0.75, "one print per walking step")
	gut.p("doe prints: %d, median step %.2f m" % [prints.size(), median])


func test_doe_prints_wander_and_never_land_in_a_trunk_or_rock() -> void:
	var way := Act1Wayfinding.new()
	add_child_autofree(way)
	var line := Act1Wayfinding._resample(Act1Wayfinding.track_points(), Act1Wayfinding.PRINT_STEP)
	var obstacles := Act1Wayfinding.trail_obstacles(line)
	assert_gt(obstacles.size(), 20, "the doe's line runs through the forest")
	var inside := 0
	for d in way.tracks.get_children():
		var p := (d as Node3D).position
		if not Act1Wayfinding.is_clear(Vector2(p.x, p.z), obstacles, 0.0):
			inside += 1
	assert_eq(inside, 0, "no print inside a tree or rock collider")
	# A slow wander, not a ruler line and not jitter.
	var wandered := Act1Wayfinding.wander_line(line, [] as Array[Vector3])
	var max_off := 0.0
	var max_step := 0.0
	for i in range(1, wandered.size()):
		max_off = maxf(max_off, wandered[i].distance_to(line[i]))
		max_step = maxf(max_step, absf(wandered[i].distance_to(line[i]) - wandered[i - 1].distance_to(line[i - 1])))
	assert_between(max_off, 0.5, 1.0, "wanders about +-0.5-1 m")
	assert_lt(max_step, 0.25, "no per-print jitter")

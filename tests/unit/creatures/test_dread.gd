extends GutTest
## Definition of done (bible §1.5): near horror the court withdraws. Swarms
## thin to nothing, songbirds go (crows stay), the grade gets "dread" as Feyre
## nears and "calm" when she leaves, one wrong sound per visit; faelights are
## round warm motes; swarms cluster at landmarks.

const BUTTERFLIES := preload("res://creatures/ambient/scenes/butterflies.tscn")
const FAELIGHTS := preload("res://creatures/ambient/scenes/faelights.tscn")
const BLUEBIRD := preload("res://creatures/ambient/scenes/songbird_blue.tscn")
const CROW := preload("res://creatures/ambient/scenes/crow.tscn")

var moods: Array = []


func before_each() -> void:
	moods.clear()
	EventBus.mood_requested.connect(_on_mood)


func after_each() -> void:
	EventBus.mood_requested.disconnect(_on_mood)


func _on_mood(mood: StringName, intensity: float, _s: float) -> void:
	moods.append([mood, intensity])


func _field(at: Vector3) -> DreadField:
	var f := DreadField.new()
	f.radius = 30.0
	f.inner = 10.0
	add_child_autofree(f)
	f.global_position = at
	return f


func test_falloff_is_full_inside_and_gone_beyond() -> void:
	assert_eq(DreadField.falloff(5.0, 10.0, 30.0), 1.0)
	assert_eq(DreadField.falloff(31.0, 10.0, 30.0), 0.0)
	assert_between(DreadField.falloff(20.0, 10.0, 30.0), 0.1, 0.9)


func test_swarm_thins_to_nothing_near_horror() -> void:
	var swarm := BUTTERFLIES.instantiate() as AmbientSwarm
	add_child_autofree(swarm)
	_field(Vector3(5, 0, 0))
	for i in 30:
		swarm._process(0.2)
	assert_eq(swarm.multimesh.visible_instance_count, 0)


func test_songbirds_go_but_crows_stay() -> void:
	_field(Vector3.ZERO)
	var bird := BLUEBIRD.instantiate() as Bird
	add_child_autofree(bird)
	var crow := CROW.instantiate() as Bird
	add_child_autofree(crow)
	bird._physics_process(0.1)
	crow._physics_process(0.1)
	assert_true(bird.hushed)
	assert_false(bird.visible)
	assert_false(crow.hushed)


func test_dread_rises_as_she_nears_and_calms_when_she_leaves() -> void:
	var f := _field(Vector3.ZERO)
	watch_signals(f)
	f.update_level(Vector3(40, 0, 0))
	f.update_level(Vector3(5, 0, 0))
	assert_eq(moods.back(), [&"dread", 1.0])
	f._process(3.0)
	assert_signal_emit_count(f, "wrong_sound", 1)
	f._process(3.0)
	assert_signal_emit_count(f, "wrong_sound", 1, "only one wrong sound per visit")
	f.update_level(Vector3(80, 0, 0))
	assert_eq(moods.back()[0], &"calm")


func test_faelights_are_round_warm_motes() -> void:
	var swarm := FAELIGHTS.instantiate() as AmbientSwarm
	add_child_autofree(swarm)
	assert_true(swarm.multimesh.mesh is QuadMesh)
	for c in swarm.colors:
		assert_gt(c.r, c.b, "warm, never cold-blue")


func test_swarm_entries_cluster_at_landmarks() -> void:
	var mark := Node3D.new()
	mark.add_to_group(&"landmark")
	add_child_autofree(mark)
	mark.global_position = Vector3(40, 0, -20)
	var spawner := CreatureSpawner.new()
	spawner.height_func = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(spawner)
	var e := SpawnEntry.new()
	e.id = &"b"
	e.count = 3
	e.groups = 2
	e.cluster_radius = 4.0
	e.near_group = &"landmark"
	for p in spawner.positions_for(e, 0):
		assert_lte(Vector2(p.x - 40.0, p.z + 20.0).length(), 4.01)

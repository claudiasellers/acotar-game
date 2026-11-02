## F27: region workers call CourtAssets.scene()/mesh() at the same time.
## Unguarded, the shared caches crashed with signal 11 in a background build.
extends GutTest

const IDS: Array[StringName] = [
	&"autumn_border_marker", &"autumn_fallen_log", &"autumn_pass_gate",
	&"blight_bone_rock", &"blight_broken_arbor",
]
const THREADS := 6
const ROUNDS := 40
const WAVES := 8

var _results: Array = []


func before_each() -> void:
	CourtAssets._lock.lock()
	CourtAssets._scenes.clear()
	CourtAssets._resources.clear()
	CourtAssets._lock.unlock()


func _hammer(index: int) -> void:
	var seen := {}
	for r in ROUNDS:
		var id: StringName = IDS[(index + r) % IDS.size()]
		var packed := CourtAssets.scene(id)
		CourtAssets.mesh(id)
		seen[id] = packed
	_results[index] = seen


func test_scene_is_safe_from_many_threads() -> void:
	# Several waves from a cold cache: each wave races to fill it again.
	for wave in WAVES:
		before_each()
		await _wave()


func _wave() -> void:
	_results.clear()
	_results.resize(THREADS)
	var threads: Array[Thread] = []
	for i in THREADS:
		var t := Thread.new()
		t.start(_hammer.bind(i))
		threads.append(t)
	# Poll instead of blocking: a load on a worker may need the main thread.
	for t in threads:
		while t.is_alive():
			await get_tree().process_frame
		t.wait_to_finish()
	for id in IDS:
		var cached := CourtAssets.scene(id)
		assert_not_null(cached, "%s loads" % id)
		for seen: Dictionary in _results:
			if seen.has(id):
				assert_same(seen[id], cached, "every thread got the one cached %s" % id)


func test_missing_model_caches_null_without_crashing() -> void:
	assert_null(CourtAssets.scene(&"no_such_model_f27"))
	assert_true(CourtAssets._scenes.has(&"no_such_model_f27"))


## L32: place FX scenes, sound cues and the place table load through
## CourtAssets.resource() while other threads load .gltf meshes.
const PLACE_PATHS: Array[String] = [
	"res://world/spring_court/wider/fx/particles/fx_faelights.tscn",
	"res://world/spring_court/wider/fx/particles/fx_bonfire_embers.tscn",
	"res://data/places/sounds/brook.tres",
	"res://data/places/court_places.tres",
]


func _hammer_places(index: int) -> void:
	var seen := {}
	for r in ROUNDS:
		var path := PLACE_PATHS[(index + r) % PLACE_PATHS.size()]
		seen[path] = CourtAssets.resource(path)
		CourtAssets.mesh(IDS[(index + r) % IDS.size()])
	_results[index] = seen


func test_place_resources_race_mesh_loads() -> void:
	for wave in WAVES:
		before_each()
		_results.clear()
		_results.resize(THREADS)
		var threads: Array[Thread] = []
		for i in THREADS:
			var t := Thread.new()
			t.start((_hammer_places if i % 2 == 0 else _hammer).bind(i))
			threads.append(t)
		for t in threads:
			while t.is_alive():
				await get_tree().process_frame
			t.wait_to_finish()
		for path in PLACE_PATHS:
			var cached := CourtAssets.resource(path)
			assert_not_null(cached, "%s loads" % path)
			for seen: Dictionary in _results:
				if seen.has(path):
					assert_same(seen[path], cached, "every thread got the one cached %s" % path)

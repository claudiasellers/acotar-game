## Every phase ladder in data/phases must be internally consistent.
extends GutTest

const PHASE_DIR := "res://data/phases"


func _phase_sets() -> Array[PhaseSet]:
	var sets: Array[PhaseSet] = []
	for file in DirAccess.get_files_at(PHASE_DIR):
		if file.ends_with(".tres"):
			var res := load("%s/%s" % [PHASE_DIR, file])
			if res is PhaseSet:
				sets.append(res)
	return sets


func test_phase_sets_exist() -> void:
	assert_gt(_phase_sets().size(), 1, "expected the M0 test ladder and the Spring Court ladder")


func test_every_ladder_is_consistent() -> void:
	for set in _phase_sets():
		var ids := {}
		for phase in set.phases:
			assert_false(ids.has(phase.id), "%s: duplicate phase %s" % [set.resource_path, phase.id])
			ids[phase.id] = true
		assert_true(ids.has(set.start_phase), "%s: start phase missing" % set.resource_path)
		for phase in set.phases:
			if phase.next_phase != &"":
				assert_true(ids.has(phase.next_phase), "%s: %s points to missing %s" % [set.resource_path, phase.id, phase.next_phase])
				assert_not_null(phase.exit_condition, "%s: %s has a next phase but no exit" % [set.resource_path, phase.id])


func test_spring_court_ladder_matches_root_doc() -> void:
	var set := load("res://data/phases/spring_court_phases.tres") as PhaseSet
	assert_eq(set.phases.size(), 9, "root design doc §4.1 has phases 0 to 8")
	assert_eq(set.start_phase, &"p0_winter")

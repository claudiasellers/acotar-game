extends GutTest
## F28: every phase CourtMap.UNLOCK_PHASE names exists in the Spring Court's
## phase set, so a region can't wait on a phase that was renamed away.


func test_unlock_phases_exist() -> void:
	var set := load("res://data/phases/spring_court_phases.tres") as PhaseSet
	assert_not_null(set, "spring_court_phases.tres loads")
	var ids := {}
	for p in set.phases:
		ids[p.id] = true
	var stale: Array[String] = []
	for region: StringName in CourtMap.UNLOCK_PHASE:
		var phase: StringName = CourtMap.UNLOCK_PHASE[region]
		if phase != &"" and not ids.has(phase):
			stale.append("%s -> %s" % [region, phase])
	assert_eq(stale, [] as Array[String], "UNLOCK_PHASE names phases that don't exist")

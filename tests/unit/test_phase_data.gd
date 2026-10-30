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


## Flag names and gates are the Keeper's chapter mapping
## (lore/07-story/timeline-overview.md, "Mapped to the plan's phase ladder").
func test_gates_follow_the_keeper_mapping() -> void:
	var set := load("res://data/phases/spring_court_phases.tres") as PhaseSet
	var expected := {
		&"p0_winter": ["wolf_killed", "pelt_sold"],
		&"p1_wolf_and_crossing": ["beast_claim_accepted", "wall_crossed"],
		&"p2_grounds": ["first_dinner_eaten", "curtain_trap_set", "bogge_survived", "puca_resisted"],
		&"p3_house_and_woods": ["tamlin_wound_dressed", "manor_map_drawn", "study_mural_seen",
				"suriel_bound", "naga_survived", "summer_faerie_comforted"],
		&"p4_wider_court": ["starlight_pool_found", "gallery_opened", "first_painting", "attor_evaded"],
		&"p5_calanmai": ["calanmai_attended", "stranger_met", "bite_endured", "paintings_shown"],
		&"p6_blight_tightens": ["glamour_lifted", "fountain_head_found", "solstice_danced", "rhysand_faced", "sent_home"],
		&"p7_return_home": ["nesta_truth_heard", "beddor_fire_learned", "wall_recrossed"],
		&"p8_the_pass": ["alis_truth_heard", "departed_for_mountain"],
	}
	for id in expected:
		var phase := set.get_phase(id)
		assert_not_null(phase, "missing %s" % id)
		assert_eq(Array(phase.exit_condition.flags), expected[id], String(id))
		assert_eq(phase.exit_condition.mode, ExitCondition.Mode.ALL)
	assert_true(set.get_phase(&"p1_wolf_and_crossing").unlocked_regions.has("border_woods"))

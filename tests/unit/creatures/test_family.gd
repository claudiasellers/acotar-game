extends GutTest

const FATHER := preload("res://data/creatures/family/father.tres")
const ELAIN := preload("res://data/creatures/family/elain.tres")


func test_schedule_lookup() -> void:
	assert_eq(FATHER.activity_at(9.0), &"carve")
	assert_eq(FATHER.spot_at(9.0), &"hearth")
	assert_eq(FATHER.activity_at(12.5), &"eat")
	assert_eq(ELAIN.activity_at(8.0), &"garden")


func test_schedule_wraps_past_midnight() -> void:
	assert_eq(FATHER.activity_at(23.5), &"sleep")
	assert_eq(FATHER.activity_at(3.0), &"sleep")
	assert_eq(FATHER.activity_at(27.0), &"sleep")


func test_every_schedule_has_six_or_more_entries() -> void:
	for name in ["father", "nesta", "elain"]:
		var s := load("res://data/creatures/family/%s.tres" % name) as FamilySchedule
		assert_gte(s.start_hours.size(), 6)
		assert_eq(s.activities.size(), s.start_hours.size())
		assert_eq(s.spots.size(), s.start_hours.size())


func test_scripted_member_ignores_schedule() -> void:
	var m := preload("res://creatures/family/father.tscn").instantiate() as FamilyMember
	add_child_autofree(m)
	m.set_scripted(true)
	m.activity = &"gather"
	m._process(0.1)
	assert_eq(m.activity, &"gather")

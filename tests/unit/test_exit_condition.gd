extends GutTest

var _set_flags: Array = []


func _has(flag: String) -> bool:
	return _set_flags.has(flag)


func _cond(flags: Array, mode := ExitCondition.Mode.ALL) -> ExitCondition:
	var c := ExitCondition.new()
	c.mode = mode
	c.flags = PackedStringArray(flags)
	return c


func test_all_needs_every_flag() -> void:
	var c := _cond(["a", "b"])
	_set_flags = ["a"]
	assert_false(c.evaluate(_has))
	_set_flags = ["a", "b"]
	assert_true(c.evaluate(_has))


func test_any_needs_one_flag() -> void:
	var c := _cond(["a", "b"], ExitCondition.Mode.ANY)
	_set_flags = ["b"]
	assert_true(c.evaluate(_has))


func test_nested_children() -> void:
	# wolf_killed AND (crossed_on_horse OR crossed_on_foot)
	var c := _cond(["wolf_killed"])
	c.children = [_cond(["crossed_on_horse", "crossed_on_foot"], ExitCondition.Mode.ANY)]
	_set_flags = ["wolf_killed"]
	assert_false(c.evaluate(_has))
	_set_flags = ["wolf_killed", "crossed_on_foot"]
	assert_true(c.evaluate(_has))


func test_empty_condition_never_met() -> void:
	assert_false(ExitCondition.new().evaluate(_has))

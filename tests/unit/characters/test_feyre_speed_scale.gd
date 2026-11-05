extends GutTest
## T086 contract: every on-foot speed is 1.30x its pre-T086 value.

const OLD := {&"walk_speed": 3.2, &"run_speed": 8.22, &"sprint_speed": 13.10, &"aim_speed": 2.2,
		&"sprint_acceleration": 24.0, &"braking": 60.0, &"turn_friction": 10.0, &"turn_speed": 12.0}


func test_each_speed_is_130_percent_of_old() -> void:
	var f: Feyre = autofree(load("res://characters/feyre/feyre.tscn").instantiate())
	for key: StringName in OLD:
		assert_almost_eq(float(f.get(key)), float(OLD[key]) * 1.3, 0.01, "%s is 1.3x" % key)

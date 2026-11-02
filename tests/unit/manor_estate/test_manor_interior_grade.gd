extends GutTest
## The contract the look depends on: a RegionGrade that holds inside the rooms,
## read by height as well as plan, and nowhere on the grounds around them (T043).

var house: Node3D
var grade: ManorInteriorGrade
var room: Dictionary


func before_each() -> void:
	house = Node3D.new()
	house.add_to_group(ManorIndoors.GROUP)
	add_child_autofree(house)
	grade = ManorInteriorGrade.new()
	house.add_child(grade)
	room = ManorIndoors._load()[0]


func _in_room(u: float, v: float, y: float) -> Vector3:
	var rect: Rect2 = room["rect"]
	return Vector3(rect.position.x + rect.size.x * u, float(room["floor"]) + y, rect.position.y + rect.size.y * v)


func test_a_room_is_inside() -> void:
	assert_true(grade.contains(_in_room(0.5, 0.5, 0.1)))


func test_above_the_roof_is_outside() -> void:
	assert_false(grade.contains(Vector3(0.0, 500.0, 0.0)))


func test_far_off_on_the_grounds_is_outside() -> void:
	assert_false(grade.contains(Vector3(0.0, float(room["floor"]), 400.0)))


func test_a_cellar_counts_at_its_own_depth() -> void:
	for r: Dictionary in ManorIndoors._load():
		if float(r["floor"]) < ManorHouseBuilder.floor_y(0) - 0.5:
			var c := (r["rect"] as Rect2).get_center()
			assert_true(grade.contains(Vector3(c.x, float(r["floor"]) + 0.1, c.y)), "the cellar is inside")
			return
	pass_test("no cellar in this layout")


func test_it_blends_quickly_both_ways() -> void:
	assert_eq(grade.grade, &"manor_interior")
	assert_eq(grade.blend_seconds, 1.0)
	assert_eq(grade.leave_seconds, 1.0)

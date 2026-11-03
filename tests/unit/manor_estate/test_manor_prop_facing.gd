## Contract: furniture stands with its front toward the room, not toward the
## nearest wall. A prop's front faces -Z at yaw 0 (PropLib); the layouts are
## drawn by hand and tidied by ManorLayoutDsl.face_walls, which only turns pieces
## within WALL_REACH of a wall. A piece standing a little further out kept its
## hand-written yaw and showed its back to the room (Feyre's dressing-room wardrobe).
extends GutTest

const PATHS := [
	"res://data/regions/spring_court/manor_estate/house/ground.tres",
	"res://data/regions/spring_court/manor_estate/house/upper.tres",
	"res://data/regions/spring_court/manor_estate/house/service.tres",
]
## Pieces with a real front that must never face a wall they stand near.
const FRONTED := [&"wardrobe_tall", &"dresser", &"dresser_crockery", &"vanity_table", &"shoe_shelf",
		&"bookcase", &"fireplace", &"sideboard"]
const NEAR_WALL := 1.6


## Unit vector, in room space, of the way a prop's front points.
func _front(yaw_deg: float) -> Vector2:
	var v := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	return Vector2(v.x, v.z)


## [wall distance, outward normal] of the nearest wall of the room to (x, z).
func _nearest_wall(r: ManorRoomDef, x: float, z: float) -> Array:
	var cand := [[z, Vector2(0, -1)], [r.rect.size.y - z, Vector2(0, 1)],
			[x, Vector2(-1, 0)], [r.rect.size.x - x, Vector2(1, 0)]]
	var best: Array = cand[0]
	for c in cand:
		if c[0] < best[0]:
			best = c
	return best


func _backwards() -> Array:
	var bad := []
	for path in PATHS:
		var layout := load(path) as ManorHouseLayout
		for r in layout.rooms:
			for p in r.props:
				if not FRONTED.has(p.prop_id):
					continue
				var w := _nearest_wall(r, p.position.x, p.position.z)
				if w[0] <= NEAR_WALL and _front(p.yaw_deg).dot(w[1]) > 0.7:
					bad.append("%s %s at (%.1f, %.1f) yaw %d" % [r.id, p.prop_id, p.position.x, p.position.z, int(p.yaw_deg)])
	return bad


func test_fronted_furniture_faces_into_the_room() -> void:
	for b in _backwards():
		print("BACKWARDS ", b)
	assert_eq(_backwards(), [],"furniture showing its back to the room")


func test_dressing_room_wardrobe_front_points_away_from_its_wall() -> void:
	var layout := load(PATHS[1]) as ManorHouseLayout
	var found := false
	for r in layout.rooms:
		if r.id != &"dressing_room":
			continue
		for p in r.props:
			if p.prop_id == &"wardrobe_tall":
				found = true
				var w := _nearest_wall(r, p.position.x, p.position.z)
				assert_lt(_front(p.yaw_deg).dot(w[1]), -0.9, "wardrobe front points away from the %s wall" % [w[1]])
	assert_true(found, "dressing room has its wardrobe")

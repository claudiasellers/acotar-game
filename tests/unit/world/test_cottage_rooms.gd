## L38-2: the Archeron cottage's two rooms as the book has them (Keeper canon,
## ch 1-4; plans/manor-refurnish/cottage-canon.md). The main room keeps the
## hearth, table, chairs and her father's cot by the fire; the sisters' small
## room behind its partition holds the ironwood bed (never painted) and the
## dresser with their three painted drawers. The front door, the hearth and
## the Act I anchors stay where the chain expects them.
extends GutTest

const SCENE := "res://world/human_realm/cottage/cottage.tscn"
## The partition in the cottage frame (tools/blender/human_realm/cottage_buildings.py).
const PART_X := -1.1
const PART_Z := -0.6
const BED_DOOR := Vector2(-2.65, -1.75)

var _root: Node3D
var _inside: Node3D


func before_each() -> void:
	_root = (load(SCENE) as PackedScene).instantiate()
	add_child_autofree(_root)
	_inside = _root.find_child("Interior", true, false) as Node3D


func _local(n: String) -> Vector3:
	var node := _inside.get_parent().find_child(n, true, false) as Node3D   # the cottage (door) or the interior
	assert_not_null(node, n)
	return _inside.global_transform.affine_inverse() * node.global_position if node else Vector3.INF


func _in_sisters_room(p: Vector3) -> bool:
	return p.x < PART_X and p.z > PART_Z


func test_bed_and_dresser_are_in_the_sisters_room() -> void:
	for n in ["SistersBed", "Dresser", "NestasRibbonAndComb", "ElainsSeedPackets", "IronBracelets", "PegsNightclothes", "RagRug"]:
		assert_true(_in_sisters_room(_local(n)), "%s in the sisters' room" % n)
	assert_true(_in_sisters_room(_local("DresserDrawers")), "the drawers' motif goes with the dresser")


func test_main_room_keeps_hearth_table_chairs_and_the_cot() -> void:
	for n in ["Hearth", "Table", "ChairByTable", "ChairTableEnd", "FathersChair", "FathersCot", "PaintCorner"]:
		assert_false(_in_sisters_room(_local(n)), "%s in the main room" % n)
	var cot := _local("FathersCot")
	var hearth := _local("Hearth")
	assert_lt(Vector2(cot.x, cot.z).distance_to(Vector2(hearth.x, hearth.z)), 3.0, "the cot is by the fire")


func test_story_fixtures_did_not_move() -> void:
	assert_almost_eq(_local("CottageDoor"), Vector3(-1.9, 0.0, -2.95), Vector3.ONE * 0.01)
	assert_almost_eq(_local("Hearth"), Vector3(3.62, 0.0, 0.0), Vector3.ONE * 0.01)
	assert_almost_eq(_local("act1_cottage_door"), Vector3(-1.9, 0.0, -2.85), Vector3.ONE * 0.01)
	assert_almost_eq(_local("act1_cottage_interior"), Vector3(-0.5, 0.0, 0.0), Vector3.ONE * 0.01)


## "The ironwood bed is NEVER painted": no motif stands over its footprint.
func test_the_bed_is_never_painted() -> void:
	var bed := _local("SistersBed")
	var motifs := _inside.get_node("PaintedMotifs")
	for m in motifs.get_children():
		var p := _inside.global_transform.affine_inverse() * (m as Node3D).global_position
		assert_false(absf(p.x - bed.x) < 1.1 and absf(p.z - bed.z) < 0.95, "%s painted on the bed" % m.name)


func test_partition_walls_the_room_and_its_door_is_open() -> void:
	await wait_physics_frames(3)
	var space := _root.get_world_3d().direct_space_state
	var t := _inside.global_transform
	var hits := func(a: Vector3, b: Vector3) -> bool:
		var q := PhysicsRayQueryParameters3D.create(t * a, t * b, 1)
		q.hit_back_faces = true
		return not space.intersect_ray(q).is_empty()
	var mid := (BED_DOOR.x + BED_DOOR.y) * 0.5
	assert_false(hits.call(Vector3(mid, 1.0, -1.6), Vector3(mid, 1.0, 0.3)), "walk through the bedroom door")
	assert_true(hits.call(Vector3(-3.6, 1.4, -1.6), Vector3(-3.6, 1.4, 0.6)), "north partition is solid")
	assert_true(hits.call(Vector3(-0.3, 1.4, 1.6), Vector3(-1.9, 1.4, 1.6)), "east partition is solid")
	# the straight walk from the front door to the bed (the chain's sleep beat) goes through the doorway
	var door := Vector2(-1.9, -2.85)
	var bed := _local("SistersBed")
	var u := (PART_Z - door.y) / (bed.z - door.y)
	var x := lerpf(door.x, bed.x, u)
	assert_between(x, BED_DOOR.x + 0.15, BED_DOOR.y - 0.15, "door-to-bed line crosses the partition at the doorway")


func test_the_little_things_from_the_book() -> void:
	for n in ["FeyresBoots", "NestasBoots", "CurtainsFront", "CurtainsBack", "ChippedMug", "WaterPot", "HearthFlameCurls",
			"FeyresBowAndQuiver", "FathersCane", "BedroomDoor", "CandleStub"]:
		assert_not_null(_inside.find_child(n, true, false), n)
	for n in ["FeyresBoots", "NestasBoots"]:
		var p := _local(n)
		assert_lt(Vector2(p.x, p.z).distance_to(Vector2(-1.9, -2.7)), 1.2, "%s by the door" % n)

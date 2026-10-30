## Places the Act I scene spaces at the human-realm lane's anchors
## (docs/contracts/story_anchors.md, "Act I"). StoryDirector calls attach()
## for every anchor it sees; the greybox builds its own spaces instead.
class_name Act1Anchors
extends RefCounted

const ANCHORS := [&"act1_cottage_interior", &"act1_cottage_door", &"act1_food_tally_beam",
		&"act1_wolf_clearing", &"act1_fur_stall"]


## Hangs the Act I spaces for one anchor under it. Safe to call twice.
static func attach(anchor: Node3D, director: Node) -> Array[SceneSpace]:
	var spaces: Array[SceneSpace] = []
	var anchor_id := StringName(anchor.get_meta(&"anchor_id", anchor.name))
	if not ANCHORS.has(anchor_id):
		return spaces
	match anchor_id:
		&"act1_cottage_interior":
			var size: Vector3 = anchor.get_meta(&"size", Vector3(7.0, 3.0, 5.5))
			spaces.append(_add(anchor, "BeastDoor", BeastDoor.new(), size))
		&"act1_food_tally_beam":
			spaces.append(_add(anchor, "FoodTally", FoodTally.new()))
		&"act1_wolf_clearing":
			spaces.append(_add(anchor, "WolfKill", WolfKill.new(), Vector3(30.0, 6.0, 30.0)))
			spaces.append(_add(anchor, "WolfSkinning", WolfSkinning.new()))
		&"act1_fur_stall":
			spaces.append(_add(anchor, "PeltSale", PeltSale.new()))
	_ensure_ride(director)
	return spaces


static func _add(anchor: Node3D, node_name: String, space: SceneSpace, entry_size: Vector3 = Vector3.ZERO) -> SceneSpace:
	var existing := anchor.get_node_or_null(node_name) as SceneSpace
	if existing:
		space.free()
		return existing
	space.name = node_name
	if entry_size != Vector3.ZERO:
		var area := Area3D.new()
		area.name = "Entry"
		area.collision_layer = 0
		area.collision_mask = 1 << 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = entry_size
		shape.shape = box
		shape.position.y = entry_size.y * 0.5
		area.add_child(shape)
		space.add_child(area)
	anchor.add_child(space)
	return space


## The ride north follows the world lane's WallSeamPath; one per game.
static func _ensure_ride(director: Node) -> void:
	if director.get_node_or_null(^"RideNorth") or director.get_tree().root.find_child("RideNorth", true, false):
		return
	var ride := RideNorth.new()
	ride.name = "RideNorth"
	director.add_child(ride)

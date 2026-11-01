## The studio's story deeds (L30, R2: flags rise only through ActionTrigger).
##
## Canon (Keeper, ch16/19): Feyre asks for paint, Tamlin opens the cleaned
## gallery, then the painting room is hers, stocked. In play the asking is a
## deed: in P4 (starlight_pool_found) her first stroke at the easel raises
## gallery_opened, which unlocks the gallery door (ManorDoorLeaf) and stocks
## the room (StudioSupply.stocked). Her first finished canvas raises
## first_painting. Before P4 the easel stays under its dust sheet.
class_name StudioDeeds
extends RefCounted

const POOL_FLAG := "starlight_pool_found"
const GALLERY_FLAG := "gallery_opened"
const FIRST_FLAG := "first_painting"
## The gallery's locked door, as ManorHouseBuilder names it.
const GALLERY_DOOR := "Door_26_-52"


## The easel is uncovered from P4 on.
static func easel_open() -> bool:
	return WorldState.has_flag(POOL_FLAG) or WorldState.has_flag(GALLERY_FLAG)


## Call after each stroke lands. Returns true when this stroke opened the gallery.
static func stroke_made(tree: SceneTree) -> bool:
	if tree == null or not WorldState.has_flag(POOL_FLAG) or WorldState.has_flag(GALLERY_FLAG):
		return false
	raise(tree, GALLERY_FLAG)
	var door := tree.root.find_child(GALLERY_DOOR, true, false) as Node3D
	if door:
		Juice.burst(door, &"unlock")
	return true


## Saves and records the canvas (Gallery), leans it in the room and raises
## first_painting the first time. Returns the gallery record.
static func finish(canvas: StudioCanvas, title: String, tree: SceneTree, easel: Node3D) -> Dictionary:
	# Gallery takes the older canvas model; hand it this image.
	var legacy := PaintingCanvas.new(Gameplay.inventory)
	legacy.image = canvas.image
	legacy.strokes = maxi(canvas.strokes, 1)
	var record := Gameplay.gallery.finish(legacy, title, tree)
	if tree and not WorldState.has_flag(FIRST_FLAG):
		raise(tree, FIRST_FLAG)
	if easel and easel.is_inside_tree():
		StudioRoom.ensure_lean_spots(easel)
		PaintingObject.hang(record, easel.get_parent(), easel)
	return record


static func raise(tree: SceneTree, flag: String) -> void:
	var trigger := ActionTrigger.new()
	trigger.name = "StudioTrigger_%s" % flag
	trigger.flag = flag
	trigger.fire_on_body_enter = false
	tree.root.add_child(trigger)
	trigger.fire()
	trigger.queue_free()

## The wardrobe page of Feyre's journal: the dressing room's mirror and rails
## (DressingRoomView) on what she carries, beside her satchel. The manor's
## wardrobe and vanity stations open the same page on their own stock
## (DressingRoom.open). The view is made on show and let go on hide, since it
## takes the camera and her pose and gives them back when it leaves.
class_name WardrobeTab
extends MenuTab

## Which wardrobe the page is showing: DressingRoom.SATCHEL, or a station id.
var station: StringName = DressingRoom.SATCHEL
var view: DressingRoomView = null
## Who is dressing; the player when left empty.
var who: Feyre = null
var _crown_seen: bool = false


## The scene's wardrobe page, made (as a child of the shell) if it has none.
static func ensure(tree: SceneTree) -> WardrobeTab:
	var shell := MenuShell.of(tree)
	var tab := shell.find(&"wardrobe") as WardrobeTab
	if tab == null:
		tab = WardrobeTab.new()
		shell.add_child(tab)
		shell.register(tab)
	return tab


func _init() -> void:
	name = "DressingRoom"
	tab_id = &"wardrobe"
	tab_title = "Wardrobe"
	tab_order = 1


func available() -> bool:
	return is_inside_tree() and _player() != null


## News on its tab: she has the blooms for a crown and has not opened the
## page since she did (weaving has no key in the world; this is how she
## learns she can).
func has_news() -> bool:
	if CrownWeaver.best_recipe(Gameplay.inventory) == null:
		_crown_seen = false
		return false
	return not _crown_seen


func _player() -> Feyre:
	return get_tree().get_first_node_in_group(&"player") as Feyre


func _shown() -> void:
	var feyre := who if is_instance_valid(who) else _player()
	if feyre == null:
		return
	_crown_seen = true
	# Pieces arrive with the story (WardrobeStock); her satchel only holds
	# what she already has.
	if station != DressingRoom.SATCHEL:
		WardrobeStock.restock(Gameplay.wardrobe)
	view = DressingRoomView.new()
	view.setup(feyre, station)
	_book_root().add_child(view)
	MenuShell.of(get_tree()).set_window(DressingRoomView.MIRROR)


func _hidden() -> void:
	station = DressingRoom.SATCHEL
	who = null
	MenuShell.of(get_tree()).set_window(Rect2())
	if view == null or not is_instance_valid(view):
		return
	var feyre := view.feyre
	# Out of the tree now (her pose and camera come back) before the game
	# unpauses; freed at the frame's end, as a button may be mid-press.
	view.get_parent().remove_child(view)
	view.queue_free()
	view = null
	if is_instance_valid(feyre) and feyre.camera:
		feyre.camera.current = true

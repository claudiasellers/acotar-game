## The dressing room (manor): try on outfits, hair and makeup in front of the
## vanity mirror. Opened from the "wardrobe" (outfits + hair) and
## "dressing_mirror" (makeup + hair) stations, and from the satchel
## (SATCHEL: the small things she carries). The screen itself is
## DressingRoomView; this keeps the open/close entry points.
class_name DressingRoom
extends RefCounted

## Opened from her satchel rather than a station.
const SATCHEL := &"satchel"

static var _open: CanvasLayer = null


static func open(feyre: Feyre, station_id: StringName) -> void:
	if _open and is_instance_valid(_open):
		return
	# Pieces arrive with the story (WardrobeStock); her satchel only holds
	# what she already has.
	if station_id != SATCHEL:
		WardrobeStock.restock(Gameplay.wardrobe)
	var layer := CanvasLayer.new()
	layer.name = "DressingRoom"
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var view := DressingRoomView.new()
	view.setup(feyre, station_id)
	layer.add_child(view)
	_open = layer
	feyre.get_tree().root.add_child(layer)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	feyre.get_tree().paused = true


static func close_room(feyre: Feyre) -> void:
	if _open and is_instance_valid(_open):
		# Out of the tree now (her pose and camera come back) before the
		# game unpauses; freed at the frame's end, as a button may be mid-press.
		if _open.get_parent():
			_open.get_parent().remove_child(_open)
		_open.queue_free()
	_open = null
	if feyre.camera:
		feyre.camera.current = true
	feyre.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


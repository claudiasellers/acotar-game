## The dressing room (manor): try on outfits, hair and makeup in front of the
## vanity mirror. Opened from the "wardrobe" (outfits + hair) and
## "dressing_mirror" (makeup + hair) stations, and from the satchel
## (SATCHEL: the small things she carries). The screen is DressingRoomView,
## shown as the menu shell's wardrobe page (WardrobeTab); this keeps the
## open/close entry points.
class_name DressingRoom
extends RefCounted

## Opened from her satchel rather than a station.
const SATCHEL := &"satchel"


static func open(feyre: Feyre, station_id: StringName) -> void:
	var tab := WardrobeTab.ensure(feyre.get_tree())
	if tab.is_open():
		return
	tab.station = station_id
	tab.who = feyre
	tab.open()


static func close_room(feyre: Feyre) -> void:
	var tab := WardrobeTab.ensure(feyre.get_tree())
	tab.close()


static func is_open() -> bool:
	var tab := view_tab()
	return tab != null and tab.is_open()


## The open dressing room screen, or null.
static func view() -> DressingRoomView:
	var tab := view_tab()
	return tab.view if tab and tab.is_open() else null


static func view_tab() -> WardrobeTab:
	var loop := Engine.get_main_loop() as SceneTree
	return MenuShell.of(loop).find(&"wardrobe") as WardrobeTab if loop else null

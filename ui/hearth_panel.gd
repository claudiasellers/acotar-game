## The M1 hearth panel, now the brewing screen (BrewMenu, lane L62). Kept as a
## thin entry point for older callers and tools.
extends RefCounted


static func open(feyre: Feyre, station: CookingStation) -> void:
	BrewMenu.open_for(feyre, station)


static func _close(feyre: Feyre) -> void:
	var menu := BrewMenu.find(feyre.get_tree())
	if menu:
		menu.close()

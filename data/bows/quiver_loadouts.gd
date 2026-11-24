## What is in Feyre's quiver when a game starts in a phase (bow design §8.2).
## Chapter 1 is canon: "a hunting knife and three arrows", two ordinary and
## the ash. Later quivers are found in the world, not granted here.
class_name QuiverLoadouts
extends Resource

## Phase id -> {arrow item id: count}.
@export var by_phase: Dictionary = {}
## For phase sets with no row of their own (test hills, sandboxes).
@export var otherwise: Dictionary = {}


func loadout(phase: StringName) -> Dictionary:
	return by_phase.get(phase, otherwise)


## Fills an empty quiver with the phase's loadout. A quiver with anything in
## it (a loaded save, a test's own arrows) is left alone.
func fill(inventory: Inventory, phase: StringName) -> void:
	if inventory.arrow_count() > 0:
		return
	var arrows := loadout(phase)
	for item: StringName in arrows:
		inventory.add(item, int(arrows[item]))

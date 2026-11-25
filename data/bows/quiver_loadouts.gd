## What is in Feyre's quiver when a game starts in a phase (bow design §8.2).
## Chapter 1 is canon: "a hunting knife and three arrows", two ordinary and
## the ash. Later quivers are found in the world, not granted here.
class_name QuiverLoadouts
extends Resource

## Phase id -> {arrow item id: count}.
@export var by_phase: Dictionary = {}
## For phase sets with no row of their own (test hills, sandboxes).
@export var otherwise: Dictionary = {}


## Phase id -> arrows the quiver she has by then holds (§8.1): her hand in
## chapter 1, the stableboy's quiver, the armoury's, then a full one.
@export var size_by_phase: Dictionary = {}
## For phase sets with no row of their own.
@export var size_otherwise: int = Inventory.FULL_QUIVER


func size(phase: StringName) -> int:
	return int(size_by_phase.get(phase, size_otherwise))


## She carries at least the quiver this phase gives her.
func carry(inventory: Inventory, phase: StringName) -> void:
	inventory.carry_quiver(size(phase))


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

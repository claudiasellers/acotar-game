## Global signal hub. Systems announce what happened here; nothing in core
## calls story code directly.
extends Node

## A world-state flag changed value.
signal flag_changed(flag: String, value: Variant)
## Feyre did something that matters to the story (raised by ActionTrigger).
signal deed_performed(flag: String)
## PhaseManager moved from one phase to another.
signal phase_changed(previous: StringName, current: StringName)
## A region's physical lock opened or closed.
signal region_unlocked(region_id: StringName)
signal region_locked(region_id: StringName)
## A new in-game day began.
signal day_started(day: int)
## A save was written or loaded.
signal game_saved(slot: String)
signal game_loaded(slot: String)

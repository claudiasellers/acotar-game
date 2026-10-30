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

# --- Cross-lane seams (docs/STORY_INTERFACES.md). Story code listens to these;
# it never calls into systems/ or creatures/ directly.

## Systems: the family's food changed (P0 gate).
signal food_stock_changed(days_of_food: float)
## Systems: something entered Feyre's inventory, or was sold at a market.
signal item_acquired(item_id: StringName, count: int)
signal item_sold(item_id: StringName, coin: int)
## Creatures: an animal or fae died, or was skinned and butchered.
signal creature_killed(creature_id: StringName, kind: StringName, cause: StringName, position: Vector3)
signal creature_harvested(creature_id: StringName, kind: StringName, items: PackedStringArray)

## Story: hand Feyre an item the scene needs (the one ash arrow).
signal story_item_granted(item_id: StringName, count: int)
## Story: ask the owning lane to place an actor (great_wolf, doe, tamlin_beast).
signal story_spawn_requested(spawn_id: StringName, where: Transform3D)
## Story: a staging cue for an actor or group ("family", "gather").
signal story_actor_cue(actor: StringName, cue: StringName)
## Story: an anchored scene space began or ended.
signal scene_space_started(space_id: StringName)
signal scene_space_finished(space_id: StringName)
## Story to world: blend the colour grade (the wall crossing, cold to spring).
signal grade_swap_requested(to_grade: StringName, seconds: float)
## Story to world/audio: set a scene mood. &"dread" (the wolf, the beast) means
## silence the ambience, gutter the fire, cold low light; &"calm" restores.
## intensity 0..1, blended over `seconds`.
signal mood_requested(mood: StringName, intensity: float, seconds: float)
## Creatures: an arrow or blade struck a creature without (yet) killing it.
## part: &"side", &"eye", &"leg"... as the creatures lane resolves it.
signal creature_hit(creature_id: StringName, kind: StringName, cause: StringName, part: StringName)
## Story to world: change the weather now (&"snow_heavy", &"snow_slow",
## &"snow_pause", &"clear"), blended over `seconds`.
signal weather_requested(weather: StringName, seconds: float)
## Story to world/audio/VFX: a Spring Court deed or unlock lands. Sparkle and
## chime (R3); never used for the horror beats.
signal celebration_requested(kind: StringName, at: Vector3)
## Story to StoryDirector/world: move Feyre to another region (the carriage
## home, the ride back). anchor_id is a story anchor there, or empty.
signal travel_requested(region_id: StringName, anchor_id: StringName)
## Story to systems: a journal or map truth Feyre learned (Suriel answers,
## the Treaty, Amarantha's terms).
signal journal_entry_added(entry_id: StringName)

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
## Story/dialogue to faces: hold an expression on an actor for `seconds`
## (0 = until the next request), intensity 0..1 (docs/contracts/faces.md).
signal face_requested(actor: StringName, expression: StringName, intensity: float, seconds: float)
## A line was spoken aloud (lip movement and its emotion), lasting `seconds`.
signal line_spoken(actor: StringName, text: String, emotion: StringName, seconds: float)
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

# --- Feyre's vitals (docs/contracts/vitals.md; owner's OK for L76, 2026-11-24).
# Nothing calls Feyre directly: anything that hurts or frightens her emits the
# inbound signals; the vitals lane announces the outbound ones.

## Legacy, kept for naga.gd: identical to player_hit(source_id, kind, amount, Vector3.INF).
## `kind` resolves as an attack id; a family kind (&"naga") resolves to that family's default attack.
signal player_struck(source_id: StringName, kind: StringName, amount: float)
## A hit on Feyre. attack_id names an AttackData row; scale multiplies its damage.
## origin is the attacker's world position (Vector3.INF = "from in front of her").
signal player_hit(source_id: StringName, attack_id: StringName, scale: float, origin: Vector3)
## A timed status on Feyre (venom, drowsy, roar_shake...). magnitude 0..1, seconds > 0.
signal player_status_applied(source_id: StringName, tag: StringName, magnitude: float, seconds: float)
## A fright with no damage. amount 0..1 is added to dread, scaled by her dread gain.
signal player_startled(source_id: StringName, amount: float)
## A hold she breaks by mashing interact (each press costs stamina).
signal player_grabbed(source_id: StringName, break_presses: int, hold_seconds: float)
## The holder let go, or she broke free.
signal player_released(source_id: StringName)
## Health changed. delta < 0 is harm. source_id is &"" for food, rest or regen.
signal player_health_changed(health: float, max_health: float, delta: float, source_id: StringName)
## Health reached 0: she is down (dazed, seeing stars; never "dead"). cause = the attack id.
signal player_knocked_down(source_id: StringName, cause: StringName, at: Vector3)
## She came round at a rest point (or on the spot). 3 s grace follows.
signal player_woke(rest_point_id: StringName, at: Vector3)
## A status started, changed or ended (magnitude 0 = ended). For HUD and audio.
signal player_status_changed(tag: StringName, magnitude: float, seconds_left: float)
## Dread (0..1, fast) or ease (0..1, slow baseline) moved by more than 0.02. At most 10 Hz.
signal player_mood_changed(dread: float, ease: float)
## An item imbue started or ended (seconds_left 0 = ended). item_slot: &"cloak", &"boots"...
signal player_imbue_changed(item_slot: StringName, imbue_id: StringName, seconds_left: float)

# --- Hostile sites (L75) and crouch: declared so their guarded emits land.

## A hostile site calmed down after an alert.
signal site_settled(site_id: StringName)
## A hostile site noticed her; level 0..1 (curious to alerted).
signal hostile_alerted(site_id: StringName, level: float)
## Feyre crouched or stood.
signal player_stance_changed(crouched: bool)

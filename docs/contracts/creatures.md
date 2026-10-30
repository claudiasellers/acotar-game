# Contract: creatures

Owner: creatures lane (`creatures/`, `data/creatures/`, `tools/blender/creatures.py`).

## Physics
- Creatures are `CharacterBody3D` on layer 4 (`1 << 3`, same as targets) so arrows and Feyre's aim ray hit them; mask = world (layer 1).
- Models face -Z with feet at y = 0. `CreatureData.model_scene` swaps the art in with no code change.

## Groups
| Group | Members | Use |
|---|---|---|
| `creatures` | every Creature | counts, saves |
| `creature_senses` | every CreatureSenses | noise broadcast |
| `harvestable` | unharvested carcasses | systems lane's interact |
| `doe` | the doe(s) Andras hunts | great wolf target |
| `track_layer` | the scene's TrackLayer | marks |
| `family`, `family_spot`, `hearth` | family members, cottage spots (meta `spot_id`), the hearth | routines, gather cue |
| `beast`, `beast_affected_lights` | Tamlin's beast form, lights it gutters | field force |
| `story_actor_<spawn_id>` | actors StorySpawner answered with | story lane's handshake |

## Reads from other lanes
- Wind: first node in group `wind_source` with `wind_at(pos: Vector3) -> Vector3`; snowfall via `snowfall_at(pos) -> float` or property `snowfall` on the same node (0 if absent).
- Arrow type: `arrow.arrow_id` (StringName), else meta `arrow_id`, else `&"wood"`. `&"ash"` is lethal to fae.
- Player: group `player`; signals `bow_released(pos, loudness)` (optional), `arrow_fired(arrow)`.

## API
- `CreatureSenses.emit_noise(tree, pos, loudness)`: loudness 1.0 carries full hearing range.
- `Creature.on_arrow_hit(arrow)`, `Creature.die(cause)`, signals `wounded(cause)`, `died(cause)`. `scripted = true` pauses the brain.
- `Harvestable.harvest() -> Array[{item_id: StringName, qty: int}]` (once), `Harvestable.nearest(tree, pos, reach)`.
- `TrackLayer.leave(tree, kind, pos, heading, size)`; `marks_near(pos, radius)`.
- `GreatWolf`: `looked_at_player`, `took_prey(prey)`; export `kill_flag` (empty in the game; the story lane owns `wolf_killed`).
- `BeastActor`: `begin_approach(door)`, `break_door()`, `hold_presence()`, `loom(pos)`, `speak()`, `lead(pos)`, `withdraw()`, `pressure_at(pos) -> float` (0 beyond 18 m).
- `FamilyMember.set_scripted(bool)`, `go_to(pos)`.
- `StorySpawner` (add one to any scene hosting a story beat) answers `story_spawn_requested` for `great_wolf`, `doe`, `deer`, `hare`, `wolf`, `tamlin_beast`.

## EventBus (signals defined by the story lane; used only if present)
- Emits `creature_killed(creature_id, kind, cause, position)`. Kinds: `deer`, `hare`, `bird`, `wolf`, `great_wolf`. Cause: `arrow_<arrow_id>`; a creature that dies with an ash wound in it reports `arrow_ash` even if a wood arrow finished it.
- Emits `creature_harvested(creature_id, kind, items: PackedStringArray)`.
- Listens: `story_spawn_requested(spawn_id, transform)`, `story_actor_cue(actor, cue)`; beast cues `enter`, `loom`, `speak`, `lead`, `leave`; family cues `gather`, `release`.

## Item ids yielded (systems lane catalogue)
deer: `ing_venison` x3, `ing_hide`, `ing_sinew` x2 · hare: `ing_hare`, `ing_hare_pelt` · wolf: `ing_wolf_pelt`, `ing_sinew` · great wolf: `obj_wolf_pelt`.

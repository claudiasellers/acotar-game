# Story interfaces (core/ and story/)

How other lanes meet the story without calling story code, and how story
meets them. Story code never calls into `systems/`, `creatures/` or `world/`;
everything goes through `EventBus` signals, `WorldState` flags and the
autoloads below.

## Autoloads (core/)

| Autoload | Use |
|---|---|
| `WorldStreamer` | `configure(regions, parent)` or `configure_from_dir("res://data/regions/human_realm", parent)`, then `track(feyre)`. Loads the region she stands in, its `neighbors`, and anything within `load_margin` (120 m); unloads past `unload_margin` (220 m). Signals `region_loaded(id, root)`, `region_unloaded(id)`. Streams region content only; the persistent World scene (terrain, sky, GradeDirector) is never streamed. |
| `WorldDeltas` | `mark_picked(region_id, "<scatter>:<index>", respawn_days)`, `is_picked(...)`, `set_container(id, dict)`, `get_container(id)`, `set_region_value(region_id, key, value)`, `get_region_value(...)`. Saved automatically. Times are in-game days. |
| `SaveSystem` | `register_provider(key, obj)` where `obj` has `save_state() -> Dictionary` and `load_state(data)`. Keys in use: `inventory`, `proof_journal`, `body_state`, `sketchbook`, `food_tally`. |
| `StoryControl` | `mode` is FULL / WALK / LOOK / NONE during anchored moments. Ask `can_move()`, `can_look()`, `can_shoot()`, `can_interact()` before acting. `focus` is a Node3D the camera drifts toward. |

## Regions

`RegionDef` (`core/streaming/region_def.gd`): `id`, `scene_path`, `center`, `radius`, `neighbors`. One `.tres` per region in `data/regions/<world>/`. Region ids match `unlocked_regions` in `data/phases/spring_court_phases.tres`.

## EventBus signals

Emitted by other lanes, heard by story:

| Signal | Emitter | Story use |
|---|---|---|
| `food_stock_changed(days_of_food)` | systems | Food tally; `food_secured` at >= 7 days (export on the tally space). |
| `item_acquired(item_id, count)` | systems | |
| `item_sold(item_id, coin)` | systems | `obj_wolf_pelt` sold -> `pelt_sold`. |
| `creature_killed(id, kind, cause, position)` | creatures | `great_wolf` + `arrow_ash` -> `wolf_killed`. Wood only wounds him. |
| `creature_harvested(id, kind, items)` | creatures | Andras's pelt is `obj_wolf_pelt`. |

Emitted by story, heard by other lanes:

| Signal | Listener | Meaning |
|---|---|---|
| `story_item_granted(item_id, count)` | systems | e.g. `arrow_ash`, 1, if Feyre has none when the wolf scene starts. |
| `story_spawn_requested(spawn_id, transform)` | creatures | `great_wolf`, `doe`, `tamlin_beast`. Story spawns capsule stand-ins only if nobody answers. |
| `story_actor_cue(actor, cue)` | creatures | Beast: `enter`, `loom`, `speak`, `leave`. Family: `gather`, `release` (gather at the node in group `hearth`). |
| `scene_space_started(id)` / `scene_space_finished(id)` | anyone | |
| `grade_swap_requested(to_grade, seconds)` | world (GradeDirector) | `spring`, 2.0 at the wall; `human_winter` on the way back. |

## Story flags

Raised only through `ActionTrigger`. Names are the Keeper's
(`lore/07-story/timeline-overview.md`). Act I: `food_secured` (P0);
`wolf_killed`, `pelt_sold`, `beast_claim_accepted`, `wall_crossed` (P1).
Minor facts use the `fact.` prefix (e.g. `fact.beast_door.raised_knife`).

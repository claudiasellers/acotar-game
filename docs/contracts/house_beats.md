# Contract: the p3 house beats (L28)

Owner: L28 (story/act3/house/). Canon: Keeper answers 2026-11-01 (ch 12-13),
lore/07-story/timeline-overview.md, 02-locations/spring-manor-house.md,
01-world/prythian-overview.md (the study mural).

Book order (Keeper): her map of the halls comes first, then the night Tamlin
kills the Bogge (he comes to her, she dresses his hand), then the study mural.
All of it is before the Suriel.

## Where it plugs in
`Act3Anchors.ROWS` (story/act3/act3_anchors.gd) hangs one node per row:

| anchor | node | class |
|---|---|---|
| `hall_mark_1` | `HallMap`, `HallMark` | HallMap (room tracker), HallMark |
| `hall_mark_2..5` | `HallMark` | HallMark |
| `manor_infirmary` | `InfirmaryWorktable`, `WoundDressing` | InfirmaryWorktable (always), WoundDressing |
| `manor_study_mural` | `StudyMural` | StudyMural (the painting is always on the wall) |

Stage marks come from `tools/story/gen_house_beats.py`, written in each
anchor's local frame from `anchors.tres`. If the manor lane moves an anchor,
re-run it (test_act3_house checks the foyer table is in the entrance hall and
the worktable in the infirmary).

## Facts written (WorldState) and the deeds the moments raise from them
| fact | when | moment -> deed |
|---|---|---|
| `fact.hall_room.<room>.<level>` | she walks into a room after `puca_resisted` | |
| `fact.hall_rooms_enough` | `HallMapPlan.min_rooms` (10) rooms on her page | |
| `fact.hall_view.<tower room>` | a tower top's view sketched onto the world map | |
| `fact.hall_x_<n>` | E at hall mark n (X or circle) | `hall_mark_<n>` -> `fact.hall_mark_<n>` |
| `fact.hall_map_set_down` | E at the foyer table, night, all marks and enough rooms | `manor_map` -> `manor_map_drawn` |
| `fact.tamlin_knows_she_cannot_read` | he glances at her map | |
| `fact.tamlin_hand_bound` | the bowl of bloody water is poured away | `wound_dressing` -> `tamlin_wound_dressed` |
| `fact.mural_studied` | three mural details noticed | `study_mural` -> `study_mural_seen` (+ Lucien, `fact.suriel_method_known`) |

## Outputs
- Map: `WorldMapHud.reveal_place(id, true)` from the tower tops
  (`HallMapPlan.lookouts`): observatory (rosewild, fae_village,
  autumn_foothills), rose_bower (solstice_meadow, hill_of_the_rite,
  eastern_woods), lantern_lookout (western_fells), moon_tower (blossom_vale).
- Journal: `EventBus.journal_entry_added(&"mural_<detail>")` per mural detail.
- UI: `HallMapPage` (CanvasLayer, group `hall_map_page`): her wordless page.
- Mood: `dread` while the beast is in the hall, `calm` in the infirmary.

## Inputs read
- `interact` only. Glints (HouseGlint) show the next thing to use; no text.
- Actors via `request_actor`: `tamlin_beast` (StandIns.beast fallback), `tamlin`.
  Cues: none required; the beast model's `play(prowl|idle)` when it has one.
- The mural reads the active camera's gaze (`StudyMural.gaze_fn` in tests).

## For other lanes
- `InfirmaryWorktable`: `tray_point()`, `sink_point()`, `slot_point(slot)`,
  `put(slot, item)`, `item(slot)`, `clear_tray()`; slots `&"a".."d"`.
- The foyer table is a manor `table_side` at house (-8, -47), placed by
  WoundDressing.

## Dev jump and playtest
`story/act3/dev/p3_house_jump.tscn`: the entrance hall at dusk, p3, nothing of
p3 done. Playtest: `tools/playtest/p3_house_playtest.tscn` (extends the Act I
playtest). Unit: `tests/unit/story/test_act3_house.gd`.

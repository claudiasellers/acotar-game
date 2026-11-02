# Contract: P6 "The blight tightens" (ch 23–27, lane L46)

Canon: Keeper answers 2026-11-02 (all [C] unless a line is listed in its stage's
`invented`), lore/07-story/timeline-overview.md, book-scene-spaces.md.

## Who raises what (R2)
L46's scenes write **facts** only. The data moments (`tools/story/gen_moments.py`,
owned by L33) raise the deeds from them; L33's films play two of them.

| Scene (node, anchor) | Deed: what she does | Fact written | Moment -> deed |
|---|---|---|---|
| `GlenInvite` (hall_mark_1) | walks out to Tamlin on the steps, E: the ride | `fact.glen_ride_taken` | |
| `GlenPicnic` (glamour_lift_glade) | E at the blanket beside him | `fact.glen_picnic_shared` | `glamour_lift` (film "Eyes Open") -> `glamour_lifted` |
| `EyesOpenWonders` (glamour_lift_glade) | looks at the willow and the brook, stands by Tamlin (not a gate) | `fact.eyes_open_wonders` | |
| `AlisTrueMorning` (feyre_bedroom_window) | stares at Alis (her bark bleaches birch-white) | `fact.alis_true_seen` | |
| `FountainHead` (manor_fountain) | the next morning, walks up to the heron and looks at the head | `fact.fountain_head_seen` | `fountain_head` -> `fountain_head_found` |
| `SolsticeGarden` (manor_fountain) | decor: ribboned posts from fountain_head_found to solstice_danced | | |
| `SolsticeDressing` (feyre_bedroom_window) | a day later, E at the gown Alis holds out (dress-up) | `fact.solstice_dressed` | |
| `SolsticeNight` (solstice_dance_floor) | the party (faerie wine optional, E at the long tables), goes to Tamlin at the bower, follows him, keeps close in the dance (20 s) | `fact.solstice_sunrise_watched` | `solstice` -> `solstice_danced` |
| `LunchTable` (manor_dining_table) | a day later at noon, E at her place | `fact.lunch_sat_down` | `rhysand_visit` (film "The Night Court") -> `rhysand_faced` |
| `FarewellNight` (feyre_bedroom_window) | that night, E: his hand; dawn; E: the travel dress; E: her paintings | `fact.travel_dressed` | |
| `CarriageFarewell` (hall_mark_1) | E: gives Tamlin the paintings; E: gets in the carriage | `fact.carriage_boarded` | `sent_home` -> `sent_home` |

Day gates: a fact written with `Act6Space.stamp(fact)` also stores
`<fact>.day`; `Act6Space.day_after(fact)` is true from the next day on
(FountainHead after Alis, SolsticeDressing after the head, LunchTable after the
sunrise).

## Where it plugs in
- `Act6Spaces.ROWS` (story/act6/act6_spaces.gd); `StoryDirector.attach_anchor`
  calls `Act6Spaces.attach(anchor)` (one line).
- Scenes extend `Act6Space` (story/act6/act6_space.gd), an `Act2Space` with
  ground snapping, `prop(id, at)` for art/p6 props, a gaze test
  (`looking_at_point`, `gaze_hold`, `gaze_override` for tests), `press_near`,
  `go_to(region, anchor, offset)` (StoryDirector travel when unloaded) and the
  day stamps.
- Staging (marks in each anchor's frame, lines with canon tags):
  `data/story/act6/<scene>_stage.tres`, written by `tools/story/gen_act6_stages.py`.

## For other lanes
- **Alis's true form** (characters/alis/true_form/): `AlisTrueForm`, a node in
  `alis_model.tscn`. On `glamour_lifted` her skin becomes `bark_skin.gdshader`
  and her bun wild curls; `frighten(amount)` bleaches her birch-white and she
  colours back over `recover` seconds. Any scene with Alis can call it.
- **True sight** (world/shared/grades/grade_director.gd):
  `GradeDirector.with_true_sight(preset, amount)`; the director eases `sight`
  0 -> 1 over 6 s when `glamour_lifted` rises (saturation ×1.16, contrast ×1.05,
  bloom and glow up, warm ambient, fog ×0.75, magic +0.25). Dread is applied on
  top, so horror still drains it.
- **Props** (art/p6/, tools/blender/p6_props.py): head_severed, paint_tins_spilled,
  picnic_blanket, picnic_basket, fiddle, garden_streamer_post, paintings_bundle,
  wine_table_solstice, maypole_solstice, solstice_lantern_string.
- **Group** `p6_carried_paintings`: the bundle she carries from her room to
  the carriage.
- **The carriage's road**: `CarriageFarewell` ends with
  `EventBus.travel_requested(archeron_estate, arrival_archeron_estate)` when
  that region exists (P7), else the human-realm village.

## Playtest
`tools/playtest/p6_blight_playtest.tscn` (dev jump through paintings_shown;
set-downs for upstairs rooms and between days, logged). Unit:
`tests/unit/story/test_p6_blight.gd`.

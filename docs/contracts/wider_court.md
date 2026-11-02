# Contract: the wider court (P4 finish, ch 18-19), lane L44

Owner: L44 (`story/act4/`, `data/story/act4/`, `tests/unit/act4/`,
`tools/blender/wider_court_props.py`, the p4 beats of `tools/playtest/p3p4_chain.gd`).

## Deeds (R2: only through ActionTriggers in the scene)

| Flag | Scene | The deed |
|---|---|---|
| `starlight_pool_found` | `StarlightPoolSwim` (moment `starlight_pool`, coded via `Act2Spaces.CODED`) | after Tamlin's "Jump in", she is in the pool's water (≤15.5 m from its centre, not above the surface) |
| `attor_evaded` | `AttorInTheGarden` (moment `attor`, coded) | in the yew pocket within 7 s of "Stay hidden", and still until "It's gone." |

Facts (never phase flags): `fact.attor_detected` (permanent; found in the open
or rustling; the scene ends without its deed and can be faced again),
`fact.fells_range_cleared`, `fact.sentry_warbow_taken`.

## Anchors

`starlight_pool` and `attor_hiding_spot` are the region lanes' own markers.
Three more are placed by `WiderCourtAnchors.place(region_id, root)`, called
from `StoryDirector._on_region_loaded` (one line), beside the region's own
landmark (read from `CourtRegionContent.landmarks`, so they follow it):

| Anchor | Region | Where | Node (`Act3Anchors.ROWS`) |
|---|---|---|---|
| `stables_dusk` | manor_estate | stable yard mouth (-130, -9) | `StableDusk` |
| `fells_sentry_range` | western_fells | `north_watchtower` + (14, 0), yaw -90 (shoots east) | `SentryRange` (+ `SentryButt` ×3, `SentryChest`) |
| `fae_potion_room` | fae_village | `potion_house` + (18, 20), yaw 45 (faces up the bank to the house; the house stands on a 20° slope, the green is level here) | `PotionRoom` on its `stillroom_terrace` (CookingStation `fae_potion_room`) |
| (on `starlight_pool`) | starlight_glen | the pool's rim | `StarlightSteep` (CookingStation `starlight_pool`, night only) |

## Stations (group "station")

`tamlin_stables` (StableDusk: E at dusk 17:30-20:30, once a day, needs
`summer_faerie_comforted`; four strokes; reveals one map place from
western_fells, fae_village, starlight_glen, rosewild, blossom_vale),
`sentry_warbow_chest` (gives `bow_sentry_warbow` once, after a clear),
`fae_potion_room`, `starlight_pool` (CookingStation, data/stations/).

## Items granted (`EventBus.story_item_granted`)

`arrow_wood` ×6 per day for clearing the range; `bow_sentry_warbow` once.
No `obj_lucien_knife` in ch 18 (Keeper).

## Models

`story/act4/models/<id>.glb` from `tools/blender/wider_court_props.py`
(prop_kit finishes, LOD1): picnic_blanket, picnic_wine, sentry_butt,
warbow_chest, fae_cauldron, grooming_kit, stillroom_terrace (the potion
room's level stone shelf; PotionRoom adds its deck and balustrade collision). Everything else is the estate's
PropLib catalogue.

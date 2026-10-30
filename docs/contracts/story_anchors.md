# Contract: story anchors (story/core lane)

How the book's scenes find their places in the regions other lanes build.
The full list of anchors is generated: [story_anchors_table.md](story_anchors_table.md).

## For region lanes (manor, woods, wider court, world)

- For each anchor listed for your region, put a `Marker3D` in your region scene:
  - **name** = the anchor id (or set meta `anchor_id`), e.g. `manor_infirmary`
  - **group** `story_anchor`
  - placed where Feyre stands when the scene starts; -Z of the marker faces where the scene happens (actors spawn relative to it, mostly in front within 12 m)
  - keep 12 m around it walkable and free of tall scatter (Calanmai bonfires: 25 m; starlight pool: the water inside 10 m)
- Never put story logic in your scene. `StoryDirector` (autoload) hangs a `MomentSpace` under each anchor when `WorldStreamer` loads your region; nothing else is needed.
- Story state lives in `WorldState` flags. For before/after looks (the cleaned gallery, the ruined manor after `wall_recrossed`, Alis's true form after `glamour_lifted`) use `StateVisibility` and `GlamourLayer` (docs/contracts/glamour.md).
- `arrival_archeron_estate` is where the carriage sets Feyre down (`travel_requested`).

## For creature and NPC lanes

- Story asks for actors with `EventBus.story_spawn_requested(actor_id, transform)` and stages them with `story_actor_cue(actor_id, cue)`. Answer by spawning and adding the node to group `story_actor_<actor_id>` inside the handler; otherwise story places a capsule stand-in.
- Actor ids: `tamlin`, `lucien`, `alis`, `rhysand`, `nesta`, `elain`, `bogge`, `puca`, `suriel`, `naga` (and `naga_2`..`naga_4`), `attor`, `summer_faerie`, `high_fae_male` (and `_2`, `_3`), `white_horse`. A numeric suffix is another of the same kind.
- Cues per actor are listed in each moment's steps (`data/story/moments/*.tres`, `"do": "cue"`). Unknown cues may be ignored.
- Kills report `creature_killed(id, kind, cause, pos)` with `kind` = the base id (`naga`).

## For the systems lane

- `story_item_granted(item_id, n)`: `obj_lucien_knife`, `obj_white_roses`, `outfit_solstice_blue_gown`, `hair_loose_with_flowers`, `outfit_mortal_travel_dress`, `arrow_ash`.
- `journal_entry_added(entry_id)`: Suriel answers, the mural, the Treaty, Nesta's truth, Amarantha's terms.
- `celebration_requested(kind, at)` marks Spring Court deeds (sparkle and chime); horror beats use `mood_requested(&"dread", ...)` instead.

## Authoring

`tools/story/gen_moments.py` writes every moment and the anchor table; edit the generator, not the `.tres`. Steps vocabulary: `story/framework/moment_space.gd`.

## Act I anchors (human realm)

Same rules (Marker3D, group `story_anchor`, named by id). The Act I spaces are built in code (`story/act1/act1_anchors.gd`):

| Anchor | Region | What hangs there |
|---|---|---|
| `act1_cottage_interior` | cottage | The beast at the door: a box Entry centred on the marker, floor level (meta `size`, default 7 × 3 × 5.5 m) covering the room |
| `act1_cottage_door` | cottage | Where the beast comes in; -Z facing into the room |
| `act1_food_tally_beam` | cottage | The food tally notches |
| `act1_wolf_clearing` | hunting_forest | The ch1 wolf kill (30 m Entry; the doe 22 m and the wolf ~33 m in front, along -Z) and the skinning |
| `act1_fur_stall` | village | Selling the pelt to the mercenary (a woman, night-dark eyes) |

The ride north needs no anchor: it follows the world lane's `WallSeamPath`.

`act1_cottage_interior` also hangs two keepsake stations (E) on the human-realm props it finds beside it: `Hearth/HearthSpot` raises `fact.father_hearth_sat` and `SistersBed` (the unpainted ironwood bed) raises `fact.mother_bed_seen`.

# Fast travel: the whorl stones (lane L74)

Owner: the fast-travel lane (L74). Paths: `systems/fast_travel/`,
`data/fast_travel/`, `art/fast_travel/`, `tools/fast_travel/`,
`tools/blender/whorl_stones.py`, `tests/unit/fast_travel/`, this file.
Outside: `add_child(WhorlStones.new())` in `story/act1/act1_game.gd`, and
one `WhorlMapMarks.draw_all(...)` call each in L07's `ui/map/full_map.gd` and
`ui/map/minimap.gd` (owner ask, 2026-11-17: "set a marker for them on the map").

## Canon

Keeper, 2026-11-17 (ch 31): crossing back through the Wall, Feyre finds "the
mossy stones placed across from each other, a faint whorl carved into them
both. A gate." The **form is canon**; a pair in every open Spring region is
`canon:"X"`. She calls them the stones (no fae name). She traces the whorl and
paints a small rose of her own beside it (ch 2's habit of painting onto
things): a mark, never magic. Travel is **a ride, not a teleport** (Keeper;
the white mare, ch 20). No Cauldron or Mother shrines (the book has none).

## What it is

- `WhorlStones` (`systems/fast_travel/whorl_stones.gd`) is one Node in the game
  scene. It loads every `WhorlStoneDef` in `data/fast_travel/` and, on
  `WorldStreamer.region_loaded`, adds a `WhorlStone` under that region's root,
  so the pair frees with its region. Y comes from `WorldHeight.height_at`.
- `WhorlStoneDef`: `id`, `region_id`, `place_id` (a `MapPlace` id; the card
  uses the map's own words), `position` (world XZ of the way's middle),
  `yaw_degrees` (0 = stones east and west, the way north-south), `blight`,
  `canon`, `notes`. Written by `tools/fast_travel/place_whorl_stones.gd`
  (deterministic; prints slope and placement per pair; footprint slope ≤ 12°,
  inside its map place, off path/riverbed/rock, ≥ 12 m from region landmarks).
- `WhorlStone` is a `StaticBody3D` on collision layer 1 (two cylinders), in
  group `station` with `station_id = &"whorl_stone"` and `use(user)`, so
  Feyre's Interactor (E) reaches it within 2.5 m. A soft "E" glyph shows within
  3 m in free play.
- Models: `art/fast_travel/whorl_stones.glb`, `whorl_stones_blight.glb`,
  `whorl_mark.glb` (her rose, modelled in the pair's space) from
  `tools/blender/whorl_stones.py`. 2,444 tris (LOD1 1,222); prop_kit finishes
  through `PropModels.pair`.

## Pairs

| id | region | near |
|---|---|---|
| `manor_drive` | manor_estate | south lawn by the drive, inside the sentry gate |
| `wall_gate` | border_woods | the gap in the Wall (the canon pair) |
| `stream_glen` | eastern_woods | the stream glen's stone ring |
| `heron_stones` | starlight_glen | below the heron stones |
| `old_shrines` | western_fells | the old shrines, toward the middle watchtower |
| `village_green` | fae_village | the green below the great lantern tree |
| `briar_gate` | rosewild | inside the briar gate |
| `arch_avenue` | solstice_meadow | the foot of the arch avenue |
| `drum_field` | hill_of_the_rite | the drum field |
| `cider_mill` | blossom_vale | the cider mill |
| `hollow_steading` | blighted_reaches | the hollow steading (blighted, bare stone) |

None in the sealed `autumn_foothills` or in `suriel_glade` (a dread place).

## Rules

- **Mark:** the first E at a pair paints her mark: `WorldDeltas` region
  `"fast_travel"`, key = stone id (saves with the world), the mark grows on
  with a bounce, `Juice.burst(…, &"unlock")` sparkle + chime at the mark, a
  bounce on her, a sketch `whorl_<id>`, and her line on the find card.
- **Travel:** E at a marked pair opens `WhorlTravelCard` (pauses the game):
  her pictogram sketch of the marked stones (only marked ones are drawn, so no
  unexplored land is shown) and a button per destination. A destination is
  marked, not this pair, and in a region `PhaseManager.is_region_unlocked`.
  With none, her line says so and no card opens.
- **Allowed** only when `StoryControl.mode == FULL` and the phase is not
  `p7_return_home` or `p8_the_pass` (`WhorlStones.can_travel()`).
- **Ride:** `WhorlRide` (a CanvasLayer under the root) is one beat of about
  2.3 s: it fades to the satchel paper (SatchelDetail), inks the whorl
  (`WhorlInk`), brings up the place's name in the satchel serif over the mare's
  canter, puts her 2.2 m south of the pair facing through it (physics held),
  streams the region in (`WorldStreamer.update_for`), waits for `is_ready` +
  0.4 s settled (≥ 1.3 s held, 45 s cap), then fades into the arrival.
- **Look:** the card and the ride take everything from `JournalTheme`
  (SatchelDetail paper with L65's framed edge, SatchelHeading/Small labels,
  SatchelTab buttons, the theme's ink and accent): no StyleBoxFlat and no
  fonts of their own.
- **Map:** `WhorlMapMarks` draws a spiral pictogram on the minimap and full
  map for each pair whose ground is sketched (`MapReveal.is_seen` at its
  position) or that she has marked; never on unsketched land. Unmarked: thin
  plum whorl on a lilac rim. Marked: rose whorl on a gold rim with a soft
  shimmer and her little rose beside it. The full map names them "Whorl
  stones" when zoomed in as far as landmark names show.
- **R2:** never writes a WorldState flag, never changes phase, no objective
  text, no world markers or beacons. The map pictograms show only what she has
  seen (the owner asked for them).

## API

```gdscript
WhorlStones.defs() -> Array[WhorlStoneDef]
WhorlStones.is_marked(id) / mark(id) / marked_ids()
WhorlStones.destinations(from_id) -> Array[WhorlStoneDef]
WhorlStones.can_travel() -> bool
WhorlStones.travel(tree, def) -> WhorlRide   # null when not allowed
WhorlStones.spawn_for(region_id, root) -> int
```

Test: `tests/unit/fast_travel/test_fast_travel.gd`.

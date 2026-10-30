# Lane: the Spring Court woods

Branch `lane/woods-spring-court`. Owns `world/spring_court/{border_woods,
eastern_woods,suriel_glade,shared}/`, `data/regions/spring_court/{border_woods,
eastern_woods,suriel_glade}*.tres` and `tools/woods/`. Built on
`docs/contracts/world.md` and `docs/contracts/story_anchors.md`.

| Region | x | z | Area | Biomes | Gatherable types | Landmarks |
|---|---|---|---|---|---|---|
| border_woods | -700..500 | 300..1400 | 1.32 km² | 9 | 38 | 8 |
| eastern_woods | 650..1850 | -650..550 | 1.44 km² | 10 | 40 | 5 |
| suriel_glade | -950..-700 | 450..800 | 0.09 km² | 4 | 29 | 3 |

## How it fits together
- `<region>_terrain.gd`: the height provider (registered in
  `world/shared/terrain/height_providers.tres`), biome map, clearance,
  water mask and (Eastern Woods, glade) `dread_at`.
- `data/regions/spring_court/<region>_biomes.tres`: a `WoodsRegionDef` of
  `WoodsBiome`s: trees, shrubs, ground cover and forage with weights and
  densities, ambience ids, forage visuals and respawn days. Content changes
  are data edits.
- `WoodsScatter`: deterministic jittered-grid placement into `ScatterLayer`s.
  Nothing generated is committed except the small coverage reports
  (`tools/woods/write_woods_reports.gd` rewrites them).
- `WoodsRegion`: loads the baked cache (or generates) and prepares every
  buffer, mesh array and heightmap on a worker thread, then builds in small
  jobs under `FrameBudget` (4 ms of main-thread work per frame): three
  `SlicedScatterField`s (trees 256 m chunks with low-poly impostors, shrubs
  128 m, forage 64 m with the contract's forage metas), trunk colliders on
  the physics server, water, landmarks, story anchors, `TerrainFallback`,
  `DetailScatter` ground cover near Feyre and `AmbientLife`. Subclasses hand
  slow parts to the budget with `defer()` and precompute on the worker in
  `_water_ribbons()` / `_prepare_extra()`.
- `tools/generators/woods_scatter.gd` (run by `make update`) bakes
  `world/spring_court/<id>/_generated/woods_cache.res` (git-ignored). The
  cache carries a fingerprint of the generator version, biome data and
  terrain, so a stale cache is regenerated instead of trusted. Streaming a
  region in with the cache takes ~2 s over ~300 frames instead of ~16 s.
- `FloraLibrary`: ~80 procedural species and finds in the R3 storybook
  pastel look (oversized blooms), drawn with `woods_foliage.gdshader`
  (shared wind include, `magic_amount` sparkle, dread drain).

## Horror is a readable tip, not a fade
Eastern Woods: `dread_margin` biome (~140 m) between the pretty woods and the
Bogge's wood: trees thin and grey, colour drains, sparkle and birdsong stop
(the biomes list only `mist`), then black twisted trees, pale fungus, fog
volumes and the `bogge` grade preset. Same for the reed marsh and the
glade's naga backwater.

## Definition of done (met)
1. Three streamable regions, 2.85 km² together, walkable on collision terrain.
2. Named places: Border Woods (wall verge, bluebell glades, ancient oaks with
   root paths, faelight hollow with the rainbow falls, foxglove clearings and
   the moonstone ring, rose brakes, the Thornwater and its ford, the crocus
   knoll, the willow glen); Eastern Woods (deep wood, beech hall, fern
   hollows, stream glen, shallows, reed marsh, dread margin, Bogge's wood,
   woods' edge, blight edge); Suriel glade (young birches, snare glade,
   Thornwater banks, naga reeds).
3. Density: 25+ gatherable types per region, 1,500+ forage placements in each
   big region, no empty 100 m cell (tests + reports).
4. Life: pollen, petals, sparkles, faelights, fireflies, ash motes, mist;
   butterflies, songbirds, dragonflies, fish, moths.
5. Forage via the contract's `forage_field` chunks.
6. Story anchors `bogge_hunt_path`, `suriel_snare` (+ WillowGlen,
   BoggeTerritory, NagaMarsh).
7. Checks: `tests/unit/world/test_woods_data.gd`,
   `tests/unit/world/test_woods_scatter.gd`,
   `tests/integration/test_woods_region.gd`, `tools/world_smoke.gd -- spring_court`.

## Follow-ups
- The first GPU particle material of each kind compiles its shader once per
  session (~4-10 ms in the dummy renderer); warm them on the loading screen.
- CreatureSpawner per region once the creatures lane's spawner is on main.
- Glamour layers (`glamour_lifted`) for the woods' fae once docs/contracts/glamour.md lands.
- Swap any species for a Blender model by replacing its FloraLibrary builder.

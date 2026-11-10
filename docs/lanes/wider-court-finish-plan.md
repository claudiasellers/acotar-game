# Plan: make the wider court look finished on the new land

Owner's ask (2026-11-09): "make a plan to fix it". The terrain (M4WCT-1..5) is done and
merged; the planting was never redone for it. This is the plan to close that gap,
in order, with the owner's "see it first" gate on every look change.

## What's wrong now (measured)

- **Planting ignores the land.** Trees sit in the old circular habitats, at a near-uniform
  3.5–14 trees per hectare over 80–99% of every region: a tree every 30–50 m,
  whether it's a ridge, a hollow, a brook or a lake shore. The "ancient lowland forest"
  of the Western Woods has 10/ha. A closed canopy of 10–12 m trees needs roughly
  120–200/ha. The new hills (30–200 m) dwarf trees of 5–12 m planted at scale 0.8–1.3.
- **No ground cover.** The grass clumps are hidden (M4WCT-4). Between trees there's
  only the ground texture and scattered flower carpets.
- **The glen reads milky.** The court day grades' LUT lifts the blacks (fx lane's).
- Headroom: court regions draw 289–387 calls against the 1500 limit, and trees have
  card impostors past `TREE_DRAW` 260 m, so density is affordable. The cost is
  triangles near the camera: ~150/ha within 120 m is ~700 trees, ~1 M tris, the size
  of a manor view.

## Phase 0 — baseline (lead, half a day)

- Render the 18 `court_terrain_shots` views with `regions ingame` on the Mac at current
  `main`, plus `tools/perf/frame_probe` on 3 court views (glen, meadow, woods). That's
  the before for every later comparison, and the frame-time budget (16.6 ms).

## Phase 1 — planting follows the land (the big one; Opus for the code)

1. **Terrain habitats.** A new habitat shape, `terrain`, that classifies ground from
   `CourtHeight`: crest/ridge, knoll crown, slope (by steepness), hollow, valley
   floor, brook and river bank (`distance_to_brook`, `river_level_at`), lake shore
   (`lakes()`), path verge (`paths()`), and clearings (pads, sites, gates), which
   stay open. The old circles stay, for named places.
2. **Region recipes** (one task, since `court_content_table.gd` is one file; Sonnet), from
   the owner's terrain table:
   - **Western Woods:** a closed ancient forest of 150–200/ha, with big oaks and yews.
     The understory is moss and fern, with sunlit glades at the pads. The tower
     hill's flanks are wooded and its crown bare, so the watchtower reads.
   - **Glen:** birch and willow on the water, a single lilac or oak on each knoll
     crown, an open floor. The mound stays bare.
   - **Village:** orchard rows on the terrace, hedgerows along the road, the green open.
   - **Rosewild:** thorn brakes in the hollows, open hummocks.
   - **Meadow:** the plateau stays open; a wooded descent; the vast meadow open with
     the Crown Oak alone.
   - **Rite:** the crown stays bald. Wooded foothills, dark banks on the trench.
   - **Vale:** blossom orchards in rows on the south slope.
   - **Blight:** dead trees on the same rules.
   - **Autumn:** dense woods on the rising hills, which read as silhouettes from the court.
3. **Depth and weenies.** Dark tree masses on ridgelines give each depth layer a
   silhouette. Tree lines break to frame each weenie. A knoll-top lone tree, at
   scale 1.5–1.9, is a small weenie of its own.
4. **Scale.** Scale bands per role: ancient 1.4–1.9, wood 0.9–1.3, verge 0.7–1.0.
5. **Tests.**
   - `SIGHTLINES` extended to rays against tree crowns, so the weenies stay seen and
     the triangles still hide.
   - Paths, gates and pads stay clear of trunks.
   - Coverage reports pass, with `draw_calls` ≤ 1500.
   - Frame time ≤ 16.6 ms on the 3 perf views.
6. **Gate:** before and after renders of the 18 views go to the owner before submitting.

## Phase 2 — ground cover that reads as grass (preview three, owner picks)

- (a) **Shader grass:** instanced blade cards in the court palette, dense within about
  30 m, fading out, with wind. Uniform and cheap.
- (b) **CC0 models** (Poly Haven grass, clover, dandelion, periwinkle, moss), recoloured
  into the palette, as clumps near the camera.
- (c) **No grass models:** denser flower carpets and moss patches on the storybook
  ground only.
- Whatever wins becomes the meadow's fire fuel for `GroundFuel`, and the hidden
  clumps go.

## Phase 3 — the milky glen (preview, owner's call, fx lane's files)

- Render the court day grades with the LUT's dark end lowered (about 0.1 to about 0.03)
  next to now. If the owner likes it, change `build_court_fx.gd` and regenerate.

## Phase 4 — canon content on the shaped ground

- The rebuilt tavern and the well on the village green (canon). Hero assets go through
  the generator pipeline or an asset request, never raw primitives.

## Later (owner deferred)

- The weenie and landmark models: Watchtower, Lantern Tree and Bridge, Rose Spire and
  Folly, Mill and Bee Tower, Ring of Stones, Crown Oak, Heart of the Blight, Ember Crown.

## Decisions for the owner

1. The order above, or ground cover (Phase 2) before planting.
2. Whether every phase line between regions should be physically sealed, rather than
   only the Autumn border and the court's edge (the tools exist).
3. The phase table vs `CourtMap.UNLOCK_PHASE` on when the Rosewild and the Blossom Vale
   open (story lane).

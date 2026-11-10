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

## Owner's call (2026-11-10): planting first, and revisit the models

Phase 0 ran (wcterrain-13/14/15). It found the models are half the problem:

- **The trees are candy cloud blobs.** `tools/woods/blender/woods_trees.py` (rule R3)
  builds smooth icosphere canopies with pale mint tops (`LEAF_GOLD` B5E3C0), lighter
  than the new storybook ground. They read as pale cut-outs with no silhouette: the
  grass clumps' failure, but bigger.
- **Colour lives in the vertex colours.** A material-only restyle changed almost
  nothing (wcterrain-15): lower candy gain, no teal guard, more form, brushwork on
  the crowns. The fix has to be in the models.
- **The palette is confetti.** A red maple, a lime rowan, white birch puffs, pink
  cherries and mint oaks all stand side by side.
- **Scale.** The trees are 5–12 m on hills of 30–200 m.
- **The `woods_*` trees are shared** with the estate, the Eastern and Border Woods and
  the Suriel glade. Changing them changes those places too.
- Also seen:
  - the fells grade turns the Western Woods teal (`grade_fells` LUT);
  - a tree trunk sits on the vale-rim viewpoint (`vale_rim`, a planting bug);
  - the glen is milky (Phase 3).

### Track M — the models (runs beside Phase 1; different files)

**Status (2026-11-10).** M1 is done: the owner picked B, painterly leaf cards
(wcterrain-17). M2 is done for the court's ten leafy species:
- `tools/court/blender/court_trees.py`: five builds each, differing in outline
  (1–3 crown lobes, crowns wider one way), size, lean, limbs, sky holes and greens;
- `tools/court/gen_leaf_atlas.py`: the painted leaf atlas;
- `court_leaf_card.gdshader`: a per-tree tint on top of the builds.

They're court only (`CourtAssets.CARD_TREES_ON`), which leaves M3 open.

Frame time on the Mac (M4, wcterrain-19/20/21), median / p95 ms:

| View | Old trees | Card trees |
|---|---|---|
| Dense wood, about 1,000 trees, near mesh within the game's distances | 16.6 / 17.8 | 17.0 / 18.6 |
| Court Western Woods | 16.3 / 23.1 | 16.7 / 17.2 |
| Court glen | 19.9 / 27.8 | 19.1 / 36.8 (one hitch) |

Card trees draw their near mesh within `CARD_NEAR` (100 m) only, because the
cards cost overdraw, not triangles. In the first test, near meshes ran out
to 150 m and the dense wood took 19.8 ms. Frame times sit near 16.6 ms on
every run, which looks like the window capping at 60 Hz, so the headroom
below the line isn't measured.

- **M1 — direction test (preview).** Regenerate four species (oak, silver birch,
  wild cherry, yew) two ways, with bpy 5.x headless in the cloud (it installs
  there; the woods scripts may need small 5.x API fixes):
  - (A) **Storybook deep:** the same soft storybook shapes, with
    - deep painted greens (crowns darker than the sunlit ground, light only on top);
    - crowns broken into many clumps, with sky holes;
    - visible limbs, and blossom as accents rather than whole crowns.
  - (B) **Painterly leaf cards:** crowns of painted leaf-card clusters. The
    silhouette is more organic but there's more overdraw.
  - Show both in the lineup (`court_terrain_shots lineup=trees`) next to today's
    trees, and the owner picks.
- **M2 — roll out.** Every court tree species gets the chosen look:
  - near, far and impostor meshes inside the tri budgets (3000, or 4500 for the
    ancient oak);
  - shrubs, ferns, heather, bushes and flower carpets in the same palette;
  - one palette rule for autumn and blossom accents, instead of confetti.
- **M3 — shared or court-only.** Either the new trees replace the `woods_*` ones
  everywhere (one consistent Spring Court; the estate and woods change too), or the
  court gets its own species set. That's the owner's call, with renders of the
  estate both ways.
- **M4 — scale bands** come in through Phase 1 planting.
- The landmark models stay a later track.

Order: M1, then Phase 1 planting and M2 side by side (`court_content_table.gd` and
the generator vs `woods_trees.py` and the flora generator), then Phase 2 ground
cover, then the grades (glen, fells).

## Phase 0 — baseline (done: wcterrain-13/14)

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

# Plan: make the wider court look finished on the new land

Owner's ask (2026-11-09): "make a plan to fix it"; updated 2026-11-10 after the tree
exploration ("make a plan for what comes next based on everything else"). The terrain
(M4WCT-1..5) is done and merged. What's left is what grows on it, and the owner's
"see it first" gate holds for every look change: renders before anything is submitted.

## Where things stand

- **Terrain, ground and haze:** done and in `main` (M4WCT-1..5): the new land, the
  storybook-deep ground, the layered haze, and the grass clumps hidden.
- **Trees:** decided (2026-11-10), not built yet.
  - The court's woods will be a mix of Quaternius' Stylized Nature MegaKit (free tier,
    CC0) and EZ-Tree (MIT generator) models, with one palette rule: the deeper
    green, a soft grey-brown bark, the court's light.
  - The owner's words on the mixed-wood render (wcterrain-28): "I love the diversity
    of how they come out differently. Don't change it! That's how nature is."
  - So the two packs' looks are **not** evened out. Each keeps its own character.
  - The leaf-card trees (M4WCT-6) were switched off (M4WCT-7): they read tropical.
    The court runs FloraLibrary's old trees until the new set lands.
- **Previews on the lane branch only** (lineups `explore`, `explore2`, `tint`, `mix`;
  `forest=mix`):
  - `world/spring_court/wider/assets/tree_explore/` (Quaternius subset, EZ-Tree
    exports, the tint shader);
  - the EZ-Tree exporter, `tools/court/eztree/` (headless Chromium + three.js).
- **Measured problems still open:**
  - planting ignores the land: 3.5–14 trees per hectare everywhere, where a wood
    needs 120–200;
  - no ground cover;
  - the glen reads milky (LUT lifts the blacks);
  - the Western Woods grade turns the ground teal;
  - a tree stands on two viewpoints (`vale_rim`, `western_woods`) (fixed by P1);
  - the estate's lawn went flat bright green with the storybook ground (R0: the
    manor team's softened spring_grass of L56-2 was repacked too). Owner
    (2026-11-10): leave it until it can be judged with the new trees in.

## Work list by dependency (2026-11-10)

Owner: "keep a list of the plan items, organise them by dependency, and move forward
with the ones that make sense for now." Each item below has an id, its dependencies,
and its status. Details for each item are in the phase sections further down.

| Id | Item | Depends on | Status | Accept when (measured) |
|---|---|---|---|---|
| R0 | Canonical check: the estate and Spring shots before and after the haze change (M4WCT-3 touched `manor.tres`, `spring.tres`) | — | **started** | the four outdoor Spring canonical shots rendered on both commits; the differences are the haze only |
| T1 | Tree intake: Quaternius models, EZ-Tree seeds, licences (repaint EZ leaves, check bark) | — | **done** (render pending) | every file has a licence line; no file over 5 MB; triangles per model in a CSV |
| T2 | Detail steps: near (≤ 4.5k tris) to 80 m, mid (≤ 1.2k) to 260 m, far card (≤ 24) to 600 m | T1 | **done** (far: a 24-triangle crown and trunk, CourtTreeSet) | triangles in view at 150/ha (near + mid + far) ≤ 3 M, from the CSV |
| T3 | Variety layer: yaw, scale, per-tree shade, EZ builds | T1 | **done**: 1.5% of neighbour pairs share a build (Western Woods) | no two neighbouring trees share build, yaw and scale (GUT) |
| T4 | Roles and recolours: blossom, birch bark, autumn, the flowering bush fixed | T1 | **done** (14 roles, `docs/tuning.md`) | each role's mean leaf colour inside its row in `docs/tuning.md` (CSV) |
| T5 | Willow of our own (generator pipeline, `woods_trees.py` Kit) | D1, T4 | waiting | as T2 and T4 |
| T6 | Wiring: `CourtAssets` by role id; the card trees go | T2, T3, T4 | **done** (`CourtTreeSet`, on the lane) | GUT: every role id resolves to near, mid and far meshes |
| T7 | Frame time on a dense mixed wood and the court views; sets the density ceiling | T6 | **measured**: court views hold; 150/ha does not yet (below) | median ≤ 16.6 ms, draw calls ≤ 1500; the highest density that holds goes into P2 |
| T8 | Gate: role lineup and dense-wood render to the owner, then submit | T7 | **with the owner** (wcterrain-43/44/45/46) | owner's yes |
| P1 | Terrain habitats (ridge, knoll, hollow, bank, shore, verge); clearings, viewpoints and the story spots kept open | — | **done** (submitted) | GUT: habitat fractions per region; every keep-open zone has no tree in it |
| P2 | Region recipes on the new roles, at or under T7's ceiling | P1, T6, **T7** | waiting | trees/ha per region and habitat in the coverage report, inside each recipe's range |
| P3 | Depth and weenie rules; sightline tests against tree crowns | P2 | waiting | the court terrain's sightline table still passes with crowns as blockers |
| P4 | Gate: before and after renders of the 18 views, then submit | P3, T8 | waiting | owner's yes |
| F0 | Parked (owner, 2026-11-11): Dapplemesh "Cozy Woodland Groundcover" (Fab; painterly moss, fern, leafy plants, flowers; new seller, no reviews, AI-made) for the woodland floor. Revisit when it has reviews | — | parked | |
| F1 | Florals: candidate flower sets (Quaternius free plants; a named-species pack; our own generator for climbing roses, wisteria, foxgloves, lupins) rendered in the court palette, as the trees were (owner, 2026-11-10: "such a GIANT part of the court") | — | **researching** | a lineup render per candidate; licence line per file |
| F2 | Florals build: species by habitat (P1) and region | F1 (owner's pick), P2 | waiting | flowers/ha per region in the coverage report; frame time as T7 |
| G1 | Ground cover preview: Quaternius plants vs shader grass vs none | — | ready | renders of the three, plus each one's frame-time cost |
| G2 | Ground cover build; becomes the fire fuel | G1 (owner's pick) | waiting | GroundFuel tests pass on the new layer; frame time as T7 |
| C1 | Grade previews: the milky glen, the teal Western Woods | — | **done**: the teal is the moss ground (hue 160), not the ramp; the glen's darks barely matter | LUT black level and ground hue printed for now and the preview |
| C2 | Moss turned olive (owner's pick, wcterrain-37); the glen left as is | C1 (owner's pick) | **started** | the grade director's tests; the printed numbers as picked |
| E1 | Estate and Eastern Woods renders, new trees vs today's | T6 | **done** for the estate (the owner chose from lineups, tree by tree, 2026-11-12); Eastern Woods waits on P2 | renders, same views |
| E2 | Apply the estate decision: the estate tree-builder's trees replace the cotton-candy models (`EstateTrees`, `tools/blender/estate_tree.py`; 23 builds, each ≤ 6,000 triangles; `docs/tuning.md` "Estate trees") | E1, D2 | **submitted** (M4WCT-11) | GUT: `test_manor_tree_builds`; tree draws 104 (was 146); canonical shots: no change but the trees |
| V1 | Tavern and well on the village green (generator pipeline or asset request) | P2 (same content file) | waiting | on the green, clear of the paths (GUT) |
| H1 | Housekeeping: drop the previews and the card trees | T8 | waiting | nothing references them (grep) |
| L | Landmark models | owner (later) | deferred | |

Owner decisions:

| Id | Decision | Status |
|---|---|---|
| D1 | Willow: make our own, or skip | open |
| D2 | Estate: new trees everywhere, or court only (after E1). The program's rule is that the same object looks the same in every region, so "everywhere" is the expected answer | **decided** (owner, 2026-11-12): neither. The owner loves the estate's cotton-candy shapes and wanted them refined, not replaced by the court's trees: the estate gets its own trees, built from scratch (cotton-candy clouds made of leaf clumps), and the court keeps the Quaternius and EZ trees. The estate's willow is a candidate for D1 |
| D3 | Borders: seal every region border, or only the Autumn border and the edge | open |
| D4 | Opening times: phase table vs `CourtMap.UNLOCK_PHASE` (Rosewild, Blossom Vale) | open (story lane) |

The critical path is T1 → T2/T3/T4 → T6 → T7 → P2 → P3 → P4. P1, G1 and C1 can run
beside T1 now. They touch different files: P1 is `court_height.gd` and the habitat code,
G1 and C1 are preview tooling, and T1 is the new asset folder.

### Fit with the overall program (checked 2026-11-10)

The M4 brief (`wider-court-terrain.md`) asked for the highlands stripped of every model,
the ground rebuilt, "then the models layered back". The terrain half is done; this plan
is the layering half. Five fixes came out of checking it against the brief, `world.md`,
`wider_court.md`, `program.md` and the rendering rules in CLAUDE.md:

1. **Density vs detail.** At 150 trees/ha, full trees to 260 m are about 3,200 trees and
   up to 14 M triangles, and the far band adds about 14,000 more. Hence three detail
   steps in T2 with a triangle sum as acceptance, and P2 waits on T7's measured
   ceiling. Godot's own mesh LOD picks per MultiMesh chunk, not per tree.
2. **One look everywhere.** The program's consistency rule makes the estate decision (D2)
   lean to "everywhere". Until then the new trees live in the court's folder
   (`world/spring_court/wider/assets/trees/`), not the woods lane's `shared/`.
3. **Canonical shots.** M4WCT-3 changed the estate's and Spring's fog and the canonical
   shots were not re-rendered. R0 does that.
4. **Story spots.** P1 keeps open the sentry range's firing lane east of the watchtower,
   the potion room's terrace and the starlight pool's rim
   (`wider_court.md`).
5. **Measured acceptance.** Every item has a number to pass (the column above), and
   each look value (the palette, the role colours, the densities) gets a row in
   `docs/tuning.md`.

## Phase T — the new trees in the game (next)

**As built (2026-11-10).**
- T1: `world/spring_court/wider/assets/trees/` holds the 11 Quaternius models and 21
  EZ-Tree builds (`CREDITS.md`, `trees.csv`). EZ-Tree's photos are replaced by painted
  leaf sprays and barks (`tools/court/gen_ez_textures.py`), matched in coverage and
  value; render: lineup `intake`.
- T2: `tools/court/blender/court_tree_lods.py` writes `lod/<model>.glb` with a near
  (≤ 4,500) and a mid (≤ 1,200) mesh: the bark keeps its biggest pieces then
  decimates, the leaves thin by whole cards grown to keep the crown's cover.
  `tools/court/court_tree_intake.gd` checks the budgets and prints the sum: at 150/ha,
  1.0 M triangles in a 75° view (4.9 M all round, which is what shadows can see).

1. **Intake.**
   - Quaternius models: CommonTree 1–5, TwistedTree 1–5, Pine 1–5, DeadTree 1–5,
     Bush_Common, Bush_Common_Flowers.
   - EZ-Tree: several seeds each of oak, ash, aspen and bush, exported as geometry.
   - Licences:
     - Quaternius: CC0, file in the folder.
     - EZ-Tree code: MIT. Its leaf images have no stated licence, so replace them
       with painted leaf textures in the same shapes (tools/court/gen_leaf_atlas.py
       style) and show they look the same.
     - EZ bark: Poly Haven CC0 (oak, willow); check texturecan's terms (birch, pine)
       or swap in a Poly Haven bark.
   - Home: `world/spring_court/wider/assets/trees/` (the court's folder until D2),
     textures at 512 px, each file under 5 MB.
2. **Detail steps.**
   - Near meshes ≤ 4,500 tris to 80 m: the Blender decimate pass for Quaternius (the
     twisted trees are about 10k), lite settings for EZ-Tree.
   - Mid meshes ≤ 1,200 tris to 260 m (`TREE_DRAW`).
   - Far: a crossed card (≤ 24 tris) baked from the tree, to 600 m (`TREE_FAR`).
   - Acceptance: near + mid + far triangles in view at 150/ha ≤ 3 M.
3. **Variety stays natural.**
   - The packs keep their own looks (owner).
   - On top: random yaw and scale, a small per-tree shade from where it stands, and
     several builds per EZ species.
4. **Roles** (one model set covers the court's needs):
   - **Broadleaf woods:** Quaternius common trees and EZ oak and ash.
   - **Ancient oaks:** the twisted trees.
   - **Birch:** EZ aspen with a white banded bark.
   - **Blossom:** common trees recoloured cherry pink, apple white and lilac.
   - **Thicket:** the bushes, including the flowering one; fix its leaf surface
     (wcterrain-28 showed it brown).
   - **Pines:** sparingly, in the dark woods and at the edge.
   - **Autumn border:** reds and golds.
   - **Blight:** the dead trees.
   - **Willow:** EZ-Tree won't weep. Make one of our own to match, or skip willows
     (owner).
5. **Wiring.** `CourtAssets` loads the set by role id in place of the leaf-card trees
   (`CARD_TREES_ON` goes, with the card models and their tools, once the set lands).
   Court only; the estate is Phase E.
6. **Frame time.** `tools/perf/frame_probe` on a dense mixed wood and the three court
   views (woods, glen, meadow), with distance versions on. Budget 16.6 ms. The
   window seems to cap at 60 Hz, so also note draw calls and triangles.
7. **Gate:** a lineup of every role and a dense wood, rendered for the owner; then
   submit.

**T7 frame time (2026-11-11, Mac mini M4, median / p95 ms, draw calls; wcterrain-47/48).**

| View | FloraLibrary trees | Tree set |
|---|---|---|
| Court woods | 15.6 / 23.4, 388 | 17.4 / 22.5, 454 |
| Court glen | 25.1 / 145.5, 476 | 18.8 / 26.1, 551 |
| Court meadow | 18.1 / 31.4, 861 | 17.0 / 32.9, 944 |
| Dense wood, 150/ha | 15.4 / 21.4, 76 | 24.1 / 25.9, 437 |

At today's planting the tree set costs about the same (the glen is faster). A
dense wood at 150/ha is 24 ms against the 16.6 budget: the alpha-cut leaves and the
extra builds per chunk cost more than the old opaque crowns. Before P2 raises the
density: mid steps cast no shadow past the shadow range, and fewer builds per chunk
(T7b); P2's ceiling is what then holds.

## Phase P — planting follows the land (after T; the big one)

**P1 as built (2026-11-10).** `CourtLandHabitats` (`world/spring_court/wider/
court_land_habitats.gd`) reads the ground at any point as one of floor, slope,
steep, valley, hollow, crest, knoll, verge, brook bank, river bank, shore or water,
and lists 105 keep-open zones (every clearing, gate, standpoint and the three story
spots). Tree placement already skips the zones, paths and water: 161 of the court's
7,842 trees moved out (2%), including the ones on `vale_rim` and `western_woods`.
Shares per region come from `tools/court/court_habitat_report.gd`. The file avoids
the terrain bake's globs (`*terrain*`, `*height*`): it reads CourtHeight's built
clearings and path lines instead of adding to CourtHeight. A query costs about
250 µs (form) and 50 µs (keep-open), so P2 samples the form on a grid per region on
the worker rather than per tree.

1. **Terrain habitats** from `CourtHeight`:
   - crest/ridge, knoll crown, slope by steepness, hollow, valley floor;
   - brook and river bank, lake shore, path verge;
   - clearings (pads, sites, gates) stay open, and so do the named viewpoints (fixes
     `vale_rim` and `western_woods`);
   - the story spots stay open too (`wider_court.md`): the sentry range's firing lane
     east of the watchtower, the potion room's terrace, the starlight pool's rim.
2. **Region recipes** (`tools/court/court_content_table.gd`, one task), from the
   owner's terrain table:
   - **Western Woods:** a closed ancient wood of 150–200/ha, twisted oaks among the
     broadleaf, glades at the pads; the tower hill wooded but its crown bare.
   - **Glen:** birch, and willow if kept, by the water; a lone tree on each knoll;
     an open floor; the mound bare.
   - **Village:** blossom orchard rows on the terrace, hedgerows along the road, the
     green open.
   - **Rosewild:** thickets in the hollows, open hummocks.
   - **Meadow:** the plateau open, a wooded descent, the vast meadow open round the
     Crown Oak.
   - **Rite:** a bald crown, wooded foothills, dark banks on the trench.
   - **Vale:** blossom rows on the south slope.
   - **Blight:** dead trees.
   - **Autumn:** dense red and gold woods on the rising hills.
3. **Depth and weenies.**
   - Dark tree masses on the ridgelines.
   - Gaps in the tree lines frame each landmark.
   - Big lone knoll trees act as small landmarks.
4. **Tests.**
   - Sightline rays against tree crowns: the weenies stay seen, the triangles still
     hide.
   - Paths, gates and viewpoints stay clear of trunks.
   - Coverage reports pass, with `draw_calls` ≤ 1500.
   - Frame time on the perf views.
5. **Gate:** before and after renders of the 18 court views.

## Phase G — ground cover (preview, owner picks)

- (a) **Quaternius' own ground plants** (CC0, already downloaded): grass clumps
  (common and wispy), clover, ferns, flowers, petals, mushrooms. They're the same
  style as the trees, so this is the lead candidate.
- (b) **Shader grass:** instanced blade cards, dense within about 30 m, with wind.
- (c) **No plant models:** denser flower carpets and moss patches on the ground only.
- The pick becomes the meadow's fire fuel (`GroundFuel`), and the hidden grass clumps
  go.

## Phase C — colour grades (preview, owner's call; fx lane's files)

- **The milky glen:** the court day grades' LUT dark end lowered (about 0.1 to about
  0.03), shown next to now.
- **The teal Western Woods:** the fells grade's LUT pulled back to green, shown next
  to now.
- If the owner likes them, change `build_court_fx.gd` and regenerate.

## Phase E — the estate and the other woods (was M3; owner's call)

- Render the estate and the Eastern Woods with the new tree set, next to today's
  FloraLibrary trees.
- The owner picks one Spring Court look everywhere, or the court only.

## Phase V — canon on the village green

- The rebuilt tavern and the well (book). Hero assets come from the generator
  pipeline or an asset request, never raw primitives.

## Later (owner deferred)

- The landmark models: Watchtower, Lantern Tree and Bridge, Rose Spire and Folly, Mill
  and Bee Tower, Ring of Stones, Crown Oak, Heart of the Blight, Ember Crown.

## Housekeeping

- When Phase T lands, drop the preview folder (`tree_explore`), the leaf-card trees
  (models, `court_trees.py`, `gen_leaf_atlas.py`, `court_leaf_card.gdshader`) and the
  exploration lineups.

## Decisions for the owner

1. **Willow:** make our own to match, or skip.
2. **Phase E:** new trees everywhere, or court only (after renders).
3. **Borders:** physically seal every region border, or only the Autumn border and the
   court's edge as now.
4. **Opening times:** the phase table vs `CourtMap.UNLOCK_PHASE` for when the Rosewild
   and the Blossom Vale open (story lane).

## History

- **Phase 0** (wcterrain-13/14): the baseline renders.
- **Track M:**
  - M1: the direction test, A vs B (wcterrain-17); the owner picked B.
  - M2: leaf-card trees with five builds per species (M4WCT-6).
  - Switched off (M4WCT-7, "they read tropical").
  - Frame time, median / p95 ms:

    | View | Old trees | Card trees |
    |---|---|---|
    | Dense wood | 16.6 / 17.8 | 17.0 / 18.6 |
    | Court woods | 16.3 / 23.1 | 16.7 / 17.2 |
    | Court glen | 19.9 / 27.8 | 19.1 / 36.8 |

- **Exploration:**
  - EZ-Tree (wcterrain-23);
  - Quaternius (wcterrain-24, download deleted from the owner's Mac);
  - the tint test (wcterrain-27: deeper green kept, fresh spring dropped);
  - the mixed wood (wcterrain-28, approved).

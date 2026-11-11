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
  - a tree stands on two viewpoints (`vale_rim`, `western_woods`).

## Phase T — the new trees in the game (next)

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
   - Home: `world/spring_court/shared/models/court_trees/`, textures at 512–1024 px,
     each file well under the 50 MB limit.
2. **Budget.**
   - Near meshes ≤ 4,500 tris: the Blender decimate pass for Quaternius (the twisted
     trees are about 10k), lite settings for EZ-Tree.
   - Far meshes ≤ 600 tris.
   - The court's impostor range past `TREE_DRAW` stays.
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

## Phase P — planting follows the land (after T; the big one)

1. **Terrain habitats** from `CourtHeight`:
   - crest/ridge, knoll crown, slope by steepness, hollow, valley floor;
   - brook and river bank, lake shore, path verge;
   - clearings (pads, sites, gates) stay open, and so do the named viewpoints (fixes
     `vale_rim` and `western_woods`).
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

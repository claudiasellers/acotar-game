# Lane: the wider court's terrain (M4 · Wide court)

Branch `lane/wider-court-world`. Owns `world/spring_court/wider/court_height.gd`
(rebuilt from scratch), the court's providers in
`world/shared/terrain/height_providers.tres` (ids `court_*`), and the terrain
tests in `tests/unit/landscape/test_court_terrain.gd`. Built on
`docs/contracts/world.md`, the book and the owner's terrain table (below).

## Brief

The owner wanted the highlands stripped of every model and rebuilt from the
ground up, then the models layered back. The old height function was not
read: only its public API and the parameters were kept. Those parameters are
the contract's region rectangles, CourtMap, the story anchors, the landmark
ids and the estate's ground. The bar for the design:

- paths, clearings, landmarks, chokepoints, and what you can see from where;
- Zelda's triangles (a rise hides what's next, until you crest it);
- Disney's weenies (a tall thing to walk toward);
- you can never see the whole world from one place.

## The land, region by region

| Region | Terrain | Weenie | Triangle / reveal | Book |
|---|---|---|---|---|
| Western Woods (`western_fells`) | Ancient lowland forest, near flat: root ridges, dark dips, moss. One towering hill with the pond of watchers at its foot, and a winding climb. The west edge is a mossy lip over a misty gorge, with mountains beyond. | North Watchtower on the towering hill (~200 m) | pathless woods, closed canopy | ch 14: "no path", "moss-covered earth"; the pond at the foot of a towering hill |
| Starlight Glen | A valley of steep knolls on the Thornwater. Looking Lake (clear, with a steep drop-off, plus an islet) and Willow Mere. The starlight pool sits in a sunken hollow ringed by knolls, the mound overlooks it, and the glimmer crag carries the Rainbow Falls. | the watchtower beyond | the glen brae hides the glen from the estate; the mound hides the pool until you top it | ch 18: down the hill, the stream at its base, tiny brooks, steep knolls, the mound |
| Village of the Lesser Fae | A riverside terrace in a dell. The level green sits 5 m above the Thornwater; the potion house is on a ~20° bank, the Lantern Bridge crosses to the west bank, and the mill yard is upstream. | Great Lantern Tree; the Ember Crown above | two knolls pinch the road and frame the Lantern Tree | owner: a sheltered dell, a terrace by the road |
| Autumn border (sealed) | The ground lifts into rougher hills toward the far border and stands on the Rust Scarp, a crag band 22–30 m high. The Thornwater leaves over falls on the scarp line. The Sealed Pass is a notch with its gate. | the Ember Crown (~270 m) | seen from everywhere north-west, never reached | owner: rising land reads as a change of court |
| Rosewild | Low, undulating hummocks and shallow hollows, nothing steep. A brook runs to the hollow pool. | Rose Spire on its knoll | the plateau's hill hides the meadow | owner table |
| Solstice Meadow | Two levels: a flat-topped plateau on a hill for the dancing, then a gentle wooded descent to a vast, flat, low meadow. | the plateau (maypole), Crown Oak in the meadow | the meadow appears only from the plateau's north rim | ch 25: "the plateau", "a vast meadow" |
| Hill of the Rite | Foothills rising to a broad bald crown (Ring of Stones, great bonfire). The bonfire terraces step down its south-west flank. A steep-banked trench between two hills ends in the cave mouth cut into a soft hillside, and the sycamore's knoll stands nearby. | the crown (~140 m) | the knoll and the trench's hills hide the cave | ch 20 |
| Blighted Reaches | Ordinary rolling hills; the blight shows in the ground's texture, never in its shape. The pass road runs north into a canyon through the rim. | the Heart (content) | rolling hills, nothing seen far | owner: blight through silence and recoil |
| Blossom Vale | A wide, shallow, south-facing valley with soft sides. The vale stream runs down its floor to the Thornwater, and the bottom is open to the south. | Bee Tower on its knoll | the vale's rim hides the vale | owner table |

The court's edge has two forms. North and east, the land climbs away in three
stacked crag bands, each 22–30 m and taller than Feyre's whole jump chain;
the Thornwater leaves through a canyon. To the west lies the gorge. Every edge
eases out where the court meets the Wall, which stays the human realm's.

## How the code is laid out

`CourtHeight` (one file, no baked data):

1. **Design grid.** A 16 m grid holds each region's base level and character:
   roll, hummock and root-ridge amplitudes, mixed over 150 m soft rectangles,
   plus the big hills (`ZONES`, `HILLS`).
2. **Noise** for the bumps and hollows, domain-warped and scaled by region.
3. **Exact landforms**, bucketed on 128 m cells: knolls and hollows (`FORMS`,
   the seeded `KNOLL_FIELDS`, the gate pinch knolls), clearings (`PADS`, plus a
   small one at every named site), the vast meadow's flats, then the hard
   edges last (the trench, the terraces, the Rust Scarp) so no clearing
   softens a seal.
4. **Water.** The Thornwater flows at designed levels (`RIVER_PROFILE`, with
   valley widths in `VALLEY`); the Autumn falls follow the scarp line.
   Brooks (`BROOKS`) take their levels from the ground, only ever downhill.
   Lakes (`LAKES`) find their level from their shore: a shelf, then a steep
   drop-off.
5. **Paths** (`PATHS` and the tower spiral) are graded and cut-only. On steep
   ground they sink into hollow-ways; through the Rust Scarp they cut a notch.
6. **The blend.** Over `BLEND` (140 m) our ground eases to MacroHeight at every
   other lane's edge (`FOREIGN`). The court's edge (`_edge`) is added after the
   blend, and its lines stand clear of every other lane.

Providers: `DOMAIN` tiles our ground with 9 rectangles at **fade 0**. The old
registration used 11 rectangles with fade 64, which pulled every internal seam
down to MacroHeight; that was the boxy look.

Gates: `GATES` lists the gate on each way out of the estate (Briar Gate, the
brae saddle, the village knolls, the rite way, the vale's rim) plus the
meadow and the Sealed Pass. Each stands in a pinch between two steep knolls.
`tools/court/gen_court_content.gd` appends them to the content gates, locked by
`CourtMap.gate_lock()`, so each opens at its region's `CourtMap.UNLOCK_PHASE`.

Sites: `SITES` lists the named ground (every landmark id, the anchors, 29
nooks, the water). The generator lays the models back onto them: each landmark
moves to its site, the habitats round it move with it, and water habitats sit
on the lakes.

## Checks

- `tests/unit/landscape/test_court_terrain.gd`:
  - the estate's ground is exactly as without the court;
  - the providers tile without overlaps, and no seam steps;
  - named ground is usable; the book's shapes hold; lakes are clear and deep;
  - brooks run downhill in their beds, and gates stand on the ways out;
  - **Feyre's reach**, a flood fill with her 50° floor, triple jump and mantle:
    she can't climb into the Autumn hills or out of the court;
  - **sightlines** (`SIGHTLINES`): the weenies are seen, the triangles hide;
  - no gate or clearing sees more than a third of the court.
- `tests/unit/test_court_regions.gd`, `tests/unit/test_court_river_level.gd`.
- Look without a GPU: `tools/court/court_relief.gd` draws a shaded relief with
  water, paths, gates and sites. On the Mac,
  `tools/court/court_terrain_shots.tscn` renders bare-terrain views (pass
  `regions` to put the models back in).

## Decisions and open items

- **Open country between regions.** The woods lanes never sealed their
  borders, and the book's land is rolling, so the regions aren't walled. The
  gates make chokepoints on the paths, but a walker can still go round them
  over open hills. Only the Autumn border and the court's outer edge are
  physically sealed. If the owner wants every phase line sealed, the tools to
  do it are already here: scarps (`_autumn_depth` style) and the flood-fill
  test.
- **Phase table vs `CourtMap.UNLOCK_PHASE`.** The phase set opens rosewild and
  blossom_vale at `p4_wider_court`; CourtMap says `p2_grounds` and
  `p3_house_and_woods`. The gates follow CourtMap via `CourtMap.gate_lock`. The
  story lane should settle which one is right.
- **ManorWardVeil** veils only the estate edges facing earlier-opened
  neighbours. It still reads `manor_estate.tres`, which lists the woods only;
  that file is the manor lane's and is unchanged.
- **The west keeps its region id.** The owner's table renames it "Western
  Woods"; the id stays `western_fells` (dialogue and places use it).
- **Tavern and well.** Canon puts a rebuilt tavern and a well in the middle of
  the village. The green is shaped to hold them; the models are a content
  follow-up.
- The east rim at x 1850–2048 and the vale's east side (x 1500–2048) were
  unowned macro ground. They are now the court's rim, owned by no region.

## The look (M4WCT-3, owner's picks of 2026-11-09)

- **Ground:** the `storybook_deep` look of `GroundTexturePacker`, the CC0
  photo slots recoloured into soft painted bands, lower value so the near
  ground stays rich. The terrain slots import lossless: BC3 broke the soft
  gradients into squares.
- **Depth haze:** a cool lilac-blue haze darker than the pink horizon, with low
  aerial perspective. You see a green foreground, a teal midground and
  periwinkle hills against the sky. It is in spring.tres, manor.tres (fog
  only) and every daytime court grade (`build_court_fx.gd` `DEPTH_*`).
  Dusk, night and the blight keep their own fog.
- **Open:** the court grades' LUT lifts the blacks (`LUT_STRENGTH` 0.3 toward
  ramps with dark ends near 0.1). That reads milky in the glen next to the
  estate's grade. It's the fx lane's taste call.
- **Grass clumps** (`flora_grass_clump_a/b/c`, pale mint) glowed against the
  deeper ground. The owner had them taken out (M4WCT-4): `CourtRegion.DRAW_GRASS_CLUMPS`
  is false, so their chunks are hidden. Their layers stay, because GroundFuel reads them
  as the meadow's fire fuel. The lookouts' collar no longer uses them. Replacement
  ground cover is point B (planting for the new relief).

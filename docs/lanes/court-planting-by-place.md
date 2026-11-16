# Planting the court, place by place

Owner, 2026-11-15: "ignore everything about the way trees are planted right now.
Just look at the terrain. HOW should trees and foliage be planted so that they
contribute to the overall feel and look of a place in each place? We need a plan."

This is that plan. It starts from the bare land (the 21 bare-terrain views of
`p4-3` and the relief map from `tools/court/court_relief.gd`), the terrain brief
(`wider-court-terrain.md`: paths, clearings, weenies, triangles) and the book. It
does not start from the recipes in `court_content_table.gd`; those are compared
against it afterwards, place by place.

Status: **draft for the owner**. Nothing here is planted yet.

## What planting is for

Trees and plants are not a covering. In each place they do five jobs, and a place
feels like itself when all five say the same thing.

1. **Closed and open.** Where you are under trees and where you are under sky.
   This is the biggest decision in any place, and it should follow the land:
   shelter (floors, hollows, steep flanks) grows trees; exposure (crests, crowns,
   plateaus) stays open.
2. **Edges.** The eye rests on where woods meet open ground. An edge is never a
   wall: tall trees step down through small flowering trees, shrubs, then
   flowers, and it bends in and out in bays.
3. **Single trees.** One tree where the land makes a point: a knoll, a bend, a
   pool, a gate. The book's knolls are "marked by a single tree". The special
   trees (magnolia, candyfloss, wisteria, golden chain) are finds of this kind,
   never a crowd.
4. **Hide, then frame.** The terrain was shaped so a rise hides what's next and
   a tall thing calls you on. Planting thickens the rise that hides, parts where
   the view opens, and never stands in a line you are meant to see along.
5. **Rhythm on the path.** Under trees, out into light, a view; then again.
   A tight stretch before every arrival makes the arrival bigger.

Each place also gets **one colour of its own**, used at its edges, its door and
its landmark, on a green that is its own too (fresh in the vale, deep in the
old woods, grey in the blight, rust at the Autumn border).

## What the land decides

The same rules everywhere; each place uses them in different amounts.

| Land | What grows there |
|---|---|
| Floor of a valley, a hollow | the tallest and thickest trees; in a damp hollow, alder, willow and fern |
| Steep flank | a hanging wood: trees on the steep ground show the hill's shape |
| Gentle slope | open, with trees in loose groups of three to seven |
| Crest, ridge | bare, or a broken line of small wind-shaped trees; never a wall along the skyline |
| Summit with a landmark | bare, so the landmark stands against the sky |
| Knoll | one tree, or none; never a wood |
| Bank, shore | a ribbon of water trees, with a gap wherever a path meets the water |
| Path side | hedge and small trees in a rhythm; an avenue at an arrival; a gap at every view |
| A door between two places | a pinch of trees to pass through, and the new place's colour starts right there |

## The places

The nine places of the wider court, in the order a player reaches them. For
each: the feel in a line, what the land does, how it is planted, the one picture
it must give, and what stays open.

### Rosewild (north of the estate)

- **Feel:** the gardens escaping. Close, tangled, scented, pink and red and white.
- **Land:** low hummocks and shallow hollows, nothing steep; a brook to the hollow
  pool; the Rose Spire on its knoll; from the estate's north gate the ground is
  wide and gentle with the spire's knoll ahead.
- **Planting:** almost no big trees. The mass here is shrub: rose thickets and
  briar hedges, waist-high to over your head, making soft rooms on the hummocks,
  a different rose colour in each hollow. Small flowering trees (crab apple,
  hawthorn, cherry) one to a hummock top. A big old tree only down in a hollow,
  as a pool of shade. Fern and iris at the hollow pool.
- **The picture:** from the north gate, a sea of roses with the Rose Spire
  standing clear above it.
- **Stays open:** the line from the gate to the spire (roses only below
  shoulder height there); the brook; the spire's knoll.

### Blossom Vale (south-east)

- **Feel:** plenty. Sweet, bee-loud, pink and white, petals in the air.
- **Land:** a wide, shallow, south-facing valley with soft sides; the stream
  down its floor; the Bee Tower on a knoll; a rim that hides the vale until you
  are on it.
- **Planting:** trees as orchards and as architecture. A belt of taller wood on
  the rim, so you come through shade and the pink valley opens below. On the
  sunny sides, orchards in loose rows (apple white, cherry pink) with grass
  rides between and hawthorn hedges dividing them. The Blossom Cathedral is the
  tallest cherries in a double row arching over a nave. Pollard willows along
  the stream. The valley bottom is open flower meadow.
- **The picture:** stepping out of the rim wood, the whole vale in blossom below
  with the Bee Tower on its knoll.
- **Stays open:** the valley floor; the Bee Tower's knoll (lavender and low
  flowering shrubs only); the rides between orchards.

### Blighted Reaches (north and east)

- **Feel:** silence and wrongness. You want to turn back.
- **Land:** ordinary rolling hills; the pass road; the Heart far in the east.
  The blight is in the ground's colour, not its shape.
- **Planting:** a slope of sickness. At the edge the neighbour's trees thin out.
  Then dead and leafless trees, each standing alone like a figure, never in a
  group; grey grass; no flowers; nothing growing under the trees. One dead tree
  on each skyline. Toward the Heart the trees get fewer and more twisted and
  lean away from it, and round the Heart itself is a bare ring. The pass road
  was once an avenue: its trees are dead in their rows.
- **The picture:** from the reaches road, the Heart in its bare ring with every
  dead tree leaning away.
- **Stays open:** the bare ring; the road. One living green tree at the very
  edge is the only relief.

### Western Woods (west)

- **Feel:** old, vast, hushed, pathless. A hall of pillars.
- **Land:** near flat, with root ridges, dark dips and moss; one towering hill
  with the pond of watchers at its foot; a mossy lip over the misty gorge.
- **Planting:** the one true forest, and the opposite of a thicket: very large
  old trees standing well apart with high crowns, so there is no sky but you
  see a long way between the trunks. Under them moss, fern, fallen logs and
  little else. Every named nook is a glade with its own character where light
  comes down (the silent hollow under yews with nothing growing; the fern
  cleft; the root cradle). The special trees are rare finds in those glades.
  Up the towering hill the trees shrink and thin to wind-bent pines and then a
  bald top for the watchtower. Dark still trees ring the pond, with one gap.
  At the brink the last trees lean out over the gorge.
- **The picture:** giant trunks in green moss with one shaft of light on a glade.
- **Stays open:** the glades; the hilltop; the brink's lip.
- **Note:** fewer, bigger trees is also what the frame time needs here (the
  wood runs at about 20 ms a frame today because of how many leafy trees stand
  close to the player).

### Starlight Glen (west of the estate)

- **Feel:** enchanted and secret. Silver, blue and white; made for night.
- **Land:** a valley of many steep knolls on the Thornwater; tiny brooks;
  Looking Lake with its islet; Willow Mere; the starlight pool in a sunken
  hollow ringed by knolls, hidden until you top the mound; the brae that hides
  the whole glen from the estate.
- **Planting:** the knolls carry it. Each knoll has one tree, and the trees
  differ (the oak knoll, the birch knoll, a blossom knoll) so you find your
  way by them. Between the knolls the ground is open glade, fine grass and
  bluebells, with trees gathered only along the brooks. The pool's hollow is
  ringed with silver birches on its inner slopes, white trunks to catch the
  starlight, and its floor is open. Looking Lake is wooded to the water on one
  side, for the reflection, and open on the other; the islet has one tree.
  Willow Mere is willows all round. On the brae, a clump just over the crest,
  so the glen appears between trunks as you come over.
- **The picture:** from the mound, the starlight pool in its ring of white
  birches.
- **Stays open:** the mound; the hollow's floor; the glades between knolls;
  the line to the North Watchtower.

### Village of the Lesser Fae (north-west)

- **Feel:** homely, sheltered, tended. Somebody lives here.
- **Land:** a riverside terrace in a dell; the level green above the Thornwater;
  two knolls that pinch the road; the lantern brae behind the green; the crag
  of the Autumn border beyond.
- **Planting:** small-scale and useful. Hedgerows along the lanes, an orchard
  on the west bank, pollard willows and alders by the river with a gap at the
  bridge, hazel coppice, cottage flowers. The Great Lantern Tree stands alone
  on the green: no other large tree within about 60 m. The two knolls are
  wooded on their outer sides, which tightens the pinch and frames the Lantern
  Tree as you come through. A hanging wood on the lantern brae gives the tree
  a dark backdrop. The sealed road north starts as an avenue and goes wild
  toward the pass.
- **The picture:** the Great Lantern Tree framed through the pinch.
- **Stays open:** the green; the line through the pinch; the line to the
  Ember Crown from the brae top.

### Hill of the Rite (north-east)

- **Feel:** ancient, bare, a little frightening. Fire and drums at dusk.
- **Land:** foothills up to a broad bald crown with the Ring of Stones; bonfire
  terraces on its flank; a sunken way climbing between two hills; a
  steep-banked trench ending in the cave mouth; the sycamore's knoll.
- **Planting:** the crown is bald, with dark woods below it. Old oak and yew
  hang in the gullies and on the steep flanks, so the bare top rises out of
  darkness. Gnarled hawthorns line the processional way and half close over
  it, a tunnel that lets you out onto the open terraces; hawthorn is the May
  tree, and its white blossom shows at dusk. Two black yews stand at the cave
  mouth. The trench's banks are bare but for fern. One great sycamore on its
  knoll. The drum field is open grass ringed by trees.
- **The picture:** the bald crown and its stones above black woods, fires on
  the terraces.
- **Stays open:** the crown; the terraces; the trench; the drum field; the
  line to the stone ring from the estate's north gate and from the plateau.

### Solstice Meadow (north)

- **Feel:** a ballroom under the sky, then awe.
- **Land:** a flat-topped plateau on a hill for the dancing; a gentle descent;
  a vast, flat, low meadow that appears only from the plateau's north rim.
- **Planting:** emptiness is the point, so trees are few and deliberate. The
  plateau top is lawn and flowers. The Arch Avenue is a formal double row
  leading up to the dance ring (wisteria and golden chain are the obvious
  trees for it). The descent is lightly wooded, with a ride left open so the
  meadow shows from the rim. In the vast meadow there is one tree, the Crown
  Oak, and it is the biggest tree in the court; around it flowers in broad
  drifts and tall grass, with woodland only at the far edges as a frame. Each
  of the two small hills wears one clump. Wisp Hollow is damp, with willows.
- **The picture:** from the plateau's north rim, the Crown Oak alone in a sea
  of flowers.
- **Stays open:** the plateau top; the whole meadow; the lines to the stone
  ring and the Ember Crown.

### The Autumn border (sealed, north-west)

- **Feel:** another court, glimpsed. Rust, gold and flame; forbidden.
- **Land:** rough hills standing on a crag band; the Ember Crown above
  everything; the Sealed Pass a notch in the cliff.
- **Planting:** it is only ever seen from far off, so it is planted for
  distance: broad masses of autumn colour on the benches and tops, redder
  toward the Ember Crown, with dark pines for contrast and the crag faces
  bare. At the pass the Spring green and the Autumn colour meet in a line you
  can see, with a few trees half turned.
- **The picture:** from the village's brae, the Ember Crown burning red above
  the grey crag.
- **Stays open:** the Crown's top; the crag faces.

### The other woods and the estate

The Border Woods, the Eastern Woods, the Suriel Glade and the estate are other
lanes' ground and already have their own planting. The five jobs above apply
there too, but their terrain has not been studied for this plan. Owner's call
whether they are in scope.

## The doors between places

Each crossing is designed as its own small scene, after the places on both
sides are agreed:

- estate north gate to Rosewild: clipped garden to wild roses;
- estate west over the brae to the glen: the clump on the crest;
- glen to village: the wooded pinch;
- glen to Western Woods: a wall of giant trunks with one dark doorway;
- Rosewild to Solstice Meadow, meadow to the Rite, the Rite to the Reaches
  (green thinning to grey);
- estate south-east to the vale: through the rim wood.

## How we get there

1. **Agree the feel.** The owner reads the place notes above and changes
   whatever is wrong. Nothing else starts until the one-line feel of each
   place is right.
2. **A planting map for each place.** A top-down drawing made from the real
   land: where it is closed, where open, the edges, every single tree, the
   avenues, the lines that stay clear. With it, the two or three views that
   place must deliver (its arrival, its picture, its landmark). The owner
   approves the map before anything is planted. One place at a time.
3. **What is missing.** Each map lists the plants it needs that the game does
   not have yet; the checked list as of 2026-11-15 is under "Assets we do not
   have" below. The flower and ground-cover work (plan items F1, F2 and phase
   G) becomes part of each place, not a separate pass.
4. **A pilot place, built fully.** Trees, shrubs, flowers and ground, shown at
   its views against the bare land and against today's planting. This proves
   the method and the tools before the other eight.
5. **The rest, in the order a player reaches them:** Rosewild, Blossom Vale
   and the Blighted Reaches, then the Western Woods, the glen and the village,
   then the Hill of the Rite, then the Solstice Meadow. The Autumn border is
   distance work and goes last.
6. **The doors,** once both sides of each are done.

### How each place is checked

Looks are the owner's call from renders. The rest is measured:

- every zone on the map has the trees the map says (a count per zone; open
  zones have none; a knoll has one tree or none);
- every sightline in `CourtHeight.SIGHTLINES` is clear of crowns, and each
  place's views are rendered from the same standpoints every time;
- the place's heaviest view holds the frame-time target (16.6 ms) on the Mac;
- each place's plant list and colour are rows in `docs/tuning.md`.

### What carries over from the work so far

The tools stay: the land forms (`CourtLandHabitats`), the planting ceiling and
report (`CourtPlanting`), the tree set and its detail steps, the special trees,
the sightline and keep-open tests. What changes is what they are asked to do:
today each region has a recipe of densities by habitat; this plan gives each
place a map with a purpose. Where a recipe already does what the map asks, it
stays.

## Assets we do not have (checked 2026-11-15)

Checked against the court's tree set (`CourtTreeSet.ROLES`), the court's flora
and props (`wider/assets`), the woods' plants (`FloraLibrary`), the estate's
trees and flora, and each landmark's pieces in `court_content_table.gd`.

**Plants that do not exist anywhere in the game**

| Asset | For |
|---|---|
| Giant old forest tree (very tall, thick trunk, high crown, big roots) | Western Woods; the wall of trunks at its door |
| Wind-bent pine | the towering hill's upper slopes; crests |
| Old gnarled thorn tree that arches over a path | the Rite's processional way; crests |
| Great sycamore (one hero tree) | the sycamore's knoll |
| Tall arching cherry | the Blossom Cathedral's nave |
| Pollard willow | the vale stream; the village river |
| Rose thicket and briar hedge in runs, in several colours, head-high | Rosewild's rooms |
| Hedgerow in runs | village lanes; between the vale's orchards |
| Tall meadow flowers in drifts (poppy, cornflower, ox-eye daisy) | the vast meadow |
| Half-turned trees (half dead; half autumn) | the edge of the Reaches; the Sealed Pass |
| Hanging moss on old trees (optional) | Western Woods |

**In the game, but not usable in the court yet**

| Asset | Where it is now |
|---|---|
| Yew | the woods have one; the court draws a pine in its place (`CourtTreeSet`: `woods_yew` to `conifer`) |
| Orchard-shaped apple, cherry and pear | the estate's tree set; the court uses ordinary trees recoloured |
| Short glade grass, clover, small flowers, mushrooms | Quaternius' plant models are downloaded (`wider/assets/plants/qtz`) and not planted (phase G) |
| Cottage-garden flowers (hollyhock, delphinium, catmint), vegetable rows, bee skeps | the estate only |
| Light shafts under trees | the woods lane only (`woods_light_shaft.gdshader`) |

**Landmarks that are stand-ins** (the owner deferred the landmark models; the
places' pictures lean on the first seven)

| Landmark | What stands there today |
|---|---|
| Rose Spire | three thorn brakes |
| Great Lantern Tree | a lilac tree with lantern posts and bunting |
| Crown Oak | the woods' ancient oak grown to 24 m |
| Bee Tower | the ruined watchtower |
| Heart of the Blight | a mask pile, a rock and a blighted tree |
| Ember Crown | one autumn maple |
| Blossom Cathedral | four wild cherries |
| Cider Mill | the village mill and a market stall |
| Briar Gate | a flower arch and two rose bushes |
| Gardener's Folly | a shrine arch, a column and an ivy curtain |
| Vale Weir | stepping stones and a footbridge |
| Looking Lake's isle | a lilac tree and a rock |

**Not models, but needed:** planting along a line (hedges, avenues, orchard
rows), in a ring (the birches round the pool) and leaning away from a point
(the Reaches). Today's scatter plants by density inside a habitat.

**Already covered:** silver birch, oak, beech, elm, alder, willow (three
kinds), hazel, hawthorn, crab apple, lilac, pine, rowan, the autumn trees, dead
and blighted trees, the leaning trunk, the five special trees; ferns, bracken,
bramble, rose bushes, heather, lavender, hydrangea, azalea, iris, reeds, lily
pads; bluebell and the other woodland flowers; flower carpets in six colours;
moss, logs, root arches, rocks; rose and cherry petals in the air.

## Decisions for the owner

1. Are the feel lines right, place by place?
2. Which place is the pilot? Suggested: **Starlight Glen** (the book describes
   it most closely, its land is the most distinctive, and one tree per knoll
   is the clearest test of planting by the land). Rosewild is the alternative
   if the flowers should come first.
3. Are the other woods and the estate part of this, or the nine court places
   only?

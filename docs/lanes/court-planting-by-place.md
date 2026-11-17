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

### Scope (owner, 2026-11-15)

"I want to just throw out whatever rules are currently used for planting
trees, fauna, foliage, all of it ... and I want to strategically rethink it.
I've already rethought the land and landmarks."

- **Thrown out:** every rule that decides what is planted where in the court:
  the per-region recipes (so many trees per hectare in each kind of ground),
  the habitat densities, the ceilings, the species mixes. This plan replaces
  them.
- **Kept:** the land, the paths, the water, the landmarks and where they stand.
- **Kept:** the plants themselves. The trees, shrubs and flowers the game has
  stay as they are, including the estate's trees and the special trees. A new
  plant is made only where the plan needs one the game lacks ("Assets we do
  not have"), in whatever way suits that plant.

Withdrawn: an earlier draft of this section proposed re-making every plant
with one new builder so that they would match. The owner asked why, and there
was no good reason: plants match through shared colour, light and scale and
through how they are placed, not through the tool that made them.

## Assets we do not have (checked 2026-11-15)

Checked against the court's tree set (`CourtTreeSet.ROLES`), the court's flora
and props (`wider/assets`), the woods' plants (`FloraLibrary`), the estate's
trees and flora, and each landmark's pieces in `court_content_table.gd`.

**Plants that do not exist anywhere in the game** (revised against the book;
how each should look is under "How each missing asset should look")

| Asset | For |
|---|---|
| The great oak (and, grown largest, the Crown Oak) | Western Woods; Solstice Meadow |
| The pillar elm | Western Woods; the wall of trunks at its door |
| The pillar birch (**built as a preview 2026-11-16**, three builds, `CourtGreatTrees`; shown to the owner as a ring round the pool, not yet in the game) | the starlight pool's ring; the Suriel's glen; Looking Lake's isle |
| The great sycamore (one hero tree) | its knoll |
| The old thorn, arching over a path | the Rite's processional way; crests and high ground |
| The cathedral cherry | the Blossom Cathedral's nave |
| The pollard willow | the vale stream; the village river |
| The rose brake, in runs, in four colours | Rosewild's rooms; the Briar Gate |
| The hedgerow, in runs | village lanes; between the vale's orchards |
| Meadow drifts in pink, white and blue | the vast meadow |
| The frost-withered tree, and its half-turned form | Blighted Reaches |
| The turning tree (half Spring, half Autumn; a recolour) | the Sealed Pass |
| The shimmer (an effect) | dips, hollows, the special trees |
| The cave's garland | Hill of the Rite |

Dropped after reading the book: the wind-bent pine and hanging moss (no
conifer and no such moss in the book's Spring); the yew is the owner's call.

**In the game, but not usable in the court yet**

| Asset | Where it is now |
|---|---|
| Yew (only if the owner wants it; not in the book) | the woods have one; the court draws a pine in its place (`CourtTreeSet`: `woods_yew` to `conifer`) |
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

## What the book gives us (owner, 2026-11-15: "looking into how the book actually describes things")

Read back from chapter summaries and recaps of book 1 (sources at the end), not
from our own design notes. The book says little about plants, and what it says
is plain, real, and specific:

| Where | What the book has |
|---|---|
| The manor (ch 5-7) | pale walls veiled in roses and ivy; amethyst irises, pale snowdrops and butter-yellow daffodils at the front; a grander garden behind; a rose garden of white roses, with thorns; hedges; hydrangeas indoors |
| The road west (ch 14) | cultivated gardens, then wild rolling grassy hills, then clear streams, then the spring woods; a lone sycamore on top of a knoll; a large pond at the foot of a towering hill |
| The western woods (ch 10, 14) | balmy spring woods full of thrushes, squirrels and moths; a sturdy, dense oak in vivid leaf; an elm with a coarse trunk; the Suriel's glen, a ring of white birches "tall and straight as pillars", by running water |
| Magic (ch 14 and throughout) | a shimmer at the corner of the eye that turns out to be sun on a stream or wind in leaves; magic lies strongest in the land's dips and hollows; near the Bogge the spring woods recoil, wither and freeze |
| The glen (ch 18) | down a hill to a stream; knolls; a small pool whose water is starlight and feels like warm silk; crocuses, snowdrops and bluebells; golden light on grass |
| Fire Night (ch 20) | foothills; a giant bonfire on top of the first hill; a knoll; a trench-like hollow with steep banks between two hills; at its end a cave mouth in a soft hillside, dressed with flowers, branches and leaves |
| The solstice (ch 25) | fields beyond the garden; a plateau; bonfires and maypoles on the hills; damp grass; a garland of pink, white and blue wildflowers; a meadow where will-o'-the-wisps drift; dawn from a high place |
| The village (later books) | mostly destroyed; a tavern and a well at its centre rebuilt |

Not re-read directly: chapter 18. Its row is from the terrain brief and the
summaries; whether it names a willow is unconfirmed.

### What that changes

- **Real plants, a little too perfect.** Every tree the book names is an
  ordinary one (oak, elm, birch, sycamore), in fresh leaf. The magic is in how
  the place behaves and how the light falls, not in strange shapes. The
  special trees stay the exception, and they belong where the book puts magic:
  in dips and hollows.
- **The western woods are bright.** Spring woods in vivid new leaf, with
  birdsong: pillars under a green roof, not gloom.
- **No conifer is named anywhere in Spring.** The wind-bent pine and the yew
  are dropped unless the owner wants them; thorn and stunted oak do the pine's
  work on high ground.
- **The meadow's flowers are pink, white and blue.** No red poppies.
- **The blight is spring stopped,** withered and frozen where it stood. Not
  grey rot.
- **The cave is dressed for a festival:** flowers, branches and leaves round
  its mouth.
- **The lone sycamore stands on the road west** (ch 14), on a knoll between
  the estate and the western woods. Our map has "the sycamore's knoll" at the
  Hill of the Rite; chapter 20's knoll has no named tree. Owner's call which
  knoll gets it.

## How each missing asset should look

Sizes are for the grown tree in the game. "Book" says what the design rests
on; where the book is silent that is said, and the design keeps to the book's
key (real, fresh, a little too perfect).

### Trees

**The great oak** (Western Woods; one grown larger is the Crown Oak)
- Book: the sturdy, dense oak in vivid leaf that hides Feyre.
- Look: 24 m tall and wider than tall. A trunk 2 m through, standing on mossy
  root buttresses you could sit between. The first boughs leave at 3 to 4 m,
  nearly level, each as thick as an ordinary tree, so it reads as climbable.
  A dense, domed crown you cannot see through, in bright yellow-green new
  leaf. Moss on the upper side of every bough; ferns in the forks.

**The pillar elm** (Western Woods: the forest's columns; the wall at its door)
- Book: the elm with the coarse trunk.
- Look: 32 m tall. A straight clean trunk, 1.4 m through, with deep coarse
  ridged bark, no branch for the first 12 m, then a fork into a tall vase of
  boughs that open like a fountain. Its crown is high and airy, so light
  comes down between the pillars in spots.

**The pillar birch** (the starlight pool's ring; the Suriel's glen)
- Book: the ring of white birches "tall and straight as pillars".
- Look: 18 m tall, a dead-straight white trunk 0.4 m through with few black
  marks and no low branches, and a small light crown of fine drooping twigs
  near the top. Planted in a ring they read as a colonnade. Ours today are
  shorter and branch low.

**The great sycamore** (one tree, on its knoll)
- Book: the lone sycamore on top of a knoll.
- Look: 25 m tall and as wide. A patchwork trunk, 1.8 m through, flaking in
  cream, olive and grey; the upper limbs bare-barked and almost white, so
  the tree shows against any sky and glows at dusk. A broad open crown of big
  hand-shaped leaves in fresh lime, with seed balls hanging on threads.

**The old thorn** (the Rite's way; high and windy ground everywhere)
- Book: silent on the tree. Fire Night is May eve and the hawthorn is the May
  tree: this one is our reading, not the book's.
- Look: 5 to 7 m. A twisted, fluted, leaning trunk and a flat-topped crown
  swept one way by the wind, solid with white blossom going pink as it ages.
  On the processional way they stand in pairs leaning toward each other, so
  their crowns meet overhead. On Fire Night they carry what the book puts on
  the cave: garlands of flowers and leaves.

**The cathedral cherry** (Blossom Vale's nave)
- Book: silent; the vale is ours.
- Look: 14 m. A tall clean trunk with dark, glossy, banded bark; boughs that
  rise steeply and then arch over, so two rows 8 m apart meet in a pointed
  vault at about 12 m. Blossom in pale pink-white clouds, thickest on the
  vault's underside. Petals lie in drifts on the floor of the nave.

**Orchard apple, cherry and pear** (Blossom Vale; the village's west bank)
- Book: silent.
- Look: 4 to 5 m, kept low and open in the middle like a goblet. A short
  leaning trunk with old pruning scars and grey-green lichen; blossom along
  short spurs on every branch (apple white from pink buds, cherry pink, pear
  pure white). In loose rows, never a grid.

**The pollard willow** (the vale stream; the village river)
- Book: silent.
- Look: a short, thick, leaning trunk 2.5 m tall ending in a knobbly head,
  and from the head a burst of straight young shoots in gold-green. Old ones
  are hollow, with ferns growing in the hollow. In rows along water. They are
  the mark of a place that somebody tends.

**The frost-withered tree** (Blighted Reaches; half-turned at its edge)
- Book: near the Bogge the spring woods recoil, wither and freeze.
- Look: an ordinary spring tree caught mid-recoil. Its boughs bend away from
  the Heart. The leaves are still on, curled and brown-black, and rimed white
  on the side facing the Heart. Nothing has rotted or fallen. At the edge of
  the Reaches a tree is half this and half in fresh leaf, with the line
  between running through its crown.

**The turning tree** (the Sealed Pass)
- Book: later books give Autumn forests of red, gold and orange.
- Look: a Spring tree whose crown is green on the Spring side and flame on
  the Autumn side. A recolour of trees we have.

### Hedges and thickets

**The rose brake** (Rosewild)
- Book: roses and thorns everywhere at the manor; the rose garden is white.
- Look: a mound of long arching canes 2 to 3 m high and twice as wide, with
  real thorns and single, open, five-petalled flowers with gold centres (the
  wild rose; the estate keeps the full garden rose). White first, then blush,
  pink and deep red, one colour to a hollow. Ivy through its foot; red hips
  among the flowers. Mounds overlap into walls, and where canes from two
  mounds meet over a path they make an arch.

**The hedgerow** (village lanes; between the orchards)
- Book: hedges at the manor only.
- Look: a laid hedge 1.8 m high and 1.2 m thick: hawthorn, hazel, wild rose
  and honeysuckle woven together, with a taller tree left standing every 20
  to 30 m, gaps at gates, and primroses and white lace flowers along its foot.

### Flowers and ground

**Meadow drifts** (the vast meadow)
- Book: a garland of pink, white and blue wildflowers; damp grass.
- Look: knee-high drifts in those three colours only (pink campion and
  clover, white ox-eye daisy and lace flower, blue cornflower and
  forget-me-not), each drift tens of metres long and one colour, in tall soft
  grass. Dandelion clocks among them: at dusk their seed lifts and glows.

**Glade grass and the first flowers** (the glen; clearings everywhere)
- Book: crocuses, snowdrops and bluebells; golden light on grass; irises and
  daffodils at the manor.
- Look: short, fine, even grass like a lawn nobody mows, with those flowers
  in patches, each kind keeping to itself. The flowers exist; the grass does
  not (the downloaded Quaternius grass is the candidate).

### Light

**The shimmer** (everywhere magic is near)
- Book: a shimmer at the corner of the eye that turns out to be nothing.
- Look: a brief glint at the edge of the screen, in dips and hollows and near
  the special trees, that is gone when you turn to it. This is the book's own
  picture of magic and we have nothing like it.

**Light through the trees** (Western Woods)
- Book: sunlight dancing on water; the woods are bright.
- Look: soft shafts in the gaps between the pillars. The woods lane has this
  already; the court's Western Woods does not.

### Landmarks

**The garlanded cave** (Hill of the Rite)
- Book: a cave mouth in a soft hillside, dressed with flowers, branches and
  leaves.
- Look: the cave we have, with a thick wreath round its mouth of green
  boughs, white blossom and wildflowers, and more strewn on the ground before
  it. Not on the missing list before; the book asks for it.

**The Crown Oak** (Solstice Meadow)
- Book: the great oak above, and the meadow of will-o'-the-wisps.
- Look: the great oak at its largest: 26 m tall, 40 m across, a hollow trunk
  4 m through, lower boughs that sweep down to the grass and rise again. At
  night the wisps gather in its crown.

**The Rose Spire** (Rosewild)
- Book: silent; ours. Roses, ivy and thorns are the manor's own plants.
- Look: a single giant white climbing rose that has swallowed whatever once
  stood there, 20 m high, with stems as thick as an arm at the foot, and its
  flowers flushing pink toward the top.

**The Great Lantern Tree** (the village green)
- Book: silent; ours.
- Look: a lilac grown impossibly large: many trunks twined together, a broad
  dome 22 m high, flower spikes standing upright all over it, and lanterns
  hung through the crown at every height on ribbons.

**The Bee Tower** (Blossom Vale)
- Book: silent; ours.
- Look: an old round stone tower split down one side, gold comb hanging in
  sheets inside the split, roses and ivy up its walls as on the manor, and
  straw skeps round its foot.

**The Heart of the Blight** (Blighted Reaches)
- Book: the recoiling, freezing woods; the masks.
- Look: a shallow hollow where spring stopped. A ring of frost-withered
  trees all bent outward; bare frost-cracked ground inside; at the centre a
  drift of masks half buried. No rot, no movement, no sound.

**The Ember Crown** (Autumn border)
- Book: Autumn's red and gold forests (later books).
- Look: a ring of flame maples round the hilltop, red at the top and gold
  lower down, always shedding leaves that glow on the wind like embers.

**The smaller ones**
- Briar Gate: two rose brakes whose canes meet in a natural arch over the path.
- Gardener's Folly: a small open stone pavilion, roofless, with a white rose
  through its columns.
- Cider Mill: a low stone press-house with a waterwheel on the vale stream,
  apple crates and a cart.
- Vale Weir: a low curved stone weir with a plank walk along its crest.
- Looking Lake's isle: a rock with one pillar birch.

## Decisions for the owner

1. Are the feel lines right, place by place?
2. Which place is the pilot? Suggested: **Starlight Glen** (the book describes
   it most closely, its land is the most distinctive, and one tree per knoll
   is the clearest test of planting by the land). Rosewild is the alternative
   if the flowers should come first.
3. Are the other woods and the estate part of this, or the nine court places
   only?

## Sources for the book's descriptions

- Chapter 14 recap (the road west, the sycamore, the oak, the birch ring, the pond): https://www.goodreads.com/author_blog_posts/24097795-a-court-of-jealousy-and-haters-acotar-chapter-14-or-wait-did-feyre-j
- Chapter 20 recap (Fire Night: foothills, bonfire, trench, cave): https://www.goodreads.com/author_blog_posts/24139050-a-court-of-jealousy-and-haters-acotar-chapter-20-or-or-worse
- Chapter 25 recap (the solstice: plateau, maypoles, wildflowers, meadow): https://www.goodreads.com/author_blog_posts/24172130-a-court-of-jealousy-and-haters-acotar-chapter-25-or-the-chapter-that-d
- Chapter 10 recap (the Bogge; the elm): https://www.goodreads.com/author_blog_posts/24069536-a-court-of-jealousy-and-haters-acotar-chapter-10-or-no-she-didn-t-cop
- SparkNotes, chapters 18-20 (the pool; crocuses, snowdrops, bluebells; white roses; the cave): https://www.sparknotes.com/lit/a-court-of-thorns-and-roses/section6
- Wiki, Tamlin's Manor: https://acourtofthornsandroses.fandom.com/wiki/Tamlin%27s_Manor
- Wiki, Spring Court (hills, lakes, dips and hollows, the village): https://acourtofthornsandroses.fandom.com/wiki/Spring_Court

## Pilot study: the starlight pool's hollow (2026-11-16)

One spot planted whole, as a picture for the owner, before any planting rule is
written: `tools/court/study_pool_hollow.gd`, stood up by the shot tool with
`study=pool_hollow` over the court with today's scatter hidden
(`regions ingame without=trees,decor`). Nothing here is in the game yet.

What stands there, from the ground up:

| Layer | What | From |
|---|---|---|
| Floor | sward over the level floor, thinning up the slopes, none on rock; taller tufts at the water and the birches' feet | `tools/grove` (new) |
| Flowers | bluebells under the birches, snowdrops by the water, crocuses in the open and on the mound; each kind in drifts of its own | `tools/grove` (new) |
| Bank | iris, reeds, cattail, water mint, fern, mossed stones on the far banks; the arrival bank left to grass | woods kit, grove fern |
| The ring | about 26 pillar birches round the pool in clumps of one to three, open toward the mound and the Glimmerfall | `CourtGreatTrees` |
| Slopes | 26 more birches in twos and threes behind the ring, open toward the mound and the Glimmerfall; bluebells, fern and a stand of foxgloves with each group | as above |
| Knolls | one tree on each of six knolls, each a different kind; the mound bare | estate trees |
| Glow | starmoss, glowcaps, faelights by the water; small lights in the air from dusk | woods kit |

What it taught:

- **Grass takes no rim light.** A blade seen along the ground is all rim, and
  the woods' rim is warm cream: the first render was a floor of straw.
- **No twinkle on grass either.** The twinkle lights a whole 14 cm cell, which
  on a blade at your feet is a white shard.
- **A drift needs a far form.** A flower is under a pixel wide past 60 m, so a
  drift vanished from the mound. Each flower patch has a far cushion (18
  triangles, the flowers' colours over the leaves') drawn beyond 75 m.
- **Small plants go down by the cell**, each cell drawn only within its range
  (sward 80 m, fine grass 40 m, flowers to 75 m then cushions).
- **A flower belongs to something.** The first bluebells were laid as broad
  bands along the ring and read as flowers dumped on a lawn (owner,
  2026-11-16). Now they are the birches' own: the ring stands in clumps of one
  to three, and the bluebells follow the clumps' shade, thick and tall in the
  heart, feathering to small outliers at the edge, with trails of grass
  through, fern and moss at the trunks' feet, the odd white one, and the blue
  deeper here and paler there. The open floor stays grass. The rule for every
  place: a drift is placed by what it grows under or beside, never by area.
- **Look for the water first.** The Glimmer Brook runs into the pool from the
  south; the first pass planted straight across it. Its bed is kept clear, its
  banks carry iris, mint, fern and snowdrops, and no trunk stands within 3 m.
- **The way in is open.** No clump stands within 0.42 rad of the line from the
  mound, nor on the line from there to the Glimmerfall.
- **There is no shrub fit for the glen.** The woods kit's hazel and bracken are
  too crude beside the new plants. A blossoming shrub (hawthorn or blackthorn)
  joins the missing list.
- **The knolls' rock faces and the land between them are still bare** from
  inside the hollow; that is the rest of the glen's work, not this spot's.

Frame time on the Mac, look quality, 1920x1080, standing on the east bank:
bare land 17.6 ms; today's planting 24.1 ms; the study 28.9 ms (26.6 ms among
the birches; 25.3 ms from the mound). So it costs about 4 ms more than what
stands there today, nearly all of it the sward.

## The rest of the Starlight Glen, by rule (study, 2026-11-16)

After the owner passed the pool's hollow ("it looks perfect"), the same
approach across the glen: `tools/court/study_glen.gd`, `study=glen` in the shot
tool. Still a picture; the pool's hollow keeps its own study inside 118 m.

Every plant answers to something on the land, found from the land itself:

| Rule | What it reads | What it plants |
|---|---|---|
| Knolls | high points 4 m over the ground 36 m round (50 found) | one tree on each, neighbours never alike; its flower pooled in its shade and in a crescent at the knoll's north foot |
| Brooks | `CourtHeight.brooks()` | a clump of willow or birch every 34-62 m on alternate banks; iris, mint, fern, stones at the water; snowdrops beside it in stretches |
| The river | the Thornwater's line | clumps of willow and birch every 42-76 m, on the first open ground back from the water |
| Looking Lake | the lake, its level, the lake walk's end | a wood of 52 on the far side; willows wherever the bank comes down to the water; reeds in the shallows |
| Willow Mere | the mere, the Weeping Lady | willows all round, open to the Lady and to the side you come from; reeds in the shallows |
| The brae | `brae_top` and its line of sight | a clump either side of the line, 36-48 m over the crest |
| Paths | `CourtHeight.paths()` | a drift of crocuses on one verge every 70-120 m |
| Open glade | the standpoint | sward round the eye; long grass in the dips; daisies on slopes that face the sun |

No trunk stands where `CourtLandHabitats.keep_open` says none may, or within
9 m of a path.

What it found:

- **Looking Lake lies in a pit.** Its water is 23-26 m below its west bank and
  about 5 m below where the lake walk reaches it, so "wooded to the water, for
  the reflection" cannot be planted: the far wood crowns a cliff. Willow Mere's
  banks are 2-5 m sheer as well. This is the land's, not the planting's.
- **The isle has its tree already** (a landmark), so the study adds none.
- **The knolls need great trees.** The estate's garden trees are grown to 1.5-
  1.95 times their size to hold a knoll 30 m across: stand-ins for the great
  oak, sycamore and thorn on the missing list.
- **The open glade is still the thinnest part**: sward, a tree per knoll and
  its flowers. It wants the missing shrub and meadow drifts.
- Frame time at `brae_top`, Mac, look quality: today's planting 21.9 ms, the
  study 26.9 ms. It draws 1337 batches against 485: every tree is its own
  object and has no far form, which the game's version must fix.

## Owner's decisions, 2026-11-16 (after the glen's first pass)

1. Looking Lake's banks: "whatever lets you accomplish the best outcome". The
   land there may change so the far wood comes down to the water.
2. "If you need to make the assets before submitting do that." The missing
   pieces are made first; then the glen goes into the game and is submitted.

The order of work from here:

1. **Assets the glen lacks:** the great knoll trees (oak, sycamore, thorn) in
   `tools/blender/estate_tree.py` as court species (`CourtGreatTrees`); a
   blossoming thorn bush for the height between grass and crowns; meadow
   flowers for the open glade (`tools/grove`); the Weeping Lady as a real
   giant willow (asked about by the owner; offered, not yet confirmed).
2. **Looking Lake:** ease its west and north banks in `court_height.gd` so the
   water is reached on the wooded side.
3. **Into the game:** the study's rules become the glen's planting (baked by a
   generator recipe, not built at load: the study takes ~15 s to stand up),
   with far forms for the trees, the sward laid by the cell round the player,
   and the old glen recipes for trees and small plants retired. Then tests,
   `docs/tuning.md` rows, precheck and `lead/ready-M4WCT-15-1`.

## State, 2026-11-16 evening

**In the game's main branch (M4WCT-15-1, merged):** the great oak, great
sycamore, old thorn and thorn bush beside the pillar birch (`CourtGreatTrees`);
the glade's sward, flower patches with their far cushions and ferns
(`tools/grove`); the two studies and the shot tool's `study=`; this plan. No
planting in the game has changed yet.

**Not done:**

- *The glen in the game.* The game plants a region from its content's decor
  entries (`CourtScatterGenerator.decor_layers`: trees first, then ground
  layers that read the canopy, then the places' collars), as `ScatterLayer`s
  drawn by `ScatterField` in chunks, each layer with `draw_from` /
  `draw_distance` and an impostor. The studies' rules have to produce those
  layers for `starlight_glen` in place of its decor entries: trees as near and
  far layers (the great trees have no far form yet), a flower patch and its
  cushion as two layers on one set of instances (a layer carries position, yaw
  and one scale: the bluebells' tint and the grass's uneven height go), and the
  sward laid by the cell round the player, since a layer of it over the whole
  glen would be millions of instances. The region's reports, quotas and
  draw-call estimates read the decor layers and will need to read these.
- *Looking Lake's banks* (owner: free to change the land).
- *Meadow flowers* for the open glade; great blossom trees (the knolls'
  cherry and crab apple are still the estate's, grown to 1.9x).
- *The Weeping Lady* as a real giant willow (offered; the owner has not said).

## The glen in the game (2026-11-16)

Owner: remake the Weeping Lady "markedly distinct ... in color size etc.",
"then go for the rest"; and "we dont need to anchor SO much on the old design
we want to optimize for end result".

**Merged (M4WCT-16-1):** the trees each built their own way (great oak wide,
great sycamore a tower of billows, great elm a vase, aspen spire a column, old
thorn wind-blown, thorn bush many-stemmed), and the Weeping Lady: a 36 m
silver willow bowed over Willow Mere on a dark bole with roots, her strands in
the water, hung with chains of blossom that each end in a drop of light
(`great_weeping_lady` as the landmark's asset; landmarks can use the court's
great trees, turned to face the site they bow to).

**How the glen is planted now** (`world/spring_court/wider/planting/`):

| Piece | What it does |
|---|---|
| `CourtGlenPlanting` | The rules, read from the land, as scatter layers: the pool's ring and slope birches, a tree a knoll, clumps by the brooks and the river, the lake's wood and willows, the mere's willows, the brae's clumps, thorn at the edges, flowers in the shade and at the knolls' feet, the banks' plants, crocuses on the verges. The glen's content names it (`place_planting = &"glen"`) and its decor recipe keeps only what is not a plant of the place. |
| `CourtPlacePlants` | The plants by name with their materials: the glade plants (`tools/grove`), the trees near and far, the woods' plants. Prewarmed on the main thread. |
| `CourtSward` | The grass, laid round the player in 16 m cells grown on worker threads from the land, let go behind them. Near cells are the sward; past 34 m its far form (a third of the blades) thinning out to 84 m. |
| `CourtMotes` | The hollow's lights in the air, out from the golden hour through the night. |

A tree is refused where the court keeps open (paths, gates, viewpoints, the
story's spots, water, clearings; the starlight pool's clearing is its story
rim, 24 m, so its birches ring the pool outside it) and where its crown would close one of the court's sightlines.

Steps of detail: a tree is itself to about 180 m and its far form (the same
outline, a twentieth of the triangles: `estate_tree.py --far`) to 800 m; a
flower patch is flowers to 60 m, a mid form (fewer, bigger plants) to 110 m and
a cushion to 220 m.

**The land:** Looking Lake's and Willow Mere's banks are eased down to the
water (`CourtHeight.LAKE_SHORES`). The lake's brook (`lake_run`) now runs from
the Thornwater down into the lake: the lake lies 6 m under the river, and as
the lake's outflow the brook had been held up at the river's level, a causeway
across the lake's east rim where the lake walk arrives.

**Left out, on purpose or for later:**

- The old habitat map still places the glen's forage (pickable plants), so a
  forage plant can stand where the old birch copses were. Forage by place is
  its own piece of work.
- The court's trees have no trunk colliders (they never had: only the woods'
  and the manor's do).
- Meadow flowers for the open glade; great blossom trees (the knolls' cherry
  is the estate's, grown to 1.9x).
- The other places are still planted by their decor recipes.

## State, 2026-11-16 night

**In `origin/main`:** M4WCT-16-1 (the trees each built their own way, the
Weeping Lady) and M4WCT-17-3 (the Starlight Glen planted by place in the game:
`CourtGlenPlanting`, `CourtPlacePlants`, `CourtSward`, `CourtMotes`; the trees'
far forms and the flowers' mid forms; Looking Lake's and Willow Mere's banks
eased; `lake_run` running into the lake). 17-1 and 17-2 were rejected: the
pool's birches stood in the clearing drawn from the pool's whole floor (the
clearing is now the story's rim, 24 m), then a check of mine lost its trunks
to a copied packed array (the sward's trunk lookup had the same slip).

Frame time on the Mac, look quality, 1920x1080: the pool's east bank 26.7 ms
(today's planting was 24.1, the picture 28.9); the brae 24.8 ms (21.9, 26.9).

**Clear colours (owner, 2026-11-16: "clear colors and not have it look misty
or washed out or overly bright"; M4WCT-18):** the white lakes were three
things at once. The water mirrored the pale pink horizon at low angles and
its sheen was that pink too; its foam band was metres wide on the eased
shores; and the court's day grades stood a third brighter than the estate's
under a ramp that lifted black to 0.1. Now the water is aqua over azure with
a sky-blue sheen and a held mirror, the foam is a line at the waterline, and
every court day grade stands at the estate's light with a quarter of its
ramp and half its haze (`build_court_fx.gd` `DAY_*`, `DEPTH_*`; rows in
docs/tuning.md). The Weeping Lady needed no change: against azure water and
a deeper sky she stands out as she is. Evening and night under a day grade
came down with the day: deeper, and still clear in the renders.

**Next:** meadow flowers and great blossom trees for the glen's open glade;
then the next place (the Western Woods has its oak and elm).

## The whole glen, composed (plan, 2026-11-16 late; not yet planted)

Owner, after the clear-colour pass: the Starlight Pool's "placement and
foliage look great. but honestly the rest of the screenshots dont give me the
same impression. can we make the ENTIRE thing here look intentional ... to
make the person FEEL something as they walk through the areas?" Then: "you
should probably make a plan for each before just planting! also plans for
transitions too", and "make sure to make each place feel a little special".

Why the pool works and the rest does not: the pool was composed (a ring, a
way in kept open, drifts laid by bearing, one flower per kind of ground). The
rest was planted by rule (a tree per knoll, a clump every 34-62 m of brook, a
wood of 90 on the lake's far side): correct, and about nothing. So every
place below gets what the pool has: one feeling, a first sight, a frame, a
floor, ground kept open, and one thing no other place has. The glen's colours
stay silver, blue and white; each place takes one accent and keeps it to
itself.

The land it is drawn on (scratch map from `CourtHeight`): `glen_way` comes in
from the estate between two knolls of the brae (the gate, -790, 12), drops to
the brae brook (-905, 20), crosses the Thornwater at the ford (-995, 105),
runs south-west between five knolls to the mound (-1208, 270) and stops; the
pool is below it. `river_road` leaves `glen_way` at the brook and runs north
by the oak glade (-960, -245) to the village; `lake_walk` leaves it there,
crosses the river and ends above Looking Lake (-1160, -210). The glimmer
brook runs from Willow Mere to the pool, the mere run from the mere to the
river. Nothing leads to the mere, the heron stones or the lake's south shore
but the land.

### The places

| # | Place | Feeling | First sight | Planted with | Its own thing | Stays open |
|---|---|---|---|---|---|---|
| 1 | The Brae gate (-790, 12) | a threshold: wind, then a held breath | the glen's knolls and the river's shine, framed | bare turf on the crest; two old thorns in full may, one on each knoll's shoulder, leaning in over the way; thorn bushes down the lee side | the Thorn Gate: the only arch of blossom, white petals on the path | the way itself; the line from `brae_top` to the North Watchtower |
| 2 | Brook Dell (-905, 20) | close, cool, green: you lower your voice | the brook under a leaning tree | one great elm arching over the crossing, birches behind; a floor of fern and mossed stones; snowdrops in ribbons along the water | the only fern floor in the glen | the crossing; the brook's own line of sight up and down |
| 3 | The Ford (-995, 105) | release: full sun, wide water, a place to stop | the river end to end, willows trailing on the far bank | willows on the far bank in a row, parted where the way lands; iris at the water; gold flowers on the bars and banks | the Golden Ford: the only gold in the glen (kingcups; to make) | both landings; the river's reach up and down |
| 4 | The Knoll Walk (ford to mound) | wonder, and being led: what is on the next one? | the first knoll's tree from mid-ford | five knolls flank the way in turn, each crowned differently and in order: a thorn, three birches, two aspens, the blossom tree on Knoll Steps, last a great oak; a bluebell crescent at each foot on the side the way passes | the Blossom Knoll at Knoll Steps: the one pink tree on the way, petals falling (a great blossom tree; to make) | the way; the glade between knolls stays sward |
| 5 | The Mound (-1208, 270) | exposure, then awe | sky only, until the top | nothing over the knee: close turf, daisies | a daisy ring on the crown, where you stand to look | all of it |
| - | The Starlight Pool | enchantment | (passed by the owner; stays as it is) | | | |
| 6 | Glimmer Brook (pool to mere) | being beckoned: follow the lights | lights along one bank, going round a bend | faelights and starmoss down one bank only; snowdrops; three birches at each bend, giving way to willows one for one toward the mere | the string of lights (they glow at dusk) | the bank you walk |
| 7 | Willow Mere (-1150, 430) | hush, a little sorrow, a secret kept | the Weeping Lady across the water, through a parting in the willows | willows all round as a curtain, one parting where the brook leaves; lilies; only white on the ground | the Lady, and that you cannot see the water until you part the curtain | the parting; the water between it and the Lady |
| 8 | River Road (ford to oak glade) | easy company: the river beside you | a colonnade | aspens in a row along the brae brook where road and brook run together; willows in pairs on the river's outer bends; long open sward between | the Aspen Row: the one avenue | the road; the inner bends as meadow |
| 9 | Oak Glade (-960, -245) | age and shelter: a hall | the road going into shade between two trunks | great oaks in a ring round the clearing, crowns almost meeting; white wood anemones and fern beneath; foxgloves in the light at the rim; the oldest oak alone on oak knoll | the only closed canopy in the glen, over a floor of white stars (wood anemone; to make) | the clearing's heart (55 m, the story's) |
| 10 | Looking Lake (-1250, -140) | stillness: the biggest sky, the stillest water | the whole lake at once from the end of the lake walk, between two elms | a dark wood of oak and elm down to the water on the far shore; the near shore open short sward; reeds in two bays only; the isle's one tree | the mirror: the far wood's reflection lying on the water (painted into the water; to make) | the near shore; the line to the isle |
| 11 | Heron Stones (-1105, -40) | watching, waiting | reeds taller than you, one parting | the glen's one reed bed, cattails within it, a narrow way through to the stones | the reed bed you walk through | the parting; the stones |
| 12 | Watchers' Run and the west rim | lonelier, wilder: the glen letting go | long pale grass moving | long grass, thorn bushes, old thorns all leaning the same way; oaks and elms gathering toward the Western Woods | the wind's lean | the brook's line; the ridge views |

Knolls off the walks keep one tree each (they are how you find your way), but
the tree is its place's: thorn and aspen toward the rim, birch round the
pool, willow nowhere but water.

### The transitions

| | From, to | How it hands over |
|---|---|---|
| A | Estate to the Brae | the estate's last tree, then 80 m of bare, windy turf rising: nothing, on purpose. The Thorn Gate is the first thing in it. |
| B | Brae gate to Brook Dell | going down, crowns close and the light goes green; white overhead becomes white underfoot (may to snowdrops); fern begins 30 m before the water, so you know it before you see it. |
| C | Dell to the Ford | the trees stop at the terrace's edge in one step: shade to full sun. The first gold flowers stand in the dell's mouth. |
| D | Ford to the Knoll Walk | the far willows part where you land; the first knoll's thorn is the mark from mid-river; gold gives way to blue inside 40 m. |
| E | Knoll Walk to the Mound to the Pool | the great oak (the darkest thing) is last before the bare mound (the lightest); the climb shows only sky; the pool appears at the top, and the way down is the pool's own open arrival. |
| F | Pool to Glimmer Brook | the birch ring is open where the brook comes in; the lights start at the ring's edge. |
| G | Glimmer Brook to the Mere | birch gives way to willow tree by tree; the banks close; the curtain. |
| H | Mere to the river to the Ford | the mere run leaves through open sward, the sky comes back, willows mark where it meets the river; upstream is the ford's gold. The south loop closes. |
| I | Dell to River Road to Oak Glade | the Aspen Row carries you; the oaks' dark mass shows ahead over it; the road goes in between two trunks. |
| J | Oak Glade to Looking Lake | out of the shade, over the river, up a low rise with nothing on it; the lake all at once between two elms. |
| K | Lake to Heron Stones to the Knoll Walk | short sward to reeds to knolls; the Blossom Knoll is the mark that brings you back to the way. The north loop closes. |
| L | The rims | west: clumps of oak and elm thicken over 150 m into the Western Woods; north: the river road's willows carry on to the village. No line. |

### To make first

- Kingcups (gold, at water): `tools/grove`, near, mid and far forms.
- Wood anemone (white, low, in sheets): `tools/grove`, the same three forms.
- A great blossom tree for Knoll Steps: a court species in
  `tools/blender/estate_tree.py` (the estate's cherry at 1.9 times its size
  stands there now); the court's petal particles over it.
- The lake's painted reflection: a dark, wavering band on the water under
  the far wood, in `court_water.gdshader` (the water does not mirror trees).

### Order, and how it is shown

The glen draws 1318 of its 1500 allowed batches now, so composed planting
replaces the scattered clumps; it does not go on top of them.

1. The main walk: 1 to 5 with A to E.
2. The south loop: 6, 7 with F to H.
3. The north loop: 8 to 11 with I to K.
4. The rims: 12 with L.

Each is shown as a walk: pictures in order along the route, the transitions
among them, never a single piece on bare ground.

### State: the main walk is composed (2026-11-16, late)

Owner: "go". Places 1 to 5 and transitions A to E are in `CourtGlenPlaces`
(`world/spring_court/wider/planting/court_glen_places.gd`), which claims the
ground 70 m either side of `glen_way` and the ford's reach of the river; the
rules in `CourtGlenPlanting` plant what it has not claimed. Made for it:
kingcups and fallen petals (`tools/grove`), the great cherry (a court species),
and old thorns that all lean to +X so the planting can turn them. The shot
tool has the walk in order: `walk_01_climb` to `walk_11_oak`, then `mound_day`.

What the land decided, against the plan:

- The Thorn Gate stands on the brae's crest (6 m past its highest point), not
  at the gate site 45 m on: on the crest it is the first thing on the skyline
  from the estate. The gate site keeps its briar lock.
- The knolls do not flank the way in a neat alternation. As you pass them: an
  old thorn close on the south, three birches far to the north, the cherry on
  Knoll Steps 62 m north with two aspens opposite it 90 m south, and the great
  oak 24 m north just before the mound. The cherry is a mark from the way and
  a place to go up to, not a tree you pass under.
- One elm did not close Brook Dell: it took two, with oaks by the way and a
  second rank behind, before the ground went dark.

Numbers (my own probe, not the gate): 485 trees, 5.3 a hectare; 59 of 67 knoll
tops crowned; 54% of bluebell patches within 15.5 m of a trunk; no trunk on
kept-open ground; 1344 batches of the 1500 allowed.

Still to do then: the south loop, the north loop, the rims.

### State: the south loop is composed (2026-11-16, night)

M4WCT-19-1 (the main walk) is in `origin/main`. Places 6 and 7 and
transitions F to H are in `CourtGlenPlaces` too: the Glimmer Brook's groups
and white ribbon on its outer bank, its string of lights (`CourtMotes` draws
them, warm and haloed, from the golden hour), Willow Mere's curtain two deep
with its one parting, and the mere run left open to a pair of willows at the
river. The shot tool has `glimmer_01` to `glimmer_04`, `mere_parting`,
`mere_outside`, `mere_run_01` and three evening views.

What changed against the plan:

- The lights are real lights. Faelights and glowcaps alone were white dots
  among white snowdrops at dusk; the string had to be warm and in the air.
- A rule crescent of bluebells from a knoll south of the brook lies across
  the bank you walk near the bend. It stays: it is the rule's, and the blue
  is the pool's handing over.
- The estate's cherry came out of the knoll rule's kinds, so the Blossom
  Knoll's is the only pink tree in the glen.

Numbers (my probe): 481 trees, 5.2 a hectare; 59 of 67 knoll tops crowned;
53% of bluebell patches within 15.5 m of a trunk; 1367 batches of 1500.
Frame time on the Mac, look quality: the dell 23.7 ms, the ford 23.9, the
mere's parting 24.0, the pool 27.8 (as before).

Still to do then: the north loop and the rims.

### State: the whole glen is composed (2026-11-17)

Owner, on the main walk and the south loop: "looks great go ahead and push".
M4WCT-20-1 (the south loop) is in `origin/main`. Places 8 to 12 and
transitions I to L are in `CourtGlenPlaces`: the Aspen Row, the Oak Glade's
ring, doors and floor of anemones, Looking Lake's two elms, far wood and
painted mirror, the Heron Stones' reed bed, Watchers' Run and the west rim's
gathering clumps. `CourtGlenPlanting` keeps the pool's hollow, the rule knolls
(now by place: birch round the pool, thorn and aspen on the rims), the brooks'
bank plants and the river's clumps; its lake, mere and brae rules are gone.
Made for it: wood anemones (`tools/grove`), the mirror in `court_water.gdshader`
(instance uniforms on the lake's mesh). Views: `road_01_row` to
`oak_03_floor`, `lake_01_rise` to `lake_03_shore`, `heron_01`, `heron_02`,
`rim_01_run` to `rim_03_west`.

Where it falls short of the plan, said plainly:

- **The Oak Glade is a ring, not a roof.** The story's clearing is 110 m
  across and stays open, so the hall is the ring of shade round it; you stand
  in light looking at a wall of oak. Closing it overhead would mean shrinking
  the clearing, which is the story's.
- **The mirror is a shade on the water, not a picture of the trees**: a dark
  band with a crown-shaped upper edge, bluer than the wood. It reads as a
  reflection from the walk's end and from the shore; it does not show trunks.
- **The reed bed is straw-coloured** (the woods' reed, as it comes) on dry
  ground: the Heron Stones stand 90 m from any water.
- **The long grass on Watchers' Run hardly shows** against the sward at
  walking distance; the thorn bushes carry that place.

Numbers (my probe): 555 trees, 6.0 a hectare (the table allows 2 to 7); 59 of
67 knoll tops crowned; 55% of bluebell patches within 15.5 m of a trunk; no
trunk on kept-open ground; 1419 batches of 1500. Frame time on the Mac, look
quality: the oak glade 23.4 ms, the lake's shore 20.5, the pool 26.7, the
brae 23.1.

Next: the next place (the Western Woods has its oak and elm), on the same
method: a plan per place and per transition, then the walk.

# Wayside contract (L23)

The small things to find, watch and do on the walks between places, so no
walk is only walking. Owner: the wayside lane (L23). Paths: `systems/wayside/`,
`data/wayside/`, `tools/wayside/`, `tests/unit/wayside/`, this file.

## What it is

- `Wayside` (`systems/wayside/wayside.gd`) is one Node3D in the game scene
  (`story/act1/act1_game.gd`: `add_child(Wayside.new())`). It loads every
  `WaysideRoute` in `data/wayside/`, and every 0.5 s (at once after a jump of
  over 40 m) builds a node for each spot within **150 m** of Feyre and frees
  spots past **200 m**. With no `player` in the tree it follows the current
  camera, so shot probes see the spots too.
- A `WaysideRoute` (`id`, `realm`, `waypoints`, `spots`) is one walk. A
  `WaysideSpot` is one thing on it: `kind`, unique `id`, ground `position`,
  `yaw`, `target`, `items`, Feyre's `line`, `require_flags`/`forbid_flags`,
  per-kind `params`, and `canon` + `source` (R7).
- Spots never set WorldState flags (R2). What she has found is kept in
  `WorldDeltas` region `"wayside"`, key = spot id (true, or the day a snare was
  set), so it saves and loads with the world.
- No markers, no objective text. A small key glyph shows only within 3 m of
  a spot that takes the interact key.

## Kinds

| kind | node | verb | canon |
|---|---|---|---|
| `rest` | `WaysideRest` | interact: the camera eases to the view and she names three colours; first time, a sketch | X, on-voice (ch 7 colour naming) |
| `shimmer` | `WaysideShimmer` | look: a glimmer at the edge of sight that turns, looked at straight, into sunlight on water or wind in a lone sycamore; after `glamour_lifted`, a small faerie that darts off | C ch 14; the faerie is X |
| `pond_faeries` | `WaysidePondFaeries` | approach: four heads in the water turn to watch her, then sink one by one | C ch 14 |
| `vignette` | `WaysideVignette` | watch: stop and look at the animals for 1.5 s without running and you get a sketch; sprint and they bolt | doe C ch 11; others X |
| `nook` | `WaysideNook` | interact: take what's tucked away (an old coin, an arrowhead, a feather, a pigment), shown as the item's own model; cue: a drooping lilac (ch 9) or a bunting (ch 7) | X; never a mask (Keeper) |
| `crossing` | `WaysideCrossing` | run across: stepping stones, a fallen oak or a footbridge over the Thornwater, with collision on layer 1 | X (Tamlin hops brooks, ch 14) |
| `snare` | `WaysideSnare` | interact: set it; on a later day it often holds a rabbit (sometimes a brace), seeded by spot and day | grove C? ch 5; snares X |
| `sentry` | `WaysideSentry` | none: a silent masked sentry who turns to keep her in view | X post; patrols C ch 9 |

Each node extends `WaysideSpotNode` (`complete()`, `give()`, `add_model()`), is
in group `wayside_spot`, and kinds with the interact key are in group
`station` with a `station_id` of `wayside_<kind>` and `use(user)`.

## Data and generator

- `tools/wayside/wayside_gen.gd` writes `data/wayside/<route>.tres` (fixed
  seed; reruns are identical). The canon set pieces are authored there: the
  Silverspring snare grove, the doe in the deer park, the bunting and lilac
  nooks, the pond-faeries, the lone sycamore, and the Wall-road sentries.
  The Thornwater crossings come from route/river intersections. Everything
  else is placed where a route has gone 105–145 m with no spot in sight
  (26 m), 6–15 m off the line, off steep ground (22°), the river, the estate's
  buildings and gardens, the human-realm roads, the creek and the hubs.
- `tools/wayside/wayside_routes.gd` is the list of walks, shared with the audit.
- Models come from the court library (`CourtAssets` ids), the human realm's
  winter assets (res:// .glb paths), the creatures lane's ambient scenes and
  people models, and the wayside's own `systems/wayside/models/snare.glb`
  (`tools/wayside/snare_model.py`, cloud Blender).

## Measuring (F9)

`godot --headless -s tools/wayside/route_audit.gd` loads every region headless,
collects every pickup, landmark, station and creature spot, adds the wayside
spots, and prints each walk's longest stretch with nothing but pickups
(`maxGapMoment`, in seconds at run speed 8.22 m/s). `-- --cached` reruns the
maths from the last scan; `-- --before` leaves the wayside out.

| walk | before | after |
|---|---|---|
| manor → fells foot | 174 s | 23 s |
| manor → blossom vale | 161 s | 19 s |
| manor → eastern woods | 142 s | 16 s |
| manor → fae village | 132 s | 22 s |
| Wall gap → sentry gate | 124 s | 15 s |
| manor → suriel glade | 110 s | 27 s |
| manor → starlight glen | 107 s | 16 s |
| manor → hill of the rite | 86 s | 14 s |
| manor → rose spire | 68 s | 13 s |
| manor → solstice meadow | 52 s | 13 s |
| cottage → clearing | 45 s | 12 s |
| village → cottage road | 40 s | 10 s |

## Adding spots

Another lane wanting a spot on a walk sends L23 the kind, position and line;
or, after this merges, appends to the authored list in `wayside_gen.gd` in
its own handoff with a note. Never hand-edit `data/wayside/*.tres`; rerun the
generator.

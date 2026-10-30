# Contract: shot requests (layout shots, full shots, numeric checks)

Owner: layout-shots lane (`tools/shots/`). Transport between cloud lanes and
the Mac GPU listener is in `docs/contracts/shots.md` (Mac shot lane); it
carries this request file unchanged.

## Why

Cloud containers render on the CPU (Mesa lavapipe), where every frame of a
full-quality 1080p world view costs tens of seconds. Most probe shots only
ask "is the stair where it should be?". So:

1. **Layout quality** (default): 640×360, no shadows, glow, fog, volumetric
   fog, SSAO/SSIL/SSR/SDFGI, AA, particles, reflection probes or GI; one draw.
2. **One run, many shots**: the level loads once; the render loop is off
   while it loads and settles, so warm-up frames cost nothing.
3. **Numbers, not pictures**: position/overlap/height questions go in
   `checks`. A request with no shots runs `--headless` (no renderer at all).

Full quality (`"quality": "full"`, the Mac lane calls it "look") stays for
final look checks.

**Routing: cloud lavapipe first for layout; Mac only for lighting or beauty.**
A layout request runs in the cloud in seconds (numbers below); send a
request to the Mac (`docs/contracts/shots.md`) only when the question is
about light, colour, glow or overall look.

Measured in a 4-core cloud container (Mesa 25.2 lavapipe, LP_NUM_THREADS=4,
terrain baked to disk), the five human-realm views of `tools/world_shot.gd`,
2026-10-30:

| run | wall |
|---|---|
| before: `world_shot.gd`, full 1080p, one process per shot (×5) | 384 s (58 s for one) |
| layout, 1 shot, Compatibility (the layout default) | 4 s |
| layout, 5 shots + 4 checks in one run, Compatibility | 13.4 s |
| layout, 5 shots + 4 checks in one run, Forward+ | 54.8 s |
| full (look) quality, 5 shots in one run, Forward+ | 337 s |
| checks only, no shots (headless) | 2.8 s |

## Running

```
tools/shots/take_shots.sh <request.json> [out_dir]
```

- `GODOT` = Godot binary (default `godot`); `SHOTS_GODOT_ARGS` is word-split
  and placed right after the binary (the Mac listener passes window args).
- Linux with no `DISPLAY`: wraps in `xvfb-run` and sets `LP_NUM_THREADS` to
  the core count if unset. macOS: never xvfb, never `--headless`.
- Renderer: `"renderer": "compatibility"` or `"forward_plus"` wins. Left out
  (`"auto"`), a layout request uses Compatibility and a request containing
  any `"quality": "full"` uses the project's Forward+.
- On lavapipe with Forward+, the runner (and `tools/world_shot.gd`) turns
  MSAA off and clamps Terrain3D to 2 clipmap LODs: lavapipe segfaults on
  either in the World, which is why cloud world shots used to fail. Terrain
  then ends ~200 m out; results say `terrain_clamped: true`. Compatibility
  and real GPUs are untouched.
- Default `out_dir` is `user://shots/<id>`.
- Exit 0 = every shot saved; 1 = bad request or scene; 2 = a shot failed.
  Failed checks are data in `results.json` (and `FAIL` lines), not a failed
  run.

Direct form: `godot --path . res://tools/shots/shot_runner.tscn -- <request.json> [out_dir]`.

## Request (`request.json`)

```json
{
  "id": "manor_stairs",
  "scene": "world",
  "quality": "layout",
  "size": [640, 360],
  "time_of_day": 0.5,
  "grade": "spring",
  "settle_draws": 1,
  "shots": [
    {"name": "stair_top", "eye": [-112, 1.7, 2152], "at": [-150, 1.2, 2161], "fov": 70},
    {"name": "hero", "eye": [-140, 2, 2180], "frame": "opening_dawn", "quality": "full"}
  ],
  "checks": [
    {"name": "stair_on_ground", "kind": "position", "node": "name:StairTop", "expect": {"above_ground": [-0.05, 0.05]}}
  ]
}
```

Top level (all optional except at least one shot or check):

| field | default | meaning |
|---|---|---|
| `id` | `"shots"` | names the run and the default out_dir |
| `scene` | `"world"` | `"world"` = the World scene plus streamed regions, or any `res://….tscn` (interiors, probes) |
| `quality` | `"layout"` | `"layout"` or `"full"`; default for every shot |
| `size` | 640×360 layout, 1920×1080 full | default image size |
| `renderer` | `"auto"` | `"compatibility"` or `"forward_plus"`; applied by the wrapper (see Running) |
| `time_of_day`, `grade` | 0.5, scene default | world only; per-shot override allowed |
| `settle_draws` | 1 layout, 30 full | layout: forced draws before capture; full: minimum real frames |
| `warmup_s` | 0 layout, 3 full | full only: seconds the real render loop runs before capture, so TAA, GI, particles and streaming settle |

Shot fields: `name` (file name, unique), `eye`, `at` (`[x, y, z]`), `fov`
(70), `ground` (true in the world: `y` is metres above the terrain at that
x/z), `frame` (id of a `shot_frame` marker; overrides eye/at once streamed;
world shots still need `eye` to know what to stream), and per-shot
`quality`, `size`, `settle_draws`, `warmup_s`, `time_of_day`, `grade`.
Full shots never lower any quality setting.

### Checks

Every check has `name`, `kind`, optional `near` (`[x, y, z]`: stream the
world there first) and optional `expect` (value name → `[min, max]`, or an
exact bool/number/string). `ok` is `true`/`false` with `expect`, otherwise
`null`; a missing node gives `ok: false` and `error`.

Node refs: `"group:<g>"` (first node in group), `"name:<Name>"` (first
descendant with that name), or a node path from the scene root (falls back
to a name search).

| kind | fields | values |
|---|---|---|
| `position` | `node` | `x y z rotation_y_deg`; world also `ground above_ground` |
| `aabb` | `node` | merged visual bounds: `min max size_x size_y size_z` |
| `overlap` | `a b margin?` | `overlaps volume gap` (gap = distance between boxes; `margin` shrinks `a`) |
| `height` | `at: [x, z]` | `terrain` (world), `hit surface collider` from a ray straight down |
| `ray` | `from to` | `hit x y z distance collider` |
| `count` | `group` or `type`/`pattern`, `center? radius?` | `count` |

## Ready signal

The runner waits two process frames after loading or streaming, then until
the group `shot_busy` is empty (max 600 frames, then warns and shoots). A
system that keeps building after `_ready` (async bakes, deferred scatter)
adds itself to `shot_busy` and leaves it when done. No rendering happens
while waiting.

## Output (`out_dir`)

- `<shot name>.png` per shot.
- `results.json`:

```json
{
  "id": "manor_stairs", "scene": "world", "renderer": "gl_compatibility",
  "device": "llvmpipe (LLVM 20.1.2, 256 bits)", "terrain_clamped": false, "threads": "4",
  "timings_ms": {"ready": 41000, "total": 52000},
  "shots": [{"name": "stair_top", "quality": "layout", "file": "…/stair_top.png", "size": [640, 360],
             "draw_calls": 812, "primitives": 1200000, "objects": 900, "ms": 2100}],
  "checks": [{"name": "stair_on_ground", "kind": "position", "ok": true,
              "values": {"x": 1.0, "y": 3.0, "z": 2.0, "rotation_y_deg": 0.0, "ground": 3.0, "above_ground": 0.0}}],
  "checks_failed": 0
}
```

A failed shot has `error` instead of `file`. Stdout has one `SHOT` line per
shot, one `FAIL` line per failed check and a closing `SHOTS` summary line.

## Using layout mode in an existing probe

One call before the capture, after the scene is in the tree:

```gdscript
ShotQuality.apply(ShotQuality.LAYOUT, get_tree().root, scene_root, ShotQuality.LAYOUT_SIZE)
```

and draw with `RenderingServer.force_draw()` instead of awaiting frames,
with `RenderingServer.render_loop_enabled = false` while loading.

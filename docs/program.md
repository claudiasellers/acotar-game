# Rendering and interactivity program (log)

Lead: L57, thread cmsg_01RUxTjNru2LBjPGqrQoMTopHR1HW7NEPydDmVPY6sxUzc. Brief: the owner's
program brief of 2026-11-03 (§0–§4, P1–P5, T1–T6). Tunables: `docs/tuning.md`.
Canonical shots: `tools/shots/canonical.txt`. Perf pass: `tools/perf/frame_pass.sh` (`make perf`).

Owner guidance (2026-11-03 19:55Z): good output, mindful of usage, no rabbit holes. So: one
GUT contract test per new system; acceptance = the brief's checks only; a check that will not
run headless becomes a Mac step instead of iteration; canonical shots re-rendered at task end only.

## Lanes

| task | lane | branch | state |
|---|---|---|---|
| P1–P5, T1, T6, playbook | L57 (lead) | lane/render-program | L57-1 merged; L57-4/5 (opening test, signal, probe args, log) queued |
| T2 surface model | L58 | lane/surface-model | done: L58-1, -2 merged; Mac late-light check passed |
| T5 touchable world | L59 | lane/touchable-world | done: through L59-7 (props, navmesh, weather, fire, burnable grass); Mac look check of rain/petals/flames/scorch pending |
| T3a bounce light | L60 | lane/bounce-light | done: L60-2 merged; Mac dark-scene check passed |
| T4 hero meshes | L61 | lane/hero-meshes | done: L61-1..5 merged |
| T3b grade unification | L63 | lane/grade-unify | L63-1 merged; L63-2 fa6cb71 (chroma restored via LUT saturation, sky roll-off) queued; Mac before/after shots/req-L63-before-1 / -after-1 pending |
| (outside the brief) forage chemistry | L62 | lane/forage-chemistry | started from the owner's 21:55Z ask; builds on L59 |

## Readings taken (the brief said: take the most reasonable reading and record it)

- The repo has **39** `*shot*.tscn` scenes (the audit's "67" counted shot scripts and probes). All ten
  canonical shots map to existing views (`tools/world_shot.gd` ids or shot scenes), so P5 added
  no new scene. `workshop` = the burnt Archeron estate region (`burnt_estate` view), where the
  father's workshop stands. Two perf-only views were added: `manor_garden`, `manor_interior`.
- `shaders/` does not exist; shared shaders live in `world/shared/shaders/`, so T2's candy_lit goes there.
- Godot's DirectionalLight3D offers 1, 2 or 4 PSSM splits. The brief's Mac profile "3 splits"
  does not exist; the Mac profile uses **2 splits** (2048 atlas, 160 m).
- Occluders are **generated at runtime from geometry the game already knows**, not baked in
  the editor: the manor's wall pieces and floor/ceiling slabs (one OccluderInstance3D per level,
  `ManorHouseBuilder`), and the village's solid building colliders shrunk inside the drawn hull
  (`ColliderOccluders`). Nothing is committed or baked (R15), so the `occluders` make target T6
  asks for is unnecessary; T6 records that instead of adding an empty target.
  The cottage region has no building colliders (only ≤1.5 m drystone walls) and the cottage is
  one small house: no occluder there; it is not a draw-call hotspot.
- R14 (project.godot, autoloads belong to the story/core lane): the owner's brief asks for the
  occlusion project setting and the T2 importer default directly, so the lead makes those
  two one-line edits and notes them here.
- The Makefile no longer runs `git lfs pull` (already fixed on main); T6 has nothing to remove.
- Free climb and glide: GAME_DESIGN_PLAN.md calls for *marked* climbing (ivy, roots, ledges) and
  no gliding → **skipped by design** (T5 step 5).
- `generate_lods` is already true in all 1,375 glb/gltf `.import` files → T1 step 4 needs no
  change and has no triangle delta.
- Shadow profile is a GameSettings property (`shadow_profile`, `--shadow-profile=` user arg),
  not a saved pause-menu setting: adding it to the menu is UI work, a follow-up.

## P1 — cloud render capability

Cloud renders work: Mesa lavapipe (Vulkan, software) under xvfb, Forward+ and Compatibility.
The container lacked the ICD; `apt-get install mesa-vulkan-drivers` adds it (`lvp_icd.json`).
Pixel checks of *layout* run in the cloud; *look* checks (light, colour, bloom) and real frame
times go to the Mac GPU service (docs/SHOTS.md). Frame times in a cloud CSV are not budget numbers;
draw calls, primitives, objects and material counts are exact.

## P2 — terrain bake cache

`tools/mq/levels.sh` now restores from and publishes to a shared cache
(`/mnt/project-files/cache/levelcache/<name>/<fingerprint>.tar`, override with
`MQ_LEVELCACHE_SHARED`, empty = off; the Mac has no such folder, so nothing changes there).
`make setup` also runs `levels.sh ensure --cached-only`. Measured in a fresh worktree with an empty
local cache: terrain (80 MB) restored in **0.8 s**; a fresh lane's import is ~100 s, so a lane
boots a level in **under 2 minutes** instead of ~16.

## T1 — baseline and free performance

Shipped (L57-1 merged, L57-4 queued): occlusion culling with runtime occluders (manor: one OccluderInstance3D per level,
207/477/448/292/66 boxes for L-1..L3; village: 27 solid houses), 0 of 804 window/doorway points covered; shadow
profiles (mac on Apple silicon); `make perf`; LODs were already on (no change).

**Baseline counts, main d9e6d95 (cloud lavapipe, Forward+, 1920×1080; counts exact, ms not budget numbers):**

| shot | draw calls | primitives | objects |
|---|---|---|---|
| manor_front | 864 | 1,787,097 | 940 |
| hunting_forest | 786 | 1,009,250 | 827 |
| village | 327 | 616,152 | 356 |
| workshop | 334 | 620,749 | 374 |
| feyre_closeup | 736 | 4,796,677 | 839 |
| rose_garden | 453 | 1,293,972 | 537 |
| spring_vista | 501 | 4,511,052 | 595 |
| cottage, wolf_closeup | lavapipe crash (Mac only) | | |
| opening_film | film renders with forced draws: probe sees no frames (Mac only) | | |

Real frame times: Mac shot requests `shots/req-L57-3` (pre-program d9e6d95), `req-L57-4` (adb54f80, before L61's
denser crowns) and `req-L57-2` (main after L57/L58/L59/L60/L61) for manor_front, hunting_forest, manor_garden and
rose_garden, each through tools/perf/frame_probe.tscn (the PERF line in each label's log).

## Mac steps pending

1. `make perf` on the Mac at main after L57-1 merges: the real frame-time baseline (cloud ms are lavapipe).
2. cottage (`cottage_snow`) crashes lavapipe in Forward+ on both trees: its counts come from the Mac pass.
3. L58-1 look request `shots/req-L58-1`: the lead's same-prop check across manor / village / forest.
4. L59: look check of rain, petals and flames; frame time of the paced nav parse when the manor streams in.
5. L60 (T3a) frame cost: `make perf` at L60 vs the T1 baseline (budget: outdoors ≤ +2 ms, interiors ≤ baseline). The Mac
   profile has SSIL off, so also run `BOUNCE_SSIL=1 make perf` (what SSIL costs if the Mac gets it) and
   `BOUNCE_SDFGI=1 make perf` (SDFGI outdoors with volumetric fog on, T3a step 3). Record the ms here; SDFGI
   becomes a high-profile option only if it fits.
6. L60 look + corner probes: the canonical shots at L60, plus `entrance_hall` and the cottage main room
   (cottage crashes lavapipe), with two samples per room (corner vs wall centre, corner ≥5% darker), and
   `tools/lighting/bounce_probe.tscn` on the GPU (prints the PROBE numbers in the T3a section below).
7. L63 (T3b) look + clip + perf: the canonical shots at L63 against L60 (lit band, 5 samples each, within 5%; sky,
   water and window pixels < 0.98 per channel), `GRADE_PROBE=check` of `tools/env/grade_probe.tscn` on the GPU,
   and `make perf` (±0.3 ms; the only per-frame cost added is the colour LUT lookup, and the LUT itself
   builds a slice a frame during a grade blend).

## T2 (L58-1) as handed in

candy_lit.gdshaderinc is the one light(); candy_rim.gdshaderinc holds the shared rim. CandyMaterial +
MaterialLibrary replace all StandardMaterial3D outside tools/tests (76 scripts, 3 scenes); tools/import/candy_import.gd
is the importer default and in all 1,378 .import files. Checks reported: 0 StandardMaterial3D by rg; 0 stock
surfaces in all 1,378 imports; layout pixel delta 0.09–1.12% (< 8%); draw calls identical. Deviation: one line of
docs/contracts/world.md (glb import_script) changed, flagged to the director under R13. bogge_form and fur_card use
Godot's built-in RIM and stay untouched (horror values kept). Frame ms: Mac step.

## T5 (L59) as handed in

Props: 7 PropData kinds, 37 props in village + manor grounds, pooled (1 MultiMesh draw per kind + ≤16 live bodies),
manor chunk guard untouched; touch_test push 4.84 m, throw 8.81 m. Navmesh: NavBaker bakes a 192 m tile round Feyre
(parse on the main thread, bake async), manor levels inside the same tile so stairs join (deviation from "one region
per level", which would cut every flight); NavMover on wolves, BeastActor, CourtNpc, straight steering as fallback;
wolf hall→east corridor 35.7 m walked vs 35.1 straight; act1 playtest to wolf_kill passes. Weather: rain streaks,
`ground_wetness` global, petal gusts, mist via GradeDirector.set_weather_fog (0 default, ≤0.04), all held off while a
story scene runs. Chemistry: ElementField fire/water/wind, 3 rules, 2 m hash, 10 Hz, F8 overlay; fire spreads in 1.1 s,
wet grass won't light. Free climb/glide: skipped by design.

## T3a (L60) as handed in

Outdoors: ambient from the sky at 0.7 (world.tscn + GradePreset default, 19 outdoor grades; `manor_interior` keeps
1.0), reflections from the sky, SSAO radius 1.0 / intensity 1.2 at half size, SSIL low and half size on the `high`
profile only (BounceLight, world/shared/world/bounce_light.gd, follows GameSettings.shadow_profile_changed).
candy_lit `ground_bounce` 0.35, colour = terrain albedo mean (0.523, 0.548, 0.545). It applies to directional
lights only and is scaled by sun height and by how far the face looks down. The surface's own shadow does not
block it, and the lit band does not take it. The manor's room shells opt out (SDFGI lights them).

Probe (`tools/lighting/bounce_probe.tscn`, lavapipe, main vs L60 on one set under the spring grade):
shaded cliff +6.2% luma with hue toward the ground light +0.015; underside of a canopy +9.1%, toward the ground
light +0.028; shaded upward face toward the sky +0.006; inside corner 11.4% darker than its wall centre (SSAO)
and warmer (SSIL bleed); sunlit top face +0.23% (lit band unchanged).
Canonical shots: a full lavapipe world shot takes ~12 min here, and the before/after run was lost to a container
restart, so the lit-band check on the canonical shots (5 samples each, delta < 5%) moves to the Mac with the
look pass (Mac step 6). By construction only the ambient share (0.6→0.7) and the SSAO values reach lit pixels.

Readings:
- **No LightmapGI (T3a step 2).** Godot's forward renderer drops sky ambient on every lightmapped surface ("lightmap
  overrides everything") and gives dynamic objects inside the lightmap bounds probe light instead. The cottage
  and the father's shed are each one glb with inside and outside faces in the same mesh, so a bake would freeze
  their outer walls at bake-time light through day, night and every grade, and Feyre walking past would lose
  the live sky. The manor is built at runtime by ManorHouseBuilder, so there are no static meshes to unwrap or
  bake. LightmapGI also has no scripting bake API, only the editor plugin's `_bake`. Doing it right needs inner
  and outer shell meshes split in the Blender scripts (a mesh change, T4 or the art lane) and the manor build
  cached into a generated scene (manor lane). Until then interiors get SSAO everywhere, SSIL on `high`, and
  SDFGI in the manor as before. No UV2 import change, no `make lightmaps` target, nothing to git-ignore.
- **SDFGI outdoors (step 3)** is not enabled. It waits for the Mac measurement (Mac step 5).
- "Hue shift toward the ground colour" is measured toward the light leaving the ground (terrain albedo × sun
  colour). The albedo mean alone is near-neutral (snow and ice), and the warm sun dominates the bounce.

## T3b (L63) as handed in

AgX everywhere: all 20 grades (GradePreset default; `manor_interior` was already AgX, so the house → grounds
tonemapper jump is gone), the mural and wolf-eye film stages and the title (exposure 1.8 / 1.8 / 1.7 holds
Filmic's mid band, rms 3.7%). One grade layer: each preset's brightness/contrast/saturation sliders and old 1D
LUT are folded into LutParams (`data/grades/luts/`), a 32³ RGBA-half Texture3D built at load (60–130 ms in one
go; GradeDirector builds a swap target one slice a frame). Steps 2–4 of the LUT (lift/gamma/gain, hue, saturation
curve) ship as identity. LUT vs its numbers: max channel error 0.0004 on affine grades, ≤0.0101 where a channel
clamps inside a cell. Blends: the shown slider value is (blended grade value) ÷ (shown LUT's folded value), so
nothing pops when the LUT switches at mid-blend; moods keep the grade's LUT.

Probe (`tools/env/grade_probe.tscn`, lavapipe, deterministic: no fog reprojection; T3a reference retaken from a
clean worktree at 9efa62e, `tools/env/grade_reference_t3a.json`):
- Lit band (5 sunlit samples per grade): all 19 solved grades within ±1% of T3a; `dread` kept at 0.19 on purpose
  (its lit band is near black, 1.1% → 2.7% display, and 0.19 keeps the manor ambient floor readable under dread).
- Estate boundary, same prop under `manor` vs `spring`: 3.2% (T3a 2.9%; both sides were and are one tonemapper).
- Clip: the probe's sky samples look toward the sun (worst case). Under ACES at T3a these were 1.0 (255) on 9
  of 20 grades and lit tops clipped too (blush top v = 1.000). L63-1 under AgX left the toward-sun sky ≥ 0.98 on 8
  day grades. L63-2 adds a white roll-off to the LUT (above 0.8 each channel bends, slope-matched, to
  `white_level` 0.97) on the 11 bright day/dusk grades: every grade's sky now ≤ 0.97 and no pixel ≥ 0.98 but one lit white top on `manor` (0.988; no roll-off there); no white
  pixels. Raising the sun was tested and rejected (3× sun to get there). AgX's own white point
  (`tonemap_agx_white` 32 or 100) changed nothing in SDR output. The roll-off and the colour cost the 8 brightest
  grades 2.6–4.4% of lit band (blossom_vale −3.7, glen_day −4.1, pool_sparkle −4.0, human_spring −4.4, rosewild
  −3.1, spring −3.2, fells −2.6, solstice −0.1), inside the 5% tolerance; the others stay within 1%.
- Estate boundary after L63-2: 0.7%.
- Colour (L63-1): AgX took 25–50% of the lit band's chroma out at an equal lit band. L63-2 (director's recommended
  option, lead's acceptance: within 5% of T3a) gives it back with the LUT saturation curve: shadows ≤1.35,
  highlights solved per grade (1.27–1.80). Every grade but `dread` (near black) is now within 5% of its T3a chroma
  (worst human_spring +4.4%). The owner's decision on keep / restore / ACES is open; keep = set the curve to 1 / 1.

Readings:
- "AgX white 1.0" = `tonemap_white` 1.0 (Godot's default, unused by AgX). `tonemap_agx_white` stays at Godot's
  16.29: at 1.0 AgX would hard-clip every highlight, the opposite of done-when 2.
- No `make luts` output to ignore: the Texture3D is built at load. `make luts` runs the parameter generator and
  check (exit 1 if a LUT misses its numbers).
- Satchel keeps Linear: its cloth, wash and patches take SatchelTheme colours that must match the 2D page over
  them; AgX at its best exposure shifts greys up to 6% and pulls chroma.
- The 12 court grades also live as sources in `world/spring_court/wider/fx/grades/` (build_court_fx.gd's
  output, still 1D LUT + sliders). The game loads `world/shared/grades/`; re-copying the fx files over them
  would undo T3b. Follow-up for the court-fx owner: emit LutParams, or stop copying.
- Spring bloom 0.7 / 0.2 / 1.0 (R3) overrides the court grades' earlier "no daytime bloom wash" rule
  (Keeper's book-light note, still asserted by test_court_fx on the fx copies). Flagged to the director.
- Still ACES/Filmic, not shipping: `world.tscn` `tonemap_mode = 3` (GradeDirector sets AgX in `_ready`, before
  the first frame; world lane's file), and tool views: faces_shot, creature_faces_shot, indoor_camera_shot,
  art_probe, minor_fae_hall_shot, cottage_room_shot, feyre_gait_shot, render_item_icons (icon art, a non-game
  look), bounce_probe (L60's probe, ACES vs its own reference), calanmai_fire_shot. The views that mimic the
  game should follow AgX in a housekeeping pass.

## T4 (L61) as handed in

woods_trees: one Skin graph per near tree (Skin → Subsurf 2 → Decimate to the R4 cap), smooth-ellipsoid crowns, crown
winding fixed; manor_flora cherry/apple/crab-apple blobs 20 → 320 faces; rose petals 8 → 18 tris cupped. Opening film:
the 26 cylinders + box bough replaced by winter_bare / winter_bough models. All 80/80 creature gltfs have a Skeleton3D
(tools/blender/creatures_rig_graph.py for the 21 that had none). Placeholder body/figure/capsule fallbacks push_error and
assert in debug; act1 chain and the cast tests log 0 stand-ins. Budget: manor_front 963 → 973 draw calls, 1.814 → 1.860 M
prims (+2.5%). Mac: opening film mean 17.05 ms (over the 16.6 ms M1 line by 0.45 ms; logged, not acted on).
Probe table, style notes: plans/render-program/T4-hero-meshes.md.

## T1 results on the Mac (Claudias-Mini, Forward+ look, 1920×1080)

Draw calls / primitives (exact). pre = d9e6d95 (before the program); mid = adb54f80 (L57-1 + L58 + L59, before L61's
crowns); now = main bde2d78 (+ L60, L61).

| shot | pre draw | mid draw | now draw | Δ pre→now | pre prims | now prims | Δ |
|---|---|---|---|---|---|---|---|
| manor_garden | 1,137 | 703 | 703 | **−38%** | 2.69 M | 1.69 M | −37% |
| manor_front | 884 | 727 | 726 | −18% | 1.92 M | 1.47 M | −23% |
| hunting_forest | 818 | 555 | 555 | −32% | 1.19 M | 0.76 M | −36% |
| rose_garden | 473 | 358 | 358 | −24% | 1.43 M | 0.94 M | −34% |

T1 acceptance "manor garden draw calls down ≥30%": **met (−38%)**. The cut comes from occlusion (manor) and the Mac
shadow profile (2 splits instead of 4 halves the shadow passes; hunting_forest has no occluders and still drops 32%).
L61's denser crowns cost +0.3% prims (mid→now), well under the director's 10% line.
Frame time: the first Mac pass ran vsync-capped (every median ≈16.6 ms), so it says only that rose_garden is **over
budget** and the others hold 60 fps. 

Uncapped frame time (median ms, shots/req-L57-6 pre vs req-L57-5 now, same Mac):

| shot | pre | now | Δ | headroom vs 16.6 ms |
|---|---|---|---|---|
| manor_front | 13.85 | 11.70 | −2.15 | +4.9 |
| manor_garden | 16.59 | 14.85 | −1.74 | +1.8 |
| hunting_forest | 15.63 | 14.37 | −1.26 | +2.2 |
| rose_garden | 25.23 | 23.99 | −1.24 | **−7.4 (over)** |

The program made every view faster even after adding bounce, SSAO changes and denser crowns. rose_garden was already
over budget before the program and still is: a perf task for the director's backlog (likely the 12-hue rose scatter's
overdraw / shadow casters), not part of this brief. The p95 of 27–37 ms in every view is first-frames shader
compilation inside the 30-frame window, not steady state.

## T6 — housekeeping (lead)

- `git lfs pull` was already gone from the Makefile; nothing to remove.
- `make perf` and the shared terrain restore in `make setup` shipped in L57-1. `make luts` comes with T3b (L63).
  `make lightmaps` is not added (T3a skipped LightmapGI by design) and `make occluders` is not added (occluders are
  built at runtime from the manor and village geometry; there is nothing to bake).
- status.md got a "Render budgets" block with the Mac numbers; drift-log has the T6 entry.
- tools/perf/frame_probe.gd takes its settings as user args (the Mac shot listener can't set env) and runs uncapped,
  so a shot request can measure frame time:
  `shot perf_<name> res://tools/perf/frame_probe.tscn <scene args> --perf-scene=res://… --perf-name=<name> --perf-csv={out}/perf.csv`.

---

# Owner playbook: ten numbers that move the look

Everything below is neutral today (it reproduces the pre-program look). Tune one at a time against ART.md and
`references/`, then re-render the canonical shots in one Mac look request (the `shot` lines in
`tools/shots/canonical.txt`, sent with `tools/mq/shots_request.sh`). Full table with ranges: `docs/tuning.md`.

| # | tunable | where | now | try | judge on |
|---|---|---|---|---|---|
| 1 | `diffuse_ramp` (the 3-band cel look) | candy_lit.gdshaderinc; preset `data/render/candy_ramp_3band.tres` | identity (smooth lambert) | assign the 3-band preset, then move its stops | feyre_closeup, manor_front, village |
| 2 | `shade_tint` (colour of shadows) | candy_lit.gdshaderinc per family | white on props, lilac on foliage | a blush or periwinkle on props too | rose_garden, manor_front |
| 3 | `wrap` (how soft the terminator is) | candy_lit.gdshaderinc per family | 0 props, 0.4–0.55 foliage | 0.2–0.4 on props for rounder forms | feyre_closeup, workshop |
| 4 | `rim_strength` + `rim_color` (warm edge light) | candy_lit.gdshaderinc | 0 props, 0.4–0.6 foliage | 0.1–0.25 on props/gowns; never strong everywhere | feyre_closeup, rose_garden (late light) |
| 5 | `GradePreset.exposure` (+ `white_level` roll-off on the 11 bright grades) | world/shared/grades/*.tres | re-solved under AgX to hold the T3a lit band (±1%; the 8 brightest 2.6–4.4% under to keep the sky ≤0.97) | ±0.1 steps; raise white_level if you'd rather have brighter grades and some sky clip | spring_vista, manor_front, cottage |
| 6 | LUT parameters: lift/gamma/gain, hue, saturation curve, `highlight_saturation` | data/grades/luts/*.tres (LutParams, one per grade; `make luts` checks them) | identity look; saturation solved per grade (1.27–1.80 highlights) to keep T3a's pastel chroma under AgX | warm-pink lift; more or less highlight_saturation decides how candy vs soft the pastels read | every canonical shot; this is the big one |
| 7 | Spring glow / bloom / HDR threshold | Spring GradePresets | ~0.7 / ~0.2 / ~1.0 (R3 spec, T3b) | bloom 0.15–0.3 | spring_vista, rose_garden, manor_front |
| 8 | `ambient_light_sky_contribution` + `ambient_color` | world.tscn + GradePresets | 0.7 | 0.6–0.8; ambient colour toward lilac | hunting_forest, workshop (shade read) |
| 9 | `ground_bounce` + colour | candy_lit.gdshaderinc | 0.35, terrain mean grey-green | 0.2–0.5; tint toward blossom pink in Spring | rose_garden, spring_vista (undersides) |
| 10 | `pearl` / `glitter` on gowns, fountains, magic | candy_surface.gdshaderinc (per material) | 0 | 0.2–0.5 on gowns and glass; keep off horror | feyre_closeup, manor_front |

Guardrails already enforced by tests: albedo ≤ 0.85 per channel (D9), rim is lit (never emissive), no daytime
emissives, horror grades and materials keep their darkness.
Known open items for the owner: rose_garden is over the 16.6 ms line on the Mac (vsync median ~26 ms; see T1);
the wolf-eye pupil shape in the opening film is in the director's owner-decisions list.

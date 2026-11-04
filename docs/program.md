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
| P1–P5, T1 | L57 (lead) | lane/render-program | in progress |
| T2 surface model | L58 | lane/surface-model | L58-1 413510d handed in 20:48Z; Mac look request shots/req-L58-1 pending |
| T5 touchable world | L59 | lane/touchable-world | props merged (8c2ea45); L59-4 e472d51 (navmesh + weather/fire + scene yield) queued; Mac look check of rain/petals/flames left |
| T3a bounce, T3b grade, T4 hero meshes, T6 housekeeping | — | — | after L58 |
| T3b grade unification | L63 | lane/grade-unify | L63-1 e920bfa queued; L63-2 (chroma + white roll-off) handed in |

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

(numbers below)

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

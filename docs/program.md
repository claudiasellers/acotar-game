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

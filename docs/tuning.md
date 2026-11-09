# Tuning table

One row per look tunable. Defaults are neutral (today's look); taste changes are
made here by the art direction, not by lanes. Schema: **Tunable** (uniform or
property), **Where** (file that declares it), **Default**, **Range**, **What it
does**, **Lane** (who added it).

## candy_lit surface model (render program T2, L58)

Lighting uniforms live in `world/shared/shaders/candy_lit.gdshaderinc` and are on
every candy_lit surface: CandyMaterial/MaterialLibrary materials, imported glbs,
prop_finish, court_prop, manor_item, the manor house/facade shaders and the
foliage family. Per-family defaults come from `#define CANDY_*_DEFAULT` lines in
each shader, chosen to reproduce the look each one had before T2.

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `diffuse_ramp` | candy_lit.gdshaderinc | unset (identity = lambert) | GradientTexture1D | Diffuse band ramp sampled by wrapped N·L (red channel). `data/render/candy_ramp_3band.tres` is a 3-band soft-edged preset; identity until assigned. | L58 |
| `wrap` | candy_lit.gdshaderinc | 0.0 surfaces; 0.5 stylized/court foliage; 0.55 woods; 0.4 court props | 0–1 | Wraps light past the terminator: softer, rounder shading. | L58 |
| `shade_tint` | candy_lit.gdshaderinc | white surfaces; lilac (0.62,0.55,0.78) foliage; (0.66,0.56,0.82) woods; (0.66,0.58,0.80) court props | colour | Colour the shade band leans to (white = neutral grey shading). | L58 |
| `light_albedo_mix` | candy_lit.gdshaderinc | 0.0 surfaces; 1.0 foliage + court props | 0–1 | Extra albedo factor inside the light term (the foliage family's richer, deeper colour). | L58 |
| `diffuse_gain` | candy_lit.gdshaderinc | 1.0 surfaces; 2.0 foliage + court props | 0–4 | Direct diffuse multiplier. | L58 |
| `diffuse_burley` | candy_lit.gdshaderinc | 1.0 surfaces; 0.0 foliage + court props | 0–1 | Burley (Disney) retro-reflection vs plain lambert. | L58 |
| `ground_bounce`, `ground_bounce_color` | candy_lit.gdshaderinc | see Bounce light below | | | L58 hook, L60 values |
| `backlight_strength` | candy_lit.gdshaderinc | 0.0; 0.8 court foliage | 0–4 | Petals glowing when the sun is behind them. | L58 |
| `rim_color` | candy_lit.gdshaderinc | (1.0, 0.86, 0.74) median of the old rims; foliage/court props keep theirs | colour | Colour of the candy rim. The rim is **lit**: added per light, scaled by the light's colour and shadow, never an additive glow (director rule, L58-2). | L58 |
| `rim_strength` | candy_lit.gdshaderinc | 0.0 surfaces; 0.6 stylized/court foliage; 0.55 woods; 0.4 court props (their pre-T2 values, now lit) | 0–2 | Rim brightness; scaled by `magic_amount` (0.25× under dread) and, on court/woods foliage, by blight/drain. | L58 |
| `rim_power` | candy_lit.gdshaderinc | 3.0 | 0.5–8 | Rim falloff (`candy_fresnel`, the one fresnel curve; skin, fur, bark, water and FX call it too). | L58 |
| `specular` | candy_lit.gdshaderinc | 0.5 | 0–1 | Dielectric reflectance (StandardMaterial3D `metallic_specular`). | L58 |
| `albedo_cap` | candy_surface.gdshaderinc (`CandyMaterial.MAX_ALBEDO`) | 0.85 (hex D9) | 0–1 | Glare rule (L18-4): the most a lit candy surface reflects per channel, applied after texture and vertex colour. Unshaded FX are exempt. | L58 |
| `pearl` | candy_surface.gdshaderinc | 0.0 | 0–1 | Pearlescent sheen at grazing angles (CandyMaterial surfaces). | L58 |
| `glitter` | candy_surface.gdshaderinc | 0.0 | 0–1 | Twinkling glitter cells; scaled by `magic_amount`. | L58 |
| `glitter_scale` | candy_surface.gdshaderinc | 18.0 | >0 | Glitter cells per metre. | L58 |
| `glitter_color` | candy_surface.gdshaderinc | (1.0, 0.93, 0.75) | colour | Glitter colour. | L58 |

Not tunables but switches (compile-time, per shader): `CANDY_SOFT_SPEC` (court
props' soft power-law gloss instead of GGX), `CANDY_NO_SPEC_LOBE` (foliage: no
direct highlight), `CANDY_LOBES`/`CANDY_COAT` (per-pixel light rim and clearcoat).

## Shadows (render program T1, L57)

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `GameSettings.shadow_profile` | systems/settings/game_settings.gd:SHADOW_PROFILES (`--shadow-profile=` user arg) | auto (mac on Apple silicon: 2048 atlas / 2 splits / 160 m; high: 4096 / 4 splits / 220 m) | high, mac | Sun shadow crispness and reach on world-scale suns (shadow distance ≥150 m) | L57 |
| `manor_interior` fog/volumetric density, glow, ambient_color, saturation | world/shared/grades/manor_interior.tres | fog 0, volumetric 0, glow 0.3 / bloom 0 / threshold 1.4, ambient (0.92, 0.90, 0.88), saturation 1.05 | volumetric 0..0.008 | Clear indoor air; raise volumetric_density for haze | T075 |

## Bounce light (render program T3a, L60)

Outdoor ambient is the sky's (upward faces take the sky tint, downward faces the
sky's ground half), plus candy_lit's ground bounce: the sunlit ground's light
thrown back up into the shade band. Probe: `tools/lighting/bounce_probe.tscn`.

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `ambient_light_source` | world/shared/world/world.tscn | SKY (3) (unchanged) | | Ambient from the sky's radiance, not a flat colour | L60 |
| `reflected_light_source` | world.tscn | SKY (2) (unchanged) | | Reflections from the sky | L60 |
| `ambient_light_sky_contribution` | world.tscn; GradePreset default (every grade but `manor_interior`) | 0.7 (was 0.6) | 0–1 | Sky share of the ambient; the rest is the grade's `ambient_color`. `manor_interior` keeps 1.0 (T043, the owner's look) | L60 |
| `ssao_radius` / `ssao_intensity` | world.tscn, BounceLight.SSAO_RADIUS / SSAO_INTENSITY | 1.0 / 1.2 (were 1.5 / 1.5) | 0.01–16 / 0–16 | Contact shadow in corners and under things; ambient only | L60 |
| SSAO quality | BounceLight.apply (RenderingServer) | medium, half size (Godot's defaults) | | Global to the renderer | L60 |
| `ssil_enabled` | BounceLight.SSIL_PROFILES | on for `high`, off for `mac` (GameSettings.shadow_profile_name()) | | Screen-space colour bleed; `BOUNCE_SSIL=0/1` forces it for a perf pass | L60 |
| SSIL quality / `ssil_radius` / `ssil_intensity` | BounceLight | low, half size / 5.0 / 1.0 (Godot's defaults but quality) | | Cost and reach of the bleed | L60 |
| SDFGI outdoors | GradePreset.sdfgi (off outdoors) | off | | Not enabled: waits for the Mac measurement with volumetric fog (`BOUNCE_SDFGI=1 make perf`) | L60 |
| `ground_bounce` | candy_lit.gdshaderinc (`CANDY_BOUNCE_DEFAULT`) | 0.35; 0.0 on the manor's room shells (boiserie, plaster_ceiling, sky_ceiling: SDFGI lights the rooms) | 0–1 | Bounce strength. Directional lights only, scaled by the light's height over the horizon and by how much the face looks down (1 down, 0.5 sideways, 0 up); the surface's own shadow does not block it; the lit band does not take it | L60 |
| `ground_bounce_color` | candy_lit.gdshaderinc | (0.523, 0.548, 0.545) sRGB | colour | Mean albedo of the 11 terrain textures, equal weights, averaged in linear light (`tools/lighting/terrain_albedo_average.gd`). Per texture: snow (0.79,0.83,0.91), frozen_earth (0.42,0.39,0.37), rock (0.48,0.50,0.56), winter_grass (0.62,0.59,0.45), spring_grass (0.27,0.36,0.21), moss (0.22,0.43,0.30), forest_floor (0.40,0.31,0.24), path (0.50,0.40,0.31), riverbed (0.50,0.52,0.52), blight (0.46,0.44,0.48), ice (0.72,0.86,0.92). Snow and ice make it near-neutral; a greener Spring bounce is an art-direction call | L60 |

## Wider-court terrain (lane wider-court-world)

Shape values for the court's land, all in `world/spring_court/wider/court_height.gd`.
Tests (`tests/unit/landscape/test_court_terrain.gd`) hold the seals, sightlines and
the book's shapes; anything else here is taste.

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `ZONES[*][3..5]` roll / hummock / root-ridge amplitude | court_height.gd | woods 3.5/1.4/1.8, glen 12/2.6/0.3, village 9/1.1/0.3, autumn 24/4.5/7, rosewild 5.5/3.6/0, meadow 6/1.4/0, hill 11/2.2/0.4, blight 17/3.2/1, vale 5.5/1.6/0 (m) | 0–30 | How much each region rolls: large swells (380 m), hummocks (46 m), root ridges and dark dips (woods). | wider-court-world |
| `ZONE_SOFT` | court_height.gd | 150 m | 80–300 | Width of the blend between regions' characters. | wider-court-world |
| `KNOLL_FIELDS` | court_height.gd | 9 fields, 10–30 knolls each | | The single-tree knolls; count, radius, height, share of hollows. | wider-court-world |
| `HILLS` heights | court_height.gd | towering hill 138, Rite crown 104, Ember Crown 110, plateau hill 34 (m) | | The weenies' stages; sightline tests hold them. | wider-court-world |
| `LAKES[*][4]` depth | court_height.gd | 5–28 m | | How bottomless each clear lake reads (shelf, then drop-off). | wider-court-world |
| `PATH_GRADE` | court_height.gd | 0.28 | 0.15–0.4 | Steepest a path runs; steeper ground sinks it into a hollow-way. | wider-court-world |
| `BLEND` | court_height.gd | 140 m | 60–200 | How gently our ground meets other lanes' at their edges. | wider-court-world |
| Ground look | tools/court/ground_texture_packer.gd `LOOKS_ALT`, packed into world/shared/terrain/textures | `storybook_deep` (owner's pick, 2026-11-09) | photo, soft, pastel, storybook, storybook_deep, storybook_deeper | The 7 CC0 photo slots recoloured into the court's palette in soft painted bands; "deep" lowers value and adds colour so the near ground stays rich under the haze. Repack with `pack_ground_textures.gd -- <src> --look <L>`; preview with court_terrain_shots `looks=`. | wider-court-world |
| Depth haze, estate | world/shared/grades/spring.tres | fog (0.70,0.74,0.96), density 0.00078, aerial 0.1, sky affect 0.1, volumetric albedo (0.85,0.86,1.0) | aerial ≤0.2; density ≤0.00078 (≤20% fog at the 285 m weenie) | A cool haze darker than the pink horizon: green foreground, teal midground, periwinkle hills that stand out from the sky. test_grade_director holds it. | wider-court-world |
| `DRAW_GRASS_CLUMPS` | world/spring_court/wider/court_region.gd | false (owner, 2026-11-09) | bool | The pale mint grass clumps are scattered but hidden: they didn't read as grass on the storybook ground. They still count as fire fuel. | wider-court-world |
| Depth haze, court by day | world/spring_court/wider/fx/tools/build_court_fx.gd `DEPTH_*` | haze (0.70,0.74,0.96), tint 0.25, density 0.0011, aerial 0.1, sky affect 0.1 | tint 0–0.5 | The same layering in each daytime region grade, keeping a quarter of the region's own fog hue. Dusk, night and the blight keep their own fog. | wider-court-world |

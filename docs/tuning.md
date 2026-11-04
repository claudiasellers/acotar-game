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

## Colour grade (render program T3b, L63)

One tonemapper and one grade layer everywhere. The World's grades are AgX; every
preset's look is a 32³ colour LUT built at load from `data/grades/luts/<id>.tres`
(LutParams, `world/shared/grades/lut_params.gd`), applied after the tonemapper.
`make luts` (tools/env/make_lut.gd) folds anything new on a preset into its
parameters, checks each LUT against its numbers and prints the table below.
`tools/env/grade_probe.tscn` measures the lit band, sky and estate boundary per
preset (`GRADE_PROBE=check|solve|ref`).

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `tonemap_mode` | GradePreset default (every preset); mural_stage, wolf_eye_stage, title_backdrop | AgX (4) | | One tonemapper: no curve change at the estate, house or film cuts. `satchel_table` keeps Linear (its 3D page must match SatchelTheme's 2D colours) | L63 |
| `tonemap_agx_white` / `tonemap_agx_contrast` | Environment (Godot defaults, not set) | 16.29 / 1.25 | ≥2 / 1–2 | AgX's white point and curve. "AgX white 1.0" read as `tonemap_white` (1.0, unused by AgX): an AgX white of 1 would clip every highlight | L63 |
| `exposure` (film/title) | mural_stage 1.8, wolf_eye_stage 1.8, title_backdrop 1.7 | was Filmic at 1.0 / 1.0 / 0.95 | | Holds Filmic's mid band (display 0.3–0.85, rms 3.7%) under AgX | L63 |
| `LutParams.brightness` / `contrast` / `saturation` | data/grades/luts/<id>.tres | the preset's old adjustment sliders (table) | 0–2 | Folded: Godot 4.7's maths (brightness on linear light, contrast and saturation on sRGB). The preset's own sliders are now 1.0 and only moods, true sight and blends move them | L63 |
| `LutParams.curve` | data/grades/luts/<id>.tres | the old 1D GradientTexture (court grades) | Gradient | Per-channel tone curve, unchanged | L63 |
| `LutParams.lift` / `gamma` / `gain` | data/grades/luts/<id>.tres | (0,0,0) / (1,1,1) / (1,1,1) | colour | Shadows / mid-tones / highlights per channel | L63 |
| `LutParams.hue_shift` | data/grades/luts/<id>.tres | 0 | ±180° | Rotates hue about the grey axis | L63 |
| `LutParams.shadow_saturation` / `highlight_saturation` | data/grades/luts/<id>.tres | per grade (table): shadows ≤1.35, highlights 1.27–1.80; 1 / 1 on `dread` and `manor_interior` | 0–2 | Saturation curve by luma. AgX pulls 25–50% of the chroma out of lit pastels at equal brightness; these give it back (L63-2, director + lead): the lit band's chroma (max − min channel, 5 samples) within 5% of T3a on every grade but `dread` (near black). Set to 1 / 1 for AgX's own softer colour | L63 |
| `LutParams.white_level` | data/grades/luts/<id>.tres | 0.97 on the 11 bright day/dusk grades (table), 1 elsewhere | 0.9–1 | White roll-off: above 0.8 each channel bends (slope-matched) down to this, so toward-sun sky stops at 0.97 instead of paper white | L63 |
| Spring bloom (`glow_intensity` / `glow_bloom` / `glow_hdr_threshold`) | spring, human_spring, manor, grade_blossom_vale, grade_rosewild, grade_solstice, grade_fae_village, grade_starlight_glen_day, grade_starlight_pool_sparkle | 0.7 / 0.2 / 1.0 (were 0.3 / 0 / 1.4; fae_village 0.7 / 0.04 / 1.1) | | R3 "soft glowy, strong bloom". Night, dusk and horror grades keep theirs | L63 |
| `exposure` (grades) | world/shared/grades/<id>.tres | table | | Re-solved so each grade's lit band (5 sunlit samples on the probe set) is within 1% of its T3a value under AgX; on the 8 brightest day grades 2.6–4.4% under it, where the samples had to leave the white roll-off for their colour to come back. `dread` keeps 0.19: its lit band is near black either way (1.1% vs 2.7% display) and 0.19 keeps the manor's ambient floor readable under dread | L63 |

Per preset (from `make luts`; curve = the old 1D LUT at 0 / 0.5 / 1):

| Preset | exposure | brightness | contrast | saturation | curve (0 / 0.5 / 1) | lift / gamma / gain | hue | sat shadow / highlight | white |
|---|---|---|---|---|---|---|---|---|---|
| `blight` | 1.313 | 0.920 | 1.120 | 0.350 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.394 | 1.00 |
| `bogge` | 1.107 | 0.900 | 1.120 | 0.350 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.292 / 1.292 | 1.00 |
| `dread` | 0.190 | 1.000 | 1.100 | 0.400 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.000 / 1.000 | 1.00 |
| `grade_autumn_foothills` | 2.051 | 1.000 | 1.120 | 1.200 | (0.087, 0.049, 0.068) / (0.614, 0.512, 0.456) / (1.000, 0.982, 0.954) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.434 | 0.97 |
| `grade_blight` | 0.671 | 0.860 | 1.180 | 0.400 | (0.047, 0.051, 0.055) / (0.306, 0.314, 0.322) / (0.643, 0.647, 0.651) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.272 / 1.272 | 1.00 |
| `grade_blossom_vale` | 1.864 | 1.000 | 1.120 | 1.200 | (0.106, 0.087, 0.151) / (0.634, 0.571, 0.602) / (1.000, 0.996, 0.994) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.577 | 0.97 |
| `grade_fae_village` | 1.251 | 1.000 | 1.120 | 1.200 | (0.075, 0.056, 0.125) / (0.616, 0.521, 0.532) / (1.000, 0.984, 0.954) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.434 | 0.97 |
| `grade_fells` | 2.148 | 1.000 | 1.120 | 1.200 | (0.087, 0.092, 0.151) / (0.546, 0.549, 0.614) / (0.995, 0.993, 1.000) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.638 | 0.97 |
| `grade_hill_of_the_rite_dusk` | 1.178 | 1.000 | 1.120 | 1.200 | (0.064, 0.049, 0.104) / (0.605, 0.494, 0.508) / (1.000, 0.966, 0.935) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.353 | 0.97 |
| `grade_rite_calanmai_night` | 0.743 | 0.980 | 1.120 | 1.200 | (0.024, 0.018, 0.056) / (0.512, 0.443, 0.534) / (1.000, 0.953, 0.888) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.475 | 1.00 |
| `grade_rosewild` | 1.839 | 1.000 | 1.120 | 1.200 | (0.111, 0.068, 0.129) / (0.632, 0.531, 0.571) / (1.000, 0.987, 0.989) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.678 | 0.97 |
| `grade_solstice` | 2.598 | 1.000 | 1.120 | 1.200 | (0.109, 0.091, 0.144) / (0.635, 0.581, 0.518) / (1.000, 0.995, 0.975) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.799 | 0.97 |
| `grade_solstice_twilight` | 1.066 | 1.000 | 1.120 | 1.200 | (0.054, 0.049, 0.120) / (0.559, 0.499, 0.585) / (1.000, 0.971, 0.982) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.475 | 1.00 |
| `grade_starlight_glen_day` | 1.810 | 1.000 | 1.120 | 1.200 | (0.106, 0.087, 0.158) / (0.622, 0.549, 0.594) / (1.000, 0.994, 0.985) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.799 | 0.97 |
| `grade_starlight_pool_sparkle` | 1.794 | 1.000 | 1.120 | 1.200 | (0.092, 0.106, 0.181) / (0.549, 0.585, 0.635) / (1.000, 0.998, 0.989) | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.556 | 0.97 |
| `human_spring` | 2.454 | 1.000 | 1.100 | 0.950 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.799 | 0.97 |
| `human_winter` | 1.726 | 0.970 | 1.080 | 0.550 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.638 | 1.00 |
| `manor` | 1.797 | 1.000 | 1.150 | 1.220 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.799 | 1.00 |
| `manor_interior` | 1.000 | 1.000 | 1.000 | 1.050 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.000 / 1.000 | 1.00 |
| `spring` | 1.782 | 1.000 | 1.150 | 1.220 | — | (0.00, 0.00, 0.00) / (1.00, 1.00, 1.00) / (1.00, 1.00, 1.00) | 0.0 | 1.350 / 1.638 | 0.97 |

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
| `ground_bounce` | candy_lit.gdshaderinc | 0.0 | 0–1 | T3a hook: light the lit ground throws back into the shade band. | L58 (set by T3a) |
| `ground_bounce_color` | candy_lit.gdshaderinc | (1.0, 0.92, 0.86) | colour | Colour of that bounce. | L58 (set by T3a) |
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

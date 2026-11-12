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
| `manor_interior` ambient / tone mapper | world/shared/grades/manor_interior.tres | no GI; ambient_color (0.92, 0.90, 0.88) flat (sky contribution 0.0), energy 1.1; tonemap = the manor's (ACES) so nothing pops at a doorway | energy 0.8..1.4 | Even, readable light indoors; raise ambient_energy if a room reads dark. SDFGI is never on indoors (T117) | T117 |

## Bounce light (render program T3a, L60)

Outdoor ambient is the sky's (upward faces take the sky tint, downward faces the
sky's ground half), plus candy_lit's ground bounce: the sunlit ground's light
thrown back up into the shade band. Probe: `tools/lighting/bounce_probe.tscn`.

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `ambient_light_source` | world/shared/world/world.tscn | SKY (3) (unchanged) | | Ambient from the sky's radiance, not a flat colour | L60 |
| `reflected_light_source` | world.tscn | SKY (2) (unchanged) | | Reflections from the sky | L60 |
| `ambient_light_sky_contribution` | world.tscn; GradePreset default (every grade but `manor_interior`) | 0.7 (was 0.6) | 0–1 | Sky share of the ambient; the rest is the grade's `ambient_color`. `manor_interior` uses 0.0, a flat ambient (T117) | L60 |
| `ssao_radius` / `ssao_intensity` | world.tscn, BounceLight.SSAO_RADIUS / SSAO_INTENSITY | 1.0 / 1.2 (were 1.5 / 1.5) | 0.01–16 / 0–16 | Contact shadow in corners and under things; ambient only | L60 |
| SSAO quality | BounceLight.apply (RenderingServer) | medium, half size (Godot's defaults) | | Global to the renderer | L60 |
| `ssil_enabled` | BounceLight.SSIL_PROFILES | on for `high`, off for `mac` (GameSettings.shadow_profile_name()) | | Screen-space colour bleed; `BOUNCE_SSIL=0/1` forces it for a perf pass | L60 |
| SSIL quality / `ssil_radius` / `ssil_intensity` | BounceLight | low, half size / 5.0 / 1.0 (Godot's defaults but quality) | | Cost and reach of the bleed | L60 |
| SDFGI outdoors | GradePreset.sdfgi (off outdoors) | off | | Not enabled: waits for the Mac measurement with volumetric fog (`BOUNCE_SDFGI=1 make perf`) | L60 |
| `ground_bounce` | candy_lit.gdshaderinc (`CANDY_BOUNCE_DEFAULT`) | 0.35; 0.0 on the manor's room shells (boiserie, plaster_ceiling, sky_ceiling: the flat interior ambient lights the rooms) | 0–1 | Bounce strength. Directional lights only, scaled by the light's height over the horizon and by how much the face looks down (1 down, 0.5 sideways, 0 up); the surface's own shadow does not block it; the lit band does not take it | L60 |
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
| Terrain texture import | world/shared/terrain/textures/*.png.import | lossless, `size_limit` 256 (about 7 MB with mipmaps) | every slot alike (the arrays must match) | Soft painted ground: BC3 and BC7 both block its gradients, and 512 px adds nothing visible. Raise to 512 only for a detailed look. | wider-court-world |
| Depth haze, estate | world/shared/grades/spring.tres | fog (0.70,0.74,0.96), density 0.00078, aerial 0.1, sky affect 0.1, volumetric albedo (0.85,0.86,1.0) | aerial ≤0.2; density ≤0.00078 (≤20% fog at the 285 m weenie) | A cool haze darker than the pink horizon: green foreground, teal midground, periwinkle hills that stand out from the sky. test_grade_director holds it. | wider-court-world |
| Court leaf-card trees | world/spring_court/wider/court_assets.gd `CARD_TREES_ON`, `CARD_VARIANTS` | off (owner: read tropical; exploring EZ-Tree and Quaternius), 5 builds per species | | The court's ten leafy species as painterly leaf-card models (owner's pick, 2026-11-10); off puts FloraLibrary's trees back. Builds: tools/court/blender/court_trees.py. | wider-court-world |
| `CARD_NEAR` | world/spring_court/wider/court_assets.gd | 100 m | 80–150 | Leaf-card trees switch to their far mesh (fewer, bigger cards) here; nearer costs overdraw (19.8 ms vs 17.0 ms in the dense-wood test at 150 m). | wider-court-world |
| Leaf-card light | world/spring_court/shared/court_leaf_card.gdshader | rim 0.12, lime guard 0.25, tree value spread 0.12, warmth spread 0.06 | rim ≤0.2 | A low rim, so dark leaves seen edge-on don't turn tan; the spreads give each tree its own shade. | wider-court-world |
| Moss ground hue | world/shared/terrain/textures/moss_albedo.png (tools/court/recolour_moss.py), ground_texture_packer.gd PASTEL moss | hue 110 (olive), base (0.343, 0.56, 0.30), accent (0.613, 0.78, 0.58) | | Was hue 160, which read teal under the fells grade where the Western Woods floor is 93% moss. Owner picked olive over green (128) from wcterrain-37. Moss is also Spring's secondary ground blend, so it shifts wherever moss shows. | wider-court-world |
| Tree roles (palette) | world/spring_court/wider/court_tree_set.gd `ROLES`, `DEEP` | deep leaves (0.27,0.48,0.30)→(0.46,0.64,0.38), bark (0.50,0.42,0.36); cherry (0.88,0.46,0.62)→(0.99,0.74,0.84); apple (0.86,0.80,0.80)→(1,0.96,0.94); lilac (0.66,0.56,0.84)→(0.86,0.80,0.96); conifer (0.20,0.36,0.27)→(0.33,0.50,0.36); birch bark (0.88,0.86,0.82); dead bark (0.44,0.40,0.42), drain 0.35; autumn oak, maple, golden birch, rowan in reds and golds | | The owner's mixed wood (wcterrain-28) dressed by role; each pack keeps its own look. Renders: lineups roles_green, roles_colour. | wider-court-world |
| Tree detail steps | court_tree_set.gd `NEAR`; court_scatter_generator.gd `TREE_DRAW`, `TREE_FAR`, `NEIGHBOUR_GAP` | near to 80 m, mid to 260 m, far crown to 600 m; neighbours 9 m | | Near ≤ 4,500 triangles, mid ≤ 1,200, far 24 (crown and trunk). No two trees within 9 m share a build where another is free. | wider-court-world |
| Tree per-tree shade | court_tree.gdshader `tree_value_spread` | 0.08 | | Each tree a little lighter or darker than its neighbour (Quaternius and far crowns; EZ leaves keep their own 0.92–1.08). | wider-court-world |
| Land habitats | world/spring_court/wider/court_land_habitats.gd `SLOPE_DEG`, `STEEP_DEG`, `RING`, `RISE`, `WIDE_RING`, `VALLEY_DROP` | 12°, 28°, 28 m, 1.8 m, 120 m, 7 m | | How the court's ground is read for planting (finish plan P1): slope and steep by degrees; a crest or knoll stands RISE above the mean of a RING; a hollow sits RISE below; a valley floor is VALLEY_DROP under a WIDE_RING on gentle ground. `tools/court/court_habitat_report.gd` prints each region's shares. | wider-court-world |
| Water and path bands | court_land_habitats.gd `SHORE_BAND`, `RIVER_BAND`, `BROOK_BAND`, `VERGE_BAND`, `PATH_CLEAR` | 14, 18, 8, 6, 2 m | | Shore, river bank, brook bank and path verge widths from the water's or path's edge; no trunk within PATH_CLEAR of a path. | wider-court-world |
| Keep-open zones | court_land_habitats.gd `GATE_CLEAR`, `VIEW_CLEAR`, `SENTRY_LANE`/`SENTRY_HALF`, `POTION_TERRACE`, `POOL_RIM` | 8, 8, 62/7, 12, 6 m | | No trunk inside a clearing's inner radius, round a gate or a standpoint, down the sentry range, on the potion terrace or round the starlight pool (wider_court.md). | wider-court-world |
| `DRAW_GRASS_CLUMPS` | world/spring_court/wider/court_region.gd | false (owner, 2026-11-09) | bool | The pale mint grass clumps are scattered but hidden: they didn't read as grass on the storybook ground. They still count as fire fuel. | wider-court-world |
| Depth haze, court by day | world/spring_court/wider/fx/tools/build_court_fx.gd `DEPTH_*` | haze (0.70,0.74,0.96), tint 0.25, density 0.0011, aerial 0.1, sky affect 0.1 | tint 0–0.5 | The same layering in each daytime region grade, keeping a quarter of the region's own fog hue. Dusk, night and the blight keep their own fog. | wider-court-world |

## Estate trees (finish plan D2/E2, lane estate-trees)

The estate's trees come from the estate tree-builder (`tools/blender/estate_tree.py`):
a skinned trunk and limbs, each limb ending in a cloud of leaf-clump cards, the willow
all fronds. Rebuild with the builder, then `tools/court/gen_estate_tree_clumps.py` for
the clump pictures. The owner approved the set on 2026-11-12.

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| Estate tree shapes | tools/blender/estate_tree.py `RECIPES` | per species: trunk, clear stem, lean, whorls (height, limbs, reach, rise, forks), leader, cloud and card sizes | every build ≤ 6,000 triangles (`BUDGET`) | The shape of each species; lengths are fractions of the species height in FloraLib. Oak broad and low, birch slender with small high clouds, pear upright, the blossom trees round, the willow arching. | estate-trees |
| Builds per species | tools/blender/estate_tree.py `main()` | 3 (a–c), from seeds | 1–8 | The same recipe from another seed, so neighbours differ. | estate-trees |
| Willow curtains | tools/blender/estate_tree.py willow `weep`, `variants` | a–c stop above the grass; d trails a fifth of its strands to the ground (`trail` 0.2); e trails all of them (`trail` 1.0) | trail 0–1 | How long the willow's fronds hang (owner, 2026-11-12: "cut the trailing share from a third to about a fifth"). The willow has no leaf clouds: strands also drape over the crown-top wood. | estate-trees |
| Estate tree colours | world/spring_court/manor_estate/flora/estate_trees.gd `LOOKS` | shadow / mid / light per species: oak (0.30,0.56,0.44) (0.50,0.79,0.56) (0.78,0.95,0.72); birch (0.36,0.62,0.42) (0.60,0.84,0.52) (0.86,0.97,0.66); pear (0.34,0.60,0.40) (0.56,0.80,0.50) (0.82,0.94,0.64); willow (0.33,0.60,0.46) (0.52,0.80,0.52) (0.80,0.95,0.66); cherry heart (0.80,0.42,0.60) (0.96,0.66,0.80); apple heart (0.88,0.72,0.76) (0.98,0.90,0.91); crab apple heart (0.90,0.78,0.80) (0.99,0.94,0.94) | pastel; light ≤ 1.0 | The three leaf bands of a green tree. A blossom tree's clumps keep their painted colours and these tint only the heart of each cloud. | estate-trees |
| Estate bark | estate_trees.gd `BARK_ROSE`, `BARK_WHITE` | rose-brown (0.56,0.42,0.43); birch white (0.93,0.91,0.88) | | The bark colour; the court's painted bark picture gives its light and dark. | estate-trees |
| `bands` | world/spring_court/manor_estate/flora/trees/estate_tree.gdshaderinc | 4 | 2–8 | How many steps the leaf value is banded into between shadow and light. | estate-trees |
| `tree_value_spread`, `tree_hue_spread` | estate_tree.gdshaderinc | 0.08, 0.4 | 0–0.3, 0–1 | Each tree a little lighter or darker, warmer or cooler than its neighbour, from where it stands. | estate-trees |
| Estate tree light | estate_tree.gdshaderinc `CANDY_*` | wrap 0.5, shade (0.62,0.55,0.78), rim (1.0,0.86,0.72) at 0.2, backlight 0.3 | rim ≤ 0.3 | The lilac shade and soft warm rim, as the estate's other foliage; the rim is low so the leaf clumps stay readable. | estate-trees |
| `TREE_NEIGHBOUR_GAP` | world/spring_court/manor_estate/scatter/manor_scatter.gd | 16 m | 8–30 m | A tree takes a build that no tree of its species within this distance has. | estate-trees |
| `TREE_CHUNK` | manor_scatter.gd | 320 m | 128–400 m | The size of a tree draw chunk. Larger chunks keep the draw count down now that each species is several builds (104 tree draws; one build in 128 m chunks was 146). | estate-trees |
| `TRUNK_RADIUS` | estate_trees.gd | oak 0.74 m, willow 0.5, pear 0.28, birch 0.27, cherry 0.27, apple 0.25, crab apple 0.22 | | The trunk you bump into, per species, matching the model's trunk at chest height. | estate-trees |

## Bow feel (T101)

| Tunable | Where | Default | Range | What it does | Lane |
|---|---|---|---|---|---|
| `nock_time` | data/bows/*.tres (BowData) | hunting 0.3 s; fae 0.2, gilded 0.25, yew 0.4, warbow 0.55 | 0.1–0.8 s | Seconds from raising the bow (RMB) until it is nocked. After that every left click looses a full-power arrow (Zelda style, no hold-to-strengthen). A click during the nock is queued and fires when it completes. Upgrades can shorten it. | T101 |

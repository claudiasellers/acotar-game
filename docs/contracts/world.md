# World contract (world lane)

How every lane that builds land fits into one map. The world lane owns
`world/shared/`, `world/human_realm/` and this file. Change requests go to the
world lane thread ("Build the human realm and the wall").

## 1. Frame and macro map

- Metres. **+X east, -Z north, +Y up.** World origin (0, 0, 0) = the manor courtyard centre.
- **The Wall** runs east-west at `z = 1400` (`WorldMap.WALL_Z`). North of it (smaller z) is Prythian. The ride north crosses at `x = -100` (`WorldMap.WALL_GAP_X`). The seam is a shimmer strip `z 1395..1405`.
- **Map rectangle** (`WorldMap.MAP_RECT`): x -2048..2048, z -2048..3072 (21 km²). Terrain covers exactly this.

| Owner | Region(s) | x | z |
|---|---|---|---|
| World | human realm (cottage, hunting_forest, village, wall_seam, workshop) | -900..700 | 1400..2500 |
| Woods | border_woods | -700..500 | 300..1400 |
| Woods | eastern_woods | 650..1850 | -650..550 |
| Manor | manor_estate (manor_grounds, manor_house) | -600..600 | -500..500 (edge with Border Woods at z 300..500 agreed between those lanes) |
| Woods | suriel_glade (young birches, the Thornwater runs through it) | -950..-700 | 450..800 (reserved out of the fells foot / starlight glen) |
| Wider court | western_fells | -1800..-1500 / foot -1500..-700 | -900..1400 / 600..1400 |
| Wider court | starlight_glen | -1500..-600 | -500..600 |
| Wider court | fae_village | -1500..-600 | -1250..-500 |
| Wider court | autumn_foothills (sealed) | -1800..-600 | -1700..-1250 (+ -1800..-1500, -1250..-900) |
| Wider court | rosewild | -600..500 | -800..-500 |
| Wider court | solstice_meadow | -600..300 | -1350..-800 |
| Wider court | hill_of_the_rite | 300..1300 | -1500..-700 |
| Wider court | blighted_reaches | -600..1700 / -600..300 / 1300..1700 | -1700..-1500 / -1700..-1350 / -1500..-700 |
| Wider court | blossom_vale | 500..1500 | 500..1400 |

- **Thornwater river**: a shared polyline in `MacroHeight.THORNWATER`, carved into the macro height (half-width 7 m, depth 2.6 m, 20 m banks). Lanes the river crosses lay its water surface and banks dressing; edit the points only with a note in your handoff.

## 2. Terrain

- One **Terrain3D** node (v1.1.0-rc1, vendored in `addons/terrain_3d/`) for the whole map, in the persistent World scene `world/shared/world/world.tscn`. Terrain3D region size 256 (its default), vertex spacing 1 m, 320 regions; the bake works in 1024 m tiles. Baked data is ~72 MB and takes ~2.5 min on 4 cores.
- **Height is code, not committed binaries.** `WorldHeight.height_at(x, z)` = `MacroHeight` blended with every registered `HeightProvider`, in priority order. A provider's height wins inside its `bounds` and fades back to macro over its outer `fade` metres (default 64), so neighbours always meet.
- **To add your terrain:** write a script with
  ```gdscript
  static func height_at(x: float, z: float) -> float        # world coords, required
  static func texture_at(x: float, z: float) -> Vector3i    # optional: (base slot, overlay slot, blend 0-255)
  ```
  and append a `HeightProvider` (id, bounds as `Rect2(min_x, min_z, width, depth)`, fade, height_script, priority) to `world/shared/terrain/height_providers.tres` in your own handoff. Build on `MacroHeight.height_at` / `land_height_at` so the river and hills carry through.
- **Texture slots** (`WorldHeight.Tex`): 0 SNOW, 1 FROZEN_EARTH, 2 ROCK, 3 WINTER_GRASS, 4 SPRING_GRASS, 5 MOSS, 6 FOREST_FLOOR, 7 PATH, 8 RIVERBED, 9 BLIGHT, 10 ICE. Ask the world lane for new slots.
- **Bake:** `godot --headless -s world/shared/terrain/bake_terrain.gd` writes Terrain3D data to `world/shared/terrain/data/` (gitignored). The build lane bakes before export. The World scene bakes in memory if the data is missing (slow first load, logs a warning).
- **Before Terrain3D lands on main**, lanes may build stand-in chunk meshes + `HeightMapShape3D`, but under a child named `TerrainFallback`; the World scene disables every `TerrainFallback` when Terrain3D is active. Sample `WorldHeight.height_at` (not your own function) when placing things, so placement matches the final terrain.
- **Collision layer 1** = static world (terrain, buildings, rocks). Feyre's `WORLD_MASK` expects it.

## 3. Region scenes

- `world/<realm>/<region_id>/<region_id>.tscn`, realm = `human_realm` or `spring_court`. Root is a `Node3D` whose transform puts it in world coordinates; children are positioned in world space under it.
- One `RegionDef` (`core/streaming/region_def.gd`) per region in `data/regions/<realm>/<region_id>.tres`: `id`, `scene_path`, `center`, `radius`, `neighbors`, `report_path`. `WorldStreamer` streams regions around Feyre (load 120 m, unload 220 m) under a parent the World scene gives it. The World scene itself is never streamed.
- **Regions contain content only:** no `WorldEnvironment`, no sun `DirectionalLight3D`, no sky. The World scene's `GradeDirector` owns sky, sun (driven by `Clock`), fog and colour grade. Local mood goes in `FogVolume`s and `ReflectionProbe`s inside the region.
- **Grades** are `GradePreset` resources in `world/shared/grades/`: `human_winter`, `spring`, `blight` to start. Each holds sky gradient, sun, ambient, fog, exposure/saturation/contrast, bloom, the **LUT slot** (`lut`, a Texture3D or gradient), and the shader globals `snow_cover` and `magic_amount`. The story lane switches them with `EventBus.grade_swap_requested(to_grade, seconds)`; `spring` over 2.0 s at the wall is the big reveal (grey snow to candy-pastel bloom and sparkle). Story swaps hold until released.
- **Per-region grade:** add a `RegionGrade` node (`grade`, `bounds`, `blend_seconds`) to your region; `GradeDirector` blends to it while Feyre is inside. To get a region its own look, add a preset `world/shared/grades/<id>.tres` (copy `spring.tres`, set `lut` and colours) in your handoff and call it out.
- Before/after story changes use the story lane's `StateVisibility` node.
- **Region gates:** every outdoor `RegionGate` lock is at least `RegionGate.min_height()` tall (Feyre's highest triple-jump chain + 1.5 m, about 11 m), in both collision and visible mesh, and is never mantleable (`RegionGate.owns`). Indoor gates are bounded by their ceiling.
- **Manor ward veil:** `ManorWardVeil` (a `RegionGate` for manor_grounds) runs a visible rose-gold glamour veil, ground to `min_height()`, along every estate edge facing a neighbour that opens in an earlier phase (from `manor_estate.tres` neighbours + the phase table); on the gate side it follows the sentry gate line, leaving the gate as the front door. It fades out on unlock.

### 3.1 Grades in detail (experience bar §2.1)
- `GradePreset` also carries `fog_sky_affect` (keep ≈0.1–0.3: at 1.0 distance fog paints the sky flat), height fog (`fog_height` is absolute world metres and the terrain sits at roughly 0–40 m, so keep it low), `fog_aerial_perspective`, `volumetric_anisotropy`, `volumetric_light_energy` (sun god-rays), `glow_hdr_threshold`, and golden-hour sky and sun colours that `GradeDirector` blends in as the sun nears the horizon.
- `mood_requested(&"dread", w)` blends toward `grades/dread.tres` by `w` (horror palette, about 2 stops down, saturation 0.4, dense low fog, no magic, no lilac). `&"calm"` eases it back out.

### 3.2 Act I anchors and authored frames (human realm)
Each is a `Marker3D` in group `story_anchor` (the village one uses meta `anchor_id`):

| Anchor | Region | Notes |
|---|---|---|
| `opening_cottage_dawn` | cottage | Feyre's start by the door; -Z faces up the fresh deer trail |
| `first_deed_treeline` | cottage | end of the deer trail at the forest edge (the first deed) |
| `act1_cottage_interior` | cottage | room centre at floor level; meta `size` = Vector3(10.5, 3, 6) |
| `act1_cottage_door` | cottage | in the doorway, -Z into the room |
| `act1_food_tally_beam` | cottage | on the beam where the notches go |
| `act1_wolf_clearing` | hunting_forest | thicket edge; the doe clearing is 22 m along -Z and open for ~24 m around it |
| `act1_fur_stall` | village | in front of the pelt trader's stall |
| `wall_gate_north` | wall_seam | the gap |

Composed camera frames are `Marker3D`s in group `shot_frame` with meta `shot` and `fov`: `opening_dawn` (cottage, dawn) and `wall_crossing` (just past the gap, aimed at the Border Woods' great oak). `tools/world_shot.gd` uses them.

The **wall crossing** set piece: the human side is a thorn defile that narrows from 7.5 m to 2.4 m half-width over the last 46 m before the gap, with walls climbing as it narrows (`WallSeamGen.defile_half_width`). The release frame past the gap is composed in the Border Woods.

## 4. Scatter (forage, decoration, collectibles)

- Each region has a generator script (committed with its output, R15) that writes `ScatterLayer` resources (`world/shared/scatter/scatter_layer.gd`), usually into `world/<realm>/<region_id>/scatter/<layer_id>.tres`:

  | Field | Meaning |
  |---|---|
  | `id` | unique in the region; forage keys are `"<id>:<index>"` |
  | `mesh` or `mesh_path` | the Mesh, or a path to a cloud-Blender `.glb` (first MeshInstance3D; export one joined mesh per asset) or mesh `.tres` |
  | `ingredient_id` | `ing_*` id from `data/ingredients/` (lore ids); empty = decoration |
  | `tags` | `landmark`, `collectible`, `look` (a notice-moment subject), ... |
  | `instances` | `PackedFloat32Array`, 5 floats each: x, y, z (world), yaw (rad), scale |
  | `material` | material_override for all instances (stylized_flora.tres or a variant) |
| `cast_shadow`, `wind` (0-1 GPU sway; set `wind_amount` on the material, never per-instance shader params), `draw_distance` (default 120 m) | |
  | `impostor_mesh` / `impostor_path`, `impostor_distance` (default 600 m) | low-poly far LOD or card drawn past `draw_distance` |

- **glb import:** set `import_script/path="res://world/shared/import/vertex_color_import.gd"` in every cloud-Blender `.glb.import` (Godot's glTF importer doesn't turn on albedo-from-vertex-colour by itself).
- A `ScatterField` node (`region_id`, `layers`, `chunk_size` 64 m) in the region builds them into chunked `MultiMeshInstance3D`s. **No per-instance nodes** (R16).
- **Streaming without hitches (optional, owned by the woods lane):** `SlicedScatterField` (`world/shared/scatter/sliced_scatter_field.gd`) is a `ScatterField` whose chunks are prepared on a worker thread (`SlicedScatterField.prepare(layer, chunk_size)` → ready MultiMesh buffers) and added one per job with `add_chunk()`; chunks carry the same groups and metas as above. Main-thread build work goes through `FrameBudget.run(queue)` (`world/shared/scatter/frame_budget.gd`), a 4 ms per-frame budget shared by every region builder. Bake slow generation into a git-ignored `_generated/` cache from `tools/generators/` (R15) so runtime only loads.
- **Forage hookup for the systems lane:** every forage chunk is in group `forage_field` with metas `ingredient_id`, `scatter_id`, `region_id`, `instance_ids` (layer index per multimesh instance) and `layer`. Use `ScatterField.instance_position(chunk, i)` to find instance `i`, `ScatterField.set_instance_hidden(chunk, i, true)` to hide it, and the key `"<scatter_id>:<instance_ids[i]>"` with `WorldDeltas.mark_picked(region_id, key, respawn_days)`.
- **Shared stylized material (art direction R3):** use `world/shared/shaders/stylized_foliage.gdshader` as a `ShaderMaterial` for flora and soft props. Soft wrapped light with a lilac shade tint, warm rim, leaf translucency, GPU wind, automatic snow on upward faces when `snow_cover` is on (human realm), and `sparkle` glints scaled by `magic_amount` (Spring Court). Tune per species with `albedo`/`albedo_texture`, `rim_strength`, `sparkle`, `emission_glow`, `snow_catch`. Vertex colour (glTF COLOR_0) tints the albedo when `use_vertex_color` is on; wind flex comes from vertex height up to `flex_height`. `world/shared/materials/stylized_flora.tres` is the default; make per-species variants beside your assets. Set it as the layer's `material`.
- **GPU wind**: include `world/shared/shaders/foliage_wind.gdshaderinc` and call `foliage_wind(VERTEX, MODEL_MATRIX, flex)` (flex 0 at the root, 1 at the tip). Globals `wind_direction`, `wind_strength`, `snow_cover`, `magic_amount` are in `project.godot` and driven by the World scene from `Weather.wind_at()`.

## 5. Coverage report (R1, world smoke)

Each generator also writes `world/<realm>/<region_id>/<region_id>_report.json` via `ScatterReport.compute(layers, area, landmarks, draw_calls)` + `ScatterReport.save(...)`, and the RegionDef's `report_path` points at it. `tools/world_smoke.gd` fails a region when:

| Key | Fails when | Meaning |
|---|---|---|
| `types` | < 25 | distinct forage ingredient ids + collectible/landmark/look layers |
| `placements_per_km2` | < 300 | instances of those layers per km² of the region's area |
| `empty_cells` | > 0 | 100 m cells of the area with none of them |
| `landmarks` | < 3 | named landmark objects in the region |
| `draw_calls` | > 1500 | estimated draw calls with the region and neighbours loaded |

## 6. Performance budget (R16)

1080p, 60 fps (16.6 ms) on a Mac mini M4. Scatter draws to 120 m then impostors to 600 m; trees may draw further via their own impostor. Chunk everything at 64 m. Keep a region at or under ~1500 draw calls with neighbours loaded.

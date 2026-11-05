# Terrain textures

Procedural slots come from `world/shared/terrain/gen_terrain_textures.gd`.

These slots take their structure (height, normal, roughness and the pattern of
light and dark) from CC0 photo textures by [Poly Haven](https://polyhaven.com)
(public domain, no attribution required). Their colour is the slot's spring
palette from `gen_terrain_textures.gd`. They are packed by
`tools/court/pack_ground_textures.gd` from the 1k JPG maps.

| Slot | Poly Haven texture |
|---|---|
| spring_grass | leafy_grass |
| moss | forrest_ground_01 |
| forest_floor | sparse_grass |
| path | flower_scattered_dirt |
| riverbed | river_small_rocks |
| rock | mossy_rock |
| blight | withered_grass |

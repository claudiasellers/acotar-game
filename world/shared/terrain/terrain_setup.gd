## Builds and configures the one Terrain3D node (settings from WorldMap and
## docs/contracts/world.md), its texture assets, and in-memory bakes.
## Terrain3D is a GDExtension; everything here goes through ClassDB so this
## script still parses when the extension is missing.
class_name TerrainSetup
extends RefCounted

const DATA_DIR := "res://world/shared/terrain/data"
const TEXTURE_DIR := "res://world/shared/terrain/textures"
## Texture slots in WorldHeight.Tex order: file stem, uv scale.
const TEXTURES := [
	["snow", 0.08], ["frozen_earth", 0.1], ["rock", 0.06], ["winter_grass", 0.1],
	["spring_grass", 0.1], ["moss", 0.12], ["forest_floor", 0.1], ["path", 0.15],
	["riverbed", 0.15], ["blight", 0.1], ["ice", 0.05],
]


static func available() -> bool:
	return ClassDB.class_exists(&"Terrain3D")


static func make_terrain() -> Node3D:
	var terrain: Node3D = ClassDB.instantiate(&"Terrain3D")
	terrain.name = "Terrain3D"
	terrain.set(&"region_size", WorldMap.TERRAIN_REGION_SIZE)
	terrain.set(&"vertex_spacing", WorldMap.TERRAIN_VERTEX_SPACING)
	terrain.set(&"mesh_lods", 7)
	terrain.set(&"mesh_size", 48)
	terrain.set(&"collision_layer", 1)
	terrain.set(&"free_editor_textures", false)
	terrain.set(&"assets", make_assets())
	return terrain


static func make_assets() -> Resource:
	var assets: Resource = ClassDB.instantiate(&"Terrain3DAssets")
	for i in TEXTURES.size():
		var albedo_path := "%s/%s_albedo.png" % [TEXTURE_DIR, TEXTURES[i][0]]
		var normal_path := "%s/%s_normal.png" % [TEXTURE_DIR, TEXTURES[i][0]]
		if not ResourceLoader.exists(albedo_path):
			continue
		var tex: Resource = ClassDB.instantiate(&"Terrain3DTextureAsset")
		tex.set(&"name", TEXTURES[i][0])
		tex.set(&"albedo_texture", load(albedo_path))
		if ResourceLoader.exists(normal_path):
			tex.set(&"normal_texture", load(normal_path))
		tex.set(&"uv_scale", TEXTURES[i][1])
		assets.call(&"set_texture_asset", i, tex)
	return assets


static func import_region(terrain: Node3D, loc: Vector2i, images: Array[Image]) -> void:
	var data: Object = terrain.get(&"data")
	var maps: Array[Image] = [images[0], images[1], null]
	data.call(&"import_images", maps, TerrainBaker.region_origin(loc), 0.0, 1.0)


## True when baked data exists on disk.
static func has_baked_data() -> bool:
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		return false
	for f in dir.get_files():
		if f.begins_with("terrain3d") and (f.ends_with(".res") or f.ends_with(".res.remap")):
			return true
	return false

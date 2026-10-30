## The Manor Estate region: the manor house, its gardens and grounds.
##
## Region root in world coordinates (origin = forecourt centre). Parts build in
## code from data and committed generators, with fixed seeds (R15). Played on
## its own (F6 or as the current scene) it adds a preview sky and sun and spawns
## Feyre on the drive; inside the World scene the GradeDirector owns lighting.
class_name ManorEstate
extends Node3D

const PHASES_PATH := "res://data/phases/spring_court_phases.tres"
const FEYRE_SCENE := "res://characters/feyre/feyre.tscn"

@export var region_id: StringName = ManorSitePlan.REGION_GROUNDS
## Phase used when the estate is played on its own and no story is running.
@export var preview_phase: StringName = &"p3_house_and_eastern_woods"
@export var build_terrain: bool = true
@export var build_house: bool = true
@export var build_grounds: bool = true
@export var build_scatter: bool = true

var feyre: Node3D
var house: Node3D
var grounds: Node3D
var scatter: ScatterField
var standalone: bool = false


func _ready() -> void:
	standalone = get_tree().current_scene == self
	if standalone and PhaseManager.phase_set == null and ResourceLoader.exists(PHASES_PATH):
		PhaseManager.start(load(PHASES_PATH), preview_phase)
	if build_terrain:
		ManorTerrain.build_fallback(self)
	if build_house:
		house = ManorHouseBuilder.build(self)
	if build_grounds:
		grounds = ManorGrounds.build(self)
	if build_scatter:
		scatter = ManorScatter.add_field(self)
	_add_creatures()
	if standalone:
		_add_preview_environment()
		_spawn_feyre()


## The creatures lane's spawn table brings the grounds to life: songbirds,
## butterflies over the roses, faelights at night, rabbits, swans on the pond.
func _add_creatures() -> void:
	const TABLE := "res://data/creatures/spawn/manor_grounds.tres"
	if not ResourceLoader.exists(TABLE):
		return
	var spawner := CreatureSpawner.new()
	spawner.name = "CreatureSpawner"
	spawner.table = load(TABLE)
	spawner.bounds = ManorSitePlan.BOUNDS
	spawner.water_level = ManorTerrain.pond_level()
	spawner.water_bounds = Rect2(ManorSitePlan.POND_CENTER - ManorSitePlan.POND_RADII * 0.8, ManorSitePlan.POND_RADII * 1.6)
	add_child(spawner)


func _spawn_feyre() -> void:
	if not ResourceLoader.exists(FEYRE_SCENE):
		return
	feyre = (load(FEYRE_SCENE) as PackedScene).instantiate()
	var s := ManorSitePlan.SPAWN
	feyre.position = Vector3(s.x, WorldHeight.height_at(s.x, s.z) + 0.3, s.z)
	feyre.rotation.y = deg_to_rad(ManorSitePlan.SPAWN_FACING_DEG)
	add_child(feyre)
	var interactor := ManorPreviewInteractor.new()
	interactor.player = feyre
	add_child(interactor)


## Preview lighting only (R3 princess grade: warm, pink, bloomy). The World
## scene's GradeDirector replaces this when the region is streamed in.
func _add_preview_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.55, 0.66, 0.98)
	sky_mat.sky_horizon_color = Color(1.0, 0.80, 0.86)
	sky_mat.ground_horizon_color = Color(0.98, 0.82, 0.84)
	sky_mat.ground_bottom_color = Color(0.45, 0.62, 0.42)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.25
	env.ssao_enabled = true
	env.sdfgi_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.86, 0.90)
	env.fog_density = 0.0012
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(1.0, 0.90, 0.94)
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	var world_env := WorldEnvironment.new()
	world_env.name = "PreviewEnvironment"
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "PreviewSun"
	sun.light_color = Color(1.0, 0.90, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.7
	sun.directional_shadow_max_distance = 220.0
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-30.0), 0.0)
	add_child(sun)

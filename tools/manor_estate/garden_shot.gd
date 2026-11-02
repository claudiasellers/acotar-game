## Probe scene for garden shots (L35): the manor estate lit by the game's own
## manor grade, for tools/shots requests ("scene": "res://tools/manor_estate/garden_shot.tscn").
## The estate's preview sky and fog are only for opening the scene in the
## editor; shots taken under them read grey and hazy, unlike the game, so the
## preview environment is reset to the World's settings and a GradeDirector
## applies the manor grade on top, as the game does from the RegionGrade.
extends Node3D

## The World scene's environment, so tonemap, GI and fog length match the game.
const WORLD_SCENE := "res://world/shared/world/world.tscn"


func _ready() -> void:
	var estate := (load("res://world/spring_court/manor_estate/manor_estate.tscn") as PackedScene).instantiate() as ManorEstate
	add_child(estate)
	estate._add_preview_environment()
	var preview := estate.get_node("PreviewEnvironment") as WorldEnvironment
	var sun := estate.get_node("PreviewSun") as DirectionalLight3D
	var world_env := _world_environment()
	if world_env != null:
		preview.environment = world_env.environment.duplicate(true)
		preview.camera_attributes = world_env.camera_attributes
		world_env.free()
	var director := GradeDirector.new()
	director.name = "GradeDirector"
	director.environment = preview
	director.sun = sun
	director.start_grade = &"manor"
	add_child(director)


func _world_environment() -> WorldEnvironment:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var env := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env != null:
		world.remove_child(env)
	world.free()
	return env

## Gives a bare region scene the look the game shows it with: the World's
## environment and sun under a GradeDirector, on the grade that region has in
## play. Probes use this, so shots show what a player sees. A probe run with
## --preview-look gets the region's own preview sky instead; that look ships
## nowhere (T043: reviews judged on it didn't match the game).
class_name ShotLook
extends RefCounted

const WORLD_SCENE := "res://world/shared/world/world.tscn"
const PREVIEW_ARG := "--preview-look"


## Lights `estate`. Returns the director, or null under --preview-look.
static func dress(estate: Node3D, grade: StringName = &"manor") -> GradeDirector:
	if OS.get_cmdline_user_args().has(PREVIEW_ARG):
		estate.call(&"_add_preview_environment")
		return null
	var world := (load(WORLD_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	var env := world.get_node("WorldEnvironment") as WorldEnvironment
	var sun := world.get_node("Sun") as DirectionalLight3D
	world.remove_child(env)
	world.remove_child(sun)
	world.free()
	estate.add_child(env)
	estate.add_child(sun)
	var director := GradeDirector.new()
	director.name = "GradeDirector"
	director.environment = env
	director.sun = sun
	director.start_grade = grade
	estate.add_child(director)
	return director

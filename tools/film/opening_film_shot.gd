## The opening film as New Game plays it (lane L33), captured on the Mac GPU:
##   godot res://tools/film/opening_film_shot.tscn -- <out_dir> [noclip] [until=<s>]
## Stills at the script's key shots, a contact sheet, a 4 fps clip and
## timing (FilmCapture). Script: /mnt/project-files/plans/film/scripts.md §1.
extends Node

## film #2 land, #3 court, #4 beasts, #5 slaves, #6 war, #7 treaty, #8 wall,
## #9 dusk, #11 interior, #12 mother, #13 ships, #14 foxglove, #16 dawn,
## #17 eye, #18 title, #19 play.
const STILLS: Array[float] = [14.0, 27.0, 40.5, 49.0, 60.0, 73.0, 84.5, 96.0,
		121.0, 131.0, 143.0, 155.0, 167.5, 174.6, 180.0, 188.0]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cap := FilmCapture.new()
	cap.name = "FilmCapture"
	cap.out = args[0] if args.size() > 0 else "user://opening_film_shot"
	cap.stills = PackedFloat32Array(STILLS)
	cap.fps = 0.0 if args.has("noclip") else 4.0
	cap.quit_after = 190.0
	for a in args:
		if a.begins_with("until="):
			cap.quit_after = float(a.substr(6))
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.add_child(cap)
	get_tree().change_scene_to_file(OpeningFilm.SCENE)

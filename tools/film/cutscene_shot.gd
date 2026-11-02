## A cutscene as the story plays it (lane L33), captured on the Mac GPU:
##   godot res://tools/film/cutscene_shot.tscn -- <out_dir> <film_id> [noclip]
## Starts the real game at the story moment's anchor with the story up to it
## done (the chain of deeds its gates need), lets the moment start the film
## the way a player walking in would, and captures it with FilmCapture
## (stills at the script's shots, a contact sheet, a 6 fps clip in atlases,
## timing). Script: /mnt/project-files/plans/film/scripts.md sections 2 to 4.
extends Node

const GAME := "res://story/act1/act1_game.tscn"
const MOMENTS := "res://data/story/moments/%s.tres"
## film -> [moment, start region, anchor, stills (film seconds)]
const STAGES := {
	&"eyes_open": [&"glamour_lift", &"blossom_vale", &"glamour_lift_glade",
		[4.0, 11.0, 21.5, 26.0, 33.0, 36.0, 39.5, 48.0, 51.5, 56.0, 59.5, 62.0, 65.5, 70.0, 74.5]],
	&"night_court": [&"rhysand_visit", &"manor_estate", &"manor_window_hide",
		[2.0, 4.4, 6.4, 8.8, 11.0, 15.0, 18.3, 20.0, 23.0, 28.0, 33.0, 37.5, 43.0, 45.5, 48.0, 50.5,
		55.0, 59.0, 63.0, 65.5, 70.0, 72.0, 74.1, 76.5, 82.0, 86.4, 92.0, 100.0]],
	&"silent_manor": [&"alis_truth", &"manor_estate", &"manor_alis_hiding",
		[3.0, 9.0, 13.5, 16.0, 20.0, 27.0, 33.0, 37.0, 42.0, 49.0, 54.0, 58.5, 63.5, 68.0, 74.0, 81.5,
		88.0, 93.0, 99.0, 106.0, 112.0, 117.0, 123.0, 129.0, 133.0, 138.0, 144.0, 148.5]],
}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://cutscene_shot"
	var id := StringName(args[1]) if args.size() > 1 else &"eyes_open"
	if not STAGES.has(id):
		push_error("cutscene_shot: no stage for %s" % id)
		get_tree().quit(1)
		return
	var stage: Array = STAGES[id]
	var moment := load(MOMENTS % stage[0]) as StoryMoment
	WorldState.clear()
	# Everything before the moment is done; its own gate opens once the region
	# has settled (the house built, the cast placed), the way it would in play.
	# Opened at once, an auto trigger fires while the region is still loading.
	# Only its facts are held back (a deed held back could replay the moment
	# that raises it); a gate of deeds alone is held back whole.
	var own := PackedStringArray(Array(moment.require_flags).filter(func(f: String) -> bool: return f.begins_with("fact.")))
	if own.is_empty():
		own = moment.require_flags
	for f in _chain(moment.require_flags, {}):
		if not own.has(f):
			WorldState.set_flag(f, true)
	var film := Films.data_of(id)
	var cap := FilmCapture.new()
	cap.name = "FilmCapture"
	cap.out = out
	cap.stills = PackedFloat32Array(stage[3])
	cap.fps = 0.0 if args.has("noclip") else 6.0
	cap.wait_for_film = true
	cap.give_up = 900.0
	cap.quit_after = film.length + 3.0
	get_tree().root.size = Vector2i(1920, 1080)
	get_tree().root.add_child(cap)
	var game := (load(GAME) as PackedScene).instantiate()
	game.set(&"start_region", stage[1])
	game.set(&"start_anchor", stage[2])
	game.set(&"opening_shot", "")
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	_hush(moment.id)
	# The gate opens 4 s after she is placed; walking in starts it, and if the
	# trigger has not fired 2 s later, start it as the trigger would.
	var space: SceneSpace = null
	var spawned_at := -1
	for i in 240:
		await get_tree().create_timer(1.0).timeout
		if FilmPlayer.current(get_tree()):
			print("cutscene_shot: %s started after %d s" % [id, i + 1])
			break
		space = _space_of(moment.id)
		if i % 10 == 9:
			print("cutscene_shot: %d s, spawned %s, space %s, can_start %s" % [i + 1, game.get(&"spawned"),
					space != null, space.can_start() if space else false])
		if bool(game.get(&"spawned")) and spawned_at < 0:
			spawned_at = i
		if spawned_at >= 0 and i == spawned_at + 4:
			print("cutscene_shot: opening the gate %s" % [own])
			for f in own:
				WorldState.set_flag(f, true)
		if space and spawned_at >= 0 and i >= spawned_at + 6 and not space.running and space.can_start():
			print("cutscene_shot: starting %s by hand" % moment.id)
			space.start()


## The rest of the story is over by the time this moment plays: any other
## scene that could start here (the chain opens some gates in passing, like
## Calanmai's in the hall) is marked done before it can, for the whole run.
func _hush(target: StringName) -> void:
	while is_inside_tree():
		for n in get_tree().root.find_children("*", "SceneSpace", true, false):
			var other := n as SceneSpace
			if other.space_id == target or other.running or other.done_flags.is_empty() or not other.can_start():
				continue
			print("cutscene_shot: %s marked done (%s)" % [other.space_id, other.done_flags])
			for f in other.done_flags:
				WorldState.set_flag(f, true)
		await get_tree().create_timer(0.5).timeout


func _space_of(moment_id: StringName) -> SceneSpace:
	for n in get_tree().root.find_children("*", "MomentSpace", true, false):
		if (n as SceneSpace).space_id == moment_id:
			return n as SceneSpace
	return null


## Every deed the gates need, and every deed those need, back to the start.
func _chain(flags: PackedStringArray, seen: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for f in flags:
		if seen.has(f):
			continue
		seen[f] = true
		out.append(f)
		for m: StoryMoment in StoryDirector.moments:
			for step in m.steps:
				if step.get("do") == "raise" and String(step.get("flag")) == f:
					out.append_array(_chain(m.require_flags, seen))
	return out

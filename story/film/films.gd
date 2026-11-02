## The cutscenes a story moment can play (lane L33): a moment's "film" step
## calls `Films.play(space, id)`, then waits on the film's facts with
## `until_flag`. The film itself never raises a deed (R2): the moment does,
## on the fact the film writes at the right frame.
##
## When the film can't play (headless runs, tests, another film running, no
## data) every fact it would have written is written at once, so the story
## moves on exactly as if it had been skipped. Contract: docs/contracts/film.md.
class_name Films
extends RefCounted

const DATA := "res://data/film/%s.tres"
const DIRECTOR := "res://story/film/cutscenes/%s.gd"


static func data_of(id: StringName) -> FilmScript:
	var path := DATA % id
	return load(path) as FilmScript if ResourceLoader.exists(path) else null


## Starts film `id` staged around `space` (the moment's own frame). Returns
## the player, or null when the film was not played (its facts are written).
static func play(space: Node3D, id: StringName) -> FilmPlayer:
	var film := data_of(id)
	if film == null:
		push_warning("Films: no film data for %s" % id)
		return null
	var player: FilmPlayer = null
	var director_path := DIRECTOR % id
	if space != null and space.is_inside_tree() and ResourceLoader.exists(director_path):
		player = FilmPlayer.start(space.get_tree(), film)
	if player == null:
		write_facts(film)
		return null
	var director := (load(director_path) as GDScript).new() as CutsceneDirector
	director.name = "Director"
	director.space = space
	director.player = player
	player.add_child(director)
	return player


static func write_facts(film: FilmScript) -> void:
	for f in FilmPlayer.facts_of(film):
		if not WorldState.has_flag(f):
			WorldState.set_flag(f, true)

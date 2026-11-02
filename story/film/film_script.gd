## A film as data: its length, score, lines and beats. FilmPlayer plays it;
## a director script listens to its beats. Contract: docs/contracts/film.md.
class_name FilmScript
extends Resource

@export var id: StringName
@export var length: float = 60.0
## SoundBank cue played once at 0:00 (one continuous score), or none.
@export var music_cue: StringName = &""
## Written when the film ends, however it ends (finished, skipped or freed).
## Always a fact.* flag, never a phase deed (R2). Empty: write nothing.
@export var seen_flag: String = ""
## Letterbox (Cine.bars_to): 1 is 2.39:1.
@export var bars: float = 1.0
@export var lines: Array[FilmLine] = []
@export var beats: Array[FilmBeat] = []


func line(line_id: StringName) -> FilmLine:
	for l in lines:
		if l.id == line_id:
			return l
	return null


func beat_time(beat_name: StringName) -> float:
	for b in beats:
		if b.name == beat_name:
			return b.at
	return -1.0

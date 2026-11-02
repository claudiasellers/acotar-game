## A named moment in a film's timeline; the film's director script cuts,
## moves the camera or changes the set when it fires.
class_name FilmBeat
extends Resource

@export var name: StringName
## Seconds from the film's start.
@export var at: float = 0.0

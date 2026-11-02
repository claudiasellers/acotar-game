## One line of a film: narration (Feyre's voice over) or a spoken line, shown
## as a caption until a voice file exists at res://audio/voice/<id>.ogg.
## Content: data/film/*.tres. Contract: docs/contracts/film.md.
class_name FilmLine
extends Resource

## Voice-file id, e.g. &"op_01".
@export var id: StringName
## Seconds from the film's start.
@export var at: float = 0.0
## Seconds on screen (fades included).
@export var hold: float = 4.0
## &"" is narration (italic, centred); otherwise the speaker's id (upright).
@export var speaker: StringName = &""
@export_multiline var text: String = ""
## [C], [C?] or [X], as in the lore bible.
@export var canon: String = "C"

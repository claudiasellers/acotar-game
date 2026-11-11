## One chapter of the sketchbook: one story phase (data/phases) and its steps
## in story order.
class_name JournalChapter
extends Resource

@export var phase: StringName
@export var numeral: String = ""
@export var title: String = ""
## Where she is, in her voice; never ahead of the chapter's first beat.
@export var opener: String = ""
## The chapter page's big drawing (JournalSketch.MOTIFS).
@export var sketch: StringName = &"rose"
@export var entries: Array[JournalEntry] = []


## The step she's on: the furthest open one in story order (a later step that
## is ready means the story moved on), else the first not done, so a step
## done out of order never hides the rest. Null when all are done.
## Ongoing steps run beside the others and are never the current one.
func current(has_flag: Callable) -> JournalEntry:
	var ready: JournalEntry = null
	var fallback: JournalEntry = null
	for e in entries:
		if e.ongoing or e.is_done(has_flag):
			continue
		if e.is_ready(has_flag):
			ready = e
		elif fallback == null:
			fallback = e
	return ready if ready else fallback


## Steps already done, in story order, that have a memory line.
func memories(has_flag: Callable) -> Array[JournalEntry]:
	var out: Array[JournalEntry] = []
	for e in entries:
		if e.memory != "" and e.is_done(has_flag):
			out.append(e)
	return out

## One step of the story as Feyre would think of it (L54, the sketchbook).
##
## Open while every require_flag is set and done_flag is not. `after` is the
## soft "what I'm after" line; hints run gentle to plain and unlock one by one
## (HintLadder) only when she asks. `memory` is written in once it's done.
## guide_thread borrows require/done flags and lines from the G thoughts
## (data/guide/act1_guide.tres) so the two never disagree.
class_name JournalEntry
extends Resource

@export var id: StringName
@export var done_flag: String = ""
@export var require_flags: PackedStringArray = []
## Rising flags that count as a failed try (e.g. fact.bogge_looked).
@export var fail_flags: PackedStringArray = []
@export var after: String = ""
@export var hints: PackedStringArray = []
@export var memory: String = ""
@export var guide_thread: StringName = &""
## Which of her little drawings sits beside it (JournalSketch.MOTIFS).
@export var sketch: StringName = &"rose"
## A thread that runs beside the main steps until it's done (her map of the
## halls): the chapter's current() skips it and the sketchbook lists it under
## "Still on my mind" (JournalBook.ongoing), whichever chapter she's in.
@export var ongoing: bool = false
## "A" book-verified, "V" adapted, "X" invented where the book is silent (R7).
@export var canon: String = "X"


func is_done(has_flag: Callable) -> bool:
	return done_flag != "" and bool(has_flag.call(done_flag))


func is_ready(has_flag: Callable) -> bool:
	for flag in require_flags:
		if not bool(has_flag.call(flag)):
			return false
	return true


## Copies flags and lines from a GuideThread: lines[0] is the motive (after),
## the rest are hints. Entry fields already set win.
func borrow(thread: GuideThread) -> void:
	if thread == null:
		return
	if done_flag == "" and not thread.done_flags.is_empty():
		done_flag = thread.done_flags[0]
	if require_flags.is_empty():
		require_flags = thread.require_flags
	if after == "" and thread.tier_count() > 0:
		after = thread.line(0)
	if hints.is_empty() and thread.tier_count() > 1:
		hints = thread.lines.slice(1)

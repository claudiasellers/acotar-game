## Every chapter of Feyre's sketchbook (data/journal/story_journal.tres).
class_name JournalBook
extends Resource

const GUIDE_PATH := "res://data/guide/act1_guide.tres"

@export var chapters: Array[JournalChapter] = []

var _linked: bool = false


func chapter_for(phase: StringName) -> JournalChapter:
	_link()
	for c in chapters:
		if c.phase == phase:
			return c
	return null


func all_entries() -> Array[JournalEntry]:
	_link()
	var out: Array[JournalEntry] = []
	for c in chapters:
		out.append_array(c.entries)
	return out


## Fills guide-backed entries from the G thoughts once.
func _link() -> void:
	if _linked:
		return
	_linked = true
	if not ResourceLoader.exists(GUIDE_PATH):
		return
	var guide := load(GUIDE_PATH) as GuideBook
	if guide == null:
		return
	var by_id := {}
	for t in guide.threads:
		by_id[t.id] = t
	for c in chapters:
		for e in c.entries:
			if e.guide_thread != &"" and by_id.has(e.guide_thread):
				e.borrow(by_id[e.guide_thread])

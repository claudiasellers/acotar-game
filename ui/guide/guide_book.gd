## Every guide thread of one act (data/guide/*.tres).
class_name GuideBook
extends Resource

@export var threads: Array[GuideThread] = []
## Her wider thoughts, for G when no need is open (the court between moments):
## never a task, never a spoiler.
@export var reflections: PackedStringArray = [
	"Everything here is lovely. I don't trust it yet.",
	"Slowly. Every path, every face, before I need any of them.",
	"Whatever this place wants from me, it hasn't said so yet.",
]


## The open thread with the highest priority, or null for a deliberate silence.
func pick(has_flag: Callable) -> GuideThread:
	var best: GuideThread = null
	for thread in threads:
		if thread.is_open(has_flag) and (best == null or thread.priority > best.priority):
			best = thread
	return best

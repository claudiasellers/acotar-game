## Every guide thread of one act (data/guide/*.tres).
class_name GuideBook
extends Resource

@export var threads: Array[GuideThread] = []


## The open thread with the highest priority, or null for a deliberate silence.
func pick(has_flag: Callable) -> GuideThread:
	var best: GuideThread = null
	for thread in threads:
		if thread.is_open(has_flag) and (best == null or thread.priority > best.priority):
			best = thread
	return best

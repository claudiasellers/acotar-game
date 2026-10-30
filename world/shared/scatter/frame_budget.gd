## A per-frame time budget shared by every region builder, so streaming a
## region in never costs the frame more than BUDGET_USEC of main-thread work
## (heavy work runs on worker threads; this covers creating nodes, meshes and
## physics shapes from prepared data).
class_name FrameBudget
extends RefCounted

const BUDGET_USEC := 4000

## Highest main-thread cost any frame has seen (for tests and profiling).
static var max_frame_usec := 0
## The slowest single job so far, and its method name (for profiling).
static var max_job_usec := 0
static var slowest_job := ""
## Worst cost per job method name, in microseconds (for profiling).
static var job_max := {}

static var _frame := -1
static var _spent := 0


static func has_time() -> bool:
	_roll()
	return _spent < BUDGET_USEC


static func spend(usec: int) -> void:
	_roll()
	_spent += usec
	max_frame_usec = maxi(max_frame_usec, _spent)


## Runs jobs from the front of `queue` while this frame has budget left.
## A job whose kind has cost more than what is left waits for the next frame
## A kind never seen before only runs first in a frame. Each frame runs at
## least one job, so a queue always drains.
## Returns how many jobs are still queued.
static func run(queue: Array[Callable]) -> int:
	while not queue.is_empty() and has_time():
		if _spent > 0 and _spent + int(job_max.get(queue[0].get_method(), BUDGET_USEC)) > BUDGET_USEC:
			break
		var job: Callable = queue.pop_front()
		var t := Time.get_ticks_usec()
		job.call()
		var cost := Time.get_ticks_usec() - t
		job_max[job.get_method()] = maxi(job_max.get(job.get_method(), 0), cost)
		if cost > max_job_usec:
			max_job_usec = cost
			slowest_job = job.get_method()
		spend(cost)
	return queue.size()


static func reset_stats() -> void:
	max_frame_usec = 0
	max_job_usec = 0
	slowest_job = ""


static func _roll() -> void:
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_spent = 0

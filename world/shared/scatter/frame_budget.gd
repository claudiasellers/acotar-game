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
## Jobs started after this frame's accounted budget was spent: the
## scheduler's promise is that this stays 0 (only a frame's first job may
## start without room for its estimate).
static var late_starts := 0
## Jobs run(), and jobs whose cost was spent against a frame (equal unless
## a job escapes the accounting).
static var queued_jobs_started := 0
static var jobs_accounted := 0
## Test-only clock: when > 0, every job is estimated and accounted at this
## many microseconds instead of its measured time, so scheduling (and so the
## frame count) is deterministic. Measured times still feed the profiling
## stats (max_job_usec, slowest_job).
static var fixed_cost_usec := 0

static var _frames := PackedInt32Array()

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
		if _spent > 0 and _spent + _estimate(queue[0].get_method()) > BUDGET_USEC:
			break
		if _spent >= BUDGET_USEC:
			late_starts += 1
		var job: Callable = queue.pop_front()
		queued_jobs_started += 1
		var t := Time.get_ticks_usec()
		job.call()
		var measured := Time.get_ticks_usec() - t
		if measured > max_job_usec:
			max_job_usec = measured
			slowest_job = job.get_method()
		var cost := fixed_cost_usec if fixed_cost_usec > 0 else measured
		job_max[job.get_method()] = maxi(job_max.get(job.get_method(), 0), cost)
		spend(cost)
		jobs_accounted += 1
	return queue.size()


## What a job of this kind is expected to cost: its worst so far, the whole
## budget for a kind never seen, or the test clock's fixed cost.
static func _estimate(method: StringName) -> int:
	if fixed_cost_usec > 0:
		return fixed_cost_usec
	return int(job_max.get(method, BUDGET_USEC))


static func reset_stats() -> void:
	max_frame_usec = 0
	max_job_usec = 0
	slowest_job = ""
	late_starts = 0
	queued_jobs_started = 0
	jobs_accounted = 0
	_frames.clear()
	# Work already spent this frame belongs to before the reset.
	_frame = Engine.get_process_frames()
	_spent = 0


## Main-thread cost of every frame that ran jobs since reset_stats(),
## including the current one.
static func frame_costs() -> PackedInt32Array:
	var out := _frames.duplicate()
	if _spent > 0:  # the latest frame with work, not yet rolled over
		out.append(_spent)
	return out


## The `q` quantile (0..1) of frame_costs().
static func frame_quantile(q: float) -> int:
	var costs := frame_costs()
	if costs.is_empty():
		return 0
	costs.sort()
	return costs[clampi(int(ceil(q * costs.size())) - 1, 0, costs.size() - 1)]


static func _roll() -> void:
	var f := Engine.get_process_frames()
	if f != _frame:
		if _spent > 0:
			_frames.append(_spent)
		_frame = f
		_spent = 0

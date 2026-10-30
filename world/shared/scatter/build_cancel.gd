## Cancellation for region builds running on WorkerThreadPool. A region's
## _exit_tree requests a cancel for its id before joining its worker; the
## generators check `requested(id)` once per row or entry and return early,
## so quitting (or a teleport) mid-build joins in well under a second
## instead of waiting out a full generate.
class_name BuildCancel
extends RefCounted

static var _ids := {}
static var _lock := Mutex.new()


static func request(id: StringName) -> void:
	_lock.lock()
	_ids[id] = true
	_lock.unlock()


static func clear(id: StringName) -> void:
	_lock.lock()
	_ids.erase(id)
	_lock.unlock()


static func requested(id: StringName) -> bool:
	_lock.lock()
	var yes := _ids.has(id)
	_lock.unlock()
	return yes

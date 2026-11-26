## T161: frame-time probe for the mare ride out of the stable yard (the
## mount clip's route), past the (-78, 113) hitch T151 found. Logs every
## drawn frame's wall time with where the mare was and what streamed in that
## frame, then the slowest frames.
##   tools/mq/godot.sh --headless res://tools/perf/ride_hitch_probe.tscn -- --out=/tmp/x/report.json
extends "res://tools/playtest/mount_ride_clip.gd"

## Stop once she is this far down the drive (past the hitch).
const STOP_Z := 220.0

var _last_usec := 0
var _rows: Array[Dictionary] = []
var _frame_events: PackedStringArray = []
var _added := {}
var _probing := false
var _ticks := 0


func _ready() -> void:
	super()
	WorldStreamer.region_loaded.connect(func(id: StringName, _root: Node3D) -> void: _frame_events.append("loaded:%s" % id))
	WorldStreamer.region_unloaded.connect(func(id: StringName) -> void: _frame_events.append("unloaded:%s" % id))
	get_tree().node_added.connect(func(n: Node) -> void:
		if _probing:
			_added[n.get_class()] = int(_added.get(n.get_class(), 0)) + 1)


func _process(delta: float) -> void:
	super(delta)
	var now := Time.get_ticks_usec()
	if _probing and _last_usec > 0 and director and director.mare:
		var at := director.mare.global_position
		var adds := PackedStringArray()
		for k: String in _added:
			if int(_added[k]) >= 5:
				adds.append("%s x%d" % [k, _added[k]])
		_rows.append({"ms": (now - _last_usec) / 1000.0, "x": at.x, "z": at.z,
			"ev": " ".join(_frame_events), "added": ", ".join(adds), "n": _added.values().reduce(func(a: int, b: int) -> int: return a + b, 0)})
		if _rows[-1].ms > 33.0:
			print("RIDE_FRAME %.1f ms at (%.0f, %.0f) %s +%d | process %.1f ms, physics %.1f ms x%d ticks, objects %d, resources %d" % [_rows[-1].ms, at.x, at.z, _rows[-1].ev, _rows[-1].n,
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, _ticks,
					Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
		if at.z > STOP_Z:
			_report()
	_last_usec = now
	_ticks = 0
	_frame_events.clear()
	_added.clear()


func _physics_process(delta: float) -> void:
	super(delta)
	_ticks += 1


func _pilot() -> Array:
	_probing = true
	return super()


func _report() -> void:
	_probing = false
	var sorted := _rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.ms > b.ms)
	var over := 0
	for r: Dictionary in _rows:
		if r.ms > 33.0:
			over += 1
	print("RIDE_HITCH frames %d, over 33 ms %d, max %.1f ms" % [_rows.size(), over, sorted[0].ms if not sorted.is_empty() else 0.0])
	for i in mini(12, sorted.size()):
		var r: Dictionary = sorted[i]
		print("RIDE_HITCH %.1f ms at (%.0f, %.0f) %s | +%d nodes %s" % [r.ms, r.x, r.z, r.ev, r.n, r.added])
	_finish(0)

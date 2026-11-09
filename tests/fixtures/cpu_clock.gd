## CPU time used by this Godot process's main thread, in milliseconds (user
## plus system). For timing budgets in tests: unlike wall time it doesn't grow
## while the thread waits for a core, and unlike process CPU time it leaves out
## background loading, so a busy Mac or a full gate can't fail a budget, but
## more main-thread work still does. Same source of truth on Mac and Linux.
## T089: the manor's stream-in took 3.4-19 s wall under load.
## Usage: const CpuClock := preload("res://tests/fixtures/cpu_clock.gd")
extends RefCounted

static var _time := RegEx.create_from_string("(\\d+:)?\\d+:\\d+\\.\\d+")


## The main thread's CPU ms, at 10 ms resolution. Linux reads
## /proc/self/task/<pid>/stat (the main thread's id is the process id); the
## Mac asks `ps -M`, whose first thread row is the main thread. Returns -1.0
## where neither works, so callers can fall back to wall time.
static func main_thread_msec() -> float:
	var pid := OS.get_process_id()
	var stat := FileAccess.get_file_as_string("/proc/self/task/%d/stat" % pid)
	if not stat.is_empty():
		# Fields after the ")" that closes the command name: utime is the 12th,
		# stime the 13th, in clock ticks (100 a second on Linux).
		var fields := stat.substr(stat.rfind(")") + 2).split(" ")
		if fields.size() > 12:
			return (int(fields[11]) + int(fields[12])) * 10.0
	var out: Array = []
	if OS.execute("ps", ["-M", "-p", str(pid)], out) != 0 or out.is_empty():
		return -1.0
	var lines := str(out[0]).split("\n", false)
	if lines.size() < 2:
		return -1.0
	var times := _time.search_all(lines[1])  # STIME then UTIME
	if times.size() < 2:
		return -1.0
	return (_secs(times[0].get_string()) + _secs(times[1].get_string())) * 1000.0


static func _secs(text: String) -> float:
	var secs := 0.0
	for part in text.split(":"):  # [hh:]mm:ss.cc
		secs = secs * 60.0 + float(part)
	return secs

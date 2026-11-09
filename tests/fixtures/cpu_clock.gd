## The CPU time this Godot process has used, in milliseconds (all threads, user
## plus system). For timing budgets in tests: unlike wall time it doesn't grow
## while the process waits for a core, so a busy Mac or a full gate can't fail
## a budget, but more work still does. T089: the manor's stream-in took 3.4-19 s
## wall under load and 1.9-2.5 s of CPU in every run.
## Usage: const CpuClock := preload("res://tests/fixtures/cpu_clock.gd")
extends RefCounted


## Linux reads /proc/self/stat (10 ms ticks); the Mac asks ps (10 ms).
## Returns -1.0 where neither works, so callers can fall back to wall time.
static func msec() -> float:
	var stat := FileAccess.get_file_as_string("/proc/self/stat")
	if not stat.is_empty():
		# Fields after the ")" that closes the command name: utime is the 12th,
		# stime the 13th, in clock ticks (100 a second on Linux).
		var fields := stat.substr(stat.rfind(")") + 2).split(" ")
		if fields.size() > 12:
			return (int(fields[11]) + int(fields[12])) * 10.0
	var out: Array = []
	if OS.execute("ps", ["-o", "time=", "-p", str(OS.get_process_id())], out) != 0 or out.is_empty():
		return -1.0
	var text: String = str(out[0]).strip_edges()
	if text.is_empty():
		return -1.0
	var secs := 0.0
	for part in text.replace("-", ":").split(":"):  # [[dd-]hh:]mm:ss.cc
		secs = secs * 60.0 + float(part)
	return secs * 1000.0

## Sound for the grounds' horror beats, synthesised so nothing heavy is
## committed (R15): a sub drone that beats against itself, a heartbeat,
## teeth chattering in the cold, a whisper texture for the Bogge's pleas,
## faint sobbing for the puca's sisters (canon:"X": the book gives no sound)
## and the shriek when the Bogge becomes real. Every stream is cached.
##
## Horror is never toned down (R3): these are deliberately unpleasant, low
## and close, the opposite of Juice's chimes.
class_name Act2DreadAudio
extends RefCounted

const RATE := 22050

static var _cache: Dictionary = {}


static func stream(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var wav: AudioStreamWAV
	match id:
		&"drone":
			wav = _make(_drone(6.0), true)
		&"heartbeat":
			wav = _make(_heartbeat(), true)
		&"chatter":
			wav = _make(_chatter(1.6), true)
		&"whisper":
			wav = _make(_whisper(2.4, 7), true)
		&"sob":
			wav = _make(_sob(3.2), true)
		&"shriek":
			wav = _make(_shriek(1.4), false)
		_:
			push_warning("Act2DreadAudio: no sound '%s'" % id)
			wav = _make(PackedFloat32Array([0.0]), false)
	_cache[id] = wav
	return wav


static func _make(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Three low partials a few hertz apart, so the air itself throbs, over
## brown noise like wind in a closed room. Partials are whole cycles of the
## loop so it never clicks.
static func _drone(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 9091
	var freqs := [37.0, 38.5, 55.5, 74.0]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			var f: float = round(freqs[k] * seconds) / seconds
			v += sin(TAU * f * t) * (0.32 if k < 2 else 0.12)
		brown = clampf(brown + rng.randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		out[i] = v * 0.55 + brown * 0.35
	return out


## Lub-dub at about 70 bpm: two soft thumps of a falling sine.
static func _heartbeat() -> PackedFloat32Array:
	var n := int(0.86 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = _thump(t, 0.0, 1.0) + _thump(t, 0.24, 0.7)
	return out


static func _thump(t: float, at: float, gain: float) -> float:
	var d := t - at
	if d < 0.0 or d > 0.18:
		return 0.0
	var f := lerpf(70.0, 38.0, d / 0.18)
	return sin(TAU * f * d) * exp(-d * 22.0) * gain * 0.9


## Fast irregular clicks: her teeth in the leeching cold.
static func _chatter(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4417
	var next := 0
	while next < n:
		for j in 220:
			if next + j >= n:
				break
			out[next + j] += rng.randf_range(-1.0, 1.0) * exp(-float(j) / 30.0) * 0.5
		next += int(RATE * rng.randf_range(0.045, 0.085))
	return out


## Breathy syllables: band-limited noise in short bursts, pitched like a
## voice with no throat behind it.
static func _whisper(seconds: float, seed_value: int) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var lp := 0.0
	var hp_prev := 0.0
	var syllables: Array = []
	var at := 0.1
	while at < seconds - 0.2:
		var length := rng.randf_range(0.12, 0.3)
		syllables.append(Vector2(at, length))
		at += length + rng.randf_range(0.04, 0.22)
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		for s: Vector2 in syllables:
			if t >= s.x and t <= s.x + s.y:
				env = sin(PI * (t - s.x) / s.y)
				break
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.35
		var band := lp - hp_prev
		hp_prev += (lp - hp_prev) * 0.06
		out[i] = band * env * 0.9
	return out


## Two voices crying, far off and muffled (canon:"X").
static func _sob(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2203
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for voice in 2:
			var period := 1.05 + voice * 0.33
			var phase := fmod(t + voice * 0.4, period) / period
			var env := pow(sin(PI * clampf(phase * 1.6, 0.0, 1.0)), 2.0) if phase < 0.62 else 0.0
			var pitch := (410.0 + voice * 70.0) * (1.0 - 0.18 * phase) + sin(TAU * 6.0 * t) * 9.0
			v += sin(TAU * pitch * t) * env * 0.25
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.1
		out[i] = (v + lp * 0.12) * 0.6
	return out


## When it becomes real: a ripping, falling scream over a sub hit.
static func _shriek(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6661
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(1400.0, 260.0, pow(t / seconds, 0.6))
		phase += TAU * f / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var env := minf(1.0, t * 40.0) * exp(-t * 1.6)
		var hit := sin(TAU * 42.0 * t) * exp(-t * 5.0)
		out[i] = (saw * 0.45 + rng.randf_range(-1.0, 1.0) * 0.35) * env + hit * 0.8
	return out

## The Attor's sound (ch 19, L44), synthesised like Act2DreadAudio so nothing
## heavy is committed (R15). The book gives what she hears and never sees
## [C, Keeper]: a low, disembodied voice, deep and sibilant; a hiss that turns
## her blood cold; a chuckle like sand shifting; the flap of leathery wings
## and a foul wind. Horror is never toned down (R3): low, close, wet, wrong.
class_name AttorAudio
extends RefCounted

const RATE := 22050
static var _cache: Dictionary = {}


static func stream(id: StringName) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	var wav: AudioStreamWAV
	match id:
		&"voice":
			wav = Act2DreadAudio._make(_voice(3.0), true)
		&"hiss":
			wav = Act2DreadAudio._make(_hiss(1.3), false)
		&"chuckle":
			wav = Act2DreadAudio._make(_sand(1.6), false)
		&"wings":
			wav = Act2DreadAudio._make(_wings(2.2), false)
		&"gust":
			wav = Act2DreadAudio._make(_gust(2.6), false)
		_:
			wav = Act2DreadAudio.stream(id)
	_cache[id] = wav
	return wav


## A deep sibilant murmur: a growling 70-95 Hz voice under band-passed hiss,
## both shaped by syllable-like envelopes so it reads as speech with no words.
static func _voice(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1901
	var lp := 0.0
	var bp_lo := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		# syllables: 3.5-5 per second, never quite regular
		var syl := pow(maxf(sin(TAU * (4.1 * t + 0.35 * sin(TAU * 0.6 * t))), 0.0), 1.6)
		var f0 := 78.0 + 14.0 * sin(TAU * 0.45 * t) + 6.0 * sin(TAU * 2.3 * t)
		phase += TAU * f0 / RATE
		var growl := (sin(phase) + 0.5 * sin(phase * 2.0) + 0.3 * sin(phase * 3.0 + 0.4)) * (0.8 + 0.2 * rng.randf())
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.55
		bp_lo += (lp - bp_lo) * 0.18
		var sibilant := (lp - bp_lo) * (0.6 + 0.9 * pow(maxf(sin(TAU * 2.05 * t + 1.3), 0.0), 3.0))
		var tail := 1.0 if t < seconds - 0.05 else (seconds - t) / 0.05
		out[i] = (growl * 0.32 + sibilant * 0.5) * (0.25 + 0.75 * syl) * tail
	return out


## A long hiss through teeth, rising then cut.
static func _hiss(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1902
	var a := 0.0
	var b := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		a += (x - a) * 0.7
		b += (a - b) * 0.12
		var env := minf(t / 0.25, 1.0) * (1.0 if t < seconds - 0.12 else maxf((seconds - t) / 0.12, 0.0))
		out[i] = (a - b) * 0.9 * env * (0.85 + 0.15 * sin(TAU * 31.0 * t))
	return out


## A chuckle like sand shifting: bursts of tiny grains in a ha-ha-ha rhythm.
static func _sand(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1903
	for i in n:
		var t := float(i) / RATE
		var pulse := pow(maxf(sin(TAU * 5.2 * t), 0.0), 4.0) * maxf(1.0 - t / seconds, 0.0)
		var grain := rng.randf_range(-1.0, 1.0) if rng.randf() < 0.35 else 0.0
		out[i] = grain * pulse * 0.7 + sin(TAU * 62.0 * t) * pulse * 0.25
	return out


## Leathery wing beats: three heavy downstrokes, each a low thud wrapped in a
## ripping flutter of membrane.
static func _wings(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1904
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in 3:
			var at := 0.15 + k * 0.62
			var d := t - at
			if d >= 0.0 and d < 0.45:
				var env := exp(-d * 9.0)
				s += sin(TAU * (48.0 - d * 30.0) * d) * env * 0.9
				var flutter := rng.randf_range(-1.0, 1.0) * (0.5 + 0.5 * sin(TAU * 38.0 * d))
				lp += (flutter - lp) * 0.3
				s += lp * env * 0.6
		out[i] = s * (1.0 - 0.3 * t / seconds)
	return out


## The foul wind after it leaves: a swell of low rushing noise.
static func _gust(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1905
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		lp2 += (lp - lp2) * 0.2
		var env := sin(PI * clampf(t / seconds, 0.0, 1.0)) * (0.8 + 0.2 * sin(TAU * 1.7 * t))
		out[i] = lp2 * 3.2 * env
	return out

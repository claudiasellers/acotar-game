## One named sound: its variants and how it plays (see docs/contracts/audio.md).
## Written by tools/audio/gen_act1_audio.py into data/audio/act1_sound_bank.tres.
class_name SoundCue
extends Resource

@export var id: StringName
## Variants; one is picked at random per play, never the same twice running.
@export var streams: Array[AudioStream] = []
@export var volume_db: float = 0.0
## Random pitch spread per play (0.05 = +-5%).
@export var pitch_jitter: float = 0.0
@export var loop: bool = false
## Music cues go to the Music bus (GameSettings.MUSIC_GROUP); the rest to Sound.
@export var music: bool = false
## Positional plays fade out to silence at this distance (m).
@export var max_distance: float = 40.0

var _last: int = -1


func pick() -> AudioStream:
	if streams.is_empty():
		return null
	var i := randi() % streams.size()
	if streams.size() > 1 and i == _last:
		i = (i + 1) % streams.size()
	_last = i
	var stream := streams[i]
	if loop and stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	return stream


func pitch() -> float:
	return 1.0 + randf_range(-pitch_jitter, pitch_jitter)

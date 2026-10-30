## Sound hooks for the satchel and quick bar. Plays res://audio/ui/satchel_<kind>.ogg
## when the sound lane has added it, else a synthesised Juice chime, so every
## hook makes a sound today. `fired` counts plays for tests.
class_name SatchelSounds
extends RefCounted

const KINDS: Array[StringName] = [&"open", &"close", &"page", &"select", &"use", &"pin", &"pickup", &"refuse"]
const PATH := "res://audio/ui/satchel_%s.ogg"
## Fallback: Juice chime kind and pitch per hook.
const FALLBACK := {
	&"open": [&"craft", 0.8], &"close": [&"pickup", 0.7], &"page": [&"pickup", 1.25],
	&"select": [&"pickup", 1.6], &"use": [&"craft", 1.1], &"pin": [&"unlock", 1.2],
	&"pickup": [&"pickup", 1.0], &"refuse": [&"pickup", 0.5],
}

static var fired: Dictionary = {}


static func play(kind: StringName, host: Node) -> void:
	fired[kind] = int(fired.get(kind, 0)) + 1
	if host == null or not host.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	var path := PATH % kind
	var spec: Array = FALLBACK.get(kind, [&"pickup", 1.0])
	if ResourceLoader.exists(path):
		player.stream = load(path)
	else:
		player.stream = Juice.chime(spec[0])
		player.pitch_scale = spec[1]
		player.volume_db = -8.0
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

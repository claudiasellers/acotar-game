## How story code, dialogue and cutscenes ask for a face (lane L36, docs/contracts/faces.md).
##
##   Faces.express(&"tamlin", &"angry")                 # until cleared
##   Faces.express(&"lucien", &"smirk", 0.8, 2.5)        # 2.5 s, then back to rest
##   Faces.speak(&"alis", "Don't touch that.", &"contempt", 1.8)
##   Faces.clear(&"tamlin")
##
## `actor` is the cast id (tamlin, lucien, alis, father, ...) or a story actor id
## whose model is in group story_actor_<id>.  `expression` is the character's own
## preset name or one of FaceProfile.EMOTIONS; each face maps an emotion to its
## canon look (Tamlin's "angry" is jaw-tight restraint, the father's is a wince).
## Everything goes over EventBus: face_requested / line_spoken once core adds
## them, else story_actor_cue "face_<expression>" (speech then reaches faces
## through the scene tree group "faces" until line_spoken exists).
class_name Faces
extends RefCounted

const GROUP := &"faces"


static func express(actor: StringName, expression: StringName, intensity: float = 1.0, seconds: float = -1.0) -> void:
	if EventBus.has_signal(&"face_requested"):
		EventBus.emit_signal(&"face_requested", actor, expression, intensity, seconds)
	else:
		EventBus.story_actor_cue.emit(actor, StringName("face_%s" % expression))


static func clear(actor: StringName) -> void:
	if EventBus.has_signal(&"face_requested"):
		EventBus.emit_signal(&"face_requested", actor, &"clear", 0.0, 0.0)
	else:
		EventBus.story_actor_cue.emit(actor, &"face_clear")


static func speak(actor: StringName, text: String, emotion: StringName = &"", seconds: float = -1.0) -> void:
	if EventBus.has_signal(&"line_spoken"):
		EventBus.emit_signal(&"line_spoken", actor, text, emotion, seconds)
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group(GROUP):
		var d := n as FaceDriver
		if d != null and d._is_me(actor):
			d.speak(text, emotion, seconds)

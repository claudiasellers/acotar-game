## One character's canon expression range (lane L36, docs/contracts/faces.md).
## Generated into data/faces/<id>_face.tres by tools/blender/expressions/gen_face_profiles.py
## from tools/blender/expressions/face_profiles.py; edit the Python, not the .tres.
class_name FaceProfile
extends Resource

## The shared emotion vocabulary dialogue lines and story cues may name.  Every
## profile maps each of these to one of its own presets (see `aliases`).
const EMOTIONS: Array[StringName] = [&"neutral", &"happy", &"laugh", &"smirk", &"tender", &"angry", &"fury",
	&"contempt", &"disgust", &"sad", &"grief", &"afraid", &"terror", &"surprise", &"pained", &"weary",
	&"guarded", &"pleading"]

@export var character_id: StringName
## The Keeper's canon cues for this face ([C] book, [X] our reading).
@export_multiline var canon: String = ""
## A fused Spring Court mask hides brows, nose and cheeks: acting lives in the jaw, mouth and eyes.
@export var masked: bool = false
## The preset the face rests in.
@export var rest: StringName = &""
## Seconds between blinks.
@export var blink_min: float = 2.5
@export var blink_max: float = 6.0
## Preset name (String) -> { shape-key name (String): weight 0..1 }.
@export var presets: Dictionary = {}
## Emotion (String, from EMOTIONS) -> preset name (String).
@export var aliases: Dictionary = {}
## Recurring small moves over the rest face:
## [{ "preset": String, "min": float, "max": float, "hold": float, "weight": float }].
@export var tics: Array = []
## A creature's face (lane L36-3): a threat display with no blinks or visemes.
@export var creature: bool = false
## Creature only: what it is doing (its State enum name lower-cased, or its face_state()) -> preset,
## worn as its rest face while it lasts.
@export var states: Dictionary = {}
## Creature only: story cue -> { "preset": String, "seconds": float (< 0: hold) }.
@export var cues: Dictionary = {}


## The preset an expression or emotion resolves to: its own preset name first,
## then the shared vocabulary, else the rest face.
func resolve(expression: StringName) -> StringName:
	var e := String(expression)
	if presets.has(e):
		return StringName(e)
	if aliases.has(e) and presets.has(String(aliases[e])):
		return StringName(String(aliases[e]))
	return rest


func mix_of(preset: StringName) -> Dictionary:
	return presets.get(String(preset), {}) as Dictionary


static func path_for(id: StringName) -> String:
	return "res://data/faces/%s_face.tres" % id


static func for_character(id: StringName) -> FaceProfile:
	var p := path_for(id)
	if not ResourceLoader.exists(p):
		return null
	return load(p) as FaceProfile

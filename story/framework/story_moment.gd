## One book scene as data (R13): where it happens, what opens it, and the
## steps it plays. A MomentSpace runs it; StoryDirector places it at its
## anchor when the region loads.
##
## Steps are dictionaries with a "do" key. See MomentSpace for the full list:
##   {"do": "control", "mode": "LOOK", "focus": "tamlin"}
##   {"do": "spawn", "actor": "tamlin", "at": Vector3(2, 0, -3)}
##   {"do": "wait", "s": 2.5}
##   {"do": "stay", "s": 20.0, "r": 4.0, "near": "tamlin"}
##   {"do": "interact", "n": 3}
##   {"do": "raise", "flag": "glamour_lifted"}
class_name StoryMoment
extends Resource

@export var id: StringName
## Chapter(s) in the book, for the Keeper's cross-check.
@export var chapters: String
## Story anchor (Marker3D in group "story_anchor", named this id) in a region
## scene. Empty: a global moment that lives under StoryDirector.
@export var anchor_id: StringName
@export var region_id: StringName
@export var require_flags: PackedStringArray = []
## Never starts once any of these is set. Defaults to the moment's gate flag.
@export var done_flags: PackedStringArray = []
@export var night_only: bool = false
## &"enter" (walk into entry_radius), &"interact" (E within entry_radius),
## &"auto" (as soon as the requirements are met).
@export var trigger: StringName = &"enter"
@export var entry_radius: float = 6.0
@export var steps: Array[Dictionary] = []
@export_multiline var notes: String

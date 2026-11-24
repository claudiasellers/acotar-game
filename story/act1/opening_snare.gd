## Feyre's own snare on the doe trail, empty (OpeningHunt). A station in the
## Interactor's sense: E uses it once, then it's only a snare in the snow.
class_name OpeningSnare
extends Node3D

var station_id: StringName = OpeningHunt.STATION_ID
var display_name: String = "snare"
var hunt: OpeningHunt


func use(_user: Node) -> void:
	if hunt:
		hunt.check_snare()

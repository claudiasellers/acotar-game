## Every PlaceSetting of a realm, looked up by place id. Lane L32.
class_name PlaceTable
extends Resource

@export var settings: Array[PlaceSetting] = []


func find(id: StringName) -> PlaceSetting:
	for s in settings:
		if s.id == id:
			return s
	return null

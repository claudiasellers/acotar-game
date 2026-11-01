## A named set of colours: the manor's paint stock or the colour book (L30).
class_name StudioPaintSet
extends Resource

@export var id: StringName
@export var names: PackedStringArray = PackedStringArray()
@export var colors: PackedColorArray = PackedColorArray()
@export var canon: String = "X"
@export_multiline var notes: String = ""


func size() -> int:
	return mini(names.size(), colors.size())

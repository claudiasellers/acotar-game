## The glint's slow twinkle (HouseProps.glint): a gentle pulse while visible.
class_name HouseGlint
extends Node3D

var _t: float = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var k := 0.75 + 0.25 * sin(_t * 3.1)
	scale = Vector3.ONE * k
	var light := get_child(0) as OmniLight3D
	if light:
		light.light_energy = 0.4 + 0.3 * k

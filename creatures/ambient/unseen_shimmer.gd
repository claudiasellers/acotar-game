## Before the glamour lifts the manor seems near-empty: servants and courtiers
## are only a shimmer in the air at the edge of Feyre's sight. A few of these
## wander slowly round their spawn point; spawn tables gate them to
## GLAMOURED_ONLY, so they vanish when `glamour_lifted` rises. Canon X.
class_name UnseenShimmer
extends Node3D

const SHADER := preload("res://creatures/ambient/unseen_shimmer.gdshader")

@export var count: int = 3
@export var radius: float = 10.0
@export var speed: float = 0.7
## They drift away when she comes close, the way a thing at the edge of
## sight slips off when you look straight at it.
@export var shy_distance: float = 3.0

var figures: Array[MeshInstance3D] = []

var _t: float = 0.0


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 1.8
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = offset_at(i, 0.0)
		add_child(mi)
		figures.append(mi)


## Where figure `i` is at time `t`: a slow walking loop, different per figure.
func offset_at(i: int, t: float) -> Vector3:
	var phase := float(i) * 2.399
	var r := radius * (0.45 + 0.5 * fposmod(phase * 0.37, 1.0))
	var a := phase + t * speed / maxf(r, 0.5)
	return Vector3(cos(a) * r, 0.9, sin(a) * r)


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	for i in figures.size():
		var target := offset_at(i, _t)
		if player:
			var away := global_position + target - player.global_position
			away.y = 0.0
			if away.length() < shy_distance and away.length() > 0.01:
				target += away.normalized() * (shy_distance - away.length())
		figures[i].position = figures[i].position.lerp(target, clampf(delta * 2.0, 0.0, 1.0))

## Hearth firelight: a soft, irregular flicker around the authored energy.
extends OmniLight3D

@export var flicker := 0.18
@export var speed := 7.0

var _base := 0.0
var _t := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_base = light_energy
	_noise.frequency = 0.5
	_noise.seed = get_instance_id() & 0xffff


func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = _base * (1.0 + flicker * _noise.get_noise_1d(_t))

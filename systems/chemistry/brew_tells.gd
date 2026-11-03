## How a drunk brew shows on Feyre without her glowing (lane L62-2). She has
## no magic of her own before she is Made (Keeper, ch 2): a brew acts on her,
## nothing comes from her. So the tells are the world reacting, drawn as
## scene-lit particles only (no lights, no EMISSION):
## - bright: pale motes in the air round her catch whatever light there is;
## - warm: a faint warmth haze rising off her shoulders;
## - cool: rime flecks drifting off her sleeves.
## Nothing emits while no brew is active.
class_name BrewTells
extends Node3D

const NODE_NAME := "BrewTells"
## Effect at or above this shows its tell; full strength at FULL.
const SHOW := 0.3
const FULL := 3.0
## tag -> look (colour, size, count, where, drift)
const TELLS := {
	&"bright": {"color": Color(1.0, 0.95, 0.78, 0.8), "size": 0.035, "amount": 40, "lifetime": 3.0,
		"at": Vector3(0, 1.1, 0), "box": Vector3(1.4, 0.9, 1.4), "velocity": 0.05, "gravity": Vector3(0, 0.02, 0)},
	&"warm": {"color": Color(1.0, 0.86, 0.8, 0.18), "size": 0.22, "amount": 10, "lifetime": 1.8,
		"at": Vector3(0, 1.45, 0), "box": Vector3(0.25, 0.05, 0.12), "velocity": 0.25, "gravity": Vector3(0, 0.15, 0)},
	&"cool": {"color": Color(0.93, 0.97, 1.0, 0.85), "size": 0.018, "amount": 24, "lifetime": 1.6,
		"at": Vector3(0, 1.05, 0), "box": Vector3(0.38, 0.25, 0.15), "velocity": 0.04, "gravity": Vector3(0, -0.35, 0)},
}

var target: Node3D
var _fx: Dictionary = {}  # tag -> GPUParticles3D


## Puts one set of tells on `player` (idempotent). Returns it.
static func ensure(player: Node3D) -> BrewTells:
	if player == null:
		return null
	var tells := player.get_node_or_null(NODE_NAME) as BrewTells
	if tells == null:
		tells = BrewTells.new()
		tells.name = NODE_NAME
		tells.target = player
		player.add_child(tells)
	return tells


func _ready() -> void:
	for tag: StringName in TELLS:
		_fx[tag] = _particles(TELLS[tag])
		add_child(_fx[tag])


func _process(_delta: float) -> void:
	var who := target if target else get_parent()
	for tag: StringName in _fx:
		var p: GPUParticles3D = _fx[tag]
		var v := BrewEffects.effect_of(who, tag)
		p.emitting = v >= SHOW
		p.amount_ratio = clampf(v / FULL, 0.25, 1.0)


## Which tells are showing now (for tests and shots).
func showing() -> Array[StringName]:
	var out: Array[StringName] = []
	for tag: StringName in _fx:
		if (_fx[tag] as GPUParticles3D).emitting:
			out.append(tag)
	return out


static func _particles(look: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(look.amount)
	p.lifetime = float(look.lifetime)
	p.emitting = false
	p.position = look.at
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = look.box
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = float(look.velocity) * 0.5
	mat.initial_velocity_max = float(look.velocity)
	mat.gravity = look.gravity
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	var grad := Gradient.new()
	var c: Color = look.color
	grad.set_color(0, Color(c, 0.0))
	grad.add_point(0.25, c)
	grad.set_color(grad.get_point_count() - 1, Color(c, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * float(look.size)
	# Lit by the scene (per-pixel), so they only show where there is light.
	var m := MaterialLibrary.surface()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_receive_shadows = true
	quad.material = m
	p.draw_pass_1 = quad
	return p

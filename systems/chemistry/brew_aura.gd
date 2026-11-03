## The soft faelight round Feyre while a bright brew lasts (lane L62): a warm
## pearly omni light, fading in and out, that follows her. No light at all
## when no brew is active, so it costs nothing the rest of the time.
class_name BrewAura
extends Node3D

const NODE_NAME := "BrewAura"
const COLOR := Color(1.0, 0.93, 0.98)
const RANGE := 7.0
const FADE := 0.8

var target: Node3D
var _light: OmniLight3D


## Puts one aura on `player` (idempotent). Returns it.
static func ensure(player: Node3D) -> BrewAura:
	if player == null:
		return null
	var aura := player.get_node_or_null(NODE_NAME) as BrewAura
	if aura == null:
		aura = BrewAura.new()
		aura.name = NODE_NAME
		aura.target = player
		player.add_child(aura)
	return aura


func _ready() -> void:
	position = Vector3(0, 1.4, 0)
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.omni_range = RANGE
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)


func _process(delta: float) -> void:
	var want := BrewEffects.glow_energy(target if target else get_parent())
	_light.light_energy = move_toward(_light.light_energy, want, delta * BrewEffects.MAX_ENERGY / FADE)
	_light.visible = _light.light_energy > 0.01


func energy() -> float:
	return _light.light_energy if _light else 0.0

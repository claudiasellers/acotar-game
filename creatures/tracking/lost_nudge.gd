## The nudge when Feyre has lost a creature she is following
## (plans/hostile-fae/health-interactions.md §3.6, rule 3). No marker and no
## meter: after FIRST_S out of her view and more than MIN_DISTANCE away, the
## creature gives one cue from where it is: its sound in 3D and a shake of
## snow off the brush above it. Still lost REPEAT_S later it cues again, at
## most MAX_CUES times. Seeing it starts everything over.
##
## `cued(count)` lets the scene's guide speak for her after the second cue.
class_name LostNudge
extends Node

signal cued(count: int)

const FIRST_S := 20.0
## Gentle Mode (GameSettings.gentle_mode) cues sooner.
const FIRST_GENTLE_S := 12.0
const REPEAT_S := 25.0
const MAX_CUES := 3
const MIN_DISTANCE := 15.0

var creature: Creature
var cue: StringName = &""
var wounded_only: bool = false
## Cues given since she last saw it.
var count: int = 0
## Seconds it has been out of her view, far enough to count as lost.
var unseen: float = 0.0

var _next_at: float = 0.0


static func on(c: Creature) -> LostNudge:
	if c.nudge == null:
		c.nudge = LostNudge.new()
		c.nudge.name = "LostNudge"
		c.nudge.creature = c
		c.add_child(c.nudge)
	return c.nudge


func first_after() -> float:
	return FIRST_GENTLE_S if GameSettings.gentle_mode else FIRST_S


func applies() -> bool:
	if creature == null or not creature.alive or creature.scripted:
		return false
	return not wounded_only or creature.bleeding > 0.0 or creature.health < creature.data.max_health


func _physics_process(delta: float) -> void:
	var her := creature.get_tree().get_first_node_in_group(&"player") as Node3D if creature else null
	if her == null or not applies():
		reset()
		return
	tick(delta, FollowLeash.sees(creature), her.global_position.distance_to(creature.global_position))


## One step of the rule, from whether she sees it and how far it is.
func tick(delta: float, seen: bool, distance: float) -> void:
	if seen:
		reset()
		return
	if distance <= MIN_DISTANCE or count >= MAX_CUES:
		return
	unseen += delta
	if count == 0:
		_next_at = first_after()
	if unseen < _next_at:
		return
	count += 1
	_next_at = unseen + REPEAT_S
	_give_cue()
	cued.emit(count)


func reset() -> void:
	count = 0
	unseen = 0.0


func _give_cue() -> void:
	if not creature.is_inside_tree():
		return
	var at := creature.global_position + Vector3.UP * creature.data.body_height
	if cue != &"":
		SoundDirector.cue(cue, at)
	creature.add_child(_snow_shake(creature.data.body_height))


## Snow shaken off the brush above it: a short white burst that falls.
static func _snow_shake(height: float) -> GPUParticles3D:
	var shake := GPUParticles3D.new()
	shake.name = "SnowShake"
	shake.position = Vector3(0.0, height + 1.2, 0.0)
	shake.amount = 48
	shake.lifetime = 1.8
	shake.one_shot = true
	shake.explosiveness = 0.85
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.9
	mat.direction = Vector3.DOWN
	mat.spread = 60.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0.0, -2.2, 0.0)
	mat.scale_min = 0.6
	mat.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	mat.color_ramp = ramp
	shake.process_material = mat
	var flake := QuadMesh.new()
	flake.size = Vector2(0.16, 0.16)
	var surface := MaterialLibrary.surface()
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surface.vertex_color_use_as_albedo = true
	surface.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake.material = surface
	shake.draw_pass_1 = flake
	shake.emitting = true
	shake.finished.connect(shake.queue_free)
	return shake

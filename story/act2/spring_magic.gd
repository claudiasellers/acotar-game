## Tamlin's magic made visible (owner, L86-31; Keeper: canon is invisible, the
## tang of magic only, so the glow is [X]). It is green, like his eyes, his
## tunic and Spring. Gold would read as his shift. Two uses at the manor's
## table: her chair sliding out for her, and the hands that press her back
## into it at the first dinner.
class_name SpringMagic
extends RefCounted

const GREEN := Color(0.45, 1.0, 0.55)
const PALE := Color(0.85, 1.0, 0.75)
## How far her chair slides out from the table, and how long it takes.
const PULL := 0.55
const PULL_SECONDS := 0.7


## The loose chair at the foot of the dining table (ManorHouseBuilder.LOOSE_AT),
## or null when the house isn't built (tests, a stand-in room).
static func foot_chair(from: Node) -> Node3D:
	if from == null or not from.is_inside_tree():
		return null
	for found in from.get_tree().root.find_children("FootChair", "Node3D", true, false):
		return found as Node3D
	return null


## Starts `chair` sliding `away` (a flat world direction) by PULL, glittering
## green. The scene steps the slide on its own clock (ChairSlide.step), so
## it keeps the story's time, paused or ticked by hand.
static func pull_out(chair: Node3D, away: Vector3) -> ChairSlide:
	var dir := Vector3(away.x, 0.0, away.z)
	var to := chair.global_position + (dir.normalized() * PULL if dir.length() > 0.01 else Vector3.ZERO)
	if chair.is_inside_tree():
		_glitter(chair, chair.global_position + Vector3.UP * 0.5, 0.0)
	return ChairSlide.new(chair, to, PULL_SECONDS)


## A chair easing from where it stands to `to` over `seconds`.
class ChairSlide:
	extends RefCounted
	var chair: Node3D
	var from: Vector3
	var to: Vector3
	var seconds: float
	var t: float = 0.0

	func _init(c: Node3D, target: Vector3, secs: float) -> void:
		chair = c
		from = c.global_position
		to = target
		seconds = secs

	## True once the chair is there (or gone).
	func step(delta: float) -> bool:
		if chair == null or not is_instance_valid(chair):
			return true
		t = minf(t + delta, seconds) if seconds > 0.0 else 1.0
		var k := t / seconds if seconds > 0.0 else 1.0
		chair.global_position = from.lerp(to, 0.5 - 0.5 * cos(k * PI))
		return k >= 1.0


## Her chair at the foot of the table, as a scene drives it: pulled out by
## his magic, tucked back under her or into its place. Step it from the
## scene's tick. A no-op when the house has no loose chair (tests, stand-ins).
class FootChair:
	extends RefCounted
	var chair: Node3D
	var home := Vector3.INF
	var slide: ChairSlide

	## Out from the table at `table` (world), glittering green.
	func pull(from: Node, table: Vector3) -> void:
		chair = SpringMagic.foot_chair(from)
		if chair == null:
			return
		home = chair.global_position
		slide = SpringMagic.pull_out(chair, chair.global_position - table)

	## Back to its place over `seconds` (0: at once).
	func tuck(seconds: float) -> void:
		if chair == null or not is_instance_valid(chair) or home == Vector3.INF:
			return
		slide = ChairSlide.new(chair, home, seconds)
		if seconds <= 0.0:
			step(0.0)

	func step(delta: float) -> void:
		if slide and slide.step(delta):
			slide = null

	func is_out() -> bool:
		return chair != null and is_instance_valid(chair) and home != Vector3.INF \
				and not chair.global_position.is_equal_approx(home)


## Green hands of light on her shoulders, pressing down: two streams of
## sparkles falling onto her arms, and a chime.
static func press_down(on: Node3D) -> void:
	if on == null or not on.is_inside_tree():
		return
	var side := on.global_basis.x
	side.y = 0.0
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	for s: float in [-1.0, 1.0]:
		_glitter(on, on.global_position + Vector3.UP * 1.35 + side * 0.24 * s, -2.2)
	Juice.burst(null, &"spring_magic", on.global_position + Vector3.UP * 1.2)


## One burst of green sparkles at `at`, thrown down at `fall` m/s (0: about).
static func _glitter(owner: Node3D, at: Vector3, fall: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "SpringMagic"
	p.one_shot = true
	p.amount = maxi(int(40.0 * Juice.effects_scale), 1)
	p.lifetime = 0.9
	p.explosiveness = 0.7
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.16 if fall < 0.0 else 0.4
	pm.direction = Vector3.DOWN if fall < 0.0 else Vector3.UP
	pm.spread = 25.0 if fall < 0.0 else 180.0
	pm.initial_velocity_min = absf(fall) * 0.6 if fall < 0.0 else 0.3
	pm.initial_velocity_max = absf(fall) if fall < 0.0 else 1.0
	pm.gravity = Vector3(0, -0.4, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, PALE)
	ramp.add_point(0.3, GREEN)
	ramp.set_color(ramp.get_point_count() - 1, Color(GREEN, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm
	p.draw_pass_1 = Juice.sparkle_mesh()
	var root: Node = owner.get_tree().current_scene if owner.get_tree().current_scene else owner.get_tree().root
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p

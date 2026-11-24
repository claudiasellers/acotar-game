## Steps a CharacterBody by exactly `dt` when a test calls _physics_process by
## hand (L75-15, a known harness trap under F50/F51).
##
## A test that hand-ticks a body passes its own delta, but move_and_slide moves
## by the engine's: inside a physics frame that is the physics step, outside
## one it is the process delta, which on a loaded run is up to 0.15 s. So a
## 1/30 s tick moves a body ~4.5x too far (and a 0.5 s tick too short): a naga
## overshoots her mid wind-up and the camp lands 1 hit in 60 s. tick() runs the
## body's step and rescales the motion it made to `dt`.
##
## Exact for a body with collision_mask 0 (the usual for brain tests). With
## collisions the slide happened at the engine's step, so the rescale is only
## close; keep such a body off the ground and set its height yourself.
##
## Usage: const BodyTick := preload("res://tests/fixtures/body_tick.gd")
##        BodyTick.tick(naga, DT)
extends RefCounted


## The delta move_and_slide uses right now.
static func engine_delta(node: Node) -> float:
	if Engine.is_in_physics_frame():
		return node.get_physics_process_delta_time()
	return node.get_process_delta_time()


## One _physics_process(dt) of `body`, with its motion scaled to dt.
static func tick(body: CharacterBody3D, dt: float) -> void:
	var before := body.global_position
	var engine_dt := engine_delta(body)
	body._physics_process(dt)
	if engine_dt > 0.0 and not is_equal_approx(engine_dt, dt):
		body.global_position = before + (body.global_position - before) * (dt / engine_dt)

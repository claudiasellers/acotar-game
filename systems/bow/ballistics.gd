## Arrow flight maths: gravity plus quadratic drag against the moving air.
class_name Ballistics
extends RefCounted


## New velocity after `dt` seconds. Drag acts on the velocity relative to the
## wind, so a crosswind pushes the arrow downwind and a headwind shortens it.
static func step(velocity: Vector3, wind: Vector3, drag: float, gravity: float, dt: float) -> Vector3:
	var air := velocity - wind
	var accel := -drag * air.length() * air + Vector3.DOWN * gravity
	return velocity + accel * dt


## Simulates a shot from height 0 until it falls back to `floor_y`. Returns
## {"distance": horizontal metres, "drift": metres along +X, "time": s}.
static func simulate(speed: float, elevation_degrees: float, drag: float, wind: Vector3,
		gravity: float = 9.8, dt: float = 1.0 / 120.0, floor_y: float = 0.0) -> Dictionary:
	var e := deg_to_rad(elevation_degrees)
	var v := Vector3(0.0, sin(e), -cos(e)) * speed
	var p := Vector3.ZERO
	var t := 0.0
	while t < 30.0:
		v = step(v, wind, drag, gravity, dt)
		p += v * dt
		t += dt
		if p.y < floor_y and v.y < 0.0:
			break
	return {"distance": Vector2(p.x, p.z).length(), "drift": p.x, "time": t}

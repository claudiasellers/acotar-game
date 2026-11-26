## Arrow flight maths: gravity plus quadratic drag against the moving air.
## An arrow from her bow flies dead straight to the crosshair first: gravity
## and wind have no share of it for `hold` seconds (BowData.true_range at the
## bow's speed) and then ease in over `blend` (gravity_share). The real arrow
## and every prediction step through the same two functions.
class_name Ballistics
extends RefCounted


## How much of gravity and wind acts on an arrow `flown` seconds into its
## flight: none for `hold` seconds, then rising to all of it over `blend`.
static func gravity_share(flown: float, hold: float, blend: float) -> float:
	if flown < hold:
		return 0.0
	if blend <= 0.0:
		return 1.0
	return clampf((flown - hold) / blend, 0.0, 1.0)


## New velocity after `dt` seconds. Drag acts on the velocity relative to the
## wind, so a crosswind pushes the arrow downwind and a headwind shortens it.
## `share` (gravity_share) scales gravity and the wind together.
static func step(velocity: Vector3, wind: Vector3, drag: float, gravity: float, dt: float,
		share: float = 1.0) -> Vector3:
	var air := velocity - wind * share
	var accel := -drag * air.length() * air + Vector3.DOWN * gravity * share
	return velocity + accel * dt


## Metres an arrow has dropped `after` seconds past the end of its straight
## flight, with gravity easing in over `blend` (drag left out: it is for the
## crosshair's far-shot mark, not for the flight).
static func drop_after(after: float, blend: float, gravity: float = 9.8) -> float:
	if after <= 0.0:
		return 0.0
	if blend <= 0.0:
		return 0.5 * gravity * after * after
	if after < blend:
		return gravity * after * after * after / (6.0 * blend)
	var rest := after - blend
	return gravity * (blend * blend / 6.0 + 0.5 * blend * rest + 0.5 * rest * rest)


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

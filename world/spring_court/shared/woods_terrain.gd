## Shared maths for woods height providers: edge fade to the macro map,
## noise, and the carve/flatten operations features apply to the ground.
class_name WoodsTerrain
extends RefCounted

## Width of the band along a region's edge where its detail fades to the
## macro map (world contract v1: 64 m).
const EDGE_FADE := 64.0


## 1 deep inside `bounds`, 0 at its edge (smoothstep over EDGE_FADE).
static func edge_weight(bounds: Rect2, x: float, z: float) -> float:
	var d := minf(minf(x - bounds.position.x, bounds.end.x - x), minf(z - bounds.position.y, bounds.end.y - z))
	return smoothstep(0.0, EDGE_FADE, d)


static func make_noise(seed_value: int, frequency: float, octaves: int = 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	return n


## A smooth bowl: `depth` metres at the centre, 0 at `radius`.
static func hollow(x: float, z: float, center: Vector2, radius: float, depth: float) -> float:
	var t := clampf(Vector2(x, z).distance_to(center) / radius, 0.0, 1.0)
	return -depth * (1.0 - smoothstep(0.0, 1.0, t))


## How strongly a channel of the given half-depth carves at a signed edge
## distance `d` (negative inside the channel). Banks slope over `bank` m.
static func channel(d: float, depth: float, bank: float = 5.0) -> float:
	return -depth * (1.0 - smoothstep(-1.0, bank, d))


## 0..1: how much a road/path flattens the ground at edge distance `d`.
static func path_weight(d: float, shoulder: float = 2.5) -> float:
	return 1.0 - smoothstep(0.0, shoulder, d)

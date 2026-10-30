## The shared low-frequency height of the whole map. Every lane's height
## provider fades back to this at its edges, so neighbouring regions meet
## without seams. Also carves the Thornwater river, which several lanes share.
class_name MacroHeight
extends RefCounted

const SEED := 1814
const RIVER_HALF_WIDTH := 7.0
const RIVER_DEPTH := 2.6
## Distance over which the banks ease back up to the land.
const RIVER_BANK := 20.0

## The Thornwater, upstream to downstream, in world XZ. Owned jointly: the
## wider-court lane drew it; edit points here (and say so in your handoff).
static var THORNWATER := PackedVector2Array([
	Vector2(-1700.0, -1550.0), Vector2(-1350.0, -1150.0), Vector2(-1050.0, -850.0),
	Vector2(-1100.0, -350.0), Vector2(-950.0, 150.0), Vector2(-820.0, 520.0),
	Vector2(-700.0, 800.0), Vector2(-350.0, 980.0), Vector2(100.0, 1060.0),
	Vector2(500.0, 1100.0), Vector2(1000.0, 1000.0), Vector2(1450.0, 1180.0),
	Vector2(1900.0, 1300.0),
])

static var _hills: FastNoiseLite
static var _rolling: FastNoiseLite


static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var h := land_height_at(x, z)
	var d := distance_to_river(x, z)
	if d < RIVER_HALF_WIDTH + RIVER_BANK:
		var bed := h - RIVER_DEPTH
		var t := clampf((d - RIVER_HALF_WIDTH) / RIVER_BANK, 0.0, 1.0)
		h = lerpf(bed, h, t * t * (3.0 - 2.0 * t))
	return h


## Height before the river is carved. Providers that build their own banks
## can start from this.
static func land_height_at(x: float, z: float) -> float:
	_ensure_noise()
	var h := 8.0 + _hills.get_noise_2d(x, z) * 22.0 + _rolling.get_noise_2d(x, z) * 5.0
	# Western fells climb toward the escarpment.
	h += smoothstep(-700.0, -1750.0, x) * 110.0
	# Autumn foothills rise in the north-west.
	h += smoothstep(-1200.0, -1800.0, z) * smoothstep(-400.0, -1500.0, x) * 70.0
	# The human realm is a broad, lower farmed valley falling south from the Wall.
	h -= smoothstep(WorldMap.WALL_Z - 100.0, WorldMap.WALL_Z + 400.0, z) * 5.0
	return h


static func distance_to_river(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for i in THORNWATER.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, THORNWATER[i], THORNWATER[i + 1])
		best = minf(best, p.distance_to(q))
	return best


static func _ensure_noise() -> void:
	if _hills != null:
		return
	_hills = FastNoiseLite.new()
	_hills.seed = SEED
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 1.0 / 900.0
	_hills.fractal_octaves = 3
	_rolling = FastNoiseLite.new()
	_rolling.seed = SEED + 1
	_rolling.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rolling.frequency = 1.0 / 180.0
	_rolling.fractal_octaves = 2

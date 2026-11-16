class_name CourtMotes
extends MultiMeshInstance3D
## The small lights adrift in the air over the starlight pool's hollow, and
## the string of them down the Glimmer Brook's outer bank from the pool to
## Willow Mere (CourtGlenPlaces: "follow the lights"). They come out as the
## day goes and are gone by full morning (the game's Clock; a still picture
## sets `shown` itself).

const POOL := CourtGlenPlanting.POOL
const COUNT := 280
## Lit from within, past the bloom's threshold.
const GLOW := Color(2.6, 2.5, 1.9)

## Left to the clock when < 0; else 0 hides them and 1 shows them.
var shown := -1.0
var _wait := 0.0


static func build(region: Node3D, content: CourtRegionContent) -> void:
	if content.place_planting != CourtGlenPlanting.ID or not content.owns(POOL):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([content.seed, "motes"])
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 6
	mote.rings = 3
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = GLOW
	mote.material = lit
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mote
	mm.instance_count = COUNT
	var brim := WorldHeight.height_at(POOL.x + CourtGlenPlanting.POOL_RADIUS + 1.0, POOL.y)
	var origin := Vector3(POOL.x, brim, POOL.y)
	for i in COUNT:
		# most over the water and the bluebells, a few out across the floor
		var p := POOL + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * (CourtGlenPlanting.FLOOR + 4.0)
		var y := maxf(WorldHeight.height_at(p.x, p.y), brim) + rng.randf_range(0.35, 3.2)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.6, 1.5)), Vector3(p.x, y, p.y) - origin))
	var node := CourtMotes.new()
	node.name = "Motes"
	node.multimesh = mm
	node.position = origin
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 260.0
	node.visible = false
	region.add_child(node)
	# the brook's: bigger and steadier, one after another along the bank, seen from further off
	var string := CourtGlenPlaces.lights(content)
	if string.is_empty():
		return
	var along := MultiMesh.new()
	along.transform_format = MultiMesh.TRANSFORM_3D
	along.mesh = mote
	along.instance_count = string.size()
	var mid := string[string.size() / 2]
	for i in string.size():
		along.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(1.5, 2.3)), string[i] - mid))
	var brook := CourtMotes.new()
	brook.name = "MotesBrook"
	brook.multimesh = along
	brook.position = mid
	brook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brook.visibility_range_end = 420.0
	brook.visible = false
	region.add_child(brook)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = 1.0
	if shown >= 0.0:
		visible = shown > 0.5
		return
	var clock := get_tree().root.get_node_or_null(^"Clock")
	if clock == null:
		return
	visible = out_at(float(clock.get(&"time_of_day")))


## Whether the lights are out at a time of day (0..1): from the golden hour
## through the night.
static func out_at(time_of_day: float) -> bool:
	var elevation := sin((time_of_day - 0.25) * TAU)
	return GradeDirector.night_amount(elevation) + GradeDirector.golden_amount(elevation) > 0.25

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
## The brook's lights: warm, so they stand out from the snowdrops they hang
## over, each with a soft halo (the day grades' glow is too slight to give one).
const BROOK_GLOW := Color(3.2, 2.5, 1.25)
const BROOK_HALO := Color(1.0, 0.8, 0.42, 0.5)
const BROOK_HALO_SIZE := 1.5

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
	# the brook's: bigger, warm and steadier, one after another along the bank, seen from further off
	var string := CourtGlenPlaces.lights(content)
	if string.is_empty():
		return
	var lamp := mote.duplicate() as SphereMesh
	var warm := lit.duplicate() as StandardMaterial3D
	warm.albedo_color = BROOK_GLOW
	lamp.material = warm
	var halo := QuadMesh.new()
	halo.size = Vector2.ONE * BROOK_HALO_SIZE
	var soft := StandardMaterial3D.new()
	soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	soft.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	soft.billboard_keep_scale = true
	soft.no_depth_test = false
	soft.albedo_color = BROOK_HALO
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	var disc := GradientTexture2D.new()
	disc.gradient = ramp
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	disc.width = 64
	disc.height = 64
	soft.albedo_texture = disc
	halo.material = soft
	var mid := string[string.size() / 2]
	for part: Array in [["MotesBrook", lamp, 2.6, 3.6], ["MotesBrookHalo", halo, 0.8, 1.25]]:
		var along := MultiMesh.new()
		along.transform_format = MultiMesh.TRANSFORM_3D
		along.mesh = part[1]
		along.instance_count = string.size()
		var sizes := RandomNumberGenerator.new()
		sizes.seed = hash([content.seed, "brook lights"])
		for i in string.size():
			along.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sizes.randf_range(part[2], part[3])), string[i] - mid))
		var brook := CourtMotes.new()
		brook.name = part[0]
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

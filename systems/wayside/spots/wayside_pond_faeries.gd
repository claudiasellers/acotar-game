## The pond-faeries [C ch 14]: "four shining female heads poking up from the
## bright water" of a pond below a towering hill, watching her. They turn to
## follow her, never blink, and sink one by one if she comes close. No
## sparkle and no chime: this is the unsettling side of the court (R3).
class_name WaysidePondFaeries
extends WaysideSpotNode

const MODEL := "res://creatures/models/people/fae_nymph.gltf"
## Their own still pool, so the heads always sit in water even where no
## region lays the river's surface.
const POOL_MATERIAL := "res://world/spring_court/wider/fx/materials/mat_water_lake.tres"
const COUNT := 4
## They sink when she comes this near.
const SINK_RADIUS := 13.0
## They notice her from here.
const WATCH_RADIUS := 45.0
## How much of the figure stays above the water (metres from the crown).
const SHOW := 0.42

var heads: Array[Node3D] = []
var _sunk := 0.0


func build() -> void:
	var scene := load(MODEL) as PackedScene
	var water_y := float(spot.param("water_y", spot.position.y))
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = float(spot.param("pool_radius", 8.0))
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	disc.radial_segments = 32
	disc.rings = 1
	pool.mesh = disc
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ResourceLoader.exists(POOL_MATERIAL):
		pool.material_override = load(POOL_MATERIAL)
	pool.position.y = water_y - spot.position.y
	add_child(pool)
	# The lake material is translucent, so without a floor the bodies under
	# the surface show through. An opaque dark disc just under it reads as
	# deep water and leaves only the heads.
	var floor_mi := MeshInstance3D.new()
	var floor_disc := CylinderMesh.new()
	floor_disc.top_radius = disc.top_radius - 0.05
	floor_disc.bottom_radius = floor_disc.top_radius
	floor_disc.height = 0.02
	floor_disc.radial_segments = 32
	floor_disc.rings = 1
	floor_mi.mesh = floor_disc
	floor_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var deep := StandardMaterial3D.new()
	deep.albedo_color = Color(0.06, 0.16, 0.18)
	deep.roughness = 0.9
	floor_mi.material_override = deep
	floor_mi.position.y = pool.position.y - 0.1
	add_child(floor_mi)
	for i in COUNT:
		var a := TAU * float(i) / COUNT + 0.4
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(a), 0.0, sin(a)) * float(spot.param("spread", 2.2))
		pivot.position.y = water_y - spot.position.y
		add_child(pivot)
		var body: Node3D = scene.instantiate() if scene else Node3D.new()
		# Sink the figure so only the head and the top of the hair are above water.
		body.position.y = SHOW - float(spot.param("figure_height", 1.65))
		pivot.add_child(body)
		heads.append(pivot)


func _process(delta: float) -> void:
	var p := player()
	if p == null:
		return
	var d := flat_distance_to_player()
	for i in heads.size():
		var h := heads[i]
		if d < WATCH_RADIUS:
			var to := p.global_position - h.global_position
			h.rotation.y = lerp_angle(h.rotation.y, atan2(to.x, to.z), clampf(delta * (0.6 + i * 0.15), 0.0, 1.0))
	if d < SINK_RADIUS:
		if not found():
			complete()
		_sunk = minf(_sunk + delta * 0.5, 1.0)
	elif d > WATCH_RADIUS:
		_sunk = maxf(_sunk - delta * 0.2, 0.0)
	for i in heads.size():
		# One after another: the far one first, the last a beat later.
		var s := clampf(_sunk * 1.6 - i * 0.2, 0.0, 1.0)
		heads[i].position.y = float(spot.param("water_y", spot.position.y)) - spot.position.y - s * (SHOW + 0.15)

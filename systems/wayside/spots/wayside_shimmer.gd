## The corner shimmer [C ch 14]: something glimmers at the edge of her sight;
## when she turns to look straight at it, it is only "sunlight dancing on a
## nearby stream, or the wind fluttering the leaves of a lone sycamore atop a
## knoll". After the glamour lifts it is one of the court's small folk, who
## slips away [X]. A looking beat: no key, no reward, a thought the first time.
## (Never the Bogge's cold shimmer of ch 10: that one belongs to the dread.)
class_name WaysideShimmer
extends WaysideSpotNode

## Within this many degrees of straight-on it resolves.
const LOOK_DEGREES := 7.0
## It only catches the eye between these distances.
const NEAR := 6.0
const FAR := 55.0

const LIFTED_FLAG := "glamour_lifted"
const FOLK := "res://creatures/models/people/fae_pixie.gltf"

var shimmer: MeshInstance3D
## After the glamour lifts: the small faerie that was the shimmer all along.
var folk: Node3D
var _fade := 1.0
var _resolved := false
var _flit := 0.0


func build() -> void:
	if spot.param("tree", "") != "":
		add_model(StringName(spot.param("tree")), spot.target - spot.position, 0.0, float(spot.param("tree_scale", 1.0)))
	shimmer = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 2.0)
	shimmer.mesh = quad
	var mat := MaterialLibrary.surface()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.97, 0.88, 0.0)
	mat.albedo_texture = _soft_texture()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.92, 0.8)
	mat.emission_energy_multiplier = 0.6
	shimmer.material_override = mat
	shimmer.position = spot.target - spot.position + Vector3.UP * 1.4
	add_child(shimmer)
	_resolved = found()
	if bool(WorldState.get_flag(LIFTED_FLAG, false)):
		var scene := load(FOLK) as PackedScene
		if scene:
			folk = scene.instantiate()
			folk.position = shimmer.position - Vector3.UP * 0.6
			folk.scale = Vector3.ONE * 0.5
			add_child(folk)


func _process(delta: float) -> void:
	var p := player()
	var mat := shimmer.material_override as CandyMaterial
	if p == null or not p is Feyre or (p as Feyre).camera == null:
		return
	var cam := (p as Feyre).camera
	var to := shimmer.global_position - cam.global_position
	var dist := to.length()
	var angle := rad_to_deg(acos(clampf((-cam.global_basis.z).dot(to.normalized()), -1.0, 1.0)))
	# Visible only at the edge of sight: brightest 25-45 degrees off-centre.
	var edge := clampf(1.0 - absf(angle - 35.0) / 18.0, 0.0, 1.0)
	var in_range := dist > NEAR and dist < FAR
	var t := sin(Time.get_ticks_msec() * 0.004) * 0.5 + 0.5
	var want := edge * (0.35 + 0.25 * t) if in_range else 0.0
	if angle < LOOK_DEGREES and in_range:
		_fade = 0.0
		if folk:
			_flit = 0.01
		if not _resolved:
			_resolved = true
			complete(true, String(spot.param("lifted_line", "")) if folk else "")
	else:
		_fade = minf(1.0, _fade + delta * 0.25)
	if folk and _flit > 0.0:
		_flit += delta
		folk.position += Vector3(0.6, 1.4, -0.8) * delta * 3.0
		folk.visible = _flit < 1.2
	mat.albedo_color.a = lerpf(mat.albedo_color.a, want * _fade, clampf(delta * 6.0, 0.0, 1.0))


static func _soft_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	return tex

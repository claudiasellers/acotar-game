## A pulsing glint on an arrow that has landed in the ground or snow, so a
## missed arrow is never lost (T121). Ash arrows (the story's mandatory ones)
## get a bright glint, a soft light and a tall beacon seen through the woods;
## other arrows get a small glint only, and only a few at a time.
## It is a child of the arrow and frees itself when the arrow is picked up
## (leaves Arrow.STUCK_GROUP) or freed.
class_name ArrowGlimmer
extends Node3D

const GROUP := &"arrow_glimmer"
## Warm gold with a deep amber rim: reads on white snow and in dusk shade.
const CORE := Color(1.0, 0.82, 0.25)
const RIM := Color(1.0, 0.42, 0.05)
## Glint pixel_size with fixed_size on a 64 px texture: about 32 px on a 1080p screen
## at any distance (0.0005 x 64 = 0.032 of the screen height). Colours stay <= 1.0, under the glow threshold.
const ASH_GLINT := 0.00050
const WOOD_GLINT := 0.00008
const PULSE_HZ := 1.1
const LIGHT_ENERGY := 0.8
const LIGHT_RANGE := 1.8
const BEACON_HEIGHT := 7.0
const BEACON_WIDTH := 0.22
## Warm circle on the snow around the arrow (diameter, m).
const POOL_SIZE := 3.0
## At most this many non-ash arrows glimmer at once; ash always does.
const WOOD_CAP := 3

var arrow: Arrow = null
var is_ash: bool = false
var light: OmniLight3D = null
var _glint: Sprite3D = null
var _beacon: MeshInstance3D = null
var _pool: MeshInstance3D = null
var _t: float = 0.0


## Called once an arrow has stuck. Does nothing for an arrow lodged in a
## creature (it has on_arrow_hit), or a wood arrow over the cap.
static func attach(arrow: Arrow, body: Node) -> ArrowGlimmer:
	if body != null and body.has_method(&"on_arrow_hit"):
		return null
	var ash := arrow.arrow_id == &"ash"
	if not ash and arrow.get_tree().get_nodes_in_group(GROUP).size() >= WOOD_CAP:
		return null
	var g := ArrowGlimmer.new()
	g.name = "ArrowGlimmer"
	g.arrow = arrow
	g.is_ash = ash
	arrow.add_child(g)
	return g


static func of(arrow: Node) -> ArrowGlimmer:
	return arrow.get_node_or_null(^"ArrowGlimmer") as ArrowGlimmer


func _ready() -> void:
	add_to_group(GROUP)
	# World-oriented (beam upright, pool flat) whatever way the arrow is tilted.
	top_level = true
	global_position = arrow.global_position
	_t = randf() * TAU
	_glint = Sprite3D.new()
	_glint.name = "Glint"
	_glint.texture = _star()
	_glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glint.fixed_size = true
	_glint.pixel_size = ASH_GLINT if is_ash else WOOD_GLINT
	_glint.shaded = false
	_glint.no_depth_test = true
	_glint.render_priority = 10
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glint)
	if not is_ash:
		return
	light = OmniLight3D.new()
	light.name = "GlimmerLight"
	light.light_color = CORE
	light.light_energy = LIGHT_ENERGY
	light.omni_range = LIGHT_RANGE
	light.shadow_enabled = false
	add_child(light)
	var disc := QuadMesh.new()
	disc.size = Vector2(POOL_SIZE, POOL_SIZE)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_texture = _radial()
	pmat.albedo_color = Color(1, 1, 1, 0.8)
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material = pmat
	_pool = MeshInstance3D.new()
	_pool.name = "Pool"
	_pool.mesh = disc
	_pool.rotation_degrees = Vector3(-90, 0, 0)
	_pool.position = Vector3(0, 0.06, 0)
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pool)
	var beam := QuadMesh.new()
	beam.size = Vector2(BEACON_WIDTH, BEACON_HEIGHT)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.albedo_texture = _beam_texture()
	mat.no_depth_test = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material = mat
	_beacon = MeshInstance3D.new()
	_beacon.name = "Beacon"
	_beacon.mesh = beam
	_beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.position = Vector3(0.0, BEACON_HEIGHT * 0.5, 0.0)
	add_child(_beacon)


func _process(delta: float) -> void:
	if arrow == null or not is_instance_valid(arrow) or not arrow.is_in_group(Arrow.STUCK_GROUP):
		_remove()
		return
	_t += delta * TAU * PULSE_HZ
	var pulse := 0.5 + 0.5 * sin(_t)
	_glint.modulate = Color(1, 1, 1, 0.55 + 0.45 * pulse)
	_glint.scale = Vector3.ONE * (0.7 + 0.6 * pulse)
	if light:
		light.light_energy = LIGHT_ENERGY * (0.5 + 0.5 * pulse)
	if _beacon:
		(_beacon.mesh as QuadMesh).material.albedo_color = Color(1, 1, 1, 0.75 + 0.25 * pulse)


func _remove() -> void:
	remove_from_group(GROUP)
	set_process(false)
	queue_free()


## Soft warm disc for the pool on the snow: amber, not white, so it shows on snow.
static func _radial() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(CORE, 0.55), Color(RIM, 0.3), Color(RIM, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## A four-point star: bright core, long thin rays along both axes, amber rim.
static func _star() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (x + 0.5) / n * 2.0 - 1.0
			var dy := (y + 0.5) / n * 2.0 - 1.0
			var r := Vector2(dx, dy).length()
			var core := clampf(1.0 - r / 0.28, 0.0, 1.0)
			var ray := maxf(clampf(1.0 - absf(dx) / 0.07, 0.0, 1.0) * clampf(1.0 - absf(dy), 0.0, 1.0), clampf(1.0 - absf(dy) / 0.07, 0.0, 1.0) * clampf(1.0 - absf(dx), 0.0, 1.0))
			var a := clampf(maxf(core * 1.5, ray), 0.0, 1.0)
			var col := RIM.lerp(Color(1, 0.97, 0.8), clampf(core * 1.4, 0.0, 1.0))
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


## Saturated gold with an amber edge across, solid at the foot and fading upward.
static func _beam_texture() -> ImageTexture:
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var up := float(y) / (h - 1)   # 0 = top of the quad, 1 = foot
		var fade := clampf(up * 1.15, 0.0, 1.0)
		for x in w:
			var across := absf((x + 0.5) / w * 2.0 - 1.0)   # 0 centre, 1 edge
			var col := CORE.lerp(RIM, clampf(across * across * 1.2, 0.0, 1.0))
			var a := clampf(1.0 - across * across * 0.5, 0.0, 1.0) * fade
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)

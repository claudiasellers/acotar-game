## Feyre's painting nook (L30): dresses the floor around her easel so it reads
## as a place made for painting, not an easel left on an open floor. Built at
## run time as one child of the easel station, in the station's own frame
## (the easel's canvas faces -Z, where she stands to paint), so the manor's
## generated house layout stays untouched:
## - a rose arbor behind the easel with a garland and two floating faelights;
## - a round rug where she stands and a paint-spattered drop cloth under the easel;
## - the paint table at her right hand, canvases leaning at her left;
## - a still-life subject (roses on a side table) seen past the canvas;
## - potted roses at the arbor posts, a warm pink light, drifting petals,
##   gold motes, and a soft wind chime that only carries a few metres.
##   StudioNook.dress(easel_station)   # manor_house_builder, station_id easel
class_name StudioNook
extends RefCounted

const NAME := "StudioNook"
## Where she stands to paint, in the station's frame.
const STAND := Vector3(0, 0, -2.2)
## [prop id, position, yaw degrees, extra pitch degrees]; positions are in
## the station's frame, +X her left as she paints, +Z beyond the easel.
const PROPS: Array = [
	[&"rug_round", Vector3(0, 0.006, -1.5), 0.0, 0.0],
	[&"arch_trellis", Vector3(0, 0, 1.1), 0.0, 0.0],
	[&"flower_garland", Vector3(0, 2.75, 0.95), 0.0, 0.0],
	[&"potted_roses", Vector3(1.55, 0, 1.15), 0.0, 0.0],
	[&"potted_roses", Vector3(-1.55, 0, 1.15), 25.0, 0.0],
	[&"paint_table", Vector3(-1.45, 0, -1.2), -90.0, 0.0],
	[&"canvas_stack", Vector3(1.55, 0, -0.6), 100.0, 0.0],
	[&"table_side", Vector3(0.75, 0, 2.3), 0.0, 0.0],
	[&"vase_roses", Vector3(0.75, 0.7, 2.3), 0.0, 0.0],
	[&"faelight_orb", Vector3(1.05, 2.15, 1.0), 0.0, 0.0],
	[&"faelight_orb", Vector3(-1.05, 2.3, 1.0), 0.0, 0.0],
]
## The round rug (3 m) trimmed to the spot where she stands.
const RUG_SCALE := 0.85
const CLOTH_SIZE := Vector2(2.1, 1.5)
const LIGHT_COLOR := Color(1.0, 0.82, 0.86)
const CHIME_NOTES: Array[float] = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0, 2093.0]
const CHIME_SECONDS := 14.0

static var _chime: AudioStreamWAV = null


## Adds the nook once; returns it. `floor_y` is the floor's height in the
## station's frame (0 for the manor's stations, which sit on the floor).
static func dress(station: Node3D, floor_y: float = 0.0) -> Node3D:
	var nook := station.get_node_or_null(NAME) as Node3D
	if nook:
		return nook
	nook = Node3D.new()
	nook.name = NAME
	nook.position.y = floor_y
	station.add_child(nook)
	for e: Array in PROPS:
		var id: StringName = e[0]
		if not PropLib.has(id):
			continue
		var prop := PropLib.build(id)
		prop.position = e[1]
		prop.rotation_degrees = Vector3(e[3], e[2], 0.0)
		if id == &"rug_round":
			prop.scale = Vector3(RUG_SCALE, 1.0, RUG_SCALE)
		nook.add_child(prop)
	nook.add_child(_drop_cloth())
	nook.add_child(_light())
	nook.add_child(_petals())
	nook.add_child(_motes())
	nook.add_child(_chime_player())
	return nook


## A linen drop cloth under the easel, spattered in her paints.
static func _drop_cloth() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "DropCloth"
	var plane := PlaneMesh.new()
	plane.size = CLOTH_SIZE
	mi.mesh = plane
	mi.position = Vector3(0, 0.014, 0.05)
	mi.rotation_degrees.y = 6.0
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(_cloth_image())
	mat.roughness = 0.95
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _cloth_image() -> Image:
	const W := 256
	const H := 184
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1263
	var linen := Color(0.97, 0.94, 0.88)
	for y in H:
		for x in W:
			# A soft weave and a folded, slightly darker hem.
			var weave := 0.012 * sin(x * 1.7) + 0.012 * sin(y * 1.9)
			var hem := 0.04 if (x < 8 or x > W - 9 or y < 8 or y > H - 9) else 0.0
			img.set_pixel(x, y, linen.darkened(0.03 + weave + hem))
	var paints := [EstateKit.ROSE, EstateKit.PERIWINKLE, EstateKit.MINT, EstateKit.BUTTER,
		EstateKit.LILAC, EstateKit.BLUSH, EstateKit.GOLD]
	for i in 70:
		var c: Color = paints[rng.randi() % paints.size()]
		var at := Vector2(rng.randf_range(10, W - 10), rng.randf_range(10, H - 10))
		var r := rng.randf_range(1.5, 6.0) if i % 5 else rng.randf_range(6.0, 11.0)
		_splat(img, at, r, c, rng)
	return img


static func _splat(img: Image, at: Vector2, r: float, c: Color, rng: RandomNumberGenerator) -> void:
	var blobs := 1 + rng.randi() % 4
	for b in blobs:
		var o := at + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r)) * 0.8
		var br := r * (1.0 if b == 0 else rng.randf_range(0.3, 0.6))
		for y in range(int(o.y - br), int(o.y + br) + 1):
			for x in range(int(o.x - br), int(o.x + br) + 1):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var d := Vector2(x, y).distance_to(o) / br
				if d <= 1.0:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, 0.85 if d < 0.8 else 0.5))


static func _light() -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "NookLight"
	l.light_color = LIGHT_COLOR
	l.light_energy = 1.1
	l.omni_range = 4.8
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = Vector3(0, 2.3, -0.7)
	return l


## Rose petals drifting down through the arbor.
static func _petals() -> CPUParticles3D:
	var p := _drift("Petals", 18, 9.0)
	p.position = Vector3(0, 2.7, 0.3)
	p.emission_box_extents = Vector3(1.4, 0.15, 1.6)
	p.direction = Vector3(0.3, -1, 0.1)
	p.spread = 25.0
	p.gravity = Vector3(0.05, -0.18, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.15
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.1, 0.85, 1.0])
	grad.colors = PackedColorArray([Color(EstateKit.ROSE, 0.0), EstateKit.ROSE, EstateKit.BLUSH, Color(EstateKit.BLUSH, 0.0)])
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.035)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _petal_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = m
	p.mesh = quad
	return p


## Slow gold motes rising in the light, the "something here" sparkle.
static func _motes() -> CPUParticles3D:
	var p := _drift("Motes", 22, 6.0)
	p.position = Vector3(0, 0.6, -0.4)
	p.emission_box_extents = Vector3(1.5, 0.5, 1.5)
	p.direction = Vector3.UP
	p.spread = 30.0
	p.gravity = Vector3(0, 0.03, 0)
	p.initial_velocity_min = 0.04
	p.initial_velocity_max = 0.12
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.9, 0.6, 0.0), Color(1, 0.9, 0.6, 0.9), Color(1, 0.85, 0.95, 0.7), Color(1, 0.85, 0.95, 0.0)])
	p.color_ramp = grad
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = Juice._star_texture()
	quad.material = m
	p.mesh = quad
	return p


static func _drift(node_name: String, amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = maxi(int(amount * Juice.effects_scale), 1)
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _petal_texture() -> ImageTexture:
	const N := 24
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var u := (x + 0.5) / N * 2.0 - 1.0
			var v := (y + 0.5) / N * 2.0 - 1.0
			# A teardrop: wider at the top, a notch at the tip.
			var w := 0.75 - 0.35 * v
			var d := (u * u) / (w * w) + v * v
			var a := clampf((1.0 - d) * 4.0, 0.0, 1.0)
			var shade := 1.0 - 0.15 * maxf(v, 0.0)
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return ImageTexture.create_from_image(img)


## A wind chime, soft and close: a few slow bell notes, looped.
static func _chime_player() -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.name = "NookChime"
	s.stream = chime_stream()
	s.volume_db = -16.0
	s.unit_size = 1.5
	s.max_distance = 9.0
	s.position = Vector3(1.0, 2.4, 1.0)
	s.autoplay = true
	return s


static func chime_stream() -> AudioStreamWAV:
	if _chime:
		return _chime
	var rate := 22050
	var frames := int(rate * CHIME_SECONDS)
	var buf := PackedFloat32Array()
	buf.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	var t0 := 0.4
	while t0 < CHIME_SECONDS - 2.5:
		var f: float = CHIME_NOTES[rng.randi() % CHIME_NOTES.size()]
		var amp := rng.randf_range(0.5, 1.0)
		var start := int(t0 * rate)
		for i in range(start, mini(start + int(2.4 * rate), frames)):
			var lt := float(i - start) / rate
			buf[i] += amp * (sin(TAU * f * lt) + 0.3 * sin(TAU * f * 2.76 * lt) * exp(-lt * 5.0)) \
					* exp(-lt * 2.2) * minf(lt * 300.0, 1.0)
		# Clusters of two or three, then a rest, the way a breeze catches them.
		t0 += rng.randf_range(0.18, 0.4) if rng.randf() < 0.6 else rng.randf_range(1.6, 3.2)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		data.encode_s16(i * 2, clampi(int(buf[i] * 0.18 * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	_chime = wav
	return wav

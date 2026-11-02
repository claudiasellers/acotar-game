## Feyre's painting corner (L30): dresses the floor around her easel so it
## reads as a painter's corner of the manor, not an easel left on an open
## floor. Built at run time as one child of the easel station, in the
## station's own frame (the canvas faces -Z, where she stands to paint), so the
## manor's generated house layout stays untouched. Her easel stands with the
## tall south window at her back, the painter's light over her shoulder:
## - curtains tied back either side of that window on a gilt rod, and daylight
##   falling through it onto the canvas (off at night), dust motes in the beam;
## - a round rug where she stands and a paint-spattered drop cloth under the easel;
## - the paint table at her right hand and a studio stool behind her;
## - at her left, a low shelf of pigment jars, unframed canvases leaning on it
##   and a framed one beside them;
## - a still-life subject (roses on a side table) seen past the canvas;
## - a gilt candlestand and a warm lamp glow for the evenings.
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
	[&"floor_candlestand", Vector3(-1.5, 0, 0.3), 0.0, 0.0],
	[&"stool", Vector3(1.0, 0, -3.1), 15.0, 0.0],
	[&"bookcase_low", Vector3(2.35, 0, -0.9), 90.0, 0.0],
	[&"pigment_jars", Vector3(2.35, 1.2, -1.35), 90.0, 0.0],
	[&"pigment_jars", Vector3(2.35, 1.2, -0.45), 80.0, 0.0],
	[&"painting_medium", Vector3(2.0, 0, 0.75), 80.0, -12.0],
	[&"paint_table", Vector3(-1.45, 0, -1.2), -90.0, 0.0],
	[&"canvas_stack", Vector3(1.55, 0, -0.6), 100.0, 0.0],
	[&"table_side", Vector3(0.75, 0, 2.3), 0.0, 0.0],
	[&"vase_roses", Vector3(0.75, 0.7, 2.3), 0.0, 0.0],
]
## The round rug (3 m) trimmed to the spot where she stands.
const RUG_SCALE := 0.85
const CLOTH_SIZE := Vector2(2.1, 1.5)
const LIGHT_COLOR := Color(1.0, 0.82, 0.86)
## The south window behind her, in the station's frame (house builder: 1.5 m
## wide, sill 0.9 m, head 3.5 m; the wall's inner face 4.25 m behind the easel).
const WINDOW_Z := -4.25
const WINDOW_HALF := 0.75
const CURTAIN_TOP := 3.8
const CURTAIN_COLOR := Color(1.0, 0.84, 0.88)
const DAYLIGHT := Color(1.0, 0.96, 0.88)
const DAY_ENERGY := 2.2


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
	for side in [-1.0, 1.0]:
		nook.add_child(_curtain(side))
	nook.add_child(_rod())
	nook.add_child(_daylight())
	nook.add_child(_motes())
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


## Dust motes turning slowly in the window light.
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


## A pink silk curtain tied back beside the window, pleated, gathered in at
## the tie and pooling a little on the floor. `side` -1 her right, +1 her left.
static func _curtain(side: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLS := 24
	const ROWS := 18
	var width := 0.85
	var tie_y := 1.25
	for r in ROWS + 1:
		var v := float(r) / ROWS
		var y := lerpf(0.0, CURTAIN_TOP, v)
		# Gathered to a narrow waist at the tie, full above and below.
		var gather := lerpf(0.45, 1.0, clampf(absf(y - tie_y) / 1.2, 0.0, 1.0))
		for c in COLS + 1:
			var u := float(c) / COLS
			var x := WINDOW_HALF * side + side * (u * width * gather - 0.1)
			var z := WINDOW_Z + 0.12 + 0.05 * sin(u * TAU * 5.0) * (1.4 - 0.4 * gather)
			if y < 0.1:
				z += (0.1 - y) * 0.6
			st.set_uv(Vector2(u, 1.0 - v))
			st.add_vertex(Vector3(x, maxf(y, 0.01), z))
	for r in ROWS:
		for c in COLS:
			var i := r * (COLS + 1) + c
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + COLS + 1)
			st.add_index(i + 1)
			st.add_index(i + COLS + 2)
			st.add_index(i + COLS + 1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Curtain%s" % ("L" if side > 0 else "R")
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CURTAIN_COLOR
	mat.roughness = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.rim_enabled = true
	mat.rim = 0.25
	mi.material_override = mat
	# A gold tie-back cord at the waist.
	var tie := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.2
	tie.mesh = torus
	tie.position = Vector3(WINDOW_HALF * side + side * 0.17, tie_y, WINDOW_Z + 0.14)
	tie.rotation_degrees.x = 90.0
	tie.material_override = _gold()
	mi.add_child(tie)
	return mi


## The gilt curtain rod above the window, with ball finials.
static func _rod() -> Node3D:
	var rod := MeshInstance3D.new()
	rod.name = "CurtainRod"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.022
	cyl.bottom_radius = 0.022
	cyl.height = WINDOW_HALF * 2.0 + 2.0
	rod.mesh = cyl
	rod.rotation_degrees.z = 90.0
	rod.position = Vector3(0, CURTAIN_TOP + 0.04, WINDOW_Z + 0.12)
	rod.material_override = _gold()
	for side in [-1.0, 1.0]:
		var ball := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.05
		sph.height = 0.1
		ball.mesh = sph
		ball.position = Vector3(0, side * cyl.height * 0.5, 0)
		ball.material_override = rod.material_override
		rod.add_child(ball)
	return rod


static func _gold() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = EstateKit.GOLD
	m.metallic = 0.8
	m.roughness = 0.3
	return m


## Daylight through the window over her shoulder onto the canvas; it follows
## the clock and goes out at night.
static func _daylight() -> SpotLight3D:
	var l := SpotLight3D.new()
	l.name = "WindowLight"
	l.light_color = DAYLIGHT
	l.spot_range = 7.5
	l.spot_angle = 32.0
	l.spot_attenuation = 0.8
	l.shadow_enabled = true
	var from := Vector3(0, 3.2, WINDOW_Z + 0.3)
	l.transform = Transform3D(Basis.looking_at(Vector3(0, 1.0, 0.2) - from, Vector3.UP), from)
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	var follow := func() -> void:
		l.light_energy = DAY_ENERGY * day_factor()
	timer.timeout.connect(follow)
	l.add_child(timer)
	follow.call()
	return l


## 1 at midday, 0 at night, easing through dawn and dusk.
static func day_factor() -> float:
	var h := Clock.hour()
	return clampf(minf(h - 5.5, 20.5 - h) / 2.0, 0.0, 1.0)

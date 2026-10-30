## Stylized princess-look plant meshes per species, built into a PropMeshKit with
## the shared foliage shader. Vertex red = wind flex (0 at the root, 1 at the tips),
## green/blue stay 0 so the shader takes colour from each surface's albedo.
class_name FloraShapes
extends RefCounted

const SHADER := preload("res://world/shared/shaders/stylized_foliage.gdshader")
const LEAF := Color(0.42, 0.74, 0.40)
const LEAF_DARK := Color(0.30, 0.62, 0.36)
const BARK := Color(0.62, 0.42, 0.36)
const BARK_PALE := Color(0.98, 0.95, 0.93)

static var _mats: Dictionary = {}


## A cached ShaderMaterial on the shared stylized foliage shader.
static func mat(c: Color, sparkle: float = 0.0, glow: float = 0.0, translucency: float = 0.35) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), sparkle, glow, translucency]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("sparkle", sparkle)
	m.set_shader_parameter("emission_glow", glow)
	m.set_shader_parameter("translucency", translucency)
	_mats[key] = m
	return m


static func build(k: PropMeshKit, id: StringName, kind: StringName, h: float, c: Color) -> void:
	var rnd := EstateKit.rng("flora:" + String(id))
	match id:
		&"hedge_box": _hedge(k, h, c)
		&"willow": _willow(k, rnd, h, c)
		&"birch": _tree(k, rnd, h, c, BARK_PALE, 0.45, 9, 0.22, true)
		&"oak": _tree(k, rnd, h, c, BARK, 0.9, 14, 0.36, false)
		&"cherry_blossom": _tree(k, rnd, h, c, Color(0.55, 0.34, 0.36), 0.75, 12, 0.4, false, LEAF)
		&"apple_blossom", &"crab_apple": _tree(k, rnd, h, c, BARK, 0.7, 11, 0.42, false, LEAF, Color(0.95, 0.3, 0.38))
		&"pear_tree": _tree(k, rnd, h, c, BARK, 0.6, 11, 0.36, false, Color(1.0, 0.98, 0.92), Color(0.82, 0.9, 0.42))
		&"rose_climbing", &"honeysuckle": _climber(k, rnd, h, c, id == &"rose_climbing")
		&"wisteria": _wisteria(k, rnd, h, c)
		&"elderflower": _umbel_bush(k, rnd, h, c)
		&"lilac": _lilac_bush(k, rnd, h, c)
		&"blackberry": _bramble(k, rnd, h, c)
		&"lavender": _spikes(k, rnd, h, c, 18, 0.35, 0.025)
		&"foxglove": _foxglove(k, rnd, h, c)
		&"wild_hyacinth": _bells(k, rnd, h, c, 7)
		&"faelight_dandelion": _dandelion(k, rnd, h, c)
		&"wild_strawberry": _strawberry(k, rnd, h, c)
		&"starmoss": _moss(k, rnd, h, c)
		&"reed": _reeds(k, rnd, h, c)
		&"water_lily": _lily(k, rnd, h, c)
		&"tulip_bed": _tulips(k, rnd, h, c)
		&"peony": _peony(k, rnd, h, c)
		&"forget_me_not", &"buttercup", &"crocus": _small_flowers(k, rnd, h, c, id)
		&"daisy": _daisies(k, rnd, h, c)
		&"herb_patch": _herbs(k, rnd, h, c)
		&"vegetable_row": _vegetables(k, rnd, h, c)
		&"fern": _fern(k, rnd, h, c)
		&"mushroom_glowcap": _glowcaps(k, rnd, h, c)
		&"iris": _iris(k, rnd, h, c)
		&"madder": _madder(k, rnd, h, c)
		&"orchid": _orchid(k, rnd, h, c)
		_:
			match kind:
				&"tree": _tree(k, rnd, h, c, BARK, 0.7, 10, 0.38, false)
				&"bush": _rose_bush(k, rnd, h, c)
				&"climber": _climber(k, rnd, h, c, false)
				&"reed": _reeds(k, rnd, h, c)
				&"aquatic": _lily(k, rnd, h, c)
				&"groundcover": _moss(k, rnd, h, c)
				_: _small_flowers(k, rnd, h, c, id)


# --- shared pieces ------------------------------------------------------------

static func _bloom(k: PropMeshKit, m: Material, pos: Vector3, r: float) -> void:
	k.sphere(m, pos, Vector3(r, r * 0.8, r), 6, 4)
	k.torus(m, pos - Vector3(0, r * 0.25, 0), r * 0.9, r * 0.38, 6, 3)


static func _blob(k: PropMeshKit, m: Material, pos: Vector3, r: Vector3, seg: int = 7, rings: int = 4) -> void:
	k.sphere(m, pos, r, seg, rings)


static func _stem(k: PropMeshKit, m: Material, base: Vector3, tip: Vector3, r: float, bend: Vector3 = Vector3.ZERO) -> void:
	var mid := (base + tip) * 0.5 + bend
	k.tube(m, PackedVector3Array([base, mid, tip]), r, 3, Transform3D.IDENTITY, r * 0.6)


static func _leaves_ring(k: PropMeshKit, rnd: RandomNumberGenerator, m: Material, base: Vector3, n: int, length: float, width: float, up: float = 0.4) -> void:
	for i in n:
		var a := TAU * i / n + rnd.randf() * 0.4
		k.leaf(m, base, Vector3(cos(a), up, sin(a)), length * rnd.randf_range(0.8, 1.1), width, 0.5)


# --- trees --------------------------------------------------------------------

static func _tree(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color, bark: Color, spread: float,
		clusters: int, trunk_frac: float, slender: bool, leaf: Color = Color(0, 0, 0, 0), fruit: Color = Color(0, 0, 0, 0)) -> void:
	var bark_m := mat(bark, 0.0, 0.0, 0.0)
	var crown_m := mat(c, 0.15 if c.s < 0.5 else 0.0)
	var r0 := h * (0.035 if slender else 0.05)
	var trunk_h := h * trunk_frac
	k.flex = 0.05
	var trunk := PackedVector3Array()
	for i in 6:
		var t := float(i) / 5.0
		trunk.append(Vector3(sin(t * 2.0 + rnd.randf()) * r0 * 0.6 * t, r0 * 0.5 + t * h * 0.62, cos(t * 1.7) * r0 * 0.4 * t))
	k.tube(bark_m, trunk, r0, 7, Transform3D.IDENTITY, r0 * 0.45)
	k.cyl(bark_m, Vector3.ZERO, r0 * 1.7, r0, h * 0.06, 7, false)
	if slender:
		# birch: lilac-plum bark marks
		for i in 7:
			var y := h * (0.1 + i * 0.07)
			k.box(mat(Color(0.48, 0.30, 0.46), 0.0, 0.0, 0.0), Vector3(0, y, 0), Vector3(r0 * 2.05, h * 0.008, r0 * 0.5),
					PropMeshKit.at(Vector3.ZERO, rnd.randf() * TAU))
	# branches up to each crown cluster
	var crown_c := Vector3(0, h * 0.68, 0)
	var crown_r := Vector3(h * 0.32 * spread, h * 0.3, h * 0.32 * spread)
	var leaf_m := mat(leaf if leaf.a > 0.0 else c.darkened(0.12))
	for i in clusters:
		var a := TAU * i / clusters + rnd.randf() * 0.5
		var e := rnd.randf_range(0.25, 1.35)
		var dir := Vector3(cos(a) * sin(e), cos(e), sin(a) * sin(e))
		var p := crown_c + dir * crown_r * 0.72
		var cr := h * rnd.randf_range(0.11, 0.16) * (0.75 if slender else 1.0)
		k.flex = 0.35
		if e > 0.6:
			_stem(k, bark_m, Vector3(0, trunk_h + (p.y - trunk_h) * 0.2, 0), p * Vector3(0.8, 0.95, 0.8), r0 * 0.4, Vector3(0, h * 0.04, 0))
		k.flex = 1.0
		_blob(k, crown_m, p, Vector3(cr, cr * 0.8, cr), 8, 5)
		if leaf.a > 0.0 and i % 3 == 0:
			_blob(k, leaf_m, p + Vector3(0, -cr * 0.45, 0), Vector3(cr * 0.8, cr * 0.5, cr * 0.8), 6, 3)
		if fruit.a > 0.0:
			for f in 2:
				var fp := p + Vector3(rnd.randf_range(-cr, cr) * 0.8, -cr * 0.6, rnd.randf_range(-cr, cr) * 0.8)
				k.sphere(mat(fruit), fp, Vector3.ONE * h * 0.012, 5, 3)
	k.flex = 1.0
	_blob(k, crown_m, crown_c + Vector3(0, h * 0.1, 0), crown_r * 0.62, 10, 6)
	if slender:
		_blob(k, crown_m, crown_c + Vector3(0, h * 0.24, 0), crown_r * Vector3(0.35, 0.3, 0.35), 8, 5)
	# petals drifting at the foot of blossom trees
	if c.s < 0.4 and c.r > 0.9:
		k.flex = 0.0
		for i in 10:
			var a := rnd.randf() * TAU
			var rr := rnd.randf_range(0.3, h * 0.3)
			k.disc(crown_m, Vector3(cos(a) * rr, 0.02, sin(a) * rr), h * 0.012, 5)


static func _willow(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var bark_m := mat(BARK, 0.0, 0.0, 0.0)
	var leaf_m := mat(c)
	var r0 := h * 0.05
	k.flex = 0.05
	k.tube(bark_m, PackedVector3Array([Vector3(0, r0 * 0.5, 0), Vector3(r0, h * 0.3, 0), Vector3(-r0, h * 0.55, r0), Vector3(0, h * 0.7, 0)]), r0, 7,
			Transform3D.IDENTITY, r0 * 0.5)
	k.cyl(bark_m, Vector3.ZERO, r0 * 1.8, r0, h * 0.06, 7, false)
	k.flex = 0.5
	_blob(k, leaf_m, Vector3(0, h * 0.8, 0), Vector3(h * 0.36, h * 0.18, h * 0.36), 10, 6)
	# weeping curtains: drooping cones of fronds hanging from the dome
	var n := 22
	for i in n:
		var a := TAU * i / n + rnd.randf() * 0.2
		var rr := h * rnd.randf_range(0.22, 0.36)
		var top := Vector3(cos(a) * rr, h * rnd.randf_range(0.72, 0.85), sin(a) * rr)
		var ln := h * rnd.randf_range(0.45, 0.65)
		k.flex = 0.7
		k.cyl(leaf_m, top - Vector3(0, ln, 0), h * 0.012, h * 0.07, ln, 5, false)
		k.flex = 1.0
		k.leaf(mat(c.lightened(0.12)), top - Vector3(0, ln * 0.5, 0), Vector3(cos(a), -2.0, sin(a)), ln * 0.5, h * 0.05, 0.0)
	k.flex = 1.0


# --- bushes -------------------------------------------------------------------

static func _rose_bush(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF_DARK)
	var bloom_m := mat(c, 0.1, 0.05, 0.45)
	var w := h * 0.55
	k.flex = 0.2
	for i in 5:
		var a := TAU * i / 5.0
		_stem(k, mat(Color(0.45, 0.6, 0.38), 0.0, 0.0, 0.0), Vector3(cos(a) * 0.03, 0, sin(a) * 0.03), Vector3(cos(a) * w * 0.4, h * 0.4, sin(a) * w * 0.4), 0.012)
	k.flex = 0.3
	for i in 7:
		var a := TAU * i / 7.0
		var p := Vector3(cos(a) * w * 0.55, h * rnd.randf_range(0.35, 0.55), sin(a) * w * 0.55)
		_blob(k, leaf_m, p, Vector3(w * 0.45, h * 0.32, w * 0.45), 7, 4)
	k.flex = 0.6
	_blob(k, leaf_m, Vector3(0, h * 0.62, 0), Vector3(w * 0.55, h * 0.32, w * 0.55), 8, 5)
	# oversized blooms all over the crown
	k.flex = 0.9
	for i in 16:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.1, 1.45)
		var p := Vector3(cos(a) * sin(e) * w * 0.95, h * 0.5 + cos(e) * h * 0.45, sin(a) * sin(e) * w * 0.95)
		_bloom(k, bloom_m, p, h * rnd.randf_range(0.08, 0.11))
	k.flex = 1.0


static func _hedge(k: PropMeshKit, h: float, c: Color) -> void:
	# a clipped hedge segment: rounded block with soft top rolls and a darker base
	var m := mat(c)
	var w := h * 0.62
	var d := h * 0.42
	k.flex = 0.0
	k.box(mat(c.darkened(0.1)), Vector3(0, h * 0.06, 0), Vector3(w * 0.96, h * 0.12, d * 0.96))
	k.flex = 0.15
	k.box(m, Vector3(0, h * 0.45, 0), Vector3(w, h * 0.78, d))
	for sz: float in [-1.0, 1.0]:
		k.cyl(m, Vector3(0, -w * 0.5, 0), d * 0.18, d * 0.18, w, 10, true, PropMeshKit.at(Vector3(0, h * 0.84, sz * d * 0.32), 0, 0, PI * 0.5))
	for sx: float in [-1.0, 1.0]:
		k.cyl(m, Vector3(0, -d * 0.32, 0), d * 0.18, d * 0.18, d * 0.64, 10, true, PropMeshKit.at(Vector3(sx * (w * 0.5 - d * 0.18), h * 0.84, 0), 0, PI * 0.5))
	k.box(m, Vector3(0, h * 0.9, 0), Vector3(w - d * 0.36, d * 0.36 * 0.6, d * 0.64))
	k.sphere(m, Vector3(0, h * 0.9, 0), Vector3(w * 0.42, d * 0.25, d * 0.32), 8, 4, Transform3D.IDENTITY, true)


static func _umbel_bush(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var flower_m := mat(c, 0.1, 0.05, 0.5)
	var w := h * 0.45
	k.flex = 0.1
	_stem(k, mat(BARK, 0.0, 0.0, 0.0), Vector3.ZERO, Vector3(0, h * 0.4, 0), h * 0.02)
	k.flex = 0.3
	for i in 6:
		var a := TAU * i / 6.0
		_blob(k, leaf_m, Vector3(cos(a) * w * 0.5, h * 0.45, sin(a) * w * 0.5), Vector3(w * 0.45, h * 0.28, w * 0.45), 7, 4)
	_blob(k, leaf_m, Vector3(0, h * 0.68, 0), Vector3(w * 0.6, h * 0.25, w * 0.6), 8, 4)
	k.flex = 0.9
	for i in 12:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.2, 1.3)
		var p := Vector3(cos(a) * sin(e) * w, h * 0.55 + cos(e) * h * 0.42, sin(a) * sin(e) * w)
		k.sphere(flower_m, p, Vector3(h * 0.07, h * 0.025, h * 0.07), 7, 3, Transform3D.IDENTITY, true)


static func _lilac_bush(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var flower_m := mat(c, 0.1, 0.05, 0.5)
	var w := h * 0.42
	k.flex = 0.1
	_stem(k, mat(BARK, 0.0, 0.0, 0.0), Vector3.ZERO, Vector3(0, h * 0.4, 0), h * 0.02)
	k.flex = 0.3
	for i in 6:
		var a := TAU * i / 6.0
		_blob(k, leaf_m, Vector3(cos(a) * w * 0.55, h * 0.45, sin(a) * w * 0.55), Vector3(w * 0.42, h * 0.28, w * 0.42), 7, 4)
	_blob(k, leaf_m, Vector3(0, h * 0.66, 0), Vector3(w * 0.55, h * 0.25, w * 0.55), 8, 4)
	k.flex = 0.9
	for i in 14:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.1, 1.2)
		var p := Vector3(cos(a) * sin(e) * w, h * 0.55 + cos(e) * h * 0.38, sin(a) * sin(e) * w)
		k.cyl(flower_m, p, h * 0.05, 0.0, h * 0.16, 6)


static func _bramble(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF_DARK)
	var cane_m := mat(Color(0.62, 0.36, 0.42), 0.0, 0.0, 0.0)
	var w := h * 0.7
	k.flex = 0.5
	for i in 8:
		var a := TAU * i / 8.0
		_stem(k, cane_m, Vector3.ZERO, Vector3(cos(a) * w, h * 0.3, sin(a) * w), h * 0.012, Vector3(0, h * 0.6, 0))
	_blob(k, leaf_m, Vector3(0, h * 0.5, 0), Vector3(w * 0.75, h * 0.45, w * 0.75), 9, 5)
	k.flex = 0.8
	for i in 6:
		var a := TAU * i / 6.0
		_blob(k, leaf_m, Vector3(cos(a) * w * 0.6, h * 0.35, sin(a) * w * 0.6), Vector3(w * 0.3, h * 0.25, w * 0.3), 6, 3)
	for i in 18:
		var a := rnd.randf() * TAU
		var e := rnd.randf_range(0.3, 1.4)
		var p := Vector3(cos(a) * sin(e) * w * 0.8, h * 0.5 + cos(e) * h * 0.45, sin(a) * sin(e) * w * 0.8)
		k.sphere(mat(c, 0.2) if i % 3 else mat(Color(0.95, 0.3, 0.4)), p, Vector3.ONE * h * 0.03, 5, 3)
	for i in 5:
		_bloom(k, mat(Color(1.0, 0.92, 0.95)), Vector3(cos(i * 1.3) * w * 0.7, h * 0.7, sin(i * 1.3) * w * 0.7), h * 0.035)


# --- climbers -----------------------------------------------------------------

static func _climber(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color, roses: bool) -> void:
	# a flat-ish curtain of vine to stand against walls and trellises (depth ~0.4 m)
	var leaf_m := mat(LEAF_DARK if roses else LEAF)
	var bloom_m := mat(c, 0.1, 0.05, 0.45)
	var w := h * 0.5
	k.flex = 0.1
	for i in 3:
		var x := -w * 0.3 + i * w * 0.3
		var pts := PackedVector3Array()
		for j in 6:
			pts.append(Vector3(x + sin(j * 1.4 + i) * w * 0.12, j * h * 0.19, 0))
		k.tube(mat(Color(0.55, 0.4, 0.34), 0.0, 0.0, 0.0), pts, h * 0.008, 3)
	for i in 14:
		var p := Vector3(rnd.randf_range(-w * 0.45, w * 0.45), h * rnd.randf_range(0.15, 0.92), rnd.randf_range(-0.05, 0.05))
		k.flex = p.y / h
		_blob(k, leaf_m, p, Vector3(h * 0.11, h * 0.09, 0.14), 6, 4)
	for i in 16:
		var p := Vector3(rnd.randf_range(-w * 0.45, w * 0.45), h * rnd.randf_range(0.2, 0.95), -0.1)
		k.flex = 1.0
		if roses:
			_bloom(k, bloom_m, p, h * 0.035)
		else:
			# honeysuckle trumpets
			for t in 3:
				var a := TAU * t / 3.0
				k.cyl(bloom_m, p, h * 0.004, h * 0.012, h * 0.05, 4, false, PropMeshKit.at(Vector3.ZERO, a, 0.9))
	k.flex = 1.0


static func _wisteria(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var flower_m := mat(c, 0.15, 0.08, 0.5)
	var w := h * 0.5
	k.flex = 0.1
	var trunk := PackedVector3Array()
	for j in 6:
		trunk.append(Vector3(sin(j * 1.1) * w * 0.15, j * h * 0.18, 0))
	k.tube(mat(Color(0.58, 0.42, 0.40), 0.0, 0.0, 0.0), trunk, h * 0.02, 5, Transform3D.IDENTITY, h * 0.01)
	k.flex = 0.4
	for i in 8:
		var p := Vector3(rnd.randf_range(-w * 0.5, w * 0.5), h * rnd.randf_range(0.75, 0.95), rnd.randf_range(-0.1, 0.1))
		_blob(k, leaf_m, p, Vector3(h * 0.1, h * 0.06, 0.18), 6, 3)
	# long hanging racemes
	for i in 18:
		var top := Vector3(rnd.randf_range(-w * 0.5, w * 0.5), h * rnd.randf_range(0.72, 0.9), rnd.randf_range(-0.12, 0.05))
		var ln := h * rnd.randf_range(0.18, 0.32)
		k.flex = 1.0
		k.cyl(flower_m, top - Vector3(0, ln, 0), 0.0, h * 0.03, ln, 6)
	k.flex = 1.0


# --- flowers ------------------------------------------------------------------

static func _spikes(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color, n: int, spread: float, r: float) -> void:
	var stem_m := mat(Color(0.55, 0.72, 0.55))
	var flower_m := mat(c, 0.1, 0.05, 0.5)
	k.flex = 0.2
	_blob(k, stem_m, Vector3(0, h * 0.18, 0), Vector3(h * spread * 0.9, h * 0.2, h * spread * 0.9), 7, 3)
	for i in n:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * h * spread * 0.7
		var base := Vector3(cos(a) * rr * 0.4, h * 0.2, sin(a) * rr * 0.4)
		var tip := Vector3(cos(a) * rr, h * rnd.randf_range(0.85, 1.0), sin(a) * rr)
		k.flex = 0.6
		_stem(k, stem_m, base, tip - Vector3(0, h * 0.25, 0), 0.006)
		k.flex = 1.0
		k.cyl(flower_m, tip - Vector3(0, h * 0.27, 0), r, r * 0.3, h * 0.27, 5)
	k.flex = 1.0


static func _foxglove(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var bell_m := mat(c, 0.05, 0.05, 0.5)
	k.flex = 0.1
	_leaves_ring(k, rnd, leaf_m, Vector3(0, 0.03, 0), 7, h * 0.3, h * 0.1, 0.15)
	for s in 3:
		var a := TAU * s / 3.0
		var base := Vector3(cos(a) * h * 0.08, 0, sin(a) * h * 0.08)
		var top := base + Vector3(0, h * (0.85 + 0.15 * float(s == 0)), 0)
		k.flex = 0.5
		_stem(k, mat(Color(0.5, 0.7, 0.45)), base, top, 0.012)
		for b in 8:
			var t := 0.4 + b * 0.075
			var p := base.lerp(top, t)
			var ba := b * 2.1 + a
			k.flex = t
			k.cyl(bell_m, p + Vector3(cos(ba) * 0.03, -0.05, sin(ba) * 0.03), h * 0.03, h * 0.018, h * 0.06, 6, false)
	k.flex = 1.0


static func _bells(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color, n: int) -> void:
	var leaf_m := mat(LEAF)
	var bell_m := mat(c, 0.1, 0.05, 0.5)
	k.flex = 0.2
	_leaves_ring(k, rnd, leaf_m, Vector3.ZERO, 8, h * 0.9, h * 0.12, 0.6)
	for i in n:
		var a := TAU * i / n
		var base := Vector3(cos(a) * h * 0.25, 0, sin(a) * h * 0.25)
		var tip := base + Vector3(cos(a) * h * 0.1, h * rnd.randf_range(0.85, 1.0), sin(a) * h * 0.1)
		k.flex = 0.6
		_stem(k, mat(Color(0.5, 0.72, 0.48)), base, tip, 0.004, Vector3(cos(a), 0, sin(a)) * h * 0.1)
		k.flex = 1.0
		for b in 4:
			k.sphere(bell_m, tip - Vector3(0, b * h * 0.09, 0) + Vector3(cos(a + b) * 0.012, 0, sin(a + b) * 0.012),
					Vector3(h * 0.05, h * 0.06, h * 0.05), 5, 3)


static func _dandelion(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var puff_m := mat(c, 0.8, 1.6, 0.7)
	k.flex = 0.1
	_leaves_ring(k, rnd, leaf_m, Vector3.ZERO, 6, h * 0.6, h * 0.12, 0.2)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var base := Vector3(cos(a) * h * 0.1, 0, sin(a) * h * 0.1)
		var tip := base + Vector3(cos(a) * h * 0.1, h * (0.75 + 0.1 * float(i)), sin(a) * h * 0.1)
		k.flex = 0.6
		_stem(k, mat(Color(0.6, 0.8, 0.55)), base, tip, 0.004)
		k.flex = 1.0
		k.sphere(puff_m, tip, Vector3.ONE * h * 0.13, 8, 5)
		k.sphere(mat(Color(1.0, 1.0, 0.95), 1.0, 2.5, 0.8), tip, Vector3.ONE * h * 0.05, 5, 3)


static func _small_flowers(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color, id: StringName) -> void:
	# a clump of little five-petal flowers: forget-me-nots, buttercups, crocuses
	var leaf_m := mat(LEAF)
	var petal_m := mat(c, 0.1, 0.05, 0.5)
	var eye_m := mat(Color(1.0, 0.9, 0.45) if id != &"buttercup" else Color(1.0, 0.75, 0.3), 0.2, 0.2)
	var cups := id == &"crocus"
	k.flex = 0.2
	_blob(k, leaf_m, Vector3(0, h * 0.15, 0), Vector3(h * 0.9, h * 0.25, h * 0.9), 7, 3)
	if cups:
		_leaves_ring(k, rnd, leaf_m, Vector3.ZERO, 10, h * 0.9, h * 0.06, 1.6)
	var n := 9
	for i in n:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * h * 0.9
		var top := Vector3(cos(a) * rr, h * rnd.randf_range(0.7, 1.0) - h * 0.1, sin(a) * rr)
		k.flex = 0.6
		_stem(k, leaf_m, Vector3(top.x * 0.5, 0, top.z * 0.5), top, 0.004)
		k.flex = 1.0
		if cups:
			k.lathe(petal_m, top, PackedVector2Array([Vector2(0, 0), Vector2(h * 0.07, h * 0.05), Vector2(h * 0.08, h * 0.2),
					Vector2(h * 0.05, h * 0.25), Vector2(h * 0.03, h * 0.22)]), 6)
			k.sphere(eye_m, top + Vector3(0, h * 0.06, 0), Vector3.ONE * h * 0.025, 4, 2)
		else:
			for p in 5:
				var pa := TAU * p / 5.0
				k.disc(petal_m, top + Vector3(cos(pa), 0, sin(pa)) * h * 0.05, h * 0.045, 5,
						PropMeshKit.at(Vector3.ZERO, 0, 0.0, 0.0))
			k.sphere(eye_m, top + Vector3(0, h * 0.01, 0), Vector3.ONE * h * 0.03, 4, 2)


static func _daisies(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var petal_m := mat(c, 0.1, 0.05, 0.5)
	var eye_m := mat(Color(1.0, 0.82, 0.3), 0.1, 0.1)
	k.flex = 0.2
	_blob(k, leaf_m, Vector3(0, h * 0.12, 0), Vector3(h * 0.9, h * 0.2, h * 0.9), 7, 3)
	for i in 8:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * h * 0.9
		var top := Vector3(cos(a) * rr, h * rnd.randf_range(0.75, 1.0) - h * 0.05, sin(a) * rr)
		k.flex = 0.6
		_stem(k, leaf_m, Vector3(top.x * 0.6, 0, top.z * 0.6), top, 0.004)
		k.flex = 1.0
		k.disc(petal_m, top, h * 0.14, 10)
		k.sphere(eye_m, top, Vector3(h * 0.05, h * 0.025, h * 0.05), 6, 3, Transform3D.IDENTITY, true)


static func _tulips(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	var cols := [c, Color(1.0, 0.75, 0.85), Color(1.0, 0.9, 0.55), Color(0.85, 0.7, 1.0)]
	for i in 9:
		var a := TAU * i / 9.0 + rnd.randf() * 0.3
		var rr := h * (0.3 if i % 2 else 0.6)
		var base := Vector3(cos(a) * rr, 0, sin(a) * rr)
		var top := base + Vector3(0, h * rnd.randf_range(0.7, 0.85), 0)
		k.flex = 0.1
		k.leaf(leaf_m, base, Vector3(cos(a), 2.0, sin(a)), h * 0.5, h * 0.12, 0.3)
		k.flex = 0.6
		_stem(k, leaf_m, base, top, 0.006)
		k.flex = 1.0
		k.lathe(mat(cols[i % 4], 0.1, 0.05, 0.5), top, PackedVector2Array([Vector2(0, 0), Vector2(h * 0.07, h * 0.03), Vector2(h * 0.09, h * 0.12),
				Vector2(h * 0.07, h * 0.2), Vector2(h * 0.05, h * 0.22)]), 7)


static func _peony(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF_DARK)
	var bloom_m := mat(c, 0.1, 0.05, 0.5)
	k.flex = 0.1
	for i in 4:
		_stem(k, leaf_m, Vector3.ZERO, Vector3(cos(i * 1.6) * h * 0.2, h * 0.3, sin(i * 1.6) * h * 0.2), 0.01)
	k.flex = 0.3
	_blob(k, leaf_m, Vector3(0, h * 0.4, 0), Vector3(h * 0.5, h * 0.35, h * 0.5), 8, 4)
	for i in 5:
		var a := TAU * i / 5.0
		_blob(k, leaf_m, Vector3(cos(a) * h * 0.35, h * 0.3, sin(a) * h * 0.35), Vector3(h * 0.22, h * 0.18, h * 0.22), 6, 3)
	k.flex = 1.0
	for i in 6:
		var a := TAU * i / 6.0 + rnd.randf()
		var p := Vector3(cos(a) * h * 0.32, h * rnd.randf_range(0.7, 0.85), sin(a) * h * 0.32)
		if i == 5:
			p = Vector3(0, h * 0.86, 0)
		k.sphere(bloom_m, p, Vector3(h * 0.12, h * 0.1, h * 0.12), 7, 4)
		k.torus(bloom_m, p - Vector3(0, h * 0.03, 0), h * 0.11, h * 0.05, 7, 3)
		k.torus(mat(c.lightened(0.2)), p - Vector3(0, h * 0.06, 0), h * 0.13, h * 0.03, 7, 3)


static func _herbs(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	# a mixed herb patch: rosemary spikes, round sage, chive pom-poms, thyme mound
	k.flex = 0.4
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * h * 0.6, 0, sin(a) * h * 0.6)
		match i % 3:
			0: _blob(k, mat(Color(0.6, 0.78, 0.6)), p + Vector3(0, h * 0.35, 0), Vector3(h * 0.35, h * 0.35, h * 0.35), 7, 4)
			1:
				for j in 5:
					var ja := TAU * j / 5.0
					k.flex = 0.7
					k.cyl(mat(c), p + Vector3(cos(ja), 0, sin(ja)) * h * 0.1, 0.012, 0.0, h * rnd.randf_range(0.7, 0.95), 4)
				k.flex = 0.4
			_:
				_blob(k, mat(LEAF), p + Vector3(0, h * 0.2, 0), Vector3(h * 0.3, h * 0.2, h * 0.3), 6, 3)
				for j in 3:
					k.flex = 1.0
					k.sphere(mat(Color(0.85, 0.65, 1.0), 0.1), p + Vector3((j - 1) * h * 0.12, h * 0.55, 0), Vector3.ONE * h * 0.06, 5, 3)
		k.flex = 0.4
	_blob(k, mat(c.darkened(0.1)), Vector3(0, h * 0.25, 0), Vector3(h * 0.35, h * 0.25, h * 0.35), 7, 4)


static func _vegetables(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	# a row of cabbages, carrot tops and a few ripe tomatoes on canes (along X)
	k.flex = 0.0
	k.box(mat(Color(0.72, 0.52, 0.44), 0.0, 0.0, 0.0), Vector3(0, 0.03, 0), Vector3(h * 4.0, 0.06, h * 0.9))
	for i in 7:
		var x := -h * 1.8 + i * h * 0.6
		match i % 3:
			0:
				k.flex = 0.2
				k.sphere(mat(Color(0.65, 0.85, 0.55)), Vector3(x, h * 0.3, 0), Vector3(h * 0.3, h * 0.26, h * 0.3), 8, 4)
				for l in 5:
					var a := TAU * l / 5.0
					k.flex = 0.5
					k.leaf(mat(c), Vector3(x, h * 0.18, 0), Vector3(cos(a), 0.4, sin(a)), h * 0.4, h * 0.25, 0.6)
			1:
				for l in 6:
					var a := TAU * l / 6.0
					k.flex = 0.8
					k.leaf(mat(c.lightened(0.1)), Vector3(x, 0.05, 0), Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3), h * 0.8, h * 0.1, 0.4)
				k.flex = 0.0
				k.cyl(mat(Color(1.0, 0.6, 0.3)), Vector3(x, 0.0, 0), h * 0.06, h * 0.07, 0.07, 6)
			_:
				k.flex = 0.1
				k.cyl(mat(Color(0.8, 0.65, 0.45), 0.0, 0.0, 0.0), Vector3(x, 0, 0), 0.01, 0.01, h, 4)
				k.flex = 0.6
				_blob(k, mat(c), Vector3(x, h * 0.6, 0), Vector3(h * 0.2, h * 0.3, h * 0.2), 6, 3)
				for t in 4:
					k.sphere(mat(Color(0.95, 0.28, 0.32), 0.1), Vector3(x + (t - 1.5) * h * 0.1, h * (0.4 + 0.1 * float(t % 2)), -h * 0.15),
							Vector3.ONE * h * 0.06, 5, 3)


static func _iris(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(Color(0.45, 0.7, 0.55))
	var petal_m := mat(c, 0.1, 0.05, 0.5)
	k.flex = 0.3
	for i in 10:
		var a := TAU * i / 10.0
		k.leaf(leaf_m, Vector3(cos(a) * 0.03, 0, sin(a) * 0.03), Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.25), h * rnd.randf_range(0.6, 0.8), h * 0.06, 0.15)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var top := Vector3(cos(a) * h * 0.15, h * rnd.randf_range(0.82, 0.95), sin(a) * h * 0.15)
		k.flex = 0.6
		_stem(k, leaf_m, Vector3.ZERO, top, 0.007)
		k.flex = 1.0
		for p in 3:
			var pa := TAU * p / 3.0
			k.leaf(petal_m, top, Vector3(cos(pa), 1.6, sin(pa)), h * 0.12, h * 0.07, -0.2)
			k.leaf(petal_m, top, Vector3(cos(pa + 1.0), -0.3, sin(pa + 1.0)), h * 0.12, h * 0.08, 0.6)
		k.sphere(mat(Color(1.0, 0.85, 0.35), 0.2), top, Vector3.ONE * h * 0.02, 4, 2)


static func _madder(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	# a scrambling tangle of whorled leaves with tiny butter flowers and red roots peeking out
	var leaf_m := mat(c)
	k.flex = 0.0
	for i in 5:
		var a := TAU * i / 5.0
		k.tube(mat(Color(0.82, 0.24, 0.26), 0.0, 0.0, 0.0), PackedVector3Array([Vector3(0, 0.02, 0), Vector3(cos(a) * h * 0.3, 0.03, sin(a) * h * 0.3),
				Vector3(cos(a) * h * 0.4, -0.02, sin(a) * h * 0.4)]), 0.012, 4)
	for i in 6:
		var a := TAU * i / 6.0 + rnd.randf() * 0.4
		var top := Vector3(cos(a) * h * 0.3, h * rnd.randf_range(0.75, 1.0), sin(a) * h * 0.3)
		k.flex = 0.6
		_stem(k, leaf_m, Vector3.ZERO, top, 0.006, Vector3(cos(a), 0, sin(a)) * h * 0.1)
		for w in 3:
			var p := top * (0.4 + w * 0.25)
			k.flex = 0.4 + w * 0.2
			for l in 5:
				var la := TAU * l / 5.0
				k.leaf(leaf_m, p, Vector3(cos(la), 0.1, sin(la)), h * 0.12, h * 0.035, 0.3)
		k.flex = 1.0
		for f in 3:
			k.sphere(mat(Color(1.0, 0.92, 0.55), 0.1), top + Vector3((f - 1) * 0.02, 0.01 * f, 0), Vector3.ONE * h * 0.022, 4, 2)


static func _orchid(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	# broad glossy leaves at the base and two arching sprays of moth-orchid blooms
	var leaf_m := mat(Color(0.35, 0.62, 0.42))
	var petal_m := mat(c, 0.2, 0.08, 0.6)
	k.flex = 0.1
	for i in 5:
		var a := TAU * i / 5.0
		k.leaf(leaf_m, Vector3(0, h * 0.14, 0), Vector3(cos(a), 0.25, sin(a)), h * 0.45, h * 0.18, 0.4)
	for s in 2:
		var a := s * PI + 0.3
		var pts := PackedVector3Array()
		for j in 6:
			var t := float(j) / 5.0
			pts.append(Vector3(cos(a) * t * h * 0.35, h * (0.1 + sin(t * PI * 0.75) * 0.85), sin(a) * t * h * 0.35))
		k.flex = 0.6
		k.tube(mat(Color(0.55, 0.62, 0.45)), pts, 0.005, 3)
		k.flex = 1.0
		for j in 4:
			var p := pts[j + 2] + Vector3(0, -h * 0.04, 0)
			for pp in 5:
				var pa := TAU * pp / 5.0
				var off := Basis(Vector3.UP, a + PI * 0.5) * Vector3(cos(pa) * h * 0.03, sin(pa) * h * 0.03, 0)
				k.disc(petal_m, Vector3.ZERO, h * 0.035, 6, PropMeshKit.at(p + off, a + PI * 0.5, PI * 0.5))
			k.sphere(mat(Color(0.95, 0.4, 0.6), 0.2), p, Vector3.ONE * h * 0.015, 4, 2)


# --- groundcover, reeds, aquatic ------------------------------------------------

static func _strawberry(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var leaf_m := mat(LEAF)
	k.flex = 0.3
	for i in 12:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * h * 2.0
		k.leaf(leaf_m, Vector3(cos(a) * rr * 0.4, 0.0, sin(a) * rr * 0.4), Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6), h * 0.9, h * 0.6, 0.2)
	k.flex = 0.8
	for i in 8:
		var a := rnd.randf() * TAU
		var rr := rnd.randf_range(h * 0.5, h * 1.6)
		var p := Vector3(cos(a) * rr, h * 0.7, sin(a) * rr)
		if i % 3 == 0:
			for pp in 5:
				var pa := TAU * pp / 5.0
				k.disc(mat(Color(1.0, 0.97, 0.95)), p + Vector3(cos(pa), 0, sin(pa)) * h * 0.08, h * 0.08, 5)
		else:
			k.lathe(mat(c, 0.25), p - Vector3(0, h * 0.25, 0), PackedVector2Array([Vector2(0, 0), Vector2(h * 0.15, h * 0.15), Vector2(h * 0.12, h * 0.3), Vector2(0, h * 0.32)]), 6)


static func _moss(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var m := mat(c, 0.9, 0.35, 0.5)
	k.flex = 0.05
	for i in 9:
		var a := TAU * i / 9.0 + rnd.randf()
		var rr := rnd.randf_range(0.0, 0.45)
		k.sphere(m, Vector3(cos(a) * rr, 0, sin(a) * rr), Vector3(rnd.randf_range(0.15, 0.25), h, rnd.randf_range(0.15, 0.25)), 7, 3,
				Transform3D.IDENTITY, true)
	k.flex = 0.3
	for i in 10:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * 0.5
		k.sphere(mat(Color(1.0, 0.95, 0.75), 1.0, 2.0), Vector3(cos(a) * rr, h * 1.05, sin(a) * rr), Vector3.ONE * 0.012, 4, 2)


static func _fern(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var m := mat(c)
	k.flex = 0.1
	k.sphere(mat(c.darkened(0.2)), Vector3.ZERO, Vector3(h * 0.12, h * 0.1, h * 0.12), 6, 3, Transform3D.IDENTITY, true)
	for i in 10:
		var a := TAU * i / 10.0 + rnd.randf() * 0.3
		var dir := Vector3(cos(a), 0.0, sin(a))
		var pts := PackedVector3Array()
		for j in 5:
			var t := float(j) / 4.0
			pts.append(dir * t * h * 0.7 + Vector3(0, sin(t * PI * 0.8) * h * 0.85, 0))
		k.flex = 0.6
		k.tube(m, pts, 0.006, 3)
		for j in 4:
			var p := pts[j].lerp(pts[j + 1], 0.5)
			var side := dir.cross(Vector3.UP).normalized()
			var lw := h * 0.22 * (1.0 - j * 0.18)
			k.flex = 0.6 + j * 0.1
			k.leaf(m, p, side + Vector3(0, 0.3, 0) + dir * 0.4, lw, h * 0.06, 0.5)
			k.leaf(m, p, -side + Vector3(0, 0.3, 0) + dir * 0.4, lw, h * 0.06, 0.5)


static func _glowcaps(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var stalk := mat(Color(1.0, 0.97, 0.92), 0.2, 0.3)
	var cap := mat(c, 0.6, 1.4, 0.7)
	k.flex = 0.4
	for i in 7:
		var a := TAU * i / 7.0 + rnd.randf()
		var rr := rnd.randf_range(0.0, 0.18)
		var sh := h * rnd.randf_range(0.5, 1.0)
		var p := Vector3(cos(a) * rr, 0, sin(a) * rr)
		k.cyl(stalk, p, 0.012, 0.009, sh * 0.75, 5, false)
		k.sphere(cap, p + Vector3(0, sh * 0.7, 0), Vector3(sh * 0.45, sh * 0.32, sh * 0.45), 7, 3, Transform3D.IDENTITY, true)
		k.disc(mat(c.lightened(0.3), 0.3, 2.0), Vector3.ZERO, sh * 0.44, 7, PropMeshKit.at(p + Vector3(0, sh * 0.7, 0), 0, PI))


static func _reeds(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var m := mat(c)
	k.flex = 0.0
	for i in 14:
		var a := rnd.randf() * TAU
		var rr := rnd.randf() * h * 0.15
		var base := Vector3(cos(a) * rr, 0, sin(a) * rr)
		k.flex = 1.0
		k.leaf(m, base, Vector3(cos(a) * 0.15, 1.0, sin(a) * 0.15), h * rnd.randf_range(0.6, 1.0), h * 0.03, 0.2)
	for i in 4:
		var a := TAU * i / 4.0
		var base := Vector3(cos(a) * h * 0.06, 0, sin(a) * h * 0.06)
		var top := base + Vector3(cos(a) * 0.05, h * rnd.randf_range(0.85, 1.0), sin(a) * 0.05)
		k.flex = 0.8
		_stem(k, m, base, top, 0.006)
		k.flex = 1.0
		k.cyl(mat(Color(0.75, 0.48, 0.42)), top - Vector3(0, h * 0.18, 0), h * 0.022, h * 0.022, h * 0.14, 6)


static func _lily(k: PropMeshKit, rnd: RandomNumberGenerator, h: float, c: Color) -> void:
	var pad := mat(Color(0.40, 0.72, 0.42))
	var petal := mat(c, 0.2, 0.15, 0.6)
	k.flex = 0.5
	for i in 5:
		var a := TAU * i / 5.0 + rnd.randf()
		var rr := rnd.randf_range(0.15, 0.45)
		var r := rnd.randf_range(0.14, 0.22)
		var p := Vector3(cos(a) * rr, 0.005, sin(a) * rr)
		k.disc(pad, p, r, 12)
	for i in 2:
		var a := TAU * i / 2.0 + 0.8
		var p := Vector3(cos(a) * 0.2, 0.01, sin(a) * 0.2)
		k.flex = 0.6
		for l in 8:
			var la := TAU * l / 8.0
			k.leaf(petal, p, Vector3(cos(la), 0.9, sin(la)), h * 0.9, h * 0.45, -0.1)
		for l in 6:
			var la := TAU * l / 6.0 + 0.3
			k.leaf(mat(c.lightened(0.15), 0.2, 0.15), p, Vector3(cos(la), 2.0, sin(la)), h * 0.8, h * 0.35, -0.2)
		k.sphere(mat(Color(1.0, 0.88, 0.4), 0.3, 0.4), p + Vector3(0, h * 0.25, 0), Vector3.ONE * h * 0.18, 5, 3)


# --- impostor -------------------------------------------------------------------

## A cheap crossed-card silhouette for distant trees: trunk plus an octagonal crown
## in two crossed vertical planes (both faces), ~40 triangles.
static func impostor(k: PropMeshKit, h: float, c: Color, trunk: Color, weeping: bool) -> void:
	var crown := mat(c)
	var bark := mat(trunk, 0.0, 0.0, 0.0)
	var cr := h * (0.36 if weeping else 0.3)
	var cy := h * (0.62 if weeping else 0.66)
	for yaw: float in [0.0, PI * 0.5]:
		var t := PropMeshKit.at(Vector3.ZERO, yaw)
		var tw := h * 0.04
		for nz: float in [-1.0, 1.0]:
			var nn := Vector3(0, 0, nz)
			k.flex = 0.05
			k.quad(bark, Vector3(-tw, 0, 0), Vector3(-tw * 0.6, h * 0.55, 0), Vector3(tw * 0.6, h * 0.55, 0), Vector3(tw, 0, 0), nn, t)
			k.flex = 0.6
			var pts := PackedVector3Array()
			for i in 9:
				var a := TAU * i / 8.0
				var ry := cr * (1.2 if weeping and sin(a) < 0.0 else 1.0)
				pts.append(Vector3(cos(a) * cr, cy + sin(a) * ry, 0))
			for i in 8:
				k.quad(crown, Vector3(0, cy, 0), pts[i], pts[i + 1], Vector3(0, cy, 0), nn, t)
	k.flex = 1.0

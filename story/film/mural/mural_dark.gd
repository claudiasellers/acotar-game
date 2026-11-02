## The mural told true (lane L33): the same painted dioramas as the opening
## film's MuralStage, but the history Alis tells in cutscene C, in its dark
## style: black ink, rust red where the gold was, thorns at every edge. The
## only gold left in it is the High Lords' power, and it is being stolen.
## Also the one gold memory of cutscene B (the girl at the village well).
##
## Tableaux: queen (she comes over the sea; the ball; the seven High Lords'
## power drains into her hands), masks (the masquerade; Tamlin refuses her;
## the masks grow fast), terms (the hourglass, the girl with ice in her chest
## and a bow, the wolf, the arrow), well (B's flash). Build only what a film
## needs with `MuralDark.of([...])`.
## Script: /mnt/project-files/plans/film/scripts.md sections 3 (#13) and 4 (#5-#7).
class_name MuralDark
extends MuralStage

const RUST := Color(0.8, 0.2, 0.09)
const BLACK := Color(0.018, 0.01, 0.014)
const ICE := Color(0.62, 0.86, 1.0)
const DARK_IDS: Array[StringName] = [&"queen", &"masks", &"terms"]


static func of(ids: Array[StringName]) -> MuralDark:
	var m := MuralDark.new()
	m.build_only = ids
	return m


func _ready() -> void:
	# The mural told true is darker: colours show, half sunk in the ink.
	figure_ink = 0.38
	super._ready()
	for id in build_only:
		if id in DARK_IDS:
			environment.background_color = Color(0.012, 0.004, 0.006)
			# Rust is less bright than gold leaf: let it glow a touch more.
			environment.glow_hdr_threshold = 0.9
			break


# --- dark building blocks --------------------------------------------------------

func _ink(t: Dictionary, mat_name: String, rim_gain: float = 1.5) -> ShaderMaterial:
	var m := _mat(t, BLACK, RUST, rim_gain, mat_name)
	m.set_shader_parameter(&"rim_power", 3.2)
	return m


## Night gone red, without a star.
func _dark_sky(t: Dictionary, at: Vector3, size: Vector2) -> void:
	_sky(t, at, size, Color(0.02, 0.006, 0.01), Color(0.24, 0.04, 0.03))
	var sky := (t.mats as Array).back() as ShaderMaterial
	sky.set_shader_parameter(&"stars", 0.0)
	sky.set_shader_parameter(&"gold", RUST)


## A bramble of thorns along a line: thin rust-rimmed spikes, leaning out.
## Grown by scaling "Thorns" (the director's `grow_thorns`).
func _thorns(t: Dictionary, from: Vector3, to: Vector3, count: int, m: ShaderMaterial,
		tall: float = 1.0) -> Node3D:
	var root := (t.root as Node3D).get_node_or_null("Thorns") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "Thorns"
		(t.root as Node3D).add_child(root)
	for i in count:
		var k := (float(i) + _rng.randf()) / float(count)
		var th := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = _rng.randf_range(0.03, 0.08)
		c.height = _rng.randf_range(0.35, 1.3) * tall
		c.radial_segments = 6
		c.rings = 1
		th.mesh = c
		th.material_override = m
		th.position = from.lerp(to, k) + Vector3(0.0, c.height * 0.4, _rng.randf_range(-0.3, 0.3))
		th.rotation_degrees = Vector3(_rng.randf_range(-20, 20), _rng.randf_range(0, 360), _rng.randf_range(-45, 45))
		root.add_child(th)
	return root


func _floor(t: Dictionary, size: Vector3, at: Vector3) -> void:
	_box(t, size, at, _mat(t, Color(0.012, 0.006, 0.008), RUST, 0.05, "floor"))


## A thin pipe from `a` to `b` (shafts, posts, staves).
func _rod(t: Dictionary, a: Vector3, b: Vector3, r: float, m: ShaderMaterial, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	mi.mesh = c
	mi.material_override = m
	(parent if parent else t.root as Node3D).add_child(mi)
	mi.position = (a + b) * 0.5
	var d := (b - a).normalized()
	if absf(d.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, d))
	return mi


## A head-height point on a figure, in its tableau's frame (rest pose).
func _head_local(t: Dictionary, fig: Node3D) -> Vector3:
	var root := t.root as Node3D
	var top := _top_of(fig)
	return root.to_local(Vector3(fig.global_position.x, top - 0.14 * fig.scale.y, fig.global_position.z))


func _stream(t: Dictionary, from: Vector3, to: Vector3, color: Color) -> GPUParticles3D:
	var life := 1.6
	var p := _particles(t, from, Vector3(0.12, 0.2, 0.12), color, 70, 0.07, Vector3.ZERO, life)
	var pm := p.process_material as ParticleProcessMaterial
	var d := to - from
	pm.direction = d.normalized()
	pm.spread = 4.0
	pm.initial_velocity_min = d.length() / life * 0.9
	pm.initial_velocity_max = d.length() / life * 1.05
	p.preprocess = 0.0
	p.emitting = false
	return p


# --- the queen and the ball (C #5) -----------------------------------------------

## She comes over the sea; at the ball the seven High Lords drink, and their
## light runs out of them into her hands.
func _build_queen(t: Dictionary) -> void:
	_dark_sky(t, Vector3(0, 5, -16), Vector2(64, 28))
	var sea := _mat(t, Color(0.02, 0.01, 0.02), RUST * 0.8, 0.6, "sea")
	_box(t, Vector3(44, 0.2, 8), Vector3(0, -0.1, -11.0), sea)
	var ship := _ink(t, "ship", 1.6)
	_ship(t, Vector3(-6.5, 0.0, -10.0), ship).name = "Ship"
	_floor(t, Vector3(30, 0.4, 12), Vector3(0, -0.2, -1.5))
	var wood := _ink(t, "hall", 0.9)
	_box(t, Vector3(8.6, 0.9, 1.1), Vector3(0, 0.45, -1.7), wood)
	# The High Lords: the only gold left in the painting is theirs.
	var lords := _mat(t, Color(0.03, 0.02, 0.03), GOLD, 2.0, "lords")
	lords.set_shader_parameter(&"glow", 0.35)
	var who := [CAST % ["tamlin", "tamlin"], PEOPLE % "calanmai_1", PEOPLE % "reveler_2", PEOPLE % "calanmai_3",
		PEOPLE % "sentry_1", PEOPLE % "reveler_1", PEOPLE % "calanmai_2"]
	var queen_at := Vector3(5.3, 0.0, -0.7)
	var hands := queen_at + Vector3(-0.35, 1.25, 0.15)
	for i in who.size():
		var x := -3.6 + 1.2 * float(i)
		var f := _figure(t, String(who[i]), Vector3(x, 0.0, -2.75), _rng.randf_range(-8, 8), 1.0, lords, &"idle")
		_rod(t, Vector3(x, 0.9, -1.45), Vector3(x, 1.12, -1.45), 0.05, lords)
		if f:
			_stream(t, _head_local(t, f) - Vector3(0, 0.45, -0.1), hands, Color(1.0, 0.82, 0.45, 0.9)).name = "Stream%d" % i
	var queen := _ink(t, "queen", 2.2)
	var q := _figure(t, PEOPLE % "human_woman", queen_at, -62.0, 1.18, queen, &"talk", 0.45)
	if q:
		q.name = "Queen"
	var thorn_crown := _mat(t, Color(0.3, 0.05, 0.03), RUST, 1.6, "queen")
	thorn_crown.set_shader_parameter(&"glow", 0.5)
	_crown(q, thorn_crown, 1.9, 11, 0.12)
	_thorns(t, Vector3(-11, 0, 1.2), Vector3(11, 0, 1.8), 46, _ink(t, "thorns", 1.2), 0.8)
	_particles(t, Vector3(0, 3, -4), Vector3(12, 3, 4), Color(0.5, 0.1, 0.05, 0.5), 120, 0.05,
			Vector3(0.05, -0.08, 0), 9.0)
	_rail(t, Vector3(-6.4, 1.9, 5.0), Vector3(-6.2, 1.0, -9.0), Vector3(1.4, 1.45, 6.0), Vector3(1.4, 1.3, -2.0), 40.0)


## Their power drains out of them into her hands like light (#5).
func queen_drains(seconds: float) -> void:
	var root := root_of(&"queen")
	for i in 7:
		var s := root.get_node_or_null("Stream%d" % i) as GPUParticles3D
		if s:
			# On the stage's own clock, so nothing outlives it.
			var tw := create_tween()
			tw.tween_interval(seconds * 0.06 * i)
			tw.tween_callback(s.set.bind(&"emitting", true))
			tw.tween_interval(seconds * (0.85 - 0.06 * i))
			tw.tween_callback(s.set.bind(&"emitting", false))
	tween_param(&"queen", &"drain", 0.0, 1.0, seconds, "lords")
	var mats := (tableaux[&"queen"] as Dictionary).mats as Array
	for m: ShaderMaterial in mats:
		if String(m.resource_name) == "queen":
			create_tween().tween_method(func(k: float) -> void:
				m.set_shader_parameter(&"gold", RUST.lerp(GOLD, k))
				m.set_shader_parameter(&"glow", lerpf(0.0, 1.1, k)), 0.0, 1.0, seconds)


# --- the masquerade and the curse (C #6) -----------------------------------------

func _build_masks(t: Dictionary) -> void:
	_dark_sky(t, Vector3(0, 5, -14), Vector2(60, 26))
	_floor(t, Vector3(30, 0.4, 14), Vector3(0, -0.2, -2.0))
	var court := _ink(t, "court", 1.6)
	var masks := _mat(t, Color(0.16, 0.04, 0.03), RUST, 1.8, "masks")
	masks.set_shader_parameter(&"glow", 0.3)
	var kinds := ["calanmai_1", "reveler_1", "calanmai_2", "reveler_3", "calanmai_3", "reveler_2", "sentry_2", "blessed"]
	var faces := Node3D.new()
	faces.name = "Masks"
	(t.root as Node3D).add_child(faces)
	# The dancers, frozen mid-waltz in a ring behind the two of them.
	for i in kinds.size():
		var a := PI * (0.05 + 0.9 * float(i) / float(kinds.size() - 1))
		var p := Vector3(cos(a) * -3.6, 0.0, -sin(a) * 1.8 - 1.2)
		var f := _figure(t, PEOPLE % kinds[i], p, rad_to_deg(a) - 90.0 + _rng.randf_range(-20, 20), 1.0, court,
				&"walk", _rng.randf())
		_mask(t, f, masks, faces, i)
	var tamlin := _figure(t, CAST % ["tamlin", "tamlin"], Vector3(-0.85, 0.0, 0.3), 72.0, 1.06, court)
	if tamlin:
		tamlin.name = "Tamlin"
	_mask(t, tamlin, masks, faces, 0)
	var queen := _ink(t, "queen", 2.2)
	var q := _figure(t, PEOPLE % "human_woman", Vector3(0.85, 0.0, 0.3), -72.0, 1.12, queen, &"talk", 0.2)
	if q:
		q.name = "Queen"
	var thorn_crown := _mat(t, Color(0.3, 0.05, 0.03), RUST, 1.6, "queen")
	thorn_crown.set_shader_parameter(&"glow", 0.5)
	_crown(q, thorn_crown, 1.8, 11, 0.12)
	var thorns := _thorns(t, Vector3(-9, 0, 1.6), Vector3(9, 0, 2.2), 40, _ink(t, "thorns", 1.2), 1.1)
	thorns.scale = Vector3(1.0, 0.001, 1.0)
	_rail(t, Vector3(-1.2, 1.7, 6.4), Vector3(0.0, 1.4, -0.4), Vector3(0.3, 1.65, 4.2), Vector3(0.0, 1.5, 0.0), 40.0)


## An animal mask on a dancer's face (fox ears, a bird's beak, a stag's
## tines), held at scale 0 until the curse grows it fast.
func _mask(t: Dictionary, fig: Node3D, m: ShaderMaterial, holder: Node3D, kind: int) -> void:
	if fig == null:
		return
	var head := _head_local(t, fig)
	var fwd := (fig.basis * Vector3(0, 0, -1)).normalized()   # the model's own forward (-z), turned
	var mask := Node3D.new()
	mask.position = head + fwd * 0.1 * fig.scale.y
	mask.basis = Basis.looking_at(fwd, Vector3.UP)
	mask.scale = Vector3.ONE * 0.001
	holder.add_child(mask)
	var face := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.21, 0.12, 0.04)
	face.mesh = b
	face.material_override = m
	mask.add_child(face)
	match kind % 3:
		0:
			for sx in [-1.0, 1.0]:
				var ear := MeshInstance3D.new()
				var pr := PrismMesh.new()
				pr.size = Vector3(0.07, 0.13, 0.02)
				ear.mesh = pr
				ear.material_override = m
				ear.position = Vector3(0.07 * sx, 0.12, 0.0)
				mask.add_child(ear)
		1:
			var beak := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.035
			c.height = 0.16
			beak.mesh = c
			beak.material_override = m
			beak.position = Vector3(0.0, -0.02, -0.09)
			beak.rotation_degrees.x = -90.0
			mask.add_child(beak)
		_:
			for sx in [-1.0, 1.0]:
				_rod(t, Vector3(0.05 * sx, 0.05, 0.0), Vector3(0.16 * sx, 0.28, 0.0), 0.012, m, mask)
				_rod(t, Vector3(0.11 * sx, 0.16, 0.0), Vector3(0.05 * sx, 0.3, 0.0), 0.01, m, mask)


## Tamlin spits in her face (#6): a spray from him to her.
func masks_spit() -> void:
	var root := root_of(&"masks")
	var t := tableaux[&"masks"] as Dictionary
	var tam := root.get_node_or_null("Tamlin") as Node3D
	var q := root.get_node_or_null("Queen") as Node3D
	if tam == null or q == null:
		return
	var s := _stream(t, _head_local(t, tam) + Vector3(0.12, -0.04, 0.0), _head_local(t, q), Color(0.9, 0.5, 0.4, 0.8))
	s.amount = 24
	s.lifetime = 0.35
	s.one_shot = true
	var pm := s.process_material as ParticleProcessMaterial
	pm.spread = 10.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 4.5
	s.emitting = true


## Her hand closes: the masks grow fast to every face, thorns rise, the paint
## cracks (#6).
func masks_curse(seconds: float) -> void:
	var root := root_of(&"masks")
	var faces := root.get_node("Masks") as Node3D
	var tw := create_tween().set_parallel(true)
	var i := 0
	for m: Node3D in faces.get_children():
		tw.tween_property(m, ^"scale", Vector3.ONE * 1.06, seconds * 0.35).set_delay(seconds * 0.04 * i) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	tw.tween_property(root.get_node("Thorns"), ^"scale", Vector3.ONE, seconds).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween_param(&"masks", &"crack", 0.0, 0.7, seconds)
	tween_param(&"masks", &"glow", 0.0, 1.0, seconds * 0.5, "queen")
	shake(0.6)


# --- the terms (C #7) ------------------------------------------------------------

## The hourglass; the girl with ice in her chest and a bow; the wolf; the arrow.
func _build_terms(t: Dictionary) -> void:
	_dark_sky(t, Vector3(0, 5, -12), Vector2(56, 24))
	_floor(t, Vector3(30, 0.4, 12), Vector3(0, -0.2, -1.5))
	var ink := _ink(t, "terms", 1.6)
	var glass := _mat(t, Color(0.05, 0.02, 0.03), RUST, 2.4, "terms")
	# The hourglass, its sand running.
	var hg := Node3D.new()
	hg.name = "Hourglass"
	hg.position = Vector3(-4.6, 0.0, -0.8)
	(t.root as Node3D).add_child(hg)
	for y in [0.06, 2.04]:
		var disc := MeshInstance3D.new()
		var dc := CylinderMesh.new()
		dc.top_radius = 0.62
		dc.bottom_radius = 0.62
		dc.height = 0.12
		disc.mesh = dc
		disc.material_override = ink
		disc.position.y = y
		hg.add_child(disc)
	for k in 3:
		var a := TAU * k / 3.0
		_rod(t, Vector3(cos(a) * 0.55, 0.1, sin(a) * 0.55), Vector3(cos(a) * 0.55, 2.0, sin(a) * 0.55), 0.035, ink, hg)
	for half in [[1.55, 0.48, 0.03], [0.6, 0.03, 0.48]]:
		var bulb := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = half[1]
		bc.bottom_radius = half[2]
		bc.height = 0.9
		bulb.mesh = bc
		bulb.material_override = glass
		bulb.position.y = half[0] - 0.05
		hg.add_child(bulb)
	var sand := _mat(t, Color(0.45, 0.1, 0.05), RUST, 1.0, "sand")
	sand.set_shader_parameter(&"glow", 0.6)
	var top := MeshInstance3D.new()
	top.name = "SandTop"
	var tc := CylinderMesh.new()
	tc.top_radius = 0.4
	tc.bottom_radius = 0.03
	tc.height = 0.5
	top.mesh = tc
	top.material_override = sand
	top.position.y = 1.3
	hg.add_child(top)
	var low := MeshInstance3D.new()
	low.name = "SandLow"
	var lc := CylinderMesh.new()
	lc.top_radius = 0.0
	lc.bottom_radius = 0.42
	lc.height = 0.4
	low.mesh = lc
	low.material_override = sand
	low.position.y = 0.32
	low.scale = Vector3(1.0, 0.15, 1.0)
	hg.add_child(low)
	var fall := _particles(t, hg.position + Vector3(0, 0.75, 0), Vector3(0.01, 0.2, 0.01), Color(0.9, 0.3, 0.12, 0.9),
			40, 0.025, Vector3(0, -2.0, 0), 0.5)
	fall.name = "Sand"
	# The girl: small, human, ice in her chest, a bow in her hand.
	var girl := _ink(t, "girl", 2.0)
	var g := _figure(t, PEOPLE % "human_youth", Vector3(-1.5, 0.0, 0.0), 58.0, 0.92, girl, &"idle", 0.2)
	if g:
		g.name = "Girl"
		var chest := _head_local(t, g) - Vector3(0, 0.42, 0) + (g.basis * Vector3(0, 0, -1)).normalized() * 0.11
		var ice := MeshInstance3D.new()
		ice.name = "Ice"
		var d := SphereMesh.new()
		d.radius = 0.07
		d.height = 0.2
		d.radial_segments = 4
		d.rings = 2
		ice.mesh = d
		var im := StandardMaterial3D.new()
		im.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		im.albedo_color = ICE
		im.emission_enabled = true
		im.emission = ICE
		im.emission_energy_multiplier = 2.2
		ice.material_override = im
		ice.position = chest
		(t.root as Node3D).add_child(ice)
		_particles(t, chest, Vector3(0.08, 0.08, 0.08), Color(ICE, 0.7), 24, 0.03, Vector3(0, -0.05, 0), 2.0)
		# The bow, held out before her: a stave in an arc and its string.
		var bow := Node3D.new()
		bow.name = "Bow"
		bow.position = chest + Vector3(0.42, -0.05, 0.12)
		(t.root as Node3D).add_child(bow)
		var prev := Vector3.ZERO
		for k in 9:
			var a := deg_to_rad(lerpf(-55.0, 55.0, k / 8.0))
			var pt := Vector3(cos(a) * 0.55 - 0.55, sin(a) * 0.55, 0.0)
			if k > 0:
				_rod(t, prev, pt, 0.018, girl, bow)
			prev = pt
		var tip := Vector3(cos(deg_to_rad(55.0)) * 0.55 - 0.55, sin(deg_to_rad(55.0)) * 0.55, 0.0)
		_rod(t, tip, Vector3(tip.x, -tip.y, 0.0), 0.005, girl, bow)
	# The wolf, stalking toward her.
	var beast := _ink(t, "wolf", 1.4)
	var w := _figure(t, WOLF, Vector3(2.7, 0.0, -0.3), -78.0, 1.15, beast, &"stalk")
	if w:
		w.name = "Wolf"
	# The arrow on the string, waiting.
	var arrow := Node3D.new()
	arrow.name = "Arrow"
	(t.root as Node3D).add_child(arrow)
	var ash := _mat(t, Color(0.1, 0.04, 0.03), RUST, 2.0, "arrow")
	ash.set_shader_parameter(&"glow", 0.4)
	_rod(t, Vector3(-0.45, 0, 0), Vector3(0.4, 0, 0), 0.012, ash, arrow)
	var head := MeshInstance3D.new()
	var hp := PrismMesh.new()
	hp.size = Vector3(0.07, 0.12, 0.012)
	head.mesh = hp
	head.material_override = ash
	head.position = Vector3(0.46, 0, 0)
	head.rotation_degrees.z = -90.0
	arrow.add_child(head)
	if g:
		arrow.position = (t.root as Node3D).get_node("Bow").position + Vector3(0.05, 0.0, 0.0)
	_thorns(t, Vector3(-9, 0, 1.4), Vector3(9, 0, 2.0), 40, _ink(t, "thorns", 1.2), 0.9)
	_rail(t, Vector3(-4.4, 1.35, 4.6), Vector3(-4.2, 1.0, -1.0), Vector3(0.5, 1.25, 5.8), Vector3(0.5, 0.95, -0.6), 40.0)


## The sand runs down over `seconds`.
func terms_run(seconds: float) -> void:
	var hg := root_of(&"terms").get_node("Hourglass") as Node3D
	var tw := create_tween().set_parallel(true)
	tw.tween_property(hg.get_node("SandTop"), ^"scale", Vector3(0.3, 0.1, 0.3), seconds)
	tw.tween_property(hg.get_node("SandLow"), ^"scale", Vector3.ONE, seconds)


## The arrow flies into the wolf, and it falls (#7).
func terms_arrow(seconds: float) -> void:
	var root := root_of(&"terms")
	var arrow := root.get_node("Arrow") as Node3D
	var wolf := root.get_node_or_null("Wolf") as Node3D
	var to := Vector3(2.0, 0.95, -0.3)
	var tw := create_tween()
	tw.tween_property(arrow, ^"position", to, seconds * 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var ap := wolf.find_child("AnimationPlayer", true, false) as AnimationPlayer if wolf else null
		if ap and ap.has_animation(&"death_l"):
			ap.get_animation(&"death_l").loop_mode = Animation.LOOP_NONE
			ap.play(&"death_l")
		arrow.visible = false)


# --- the well (B #13) ------------------------------------------------------------

## One gold memory, a second long: a girl's face at the village well.
func _build_well(t: Dictionary) -> void:
	_sky(t, Vector3(0, 3, -8), Vector2(40, 20), Color(0.12, 0.08, 0.1), Color(0.6, 0.42, 0.3))
	var stone := _mat(t, Color(0.08, 0.06, 0.07), GOLD, 1.2, "well")
	var girl := _mat(t, Color(0.09, 0.06, 0.08), Color(1.0, 0.9, 0.7), 2.2, "well")
	var well := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.62
	c.bottom_radius = 0.66
	c.height = 0.8
	well.mesh = c
	well.material_override = stone
	well.position = Vector3(0.75, 0.4, -0.5)
	(t.root as Node3D).add_child(well)
	for sx in [-1.0, 1.0]:
		_box(t, Vector3(0.08, 1.5, 0.08), Vector3(0.75 + 0.6 * sx, 1.15, -0.5), stone)
	_box(t, Vector3(1.4, 0.08, 0.08), Vector3(0.75, 1.9, -0.5), stone)
	_box(t, Vector3(0.22, 0.22, 0.22), Vector3(0.75, 1.3, -0.5), stone)
	var g := _figure(t, PEOPLE % "human_woman", Vector3(-0.15, 0.0, 0.05), 68.0, 0.97, girl, &"talk", 0.3)
	if g:
		g.name = "Girl"
	_particles(t, Vector3(0, 1.4, 0), Vector3(1.6, 0.8, 0.6), Color(1.0, 0.85, 0.5, 0.7), 60, 0.03,
			Vector3(0, 0.05, 0), 5.0)
	var face := Vector3(-0.3, 1.5, 0.05)
	if g:
		face = _head_local(t, g)
	_rail(t, face + Vector3(0.5, -0.25, 3.0), face + Vector3(0.45, -0.3, 0.0), face + Vector3(0.4, -0.2, 2.5), face + Vector3(0.4, -0.25, 0.0), 36.0)

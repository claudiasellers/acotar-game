## Cutscene C "The Silent Manor" (lane L33; scripts.md section 4, end of ch 31
## into ch 32): Feyre back across the Wall, in the wrecked, empty house.
## Alis limps in, takes her to the kitchen and, packing a satchel, tells her
## everything nobody could say all game, in the opening film's living-mural
## style gone dark (MuralDark: rust and thorns where the gold was). Tamlin is
## Under the Mountain with Amarantha; Feyre will go after him. Dawn on the
## garden steps: she walks out north, toward the mountain.
##
## Played by the alis_truth moment (anchor manor_alis_hiding, the kitchen),
## which raises alis_truth_heard on the film's seen fact; the walk north
## afterwards is the deed for departed_for_mountain. Points are in the manor
## house's layout frame (use_house): the entry hall Rect2(-10, -60, 20, 32)
## with the dining-room door on its east wall at (10, -38), the kitchen
## Rect2(42, -68, 14, 14) with its two long tables at z -60, the garden room
## Rect2(-10, -72, 20, 12) whose doors open north onto the steps.
extends CutsceneDirector

const NIGHT := 0.2
const DAWN := 0.27
const SATCHEL_COLOR := Color(0.32, 0.2, 0.12)
## The pass into the mountain, in world x/z (the_pass_road anchor).
const PASS_WORLD := Vector2(300.0, -1680.0)

const FEYRE_KNEEL := Vector3(1.6, 0.0, -41.5)
const FEYRE_HIDE := Vector3(10.65, 0.0, -37.35)
const ALIS_IN := Vector3(1.0, 0.0, -29.2)
const ALIS_SNIFF := Vector3(4.9, 0.0, -35.4)
const ALIS_PACK := Vector3(49.25, 0.0, -61.0)
const FEYRE_SIT := Vector3(50.55, 0.0, -58.85)
const FEYRE_STAND := Vector3(50.3, 0.0, -58.3)
const SATCHEL_AT := Vector3(49.25, 0.9, -60.25)
const STEPS_IN := Vector3(0.0, 0.0, -70.6)
const STEPS_OUT := Vector3(0.0, 0.0, -75.4)

var alis: Node3D
var hood: Node3D
var cloak: Node3D
var satchel: Node3D
var insert: FilmInsert
var mural: MuralDark


func _setup() -> void:
	use_house()
	Clock.from_dict({"time_of_day": NIGHT, "day": Clock.day})
	player.veil_to(1.0, 0.0)
	grade.to_param(&"cold", 0.35, 0.0)
	_wreck()
	put_feyre(FEYRE_KNEEL, FEYRE_KNEEL + Vector3(0.0, 0.0, 2.0))
	pose(feyre_model(), &"kneel_slump", 0.0)
	alis = bring(&"alis", ALIS_IN, ALIS_SNIFF)
	_quiet(alis)
	alis.visible = false
	_cloak()
	insert = FilmInsert.new()
	player.add_child(insert)
	mural = MuralDark.of([&"queen", &"masks", &"terms"])
	insert.set_stage(mural)


func _end_mark() -> Transform3D:
	var p := ground(STEPS_OUT)
	return Transform3D(Basis.looking_at(_north_dir(p), Vector3.UP), p)


func _teardown() -> void:
	if insert and is_instance_valid(insert):
		insert.queue_free()
	Clock.from_dict({"time_of_day": DAWN, "day": Clock.day})
	if alis and is_instance_valid(alis):
		alis.visible = true
		put(alis, STEPS_IN + Vector3(0.9, 0.0, -1.2), STEPS_OUT + Vector3(0.0, 0.0, -4.0))


func _quiet(who: Node3D) -> void:
	var n: Variant = who.get(&"notice") if who else null
	if n is Object and &"enabled" in (n as Object):
		(n as Object).set(&"enabled", false)


## Toward the pass, flat.
func _north_dir(from: Vector3) -> Vector3:
	var d := Vector3(PASS_WORLD.x - from.x, 0.0, PASS_WORLD.y - from.z)
	return d.normalized() if d.length() > 1.0 else -frame.basis.z


func _mat(color: Color, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


## The hall wrecked: blood dried dark on the marble, claw gouges in the walls.
func _wreck() -> void:
	var blood := _mat(Color(0.18, 0.02, 0.02), 0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 32
	for i in 7:
		var pool := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = rng.randf_range(0.25, 0.8)
		c.bottom_radius = c.top_radius
		c.height = 0.01
		pool.mesh = c
		pool.material_override = blood
		add_prop(pool, ground(Vector3(rng.randf_range(-5.0, 6.0), 0.0, rng.randf_range(-48.0, -33.0)), 0.006))
		pool.scale = Vector3(rng.randf_range(0.6, 1.8), 1.0, rng.randf_range(0.5, 1.2))
		pool.rotation.y = rng.randf() * TAU
	var gouge := _mat(Color(0.12, 0.1, 0.09), 0.9)
	# Four claws dragged down the east wall, beside the dining-room door.
	for set_i in 3:
		var base := Vector3(9.94, 1.2 + set_i * 0.35, -43.0 + set_i * 2.6)
		for k in 4:
			var g := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.03, 1.1, 0.035)
			g.mesh = b
			g.material_override = gouge
			add_prop(g, at(base + Vector3(0.0, 0.0, k * 0.11)))
			g.global_basis = frame.basis * Basis(Vector3.RIGHT, 0.35)


## A travelling cloak and its hood, over Alis until the hood falls.
func _cloak() -> void:
	var wool := _mat(Color(0.16, 0.14, 0.12), 0.95)
	cloak = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.42
	c.height = 1.3
	c.cap_bottom = false
	(cloak as MeshInstance3D).mesh = c
	(cloak as MeshInstance3D).material_override = wool
	alis.add_child(cloak)
	cloak.position = Vector3(0.0, 0.72, 0.0)
	hood = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.17
	s.height = 0.38
	(hood as MeshInstance3D).mesh = s
	(hood as MeshInstance3D).material_override = wool
	alis.add_child(hood)
	hood.position = Vector3(0.0, CutsceneDirector.head_of(alis).y - alis.global_position.y + 0.02, 0.03)
	props.append(cloak)
	props.append(hood)


## Feyre walks to `local` over `seconds`: her body moves, her model faces the way.
func walk_feyre(local: Vector3, seconds: float) -> void:
	var to := ground(local)
	var d := to - feyre.global_position
	_face_feyre(d)
	var ap := anim_of(feyre_model())
	if ap and ap.has_animation(&"walk"):
		ap.play(&"walk", 0.3)
	var tw := create_tween()
	tw.tween_property(feyre, ^"global_position", to, seconds)
	tw.tween_callback(func() -> void:
		if ap and ap.has_animation(&"idle"):
			ap.play(&"idle", 0.5))


# --- beats -----------------------------------------------------------------------

## #1 The entry hall, wrecked. Feyre kneels among it. Wind; no birds.
func _b_hall() -> void:
	player.veil_to(0.0, 2.5)
	shot(Vector3(7.4, 3.4, -31.0), Vector3(1.6, 0.6, -41.5), 42.0, 0.6, 6.0)


## #2 A sound: she hides behind the dining-room door.
func _b_sound() -> void:
	pose(feyre_model(), &"", 0.0)
	put_feyre(FEYRE_HIDE, ALIS_SNIFF)
	pose(feyre_model(), &"crouch", 0.0)
	# Over her crouched head, out through the doorway (z -39.2 to -36.8) into the hall.
	shot(Vector3(12.2, 1.35, -37.9), Vector3(4.9, 1.0, -35.4), 38.0, 0.15, 5.0)


## A cloaked figure limps in and sniffs the air. The hood falls: Alis.
func _b_hood() -> void:
	alis.visible = true
	put(alis, ALIS_IN, ALIS_SNIFF)
	walk(alis, ALIS_SNIFF, 3.6)
	var ap := anim_of(alis)
	after(1.0, func() -> void:
		if ap:
			ap.speed_scale = 0.55)
	after(4.0, func() -> void:
		turn(alis, FEYRE_HIDE, 0.8)
		var tw := create_tween()
		tw.tween_property(hood, ^"position:y", hood.position.y - 0.25, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(hood, ^"scale", Vector3(1.3, 0.25, 1.3), 0.5)
		tw.tween_callback(func() -> void: hood.visible = false)
		close(alis, 1.6, 0.3, 32.0, 0.15, 3.0, -0.04))


## #3 The kitchen. Alis packs a satchel while they talk.
func _b_kitchen() -> void:
	pose(feyre_model(), &"", 0.0)
	cloak.visible = false
	put(alis, ALIS_PACK, ALIS_PACK + Vector3(0.0, 0.0, 1.0))
	put_feyre(FEYRE_SIT, FEYRE_SIT + Vector3(0.0, 0.0, -1.0))
	pose(feyre_model(), &"sit", 0.0)
	pose(alis, &"pack", 0.6)
	satchel = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.42, 0.3, 0.16)
	(satchel as MeshInstance3D).mesh = b
	(satchel as MeshInstance3D).material_override = _mat(SATCHEL_COLOR, 0.8)
	add_prop(satchel, at(SATCHEL_AT + Vector3(0.0, 0.15, 0.0)))
	shot(Vector3(52.6, 1.65, -57.2), Vector3(49.6, 1.0, -60.5), 40.0, 0.3, 6.0)
	after(4.4, func() -> void: over(feyre, alis, 34.0, -0.4, 0.15, 4.0))
	after(8.4, func() -> void: close(alis, 1.3, 0.3, 30.0, 0.15, 3.0, -0.05))


## #4 Alis, still packing: High Queen of Prythian; the game is over, to her.
func _b_packing() -> void:
	close(alis, 1.15, -0.3, 30.0, 0.12, 5.0, -0.05)
	after(5.3, func() -> void: over(alis, feyre, 34.0, 0.4, 0.12, 4.0))


## #5 The mural, told true: she came over the sea; at the ball she stole the
## High Lords' power, all seven.
func _b_mural_queen() -> void:
	mural.play(&"queen", 11.0, 2.4)
	insert.cover_to(1.0, 1.6)


func _b_drain() -> void:
	mural.queen_drains(4.0)


## #6 The masquerade. Tamlin refuses her and spits in her face.
func _b_mural_masks() -> void:
	mural.play(&"masks", 15.0, 1.8)
	after(3.0, func() -> void: mural.masks_spit())


## Her hand closes: the masks grow fast to every face.
func _b_curse() -> void:
	mural.masks_curse(2.6)


## #7 The terms: the hourglass, the girl with ice in her heart and a bow, the wolf.
func _b_mural_terms() -> void:
	mural.play(&"terms", 19.0, 1.8)
	mural.terms_run(19.0)


## The arrow.
func _b_arrow() -> void:
	mural.terms_arrow(2.4)


## #8 Back in the kitchen: close on Feyre as she understands.
func _b_understand() -> void:
	insert.cover_to(0.0, 1.4)
	close(feyre, 0.95, 0.25, 30.0, 0.15, 5.0, -0.05)
	after(5.2, func() -> void: close(alis, 1.2, -0.3, 30.0, 0.12, 6.0, -0.05))


## #9 Alis stops packing: "You stupid, stupid girl. You never said it."
func _b_stop() -> void:
	pose(alis, &"", 0.8)
	turn(alis, FEYRE_SIT, 0.8)
	over(feyre, alis, 32.0, -0.4, 0.15, 4.5)
	after(4.8, func() -> void: close(feyre, 1.0, 0.25, 30.0, 0.12, 5.5, -0.05))


## #10 Feyre stands. Her face sets: "Where is he?"
func _b_stand() -> void:
	pose(feyre_model(), &"", 1.0)
	put_feyre(FEYRE_STAND, ALIS_PACK)
	shot(Vector3(47.2, 0.95, -57.6), Vector3(50.3, 1.5, -58.3), 36.0, 0.2, 3.0)
	after(3.0, func() -> void: over(feyre, alis, 32.0, -0.4, 0.12, 4.0))
	after(7.2, func() -> void: close(feyre, 1.0, 0.3, 28.0, 0.15, 3.0, -0.05))


## #11 Alis looks at her a long moment, then pulls the satchel on: "Get your cloak."
func _b_look() -> void:
	close(alis, 1.25, -0.25, 30.0, 0.1, 3.0, -0.05)
	after(2.2, func() -> void:
		if satchel and is_instance_valid(satchel):
			satchel.reparent(alis)
			satchel.position = Vector3(0.22, 0.95, 0.12)
			satchel.rotation = Vector3(0.0, 0.0, 0.3))


## #12 The garden steps at dawn. She walks out of the ruined house, north;
## the mountain is the one shape on the skyline. Ease into her camera.
func _b_steps() -> void:
	player.veil_to(1.0, 0.3)
	after(0.35, func() -> void:
		Clock.from_dict({"time_of_day": DAWN, "day": Clock.day})
		grade.to_param(&"cold", 0.0, 4.0)
		alis.visible = false
		put_feyre(STEPS_IN, STEPS_OUT)
		_mountain()
		var p := ground(STEPS_IN)
		var n := _north_dir(p)
		var right := n.cross(Vector3.UP)
		shot_world(p - n * 2.6 + right * 0.6 + Vector3.UP * 1.45, p + n * 60.0 + Vector3.UP * 14.0, 40.0, 0.6, 9.0)
		player.veil_to(0.0, 1.6)
		walk_feyre(STEPS_OUT, 6.0))


## Under the Mountain: a dark peak far to the north, alone on the horizon.
func _mountain() -> void:
	var p := ground(STEPS_OUT)
	var n := _north_dir(p)
	var across := n.cross(Vector3.UP)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.12, 0.17)
	m.roughness = 1.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A ragged range, not a cone: the peak and two shoulders, few-sided and
	# turned unevenly so the skyline breaks.
	for spec: Array in [[0.0, 1400.0, 420.0, 330.0, 0.3], [-260.0, 1520.0, 300.0, 280.0, 1.1],
			[230.0, 1480.0, 250.0, 300.0, 2.0], [110.0, 1350.0, 190.0, 160.0, 0.7]]:
		var peak := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 4.0
		c.bottom_radius = spec[3]
		c.height = spec[2]
		c.radial_segments = 6
		c.rings = 1
		peak.mesh = c
		peak.material_override = m
		peak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var at_p: Vector3 = p + n * float(spec[1]) + across * float(spec[0])
		add_prop(peak, Vector3(at_p.x, p.y + float(spec[2]) * 0.3, at_p.z))
		peak.rotation = Vector3(0.0, spec[4], 0.04 * signf(float(spec[0])))


func _b_handover() -> void:
	grade.to_param(&"cold", 0.0, 1.0)

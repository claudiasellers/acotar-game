## Cutscene B "The Night Court" (lane L33; scripts.md section 3, ch 26): lunch
## in the dining hall. Tamlin leaps up snarling at the doors, Lucien hides
## Feyre in the window curtains under a glamour, and a stranger walks into
## the house: Rhysand, High Lord of the Night Court. He finds her, gets into
## her head, makes Tamlin beg, hears her false name, and is gone. The first
## time the player sees Tamlin afraid, and hears "Amarantha" and "Under the
## Mountain".
##
## Played by the rhysand_visit moment, which raises rhysand_faced when the
## film's seen fact is written. "fact.false_name_clare_beddor" is written at
## its frame by the film itself. Points are in the manor house's layout frame
## (use_house): the dining hall is Rect2(10, -48, 22, 20), its doors on the
## west wall at (10, -38), the long table at (21, -38), windows on the south
## wall (z -28). Rhysand has no model yet: until the cast lane makes one he
## is the cast rig re-dressed (Tamlin's build, unmasked): blue-black hair,
## black clothes with dark silver, violet eyes, half in his own shadow, so a
## stand-in reads as intended (scripts.md, B note).
extends CutsceneDirector

const NOON := 0.5
const VEIL := preload("res://story/film/cutscenes/glamour_veil.gdshader")
const RHYS_MODEL := "res://characters/rhysand/rhysand_model.tscn"
## The stand-in's rig: tall, young, athletic; his mask and claws come off.
const RHYS_STANDIN := "res://characters/tamlin/tamlin_model.tscn"
const RHYS_HIDE := ["tamlin_mask", "Claws"]
const PLATE := "res://art/dinner/dinner_plate.glb"
const GOBLET := "res://art/dinner/dinner_goblet.glb"
const KNIFE := "res://characters/father/model/father_knife.glb"
const VIOLET := Color(0.62, 0.42, 1.0)
const TABLE_TOP := 0.8

## The seats: Tamlin at the head (a chair the scene brings), Lucien and
## Feyre facing each other at his right and left hand.
const TAMLIN_SEAT := Vector3(16.35, 0.0, -38.0)
const LUCIEN_SEAT := Vector3(17.6, 0.0, -39.1)
const FEYRE_SEAT := Vector3(17.6, 0.0, -36.9)
const DOOR := Vector3(10.4, 0.0, -38.0)
## The curtains: the window at x 16.6 on the south wall.
const DRAPE := Vector3(15.9, 0.0, -28.5)
const LUCIEN_GUARD := Vector3(15.9, 0.0, -29.05)
const LUCIEN_ASIDE := Vector3(14.85, 0.0, -29.7)
const RHYS_GREET := Vector3(14.3, 0.0, -37.3)
const RHYS_GOBLET := Vector3(17.25, 0.0, -36.35)
const RHYS_FEYRE := Vector3(15.9, 0.0, -29.75)
const TAMLIN_BEG := Vector3(16.1, 0.0, -32.6)
const ROOM := Vector3(18.5, 0.0, -34.0)

var tamlin: Node3D
var lucien: Node3D
var rhys: Node3D
var chair: Node3D
var knife_on_table: Node3D
var goblet_on_table: Node3D
var held_knife: Node3D
var veil: MeshInstance3D
var veil_mat: ShaderMaterial
var shadow: OmniLight3D
var smoke: GPUParticles3D
var insert: FilmInsert
var mural: MuralDark


func _setup() -> void:
	use_house()
	Clock.from_dict({"time_of_day": NOON, "day": Clock.day})
	player.veil_to(1.0, 0.0)
	_dress_table()
	# Their own: the lunch's Tamlin and Lucien go when the lunch ends.
	tamlin = bring_own(&"tamlin", TAMLIN_SEAT, TAMLIN_SEAT + Vector3(1.0, 0.0, 0.0))
	lucien = bring_own(&"lucien", LUCIEN_SEAT, LUCIEN_SEAT + Vector3(0.0, 0.0, 1.0))
	for who in [tamlin, lucien]:
		_quiet(who)
	put_feyre(FEYRE_SEAT, FEYRE_SEAT + Vector3(0.0, 0.0, -1.0))
	pose(tamlin, &"sit", 0.0)
	pose(lucien, &"sit", 0.0)
	pose(feyre_model(), &"sit", 0.0)
	rhys = _rhysand()
	rhys.visible = false
	insert = FilmInsert.new()
	player.add_child(insert)
	mural = MuralDark.of([&"well"])
	insert.set_stage(mural)


func _end_mark() -> Transform3D:
	return Transform3D(Basis.looking_at(at(ROOM) - at(DRAPE), Vector3.UP).orthonormalized(), ground(DRAPE + Vector3(0, 0, -0.15)))


func _teardown() -> void:
	if insert and is_instance_valid(insert):
		insert.queue_free()
	for who in [tamlin, lucien]:
		if who and is_instance_valid(who) and who.has_method(&"set_claws"):
			who.call(&"set_claws", 0.0)
	# Where play finds them: Tamlin and Lucien getting up off the floor.
	if tamlin and is_instance_valid(tamlin):
		put(tamlin, TAMLIN_BEG, DRAPE)
	if lucien and is_instance_valid(lucien):
		put(lucien, LUCIEN_ASIDE, ROOM)


func _quiet(who: Node3D) -> void:
	var n: Variant = who.get(&"notice") if who else null
	if n is Object and &"enabled" in (n as Object):
		(n as Object).set(&"enabled", false)


func _top(local: Vector3) -> Vector3:
	return at(Vector3(local.x, TABLE_TOP, local.z))


## Lunch: a chair at the head for Tamlin, three places laid, her knife.
func _dress_table() -> void:
	chair = PropLib.build(&"chair_dining")
	add_prop(chair, at(TAMLIN_SEAT))
	chair.global_basis = Basis(Vector3.UP, frame.basis.get_euler().y - PI * 0.5)
	for p in [[Vector3(17.05, 0, -38.0), -90.0], [Vector3(17.6, 0, -38.5), 0.0], [Vector3(17.6, 0, -37.5), 180.0]]:
		load_prop(PLATE, _top(p[0]), float(p[1]))
	load_prop(GOBLET, _top(Vector3(17.25, 0, -38.35)))
	load_prop(GOBLET, _top(Vector3(17.95, 0, -38.65)))
	goblet_on_table = load_prop(GOBLET, _top(Vector3(17.95, 0, -37.35)))
	knife_on_table = load_prop(KNIFE, _top(Vector3(17.95, 0.01, -37.55)), 90.0)
	if knife_on_table:
		knife_on_table.rotation_degrees.x = 90.0


# --- Rhysand ---------------------------------------------------------------------

## The cast lane's Rhysand when there is one; until then a painted stand-in.
## Either way: violet eyes, his own dark around him, the light cooling.
func _rhysand() -> Node3D:
	var who: Node3D
	if ResourceLoader.exists(RHYS_MODEL):
		who = (load(RHYS_MODEL) as PackedScene).instantiate() as Node3D
	else:
		who = (load(RHYS_STANDIN) as PackedScene).instantiate() as Node3D
	who.name = "FilmRhysand"
	add_prop(who, ground(DOOR))
	cast.append(who)
	# Re-dressed once in the tree: the rig puts its outfit on in _ready.
	if not ResourceLoader.exists(RHYS_MODEL):
		_redress(who)
	_quiet(who)
	if who.find_child("Eyes", true, false) == null:
		_eyes(who)
	shadow = OmniLight3D.new()
	shadow.light_negative = true
	shadow.light_color = Color(0.85, 0.8, 1.0)
	shadow.light_energy = 0.0
	shadow.omni_range = 5.0
	shadow.position = Vector3(0.0, 1.3, 0.0)
	who.add_child(shadow)
	smoke = GPUParticles3D.new()
	smoke.amount = 60
	smoke.lifetime = 3.0
	smoke.emitting = false
	smoke.local_coords = false
	smoke.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 5, 6))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.45
	pm.gravity = Vector3(0.0, 0.12, 0.0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.scale_min = 0.7
	pm.scale_max = 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	smoke.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.7)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.03, 0.02, 0.06, 0.55)
	sm.albedo_texture = MuralStage._soft_dot()
	q.material = sm
	smoke.draw_pass_1 = q
	smoke.position = Vector3(0.0, 0.35, 0.0)
	who.add_child(smoke)
	return who


func _paint(node: Node, m: Material) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = m
	for c in node.get_children():
		_paint(c, m)


## The stand-in dressed as Rhysand: everything Tamlin's that would give
## him away goes (mask, claws), hair blue-black, clothes black with dark
## silver at the trims and chains, the eyes violet and faintly lit.
func _redress(who: Node3D) -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.028, 0.026, 0.036)
	black.roughness = 0.55
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.36, 0.36, 0.42)
	silver.metallic = 0.8
	silver.roughness = 0.35
	var hair := StandardMaterial3D.new()
	hair.albedo_color = Color(0.03, 0.032, 0.05)
	hair.roughness = 0.42
	hair.rim_enabled = true
	hair.rim = 0.35
	for mi: MeshInstance3D in who.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.name)
		if RHYS_HIDE.has(part) or RHYS_HIDE.has(String(mi.get_parent().name)):
			mi.visible = false
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			var kind := m.resource_name if m else ""
			if part.begins_with("hair_"):
				mi.set_surface_override_material(i, hair)
			elif part == "Eyes" and m is BaseMaterial3D:
				var eye := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				eye.albedo_color = Color(0.72, 0.52, 1.0)
				eye.emission_enabled = true
				eye.emission = VIOLET
				eye.emission_energy_multiplier = 0.6
				mi.set_surface_override_material(i, eye)
			elif mi.get_parent() != null and String(mi.get_parent().name).begins_with("tamlin_"):
				mi.set_surface_override_material(i, silver if kind in ["trim", "chain", "gem"] else black)


## Two violet eyes on the head bone, a little in front of the face.
func _eyes(who: Node3D) -> void:
	for s in who.find_children("*", "Skeleton3D", true, false):
		var sk := s as Skeleton3D
		var i := sk.find_bone("Head")
		if i < 0:
			i = sk.find_bone("head")
		if i < 0:
			continue
		var rest := sk.get_bone_global_rest(i)
		var top_skel := sk.to_local(Vector3(0.0, MuralStage._top_of(who), 0.0) + who.global_position * Vector3(1, 0, 1)).y
		# The cast rigs face +z in skeleton space; the people glTFs face -z.
		var fwd := 1.0 if ResourceLoader.exists(RHYS_MODEL) else -1.0
		var y := rest.origin.y + (top_skel - rest.origin.y) * 0.45
		var att := BoneAttachment3D.new()
		att.bone_name = sk.get_bone_name(i)
		sk.add_child(att)
		for sx in [-1.0, 1.0]:
			var eye := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.014
			sph.height = 0.02
			eye.mesh = sph
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.8, 0.65, 1.0)
			m.emission_enabled = true
			m.emission = VIOLET
			m.emission_energy_multiplier = 4.0
			eye.material_override = m
			att.add_child(eye)
			eye.transform = rest.affine_inverse() * Transform3D(Basis(), Vector3(0.034 * sx, y, 0.1 * fwd))
		return


## His dark around him; the room's light cools while he is in it.
func _darken(k: float, seconds: float) -> void:
	create_tween().tween_property(shadow, ^"light_energy", 1.4 * k, seconds)
	smoke.emitting = k > 0.0
	grade.to_param(&"cold", 0.65 * k, seconds)


# --- beats -----------------------------------------------------------------------

## #1 Lunch, warm noon light: the three of them at table.
func _b_lunch() -> void:
	player.veil_to(0.0, 1.4)
	shot(Vector3(13.4, 2.1, -33.2), Vector3(18.4, 0.9, -38.0), 40.0, 0.4, 3.5)


## Tamlin's chair flips back as he leaps up, snarling at the doors.
func _b_snarl() -> void:
	pose(tamlin, &"", 0.25)
	put(tamlin, TAMLIN_SEAT + Vector3(0.2, 0, 0), DOOR)
	if tamlin.has_method(&"set_claws"):
		tamlin.call(&"set_claws", 1.0)
	# The chair goes over backwards (its back is to the doors).
	var tw := create_tween()
	tw.tween_property(chair, ^"global_position", at(TAMLIN_SEAT + Vector3(-0.5, 0, 0)), 0.3)
	tw.parallel().tween_property(chair, ^"rotation:x", deg_to_rad(80.0), 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pose(lucien, &"", 0.4)
	put(lucien, LUCIEN_SEAT + Vector3(0, 0, 0.1), DOOR)
	close(tamlin, 1.6, 0.4, 36.0, 0.25, 2.0, -0.02)


## Close: Feyre's hand closes on the dinner knife by her plate.
func _b_knife() -> void:
	# From her right, low over the table: her hand and the knife.
	shot_world(at(Vector3(18.75, 1.4, -36.55)), _top(Vector3(17.95, 0, -37.55)), 34.0, 0.15, 2.0)
	pose(feyre_model(), &"reach", 0.5)
	after(0.9, func() -> void:
		if knife_on_table:
			knife_on_table.visible = false
		held_knife = hold(feyre_model(), KNIFE, "RightHand",
				Transform3D(Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)), Vector3(0.0, 0.08, 0.02))))


## #2 Lucien pushes her against the velvet drapes, his back to her.
func _b_curtain() -> void:
	pose(feyre_model(), &"", 0.0)
	put_feyre(DRAPE, ROOM)
	put(lucien, LUCIEN_GUARD, ROOM)
	_veil()
	shot(Vector3(17.4, 1.55, -31.4), Vector3(15.9, 1.35, -28.8), 36.0, 0.2, 3.0)


## A faint grey veil settles over her (his glamour); she fades into the curtain.
func _b_veil_on() -> void:
	create_tween().tween_method(func(v: float) -> void: veil_mat.set_shader_parameter(&"amount", v), 0.0, 0.88, 2.4)


func _veil() -> void:
	veil = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.36
	c.bottom_radius = 0.42
	c.height = 1.9
	c.cap_top = false
	c.cap_bottom = false
	veil.mesh = c
	veil_mat = ShaderMaterial.new()
	veil_mat.shader = VEIL
	veil_mat.set_shader_parameter(&"amount", 0.0)
	veil.material_override = veil_mat
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_prop(veil, ground(DRAPE, 0.95))
	veil.global_basis = Basis.looking_at(at(DRAPE) - at(ROOM), Vector3.UP)


## #3 Tamlin sheathes his claws, rights his chair and slouches into it.
## Footsteps stroll toward the doors (over Lucien's shoulder, from her).
func _b_slouch() -> void:
	if tamlin.has_method(&"set_claws"):
		tamlin.call(&"set_claws", 0.0)
	chair.rotation.x = 0.0
	chair.global_position = at(TAMLIN_SEAT)
	put(tamlin, TAMLIN_SEAT, TAMLIN_SEAT + Vector3(1.0, 0, 0))
	pose(tamlin, &"sit_slouch", 0.0)
	put(lucien, LUCIEN_GUARD, ROOM)
	# From the window corner past the drapes, out over the room to the doors.
	shot(Vector3(17.0, 1.6, -28.9), Vector3(12.0, 1.2, -37.5), 40.0, 0.25, 5.0)


## #4 He walks in. With every step the light cools and the shadows lean in.
func _b_enter() -> void:
	rhys.visible = true
	put(rhys, DOOR, RHYS_GREET)
	walk(rhys, RHYS_GREET, 3.6)
	_darken(1.0, 3.0)
	shot_on(at(Vector3(13.6, 0.55, -34.6)), rhys, 40.0, 0.3, 4.0, 0.0, -0.1)


## Feyre's eyes widen: the stranger from Fire Night.
func _b_eyes_widen() -> void:
	close(feyre, 0.95, 0.25, 30.0, 0.12, 2.2, -0.04)


func _b_greet() -> void:
	turn(rhys, TAMLIN_SEAT, 0.4)
	over(tamlin, rhys, 34.0, 0.4, 0.15, 3.0)
	after(3.0, func() -> void: over(rhys, tamlin, 34.0, -0.42, 0.12, 2.0))
	after(5.2, func() -> void: close(rhys, 1.3, -0.3, 32.0, 0.15, 4.5, -0.04))


## #5 He turns to Lucien: "A fox mask. Appropriate for you, Lucien."
func _b_fox() -> void:
	turn(rhys, LUCIEN_GUARD, 0.7)
	after(0.7, func() -> void: close(rhys, 1.6, 0.65, 34.0, 0.15, 3.5, -0.06))


## #6 He lifts Feyre's goblet from the table and sniffs it.
func _b_goblet() -> void:
	walk(rhys, RHYS_GOBLET, 1.6)
	after(1.7, func() -> void:
		turn(rhys, Vector3(17.95, 0, -37.35), 0.3)
		pose(rhys, &"reach", 0.5)
		if goblet_on_table:
			goblet_on_table.visible = false
		hold(rhys, GOBLET, _hand(rhys), Transform3D(Basis(), Vector3(0.0, 0.07, 0.03)))
		close(rhys, 1.2, 0.35, 30.0, 0.12, 2.6, -0.06))
	shot(Vector3(19.4, 1.5, -34.4), Vector3(17.4, 1.2, -36.6), 36.0, 0.2, 1.6)


func _hand(who: Node3D) -> String:
	for s in who.find_children("*", "Skeleton3D", true, false):
		for b in ["RightHand", "hand.R", "hand_r", "Hand.R", "right_hand"]:
			if (s as Skeleton3D).find_bone(b) >= 0:
				return b
	return "RightHand"


## #7 He turns his head slowly and looks straight at the curtains. Push in on
## his violet eyes.
func _b_look() -> void:
	pose(rhys, &"", 0.6)
	turn(rhys, DRAPE, 1.6)
	after(1.5, func() -> void: close(rhys, 0.75, 0.0, 26.0, 0.3, 4.0, -0.02))


## #8 He brushes Lucien aside; the veil tears like wet paper; he pries the
## knife out of her fist.
func _b_tear() -> void:
	_darken(1.4, 1.0)
	walk(rhys, RHYS_FEYRE, 1.4)
	# Along the window wall: the veil on her, him coming in from the right.
	shot(Vector3(13.4, 1.5, -28.95), Vector3(15.75, 1.25, -28.7), 36.0, 0.15, 3.4)
	after(1.0, func() -> void:
		walk(lucien, LUCIEN_ASIDE, 0.35)
		create_tween().tween_method(func(v: float) -> void: veil_mat.set_shader_parameter(&"tear", v), 0.0, 1.0, 1.2) \
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD))
	after(2.2, func() -> void:
		turn(rhys, DRAPE, 0.2)
		pose(rhys, &"reach", 0.4))
	after(3.0, func() -> void:
		if held_knife and is_instance_valid(held_knife):
			held_knife.visible = false
		hold(rhys, KNIFE, _hand(rhys), Transform3D(Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, 0.0)), Vector3(0.0, 0.08, 0.02)))
		pose(rhys, &"", 0.5))


## #9 Horror. Close on Feyre: the frame cracks into violet static, whispers
## circle in her head, her knees give and she sinks to the floor.
func _b_mind() -> void:
	close(feyre, 0.9, -0.2, 30.0, 0.2, 5.0, -0.04)
	grade.to_param(&"crack", 1.0, 2.5)
	after(1.8, func() -> void: pose(feyre_model(), &"kneel_slump", 2.6))


## #10 Tamlin on his feet, his voice breaking.
func _b_beg() -> void:
	grade.to_param(&"crack", 0.35, 1.5)
	pose(tamlin, &"", 0.4)
	put(tamlin, TAMLIN_BEG + Vector3(0.0, 0.0, -1.6), RHYS_FEYRE)
	walk(tamlin, TAMLIN_BEG, 1.5)
	after(1.0, func() -> void: close(tamlin, 1.4, 0.3, 32.0, 0.12, 3.5, -0.04))


## #11 Low angle: Tamlin kneels and puts his forehead to the marble.
func _b_kneel() -> void:
	grade.to_param(&"crack", 0.0, 2.0)
	turn(rhys, TAMLIN_BEG, 0.6)
	pose(tamlin, &"kneel", 1.0)
	shot(Vector3(15.3, 0.35, -30.9), Vector3(16.1, 0.75, -32.6), 40.0, 0.15, 4.0)
	after(3.4, func() -> void:
		pose(tamlin, &"kneel_bow", 1.2)
		shot_on(at(Vector3(17.2, 0.45, -30.6)), rhys, 34.0, 0.15, 3.0, 0.0, -0.05))


## "You too, fox-boy." Lucien kneels.
func _b_fox_boy() -> void:
	turn(rhys, LUCIEN_ASIDE, 0.5)
	pose(lucien, &"kneel", 1.0)
	# Once he is down (the shot finds him where he kneels, not where he stood).
	after(0.9, func() -> void: over(rhys, lucien, 36.0, 0.75, 0.1, 2.5, 2.2))


## #12 Rhysand crouches by her on the floor: "What's your name, love?"
func _b_crouch() -> void:
	turn(rhys, DRAPE, 0.4)
	pose(rhys, &"crouch", 0.9)
	var mid := (at(DRAPE) + at(RHYS_FEYRE)) * 0.5
	var across := (at(DRAPE) - at(RHYS_FEYRE)).normalized().cross(Vector3.UP)
	shot_world(mid + across * 1.5 + Vector3.UP * 0.75, mid + Vector3.UP * 0.7, 32.0, 0.15, 3.5)
	after(3.6, func() -> void: close(feyre, 0.85, 0.25, 30.0, 0.08, 2.4, -0.06))


## #13 A one-second gold flash: a girl's face at the village well, back home.
## Then Rhysand smiles slowly: he knows whose name that is.
func _b_flash() -> void:
	mural.play(&"well", 1.2, 0.0)
	insert.set_param(&"paint", 1.0)
	insert.cover_to(1.0, 0.08)
	after(1.0, func() -> void:
		insert.cover_to(0.0, 0.15)
		close(rhys, 0.95, -0.25, 28.0, 0.12, 3.5, -0.06))


## #14 He stands and looks at all three of them.
func _b_stand() -> void:
	pose(rhys, &"", 0.9)
	turn(rhys, ROOM, 1.2)
	shot_on(at(Vector3(17.0, 0.3, -32.4)), rhys, 42.0, 0.2, 6.0, 0.0, -0.2)


## #15 He vanishes into nothing, as if he stepped through a rip in the world.
func _b_vanish() -> void:
	var burst := smoke.duplicate() as GPUParticles3D
	add_prop(burst, rhys.global_position + Vector3.UP * 0.9)
	burst.amount = 140
	burst.one_shot = true
	burst.explosiveness = 0.9
	(burst.process_material as ParticleProcessMaterial).initial_velocity_max = 1.6
	burst.emitting = true
	rhys.visible = false
	smoke.emitting = false
	shadow.light_energy = 0.0
	grade.to_param(&"cold", 0.25, 0.3)


## #16 The light warms slowly. Tamlin is still on his knees, his hands
## shaking; Feyre on the floor looks from him to Lucien.
func _b_after() -> void:
	grade.to_param(&"cold", 0.0, 8.0)
	pose(tamlin, &"kneel", 2.0)
	shot(Vector3(19.4, 1.25, -31.0), Vector3(15.4, 0.75, -30.6), 40.0, 0.25, 9.0)
	after(4.0, func() -> void: close(lucien, 1.4, 0.3, 32.0, 0.1, 3.0, -0.04))
	after(7.6, func() -> void: close(feyre, 1.0, -0.25, 30.0, 0.1, 3.0, -0.05))


## Hold on the silence; they cannot look at her.
func _b_silence() -> void:
	shot(Vector3(13.6, 1.1, -29.0), Vector3(15.9, 0.75, -28.8), 34.0, 0.12, 3.0)


## Ease into her camera: she gets up.
func _b_handover() -> void:
	pose(feyre_model(), &"", 1.4)
	pose(lucien, &"", 1.6)

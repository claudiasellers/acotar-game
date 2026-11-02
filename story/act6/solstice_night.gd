## Ch25 [C] (Keeper): the Solstice on a plateau in the fields. Crowds of fae,
## unglamoured, that she sees for the first time; faerie wine (Lucien warns
## her; she drinks and gets giddy; he stays close); Tamlin plays the fiddle in
## the band. Then he takes her to the edge of a vast meadow where will-o'-the-
## wisps, "spirits of air and light", dance round them, and they dance until
## "It's almost dawn", and watch the sun rise.
## Play: she has the run of the party (the wine is optional and makes the
## world swim and sparkle for a minute); going to Tamlin at the musicians'
## bower ends the music; she follows him to the wisp hollow; the dance is
## keeping close to him as he turns her round (20 s together). Hangs on
## solstice_dance_floor. Fact: fact.solstice_sunrise_watched.
class_name SolsticeNight
extends Act6Space

const FIDDLE := "res://art/p6/fiddle.glb"
## Seconds of the party before Tamlin will leave the band.
const PARTY := 45.0
const DANCE := 20.0
const DANCE_R := 1.3
const KEEP_CLOSE := 2.4
const LATE := 22.5 / 24.0
## Grades (L18's presets): the meadow at golden hour, then the twilight of the
## wisps. A story hold, released at the end.
const PARTY_GRADE := &"grade_solstice"
const NIGHT_GRADE := &"grade_solstice_twilight"
## Lantern strings between the tables and the ring, in the dance floor's frame.
const LANTERNS: Array[Vector3] = [Vector3(70.0, 0.0, 12.0), Vector3(50.0, 0.0, 4.0), Vector3(28.0, 0.0, -6.0),
	Vector3(36.0, 0.0, -50.0), Vector3(14.0, 0.0, -30.0)]
## The sun clears the meadow's rim at about 5.8 h (GradeDirector.sun_rotation).
const SUNRISE := 6.3 / 24.0
## The crowd: true forms (the glamour is gone), round the dance ring.
const CROWD := [&"reveler_1", &"reveler_2", &"reveler_3", &"fae_nymph", &"fae_rose", &"fae_pixie",
		&"fae_dryad", &"fae_moth", &"fae_fox", &"fae_birch", &"fae_satyr", &"fae_stag", &"fae_owl",
		&"fae_longlimb", &"fae_hedgehog", &"reveler_1", &"reveler_2", &"fae_nymph"]

var drank: bool = false
var danced: float = 0.0
var crowd: Array[Node3D] = []
var dressing: Array[Node3D] = []
var wisps: GPUParticles3D
var _party := 0.0
var _angle := 0.0


func _init() -> void:
	space_id = &"solstice_night"
	require_flags = PackedStringArray(["fact.solstice_dressed"])
	done_flags = PackedStringArray(["fact.solstice_sunrise_watched"])
	arrive_radius = 60.0


func _build_beats() -> Array:
	return [
		Beats.run(_open_party, "the party"),
		say(&"crowds_thought"),
		say(&"lucien_wine_warning"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.release()
			aside(&"wine_prompt"), "the run of the party"),
		PartyBeat.new(self),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(actor(&"tamlin")), "the music ends"),
		say(&"tamlin_come_away"),
	] + fade_time(LATE, _night_falls, "later") + [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.release()
			aside(&"follow_thought"), "she follows him"),
		lead_over_ground(&"tamlin", [&"hollow_path", &"hollow_edge", &"hollow"], 6.0, 2.0),
		Beats.run(_open_wisps, "the wisps"),
		say(&"wisps_thought"),
		DanceBeat.new(self),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(actor(&"tamlin"))
			EventBus.face_requested.emit(&"tamlin", &"tender", 0.8, 4.0)
			delight(&"unlock", &"", actor(&"tamlin")), "the kiss"),
		say(&"kiss_thought"),
		say(&"tamlin_almost_dawn"),
	] + fade_time(SUNRISE, _sunrise, "until dawn") + [
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(_sun_target())
			EventBus.celebration_requested.emit(&"dance", player().global_position if player() else global_position)
			stamp("fact.solstice_sunrise_watched"), "sunrise"),
		say(&"sunrise_thought"),
		Beats.run(func(_s: SceneSpace) -> void:
			_close()
			StoryControl.release(), "morning"),
	]


func _open_party(_s: SceneSpace) -> void:
	_party = 0.0
	drank = false
	danced = 0.0
	var t := cast(&"tamlin", &"bower", &"ring")
	t.global_position = ground_mark(&"bower")
	if t.has_method(&"hold"):
		t.call(&"hold", FIDDLE, "LeftHand", Transform3D(Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(80.0))), Vector3(0.0, 0.08, 0.05)))
	EventBus.face_requested.emit(&"tamlin", &"happy", 0.7, 30.0)
	var l := cast(&"lucien", &"lucien_near", &"ring")
	l.global_position = ground_mark(&"lucien_near")
	_spawn_crowd()
	_dress_party()
	EventBus.grade_swap_requested.emit(PARTY_GRADE, 2.0)
	SoundDirector.cue(&"music_spring_estate")
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	StoryControl.set_focus(t)


## The faerie wine on its own table by the long tables, and lantern strings
## that glow once the sun is down.
func _dress_party() -> void:
	if not dressing.is_empty():
		return
	var wt := ground_mark(&"wine_table") + Vector3(0.0, 0.0, 3.5)
	var table := prop(&"wine_table_solstice", wt, 0.4)
	if table:
		dressing.append(table)
	var a := get_parent() as Node3D
	for i in LANTERNS.size():
		var at := snap(a.global_transform * LANTERNS[i] if a else LANTERNS[i])
		var string := prop(&"solstice_lantern_string", at + Vector3.UP * 2.6, 0.5 + i * 0.9)
		if string == null:
			continue
		dressing.append(string)
		var lamp := OmniLight3D.new()
		lamp.light_color = [Color(1.0, 0.78, 0.86), Color(0.8, 0.86, 1.0), Color(1.0, 0.92, 0.7)][i % 3]
		lamp.light_energy = 1.4
		lamp.omni_range = 9.0
		lamp.position = Vector3(0.0, -0.4, 0.0)
		string.add_child(lamp)


func _spawn_crowd() -> void:
	if not crowd.is_empty():
		return
	var ring := ground_mark(&"ring")
	for i in CROWD.size():
		var path := "res://creatures/people/scenes/%s.tscn" % CROWD[i]
		if not ResourceLoader.exists(path):
			continue
		var npc := (load(path) as PackedScene).instantiate() as Node3D
		npc.name = "Reveler%d" % i
		var a := TAU * float(i) / float(CROWD.size()) + 0.17 * float(i % 3)
		var r := 7.5 + 4.0 * float(i % 3)
		if &"wander_radius" in npc:
			npc.set(&"wander_radius", 2.5)
		add_child(npc)
		npc.global_position = snap(ring + Vector3(cos(a) * r, 0.0, sin(a) * r))
		npc.look_at(Vector3(ring.x, npc.global_position.y, ring.z), Vector3.UP)
		crowd.append(npc)


## E at the long tables: faerie wine. The world swims, sparkles and giggles
## for a minute (the dreamy grade at a third), and Lucien sighs.
func drink() -> void:
	if drank:
		return
	drank = true
	note_mood()
	EventBus.mood_requested.emit(&"enchanted_sleep", 0.32, 2.0, 0.0)
	EventBus.story_item_granted.emit(&"ing_faerie_wine", 0)
	Juice.burst(player(), &"craft")
	aside(&"wine_thought")
	get_tree().create_timer(50.0).timeout.connect(func() -> void:
		if is_inside_tree():
			EventBus.mood_requested.emit(&"calm", 0.0, 6.0, 0.0))
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_inside_tree() and running:
			aside(&"lucien_nursemaid"))


func _night_falls() -> void:
	SoundDirector.stop_cue(&"music_spring_estate", 3.0)
	var t := actor(&"tamlin")
	if t:
		for c in t.find_children("Hold_fiddle", "", true, false):
			c.queue_free()
		t.global_position = ground_mark(&"tamlin_leave")
	place_feyre(ground_mark(&"tamlin_leave") + Vector3(1.2, 0.0, 1.0))
	dismiss(&"lucien")
	EventBus.grade_swap_requested.emit(NIGHT_GRADE, 3.0)


func _open_wisps(_s: SceneSpace) -> void:
	_angle = 0.0
	wisps = GPUParticles3D.new()
	wisps.name = "Wisps"
	wisps.amount = 90
	wisps.lifetime = 7.0
	wisps.preprocess = 4.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 9.0
	pm.gravity = Vector3(0.0, 0.05, 0.0)
	pm.orbit_velocity_min = 0.04
	pm.orbit_velocity_max = 0.1
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.82, 0.93, 0.0), Color(0.86, 0.9, 1.0, 1.0), Color(0.85, 1.0, 0.92, 1.0), Color(1.0, 0.95, 0.75, 0.0)])
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	wisps.process_material = pm
	var orb := SphereMesh.new()
	orb.radius = 0.07
	orb.height = 0.14
	orb.radial_segments = 8
	orb.rings = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color(0.9, 0.92, 1.0)
	m.emission_energy_multiplier = 4.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb.material = m
	wisps.draw_pass_1 = orb
	add_child(wisps)
	wisps.global_position = ground_mark(&"hollow") + Vector3.UP * 1.6
	var glow := OmniLight3D.new()
	glow.name = "WispGlow"
	glow.light_color = Color(0.82, 0.86, 1.0)
	glow.light_energy = 1.6
	glow.omni_range = 11.0
	wisps.add_child(glow)
	# Spirits of air and light: the hollow is lit by them alone (and a high,
	# cool wash for the moon), each light drifting on its own slow loop.
	var hollow := ground_mark(&"hollow")
	var moon := OmniLight3D.new()
	moon.name = "MoonWash"
	moon.light_color = Color(0.7, 0.76, 1.0)
	moon.light_energy = 0.9
	moon.omni_range = 70.0
	moon.omni_attenuation = 0.6
	wisps.add_child(moon)
	moon.global_position = hollow + Vector3(-10.0, 30.0, 6.0)
	for i in 6:
		var w := OmniLight3D.new()
		w.light_color = [Color(1.0, 0.8, 0.92), Color(0.78, 0.88, 1.0), Color(0.82, 1.0, 0.9)][i % 3]
		w.light_energy = 1.5
		w.omni_range = 7.0
		wisps.add_child(w)
		var ang := TAU * i / 6.0
		var home := hollow + Vector3(cos(ang) * 4.5, 1.4 + 0.3 * (i % 2), sin(ang) * 4.5)
		w.global_position = home
		var tw := w.create_tween().set_loops()
		tw.tween_property(w, "global_position", home + Vector3(sin(ang) * 1.4, 0.7, -cos(ang) * 1.4), 3.0 + i * 0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(w, "global_position", home, 3.0 + i * 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Juice.burst(null, &"unlock", wisps.global_position)


func _sunrise() -> void:
	if wisps:
		wisps.emitting = false
	var p := player()
	var t := actor(&"tamlin")
	if p and t:
		t.global_position = p.global_position + Vector3(0.9, 0.0, 0.3)
		var sun := _sun_target().global_position
		t.look_at(Vector3(sun.x, t.global_position.y, sun.z), Vector3.UP)


## East, low: where the sun comes up over the meadow.
func _sun_target() -> Node3D:
	var n := get_node_or_null(^"Sunrise") as Node3D
	if n == null:
		n = Node3D.new()
		n.name = "Sunrise"
		add_child(n)
	var p := player()
	n.global_position = (p.global_position if p else global_position) + Vector3(60.0, 6.0, 0.0)
	return n


func _close() -> void:
	for n in dressing:
		if is_instance_valid(n):
			n.queue_free()
	dressing.clear()
	GradeDirector.release_story_holds(get_tree())
	for n in crowd:
		if is_instance_valid(n):
			n.queue_free()
	crowd.clear()
	dismiss(&"tamlin")
	if wisps:
		wisps.queue_free()
		wisps = null


## Free run of the party; E at the long tables drinks the wine. Ends when she
## goes to Tamlin at the bower after PARTY seconds (or after the wine).
class PartyBeat:
	extends SceneBeat
	var s: SolsticeNight
	var _pressed := 0

	func consumes_time() -> bool:
		return true

	func _init(space: SolsticeNight) -> void:
		s = space
		label = "the party"

	func enter(_space: SceneSpace) -> void:
		_pressed = s.presses()

	func tick(_space: SceneSpace, delta: float) -> bool:
		s._party += delta
		if s.presses() > _pressed:
			_pressed = s.presses()
			if s.player_within(3.2, s.ground_mark(&"wine_table")):
				s.drink()
		var may_go := s._party >= SolsticeNight.PARTY or (s.drank and s._party >= 15.0)
		return may_go and s.player_within(6.0, s.ground_mark(&"bower"))


## He turns her round in the wisps: Tamlin walks a slow circle; time counts
## while she keeps within KEEP_CLOSE of him. A sparkle every 5 s together.
class DanceBeat:
	extends SceneBeat
	var s: SolsticeNight
	var _next := 5.0

	func consumes_time() -> bool:
		return true

	func _init(space: SolsticeNight) -> void:
		s = space
		label = "the dance"

	func enter(_space: SceneSpace) -> void:
		_next = 5.0

	func tick(_space: SceneSpace, delta: float) -> bool:
		var t := s.actor(&"tamlin")
		if t == null:
			return true
		var c := s.ground_mark(&"hollow")
		var close := s.player_within(SolsticeNight.KEEP_CLOSE, t.global_position)
		s._angle += delta * (0.55 if close else 0.2)
		var p := c + Vector3(cos(s._angle), 0.0, sin(s._angle)) * SolsticeNight.DANCE_R
		t.global_position = Vector3(p.x, WorldHeight.height_at(p.x, p.z), p.z)
		var pl := s.player()
		if pl:
			t.look_at(Vector3(pl.global_position.x, t.global_position.y, pl.global_position.z), Vector3.UP)
		if close:
			s.danced += delta
			if s.danced >= _next:
				_next += 5.0
				Juice.burst(t, &"pickup", Vector3.ZERO, 1.0 + s.danced * 0.02)
		return s.danced >= SolsticeNight.DANCE

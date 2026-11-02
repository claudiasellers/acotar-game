## Contract (lane L36-3, docs/contracts/faces.md): every creature face with a
## profile carries the keys its presets use; what the creature is doing drives
## its threat display (the naga strikes with jaw dropped, Andras is silent on
## the stalk and gapes in the rush, slack in death); story cues and
## Faces.express reach it over EventBus; the snarl bones move the right way.
extends GutTest

const GREAT_WOLF := preload("res://creatures/wolves/great_wolf.tscn")
const WOLF := preload("res://creatures/wolves/wolf.tscn")
const NAGA := preload("res://creatures/fae/naga.tscn")
const SURIEL := preload("res://creatures/fae/suriel.tscn")
const ATTOR := preload("res://creatures/fae/attor.tscn")
const CREATURES: Array[StringName] = [&"great_wolf", &"wolf", &"suriel", &"naga", &"attor"]


func before_each() -> void:
	WorldState.clear()


func _face(n: Node) -> CreatureFace:
	var f := n.get(&"face") as CreatureFace
	assert_not_null(f, "%s has a CreatureFace" % n.name)
	if f:
		f.set_process(false)
	return f


func _run(f: CreatureFace, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		f.tick(1.0 / 60.0)
		t += 1.0 / 60.0


func test_creature_profiles_cover_every_emotion_and_state() -> void:
	for id in CREATURES:
		var p := FaceProfile.for_character(id)
		assert_not_null(p, "profile for %s" % id)
		assert_true(p.creature, "%s is a creature face" % id)
		for e in FaceProfile.EMOTIONS:
			assert_true(p.presets.has(String(p.aliases.get(String(e), ""))), "%s resolves %s" % [id, e])
		for s: String in p.states:
			assert_true(p.presets.has(String(p.states[s])), "%s state %s" % [id, s])


func test_fae_models_carry_their_threat_keys() -> void:
	for scene: PackedScene in [NAGA, SURIEL, ATTOR]:
		var n := scene.instantiate() as Node3D
		add_child_autofree(n)
		var f := _face(n)
		assert_gt(f.meshes.size(), 0, "%s has a keyed mesh" % n.name)
		for mix: Dictionary in f.profile.presets.values():
			for k: String in mix:
				var found := false
				for mi in f.meshes:
					found = found or mi.find_blend_shape_by_name(k) >= 0
				assert_true(found, "%s carries %s" % [n.name, k])


func test_naga_strikes_jaw_dropped_and_tastes_the_air_at_rest() -> void:
	var n := NAGA.instantiate() as Naga
	add_child_autofree(n)
	var f := _face(n)
	n.state = Naga.State.STRIKE
	_run(f, 0.5)
	assert_eq(f.state_name, &"strike")
	assert_gt(f.weight_of("threat"), 0.95, "the jaw drops off the teeth")
	assert_gt(f.weight_of("eyes_wide"), 0.95)
	n.state = Naga.State.LURK
	var tongue := 0.0
	var t := 0.0
	while t < 8.0:
		f.tick(1.0 / 60.0)
		tongue = maxf(tongue, f.weight_of("tongue"))
		t += 1.0 / 60.0
	assert_gt(tongue, 0.9, "the tongue flicks while it lurks")
	assert_lt(f.weight_of("threat"), 0.05, "and the jaw is shut again")


func test_suriel_shrieks_on_cue_and_smiles_while_it_answers() -> void:
	var s := SURIEL.instantiate() as Suriel
	add_child_autofree(s)
	var f := _face(s)
	EventBus.story_actor_cue.emit(&"suriel", &"caught")
	_run(f, 0.5)
	assert_almost_eq(f.weight_of("threat"), 0.55, 0.05, "caught, it smiles that lipless smile")
	EventBus.story_actor_cue.emit(&"suriel", &"naga_are_coming")
	_run(f, 0.4)
	assert_eq(f.current_expression(), &"shriek")
	assert_gt(f.weight_of("eyes_wide"), 0.9)
	_run(f, 3.0)
	assert_eq(f.current_expression(), &"", "the shriek passes")
	Faces.speak(&"suriel", "Ask your questions.", &"", 1.0)
	_run(f, 0.3)
	assert_eq(f.current_expression(), &"speak")


func test_attor_takes_faces_express_like_the_cast() -> void:
	var a := ATTOR.instantiate() as Attor
	add_child_autofree(a)
	var f := _face(a)
	Faces.express(&"attor", &"fury")
	_run(f, 0.5)
	assert_eq(f.current_expression(), &"roar")
	assert_gt(f.weight_of("threat"), 0.95)
	EventBus.story_actor_cue.emit(&"attor", &"speaks_of_her")
	_run(f, 0.5)
	assert_eq(f.current_expression(), &"hiss")


func test_snarl_bones_move_the_right_way() -> void:
	var w := GREAT_WOLF.instantiate() as GreatWolf
	add_child_autofree(w)
	var f := _face(w)
	assert_not_null(f.snarl, "the wolf rig gets a snarl")
	var sk := f.snarl.get_skeleton()
	for spec: Array in [[&"jaw", &"jaw_open", Vector3.DOWN], [&"ear_l", &"ears_back", Vector3.BACK],
			[&"ear_r", &"ears_back", Vector3.BACK], [&"head", &"head_low", Vector3.DOWN]]:
		var bone := sk.find_bone(spec[0] as StringName)
		var b := sk.get_bone_global_rest(bone).basis
		var tip0 := b * Vector3.UP
		var tip1 := (b * Basis(Vector3.RIGHT, f.snarl.angle_of(spec[1] as StringName, bone))) * Vector3.UP
		assert_gt((tip1 - tip0).dot(spec[2] as Vector3), 0.05, "%s %s" % spec.slice(0, 2))


func test_andras_is_silent_on_the_stalk_gapes_in_the_rush_and_goes_slack() -> void:
	var w := GREAT_WOLF.instantiate() as GreatWolf
	add_child_autofree(w)
	var f := _face(w)
	w.state = GreatWolf.State.STALK
	_run(f, 0.5)
	assert_eq(f.weight_of("jaw_open"), 0.0, "no bared jaws on the stalk")
	assert_gt(f.weight_of("ears_up"), 0.7)
	w.state = GreatWolf.State.RUSH
	_run(f, 0.5)
	assert_gt(f.weight_of("jaw_open"), 0.9)
	assert_gt(f.weight_of("ears_back"), 0.85)
	assert_almost_eq(float(f.snarl.weights.get("jaw_open", 0.0)), f.weight_of("jaw_open"), 0.001,
		"the bones get what the face composes")
	w.state = GreatWolf.State.STARE
	_run(f, 0.5)
	assert_lt(f.weight_of("jaw_open"), 0.05, "the too-aware look is jaw shut, ears up")
	w.alive = false
	_run(f, 0.5)
	assert_eq(f.state_name, &"dead")
	assert_gt(f.weight_of("jaw_open"), 0.35, "slack in death")


func test_pack_wolves_snarl_while_they_circle_and_gape_on_the_feint() -> void:
	var pack := WolfPack.new()
	add_child_autofree(pack)
	var w := WOLF.instantiate() as Wolf
	pack.add_child(w)
	var f := _face(w)
	pack.phase = WolfPack.Phase.CIRCLE
	_run(f, 0.5)
	assert_eq(f.state_name, &"circle")
	assert_gt(f.weight_of("ears_back"), 0.85)
	assert_gt(f.weight_of("head_low"), 0.6)
	w.lunge(Vector3(0, 0, -5))
	_run(f, 0.4)
	assert_gt(f.weight_of("jaw_open"), 0.95)

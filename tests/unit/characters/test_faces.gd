## Contract (lane L36, docs/contracts/faces.md): every cast face with a profile
## carries the expression shapes its presets use; every shared emotion resolves to
## one of the character's own canon looks; a story cue or a spoken line changes
## the face over EventBus, a timed look returns to rest, the face blinks, and
## talking moves the visemes.
extends GutTest

const CAST: Array[StringName] = [&"tamlin", &"lucien", &"alis", &"father", &"nesta", &"elain"]
const EXPRESSION_KEYS: Array[String] = ["smile_L", "smile_R", "frown_L", "frown_R", "sneer_L", "sneer_R",
	"lip_press", "jaw_clench", "mouth_stretch", "eyes_wide_L", "eyes_wide_R", "squint_L", "squint_R",
	"brow_down_L", "brow_down_R", "brow_up_L", "brow_up_R", "brow_inner_up", "cheek_raise", "mouth_side_L",
	"mouth_side_R", "chin_raise", "lips_part"]


func _model(id: StringName) -> Node3D:
	var scene := load("res://characters/%s/%s_model.tscn" % [id, id]) as PackedScene
	var m := scene.instantiate() as Node3D
	add_child_autofree(m)
	return m


func _driver(m: Node3D) -> FaceDriver:
	var d := m.get(&"face") as FaceDriver
	assert_not_null(d, "cast model has a FaceDriver")
	d.set_process(false)
	return d


func _run(d: FaceDriver, seconds: float, step: float = 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds:
		d.tick(step)
		t += step


func test_profiles_cover_every_emotion() -> void:
	for id in CAST:
		var p := FaceProfile.for_character(id)
		assert_not_null(p, "profile for %s" % id)
		assert_true(p.presets.has(String(p.rest)), "%s rest preset exists" % id)
		for e in FaceProfile.EMOTIONS:
			assert_true(p.presets.has(String(p.aliases.get(String(e), ""))), "%s resolves %s" % [id, e])


func test_models_carry_every_shape_their_presets_use() -> void:
	for id in CAST:
		var m := _model(id)
		var body := m.find_child("Body", true, false) as MeshInstance3D
		assert_not_null(body, "%s body" % id)
		for k in EXPRESSION_KEYS:
			assert_gt(body.find_blend_shape_by_name(k), -1, "%s has %s" % [id, k])
		var p := FaceProfile.for_character(id)
		for mix: Dictionary in p.presets.values():
			for k: String in mix:
				assert_gt(body.find_blend_shape_by_name(k), -1, "%s preset key %s" % [id, k])


func test_every_cast_mouth_opens_onto_teeth() -> void:
	for id in CAST:
		var m := _model(id)
		var mouth := m.find_child("Mouth", true, false) as MeshInstance3D
		assert_not_null(mouth, "%s has a mouth (bag, teeth, tongue)" % id)
		assert_gt(mouth.find_blend_shape_by_name("jaw_open"), -1, "%s lower teeth follow the jaw" % id)
		var d := _driver(m)
		assert_true(mouth in d.meshes, "%s mouth is driven with the face" % id)


func test_masked_faces_never_move_skin_under_the_mask() -> void:
	var d := _driver(_model(&"tamlin"))
	assert_true(d.profile.masked)
	d.profile.presets["_probe"] = {"brow_down_L": 1.0, "brow_inner_up": 1.0, "cheek_raise": 1.0, "squint_L": 1.0}
	d.express(&"_probe")
	_run(d, 0.5)
	assert_eq(d.weight_of("brow_down_L"), 0.0)
	assert_eq(d.weight_of("brow_inner_up"), 0.0)
	assert_eq(d.weight_of("cheek_raise"), 0.0)
	assert_lte(d.weight_of("squint_L"), FaceDriver.MASKED_SQUINT)
	d.profile.presets.erase("_probe")


func test_tamlin_angry_is_jaw_tight_restraint_and_fury_comes_by_cue() -> void:
	var d := _driver(_model(&"tamlin"))
	Faces.express(&"tamlin", &"angry")
	_run(d, 0.5)
	assert_eq(d.current_expression(), &"restraint")
	assert_gt(d.weight_of("jaw_clench"), 0.85)
	EventBus.story_actor_cue.emit(&"tamlin", &"face_fury")
	_run(d, 0.5)
	assert_eq(d.current_expression(), &"fury")
	assert_gt(d.weight_of("sneer_R"), 0.9)
	Faces.clear(&"tamlin")
	_run(d, 1.0)
	assert_eq(d.current_expression(), &"")


func test_lucien_smirks_on_the_scarred_side() -> void:
	var m := _model(&"lucien")
	var d := _driver(m)
	assert_gte(d.meshes.size(), 2, "body and scar both move")
	d.express(&"smirk", 1.0, 0.4)
	_run(d, 0.3)
	assert_gt(d.weight_of("smile_L"), d.weight_of("smile_R") + 0.5)
	_run(d, 1.0)
	assert_eq(d.current_expression(), &"", "a timed look returns to rest")


func test_father_beard_moves_with_his_mouth() -> void:
	var d := _driver(_model(&"father"))
	assert_gte(d.meshes.size(), 2, "body and beard")


func test_faces_blink_and_talk() -> void:
	var d := _driver(_model(&"alis"))
	var shut := 0.0
	var t := 0.0
	while t < d.profile.blink_max + 0.8:
		d.tick(1.0 / 60.0)
		shut = maxf(shut, d.weight_of("blink_L"))
		t += 1.0 / 60.0
	assert_gt(shut, 0.9, "she blinked")
	Faces.speak(&"alis", "Mind the pot, girl.", &"contempt", 1.2)
	var mouth := 0.0
	for i in 60:
		d.tick(1.0 / 60.0)
		for v in FaceDriver.VISEMES:
			mouth = maxf(mouth, d.weight_of(v))
	assert_gt(mouth, 0.4, "visemes move while she talks")
	assert_eq(d.current_expression(), &"sneer", "contempt is Alis's sneer")
	_run(d, 1.0)
	assert_false(d.is_talking())


func test_sisters_lashes_ride_the_lids_and_elain_never_sneers() -> void:
	for id: StringName in [&"nesta", &"elain"]:
		var m := _model(id)
		var lashes := m.find_child("Lashes", true, false) as MeshInstance3D
		assert_not_null(lashes, "%s has strand lashes" % id)
		assert_gt(lashes.find_blend_shape_by_name("blink_L"), -1, "%s lashes close with the lid" % id)
		assert_true(lashes in _driver(m).meshes, "%s lashes are driven" % id)
	var p := FaceProfile.for_character(&"elain")
	for mix: Dictionary in p.presets.values():
		for k: String in mix:
			assert_false(k.begins_with("sneer"), "Elain never sneers [C]")
	var d := _driver(_model(&"nesta"))
	Faces.express(&"nesta", &"contempt")
	_run(d, 0.5)
	assert_eq(d.current_expression(), &"sneer")
	assert_gt(d.weight_of("sneer_R"), 0.7)


func test_feyre_has_her_face_too() -> void:
	var m := (load("res://characters/feyre/model/feyre_model.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	var d := _driver(m)
	assert_eq(d.character_id, &"feyre")
	var body := m.find_child("Body", true, false) as MeshInstance3D
	for k in EXPRESSION_KEYS:
		assert_gt(body.find_blend_shape_by_name(k), -1, "feyre has %s" % k)
	assert_not_null(m.find_child("Mouth", true, false), "her mouth opens onto teeth")
	for e in FaceProfile.EMOTIONS:
		assert_true(d.profile.presets.has(String(d.profile.aliases.get(String(e), ""))), "feyre resolves %s" % e)
	Faces.express(&"feyre", &"angry")
	_run(d, 0.5)
	assert_eq(d.current_expression(), &"glare", "her anger is the glare and the clamped jaw")
	assert_gt(d.weight_of("jaw_clench"), 0.6)


func test_feyre_mouth_opening_stays_inside_her_lips() -> void:
	# F35: wide painted lips must not carry the slit, the bag and the teeth out into the cheek
	# (mouth.SEAM_HALF_MAX 0.0105 m x her horizontal scale ~1.05, / 0.86 for the bag: < 0.013 a side)
	var m := (load("res://characters/feyre/model/feyre_model.tscn") as PackedScene).instantiate() as Node3D
	add_child_autofree(m)
	var mouth := m.find_child("Mouth", true, false) as MeshInstance3D
	assert_lt(mouth.mesh.get_aabb().size.x, 0.028, "the inside of her mouth is no wider than her lips")
	assert_gt(mouth.mesh.get_aabb().size.x, 0.018, "but still spans her mouth")

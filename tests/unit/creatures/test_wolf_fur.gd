## Contract for lane L43 (quality audit B7): the great wolf and the doe wear the
## fur coat (creatures/materials/fur.gdshader with shells), the wolf keeps the
## skeleton and clips the motion (L22) and face (L36-3) lanes rely on, and the
## models stay inside R4's budget.
extends GutTest

const WOLF := preload("res://creatures/models/great_wolf.gltf")
const DEER := preload("res://creatures/models/deer.gltf")
const FUR := preload("res://creatures/materials/fur.gdshader")
const CARD := preload("res://creatures/materials/fur_card.gdshader")
const WOLF_BONES := [
	"root", "body", "hips", "spine", "ribs", "chest", "neck", "head", "muzzle", "jaw", "ear_l", "ear_r",
	"tail0", "tail1", "tail2", "tail3",
	"upper_fl_l", "lower_fl_l", "paw_fl_l", "upper_fl_r", "lower_fl_r", "paw_fl_r",
	"upper_hl_l", "lower_hl_l", "paw_hl_l", "upper_hl_r", "lower_hl_r", "paw_hl_r",
]


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


func _material(root: Node, name: String) -> Material:
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m and (m.resource_name == name or mi.mesh.surface_get_name(s) == name):
				return m
	return null


func _tris(root: Node) -> int:
	var n := 0
	for mi in _meshes(root):
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			n += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _shells(m: Material) -> int:
	var n := 0
	var p := m.next_pass
	while p != null:
		n += 1
		p = p.next_pass
	return n


func test_wolf_keeps_its_skeleton() -> void:
	var w := autofree(WOLF.instantiate()) as Node3D
	var sk := w.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var names: Array[String] = []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	for b: String in WOLF_BONES:
		assert_has(names, b, "bone %s" % b)
	assert_eq(sk.get_bone_count(), WOLF_BONES.size())
	assert_not_null(SnarlModifier.attach(sk), "the snarl still finds jaw, ears and head")


func test_wolf_clips_match_the_gait_table() -> void:
	var w := autofree(WOLF.instantiate()) as Node3D
	var ap := w.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var f := FileAccess.open("res://data/animation/creatures/great_wolf_gaits.txt", FileAccess.READ)
	var rows := 0
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols := line.split(" ", false)
		assert_true(ap.has_animation(cols[0]), "clip %s" % cols[0])
		if ap.has_animation(cols[0]):
			assert_almost_eq(ap.get_animation(cols[0]).length, float(cols[2]), 0.05, cols[0])
		rows += 1
	assert_eq(rows, 10)


func test_wolf_wears_fur_shells_and_guard_hair() -> void:
	var w := autofree(WOLF.instantiate()) as Node3D
	var coat := _material(w, "great_wolf_coat") as ShaderMaterial
	assert_not_null(coat)
	assert_eq(coat.shader, FUR)
	assert_eq(_shells(coat), 6, "hide + 6 shells")
	var hair := _material(w, "great_wolf_guard_hair") as ShaderMaterial
	assert_not_null(hair)
	assert_eq(hair.shader, CARD)


func test_wolf_budget_and_draw_passes() -> void:
	var w := autofree(WOLF.instantiate()) as Node3D
	assert_lt(_tris(w), 15000, "R4: creatures <= 15k triangles")
	var passes := 0
	for mi in _meshes(w):
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			passes += 1 + (_shells(m) if m else 0)
	assert_lte(passes, 12, "draw passes per wolf (surfaces + shells)")


func test_wolf_eyes_glow_softly_at_rest() -> void:
	var wolf := preload("res://creatures/wolves/great_wolf.tscn").instantiate() as GreatWolf
	add_child_autofree(wolf)
	var eyes := _material(wolf.model, "Eyes") as CandyMaterial
	assert_not_null(eyes)
	assert_true(eyes.emission_enabled, "GreatWolf._set_eye_glow drives this")
	assert_almost_eq(eyes.emission_energy_multiplier, wolf.data.eye_glow, 0.01, "daylight: no more than eye_glow")
	assert_lte(wolf.data.eye_glow, 0.61)


func test_fur_meshes_carry_rest_and_zone_data() -> void:
	for model: PackedScene in [WOLF, DEER]:
		var m := autofree(model.instantiate()) as Node3D
		var found := false
		for mi in _meshes(m):
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s) as ShaderMaterial
				if mat and mat.shader == FUR:
					var arrays := mi.mesh.surface_get_arrays(s)
					assert_not_null(arrays[Mesh.ARRAY_COLOR], "zones")
					assert_not_null(arrays[Mesh.ARRAY_TEX_UV2], "rest z")
					found = true
		assert_true(found, "%s has a fur coat" % model.resource_path)


func test_doe_coat_is_fur_not_flat() -> void:
	var d := autofree(DEER.instantiate()) as Node3D
	var coat := _material(d, "deer_coat") as ShaderMaterial
	assert_not_null(coat)
	assert_eq(_shells(coat), 4)
	assert_lt(_tris(d), 15000)

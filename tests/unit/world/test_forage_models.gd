extends GutTest
## The forage pickups (art/forage/<id>.glb): every item foraged today has one,
## within budget and standing on the ground, and pickable layers draw it.

const BIOMES := [
	"res://data/regions/spring_court/border_woods_biomes.tres",
	"res://data/regions/spring_court/eastern_woods_biomes.tres",
	"res://data/regions/spring_court/suriel_glade_biomes.tres",
]
const HUMAN_SCATTER := [
	"res://world/human_realm/cottage/scatter",
	"res://world/human_realm/hunting_forest/scatter",
	"res://world/human_realm/wall_seam/scatter",
	"res://world/human_realm/workshop/scatter",
	"res://world/human_realm/village/scatter",
]


func _foraged_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for path: String in BIOMES:
		var def := load(path) as WoodsRegionDef
		for id: StringName in def.forage_visuals:
			if not ids.has(id):
				ids.append(id)
	for dir_path: String in HUMAN_SCATTER:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".tres"):
				var layer := load("%s/%s" % [dir_path, f]) as ScatterLayer
				if layer and layer.ingredient_id != &"" and not ids.has(layer.ingredient_id):
					ids.append(layer.ingredient_id)
	return ids


func _tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		n += (idx.size() if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func test_every_foraged_item_has_a_model_in_budget_on_the_ground() -> void:
	var ids := _foraged_ids()
	assert_gt(ids.size(), 60, "the woods and human-realm finds list the foraged ids")
	for id in ids:
		var mesh := ScatterLayer.forage_model(id)
		assert_not_null(mesh, "art/forage/%s.glb" % id)
		if mesh == null:
			continue
		assert_lt(_tris(mesh), 3001, "%s within 3k tris" % id)
		var box := mesh.get_aabb()
		assert_almost_eq(box.position.y, 0.0, 0.03, "%s stands on the ground" % id)
		assert_lt(Vector2(box.get_center().x, box.get_center().z).length(), 0.15, "%s is centred" % id)


func test_pickable_layers_draw_the_model_and_decor_keeps_its_mesh() -> void:
	var pick := ScatterLayer.new()
	pick.ingredient_id = &"ing_snowdrop"
	pick.mesh = BoxMesh.new()
	assert_eq(pick.draw_mesh(), ScatterLayer.forage_model(&"ing_snowdrop"))
	var decor := ScatterLayer.new()
	decor.mesh = BoxMesh.new()
	assert_eq(decor.draw_mesh(), decor.mesh)
	var unknown := ScatterLayer.new()
	unknown.ingredient_id = &"ing_not_modelled"
	unknown.mesh = BoxMesh.new()
	assert_eq(unknown.draw_mesh(), unknown.mesh, "no model: the layer's own mesh")


func test_larder_chicken_is_a_small_table_find() -> void:
	# Suriel bait (LarderPickup): lies on the kitchen table, about 0.35 m long.
	var mesh := ScatterLayer.forage_model(&"ing_dead_chicken")
	assert_not_null(mesh, "art/forage/ing_dead_chicken.glb")
	if mesh == null:
		return
	assert_lt(_tris(mesh), 3001)
	var box := mesh.get_aabb()
	assert_almost_eq(box.position.y, 0.0, 0.03, "rests on the table top")
	assert_almost_eq(maxf(box.size.x, box.size.z), 0.35, 0.05, "about 0.35 m long")
	assert_lt(box.size.y, 0.15, "lies flat")

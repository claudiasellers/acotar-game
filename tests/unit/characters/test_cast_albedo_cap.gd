extends GutTest
## Lane L48-3: no cast model's skin is authored brighter than the art-direction cap
## (every albedo channel <= 0.85 sRGB), so faces don't bloom chalk-white under the
## night grades. Covers every characters/<id>/<id>_model.tscn.

const CAP := 0.852


func _models() -> Array[String]:
	var out: Array[String] = []
	for id in DirAccess.get_directories_at("res://characters"):
		var path := "res://characters/%s/%s_model.tscn" % [id, id]
		if ResourceLoader.exists(path):
			out.append(path)
	return out


func test_every_cast_skin_is_under_the_cap() -> void:
	var models := _models()
	assert_gt(models.size(), 5, "found the cast")
	for path in models:
		var state := (load(path) as PackedScene).get_state()
		for n in state.get_node_count():
			for p in state.get_node_property_count(n):
				var v: Variant = state.get_node_property_value(n, p)
				if v is ShaderMaterial:
					var c: Variant = (v as ShaderMaterial).get_shader_parameter(&"albedo")
					if c is Color:
						var col := c as Color
						assert_lte(maxf(col.r, maxf(col.g, col.b)), CAP, "%s %s skin albedo" % [path.get_file(), state.get_node_property_name(n, p)])

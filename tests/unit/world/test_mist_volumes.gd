extends GutTest
## Mist FogVolumes stay see-through (L51). The mill pond's mist at density 0.8
## per metre was opaque within a few metres: a black wall at night, a white one
## by day. Ground mists elsewhere run 0.03-0.12.

const MAX_MIST_DENSITY := 0.15
const SCENES := [
	"res://world/human_realm/village/village.tscn",
	"res://world/human_realm/cottage/cottage.tscn",
]


func test_human_realm_mists_are_see_through() -> void:
	for path: String in SCENES:
		var root: Node = (load(path) as PackedScene).instantiate()
		var found := 0
		for fv: Node in root.find_children("*", "FogVolume", true, false):
			var mat := (fv as FogVolume).material as FogMaterial
			assert_not_null(mat, "%s %s has a FogMaterial" % [path, fv.name])
			if mat != null:
				found += 1
				assert_lte(mat.density, MAX_MIST_DENSITY, "%s %s stays see-through" % [path, fv.name])
		assert_gt(found, 0, "%s has its mist" % path)
		root.free()

extends GutTest
## Gowns cover Feyre's torso only from the bodice down; hiding her whole torso
## surface (it runs to the neck) made every open neckline see-through. The rule
## lives in tools/gen_gameplay_data.py (body_hides); this guards the output.

const PIECES := "res://data/wardrobe/pieces"
const BARE_ARMS := ["gown_starlight", "gown_garden"]


func _gowns() -> Array[WardrobePiece]:
	var out: Array[WardrobePiece] = []
	for f in DirAccess.get_files_at(PIECES):
		if not f.ends_with(".tres"):
			continue
		var p := load("%s/%s" % [PIECES, f]) as WardrobePiece
		if p and p.mesh_path.get_file().begins_with("gown_"):
			out.append(p)
	return out


func test_gowns_never_hide_the_torso() -> void:
	var gowns := _gowns()
	assert_gt(gowns.size(), 40, "the gown pieces are found")
	for p in gowns:
		assert_false(p.hides_body_regions.has(&"torso"), "%s must not hide the torso" % p.id)
		assert_true(p.hides_body_regions.has(&"legs"), "%s still hides the legs under the skirt" % p.id)


func test_sheer_and_short_sleeved_gowns_show_the_arms() -> void:
	for p in _gowns():
		if BARE_ARMS.has(p.mesh_path.get_file().get_basename()):
			assert_false(p.hides_body_regions.has(&"arms"), "%s leaves the forearms bare" % p.id)

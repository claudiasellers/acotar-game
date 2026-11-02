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


## Meshes whose sleeves run to the wrist (build_wardrobe.py / build_feyre.py cut the
## arm at x 0.50 or more), so the arms region is fully under them. Any other piece
## hiding "arms" leaves the forearms invisible with floating hands (T042).
const LONG_SLEEVED := ["hunter_tunic", "riding_leathers", "woods_leathers", "painter_smock",
		"gown_solstice"]


func test_only_wrist_length_sleeves_hide_the_arms() -> void:
	var seen := 0
	for f in DirAccess.get_files_at(PIECES):
		if not f.ends_with(".tres"):
			continue
		var p := load("%s/%s" % [PIECES, f]) as WardrobePiece
		if p == null or not p.hides_body_regions.has(&"arms"):
			continue
		seen += 1
		var mesh := p.mesh_path.get_file().get_basename()
		assert_true(LONG_SLEEVED.has(mesh) or mesh.begins_with("gown_") and not ["gown_starlight", "gown_garden"].has(mesh),
				"%s hides the arms but its sleeves stop short" % p.id)
	assert_gt(seen, 5, "some pieces do hide the arms")


func test_short_sleeved_tunics_hide_the_torso_only() -> void:
	var n := 0
	for f in DirAccess.get_files_at(PIECES):
		if not (f.begins_with("spring_tunic") or f.begins_with("fae_tunic")):
			continue
		n += 1
		var p := load("%s/%s" % [PIECES, f]) as WardrobePiece
		assert_false(p.hides_body_regions.has(&"arms"), "%s leaves the forearms visible" % p.id)
		assert_true(p.hides_body_regions.has(&"torso"), "%s still covers the torso" % p.id)
	assert_gt(n, 8, "the tunic variants are found")

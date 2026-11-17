## Writes the white mare's dress-up pieces, data/mount/decor/*.tres (L47-7,
## docs/contracts/mare_bond.md). One table, so the colours and recipes stay
## together; rerun after editing it:
##   godot --headless -s tools/mount/gen_mare_decor.gd
## Colours keep under the 0.85 albedo cap (docs/tuning.md albedo_cap).
extends SceneTree

const OUT := "res://data/mount/decor"
const MODELS := "res://systems/mount/models/"

## The R3 candy palette, each under the cap.
const ROSE := Color(0.85, 0.6, 0.7)
const BLUSH := Color(0.85, 0.72, 0.76)
const LILAC := Color(0.72, 0.62, 0.84)
const PERI := Color(0.62, 0.68, 0.85)
const MINT := Color(0.6, 0.8, 0.7)
const BUTTER := Color(0.85, 0.79, 0.56)
const PEARL := Color(0.84, 0.82, 0.8)

const MANE := ["ManeBlush", "ManeLilac", "ManeRose"]
const BROW := ["BloomRose", "BloomButter", "BloomPeri"]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	for p: Dictionary in _table():
		var d := MareDecor.new()
		d.id = StringName(p["id"])
		d.display_name = p["name"]
		d.slot = StringName(p["slot"])
		d.blurb = p.get("blurb", "")
		d.tint_surfaces = PackedStringArray(p.get("tint", []))
		d.model = p.get("model", "")
		d.bone = StringName(p.get("bone", ""))
		d.colors = PackedColorArray(p.get("colors", []))
		d.pearl = p.get("pearl", 0.0)
		d.glitter = p.get("glitter", 0.0)
		d.inputs = p.get("inputs", {})
		var err := ResourceSaver.save(d, "%s/%s.tres" % [OUT, p["id"]])
		if err != OK:
			push_error("could not write %s" % p["id"])
		n += 1
	print("gen_mare_decor: wrote %d pieces" % n)
	quit()


func _table() -> Array[Dictionary]:
	var t: Array[Dictionary] = []
	# Saddle cloths: the rose she came with, and five more.
	t.append({"id": "cloth_rose", "name": "Rose saddle cloth", "slot": "cloth", "tint": ["SaddleCloth"],
		"blurb": "The cloth she came to me in."})
	for c: Array in [["lilac", "Lilac", LILAC, {"tag:bloom_lilac": 4, "tag:cordage": 1}],
			["peri", "Periwinkle", PERI, {"tag:bloom_sky": 3, "tag:cordage": 1}],
			["mint", "Mint", MINT, {"ing_moss": 2, "tag:cordage": 1}],
			["butter", "Buttercup", BUTTER, {"tag:bloom_butter": 4, "tag:cordage": 1}],
			["pearl", "Pearl", PEARL, {"tag:bloom_pearl": 4, "tag:cordage": 1}]]:
		t.append({"id": "cloth_" + c[0], "name": "%s saddle cloth" % c[1], "slot": "cloth", "tint": ["SaddleCloth"],
			"colors": [c[2]], "pearl": 0.25, "inputs": c[3]})
	# Mane dyes: three locks each, so every dye is a soft three-tone.
	t.append({"id": "mane_spring", "name": "Blush and lilac mane", "slot": "mane", "tint": MANE,
		"blurb": "Her own colours."})
	for c: Array in [["rose", "Rose-petal mane", [ROSE, BLUSH, Color(0.82, 0.52, 0.64)], {"ing_madder": 1, "tag:bloom_rose": 3}],
			["lavender", "Lavender-mist mane", [LILAC, Color(0.78, 0.7, 0.85), Color(0.66, 0.56, 0.8)], {"ing_violet": 1, "tag:bloom_lilac": 3}],
			["sky", "Periwinkle-sky mane", [PERI, Color(0.72, 0.78, 0.85), LILAC], {"ing_woad": 1, "tag:bloom_sky": 2}],
			["butter", "Butter-cream mane", [BUTTER, Color(0.85, 0.82, 0.7), BLUSH], {"ing_marsh_marigold": 1, "tag:bloom_butter": 3}],
			["pearl", "Pearl-white mane", [PEARL, Color(0.8, 0.8, 0.84), BLUSH], {"ing_chalk": 1, "tag:bloom_pearl": 3}],
			["mint", "Sea-mint mane", [MINT, Color(0.7, 0.84, 0.8), PERI], {"ing_moss": 2, "tag:bloom_pearl": 1}]]:
		t.append({"id": "mane_" + c[0], "name": c[1], "slot": "mane", "tint": MANE, "colors": c[2], "pearl": 0.35, "inputs": c[3]})
	# Tack metal: bit, rings, pommel, stirrups.
	t.append({"id": "tack_gold", "name": "Gold tack", "slot": "tack", "tint": ["Gold"], "blurb": "Gold, as the manor does everything."})
	for c: Array in [["rosegold", "Rose-gold tack", Color(0.85, 0.62, 0.55), {"ing_red_ochre": 1, "ing_iron_filings": 1}],
			["silver", "Silver tack", Color(0.78, 0.8, 0.84), {"ing_iron_filings": 2, "ing_chalk": 1}],
			["pearl", "Pearl tack", Color(0.84, 0.8, 0.78), {"ing_snail_shell": 2, "ing_chalk": 1}]]:
		t.append({"id": "tack_" + c[0], "name": c[1], "slot": "tack", "tint": ["Gold"], "colors": [c[2]],
			"pearl": 0.5 if c[0] == "pearl" else 0.15, "inputs": c[3]})
	# Hoof polish: a pearl shine, and glitter in three colours.
	t.append({"id": "hooves_bare", "name": "Bare hooves", "slot": "hooves", "tint": ["Hoof"], "blurb": "Clean and oiled."})
	for c: Array in [["pearl", "Pearl hoof polish", PEARL, 0.8, 0.0, {"ing_snail_shell": 1}],
			["gold", "Gold-glitter hooves", Color(0.85, 0.72, 0.46), 0.2, 0.9, {"ing_iron_filings": 1, "tag:bloom_butter": 1}],
			["pink", "Pink-glitter hooves", Color(0.85, 0.62, 0.72), 0.2, 0.9, {"ing_cherry_blossom": 2, "ing_snail_shell": 1}],
			["lilac", "Lilac-glitter hooves", LILAC, 0.2, 0.9, {"tag:bloom_lilac": 2, "ing_snail_shell": 1}]]:
		t.append({"id": "hooves_" + c[0], "name": c[1], "slot": "hooves", "tint": ["Hoof"], "colors": [c[2]],
			"pearl": c[3], "glitter": c[4], "inputs": c[5]})
	# The blooms on her brow.
	t.append({"id": "brow_spring", "name": "Spring brow blooms", "slot": "brow", "tint": BROW, "blurb": "Rose, buttercup and periwinkle."})
	for c: Array in [["rose", "Rose brow blooms", [ROSE, BLUSH, ROSE], {"tag:bloom_rose": 3}],
			["lilac", "Lilac brow blooms", [LILAC, Color(0.8, 0.72, 0.85), LILAC], {"tag:bloom_lilac": 3}],
			["pearl", "Moon-white brow blooms", [PEARL, BUTTER, PEARL], {"tag:bloom_pearl": 3}],
			["sky", "Sky brow blooms", [PERI, PEARL, PERI], {"tag:bloom_sky": 2}]]:
		t.append({"id": "brow_" + c[0], "name": c[1], "slot": "brow", "tint": BROW, "colors": c[2], "pearl": 0.2, "inputs": c[3]})
	# Pieces she wears: a neck garland, mane bows, a tail bow, each in five colours.
	var tones := [["rose", "Rose", ROSE, "tag:bloom_rose"], ["lilac", "Lilac", LILAC, "tag:bloom_lilac"],
		["butter", "Buttercup", BUTTER, "tag:bloom_butter"], ["pearl", "Pearl", PEARL, "tag:bloom_pearl"],
		["sky", "Periwinkle", PERI, "tag:bloom_sky"]]
	for c: Array in tones:
		var few := 3 if c[0] == "sky" else 5
		t.append({"id": "garland_" + c[0], "name": "%s neck garland" % c[1], "slot": "garland",
			"model": MODELS + "mare_garland.gltf", "bone": "neck", "colors": [c[2]],
			"inputs": {c[3]: few, "tag:cordage": 1}})
		t.append({"id": "bows_" + c[0], "name": "%s mane bows" % c[1], "slot": "bows",
			"model": MODELS + "mare_mane_bows.gltf", "bone": "neck", "colors": [c[2]], "pearl": 0.3,
			"inputs": {"tag:cordage": 2, c[3]: 1 if c[0] == "sky" else 2}})
		t.append({"id": "tail_" + c[0], "name": "%s tail bow" % c[1], "slot": "tail",
			"model": MODELS + "mare_tail_bow.gltf", "bone": "tail0", "colors": [c[2]], "pearl": 0.3,
			"inputs": {"tag:cordage": 1, c[3]: 1 if c[0] == "sky" else 2}})
	return t

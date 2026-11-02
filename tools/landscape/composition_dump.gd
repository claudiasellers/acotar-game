## Dumps every scatter placement of the open-world regions to CSV for the
## composition audit (tools/landscape/composition_audit.py):
##   godot --headless --path . -s res://tools/landscape/composition_dump.gd -- <out_dir> [region ...]
## One file per region: id,tags,x,z,scale. Human realm reads the committed
## scatter .tres; the Spring Court regions run their generators (fixed seeds).
extends SceneTree

const WOODS := ["border_woods", "eastern_woods", "suriel_glade"]
const COURT := ["autumn_foothills", "blighted_reaches", "blossom_vale", "fae_village", "hill_of_the_rite",
		"rosewild", "solstice_meadow", "starlight_glen", "western_fells"]
const HUMAN := ["cottage", "hunting_forest", "village", "wall_seam", "workshop"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://composition"
	var only := args.slice(1)
	DirAccess.make_dir_recursive_absolute(out)
	for r in HUMAN + WOODS + COURT:
		if not only.is_empty() and not only.has(r):
			continue
		var layers: Array[ScatterLayer] = []
		var bounds := Rect2()
		if r in WOODS:
			var def: WoodsRegionDef = load("res://data/regions/spring_court/%s_biomes.tres" % r)
			bounds = def.provider.BOUNDS
			for kind in ["tree", "shrub", "forage"]:
				var pts := WoodsScatter.place(def, bounds, kind)
				for id: StringName in WoodsScatter.sorted_ids(pts):
					var l := ScatterLayer.new()
					l.id = StringName("%s:%s" % [kind, id])
					l.instances = pts[id]
					layers.append(l)
		elif r in COURT:
			var content: CourtRegionContent = load("res://data/regions/spring_court/content/%s.tres" % r)
			bounds = content.bounding_rect()
			layers.append_array(CourtScatterGenerator.decor_layers(content))
			for l in CourtScatterGenerator.forage_layers(content):
				l.tags = PackedStringArray(Array(l.tags) + ["forage"])
				layers.append(l)
		else:
			var dir := "res://world/human_realm/%s/scatter" % r
			for f in DirAccess.get_files_at(dir):
				if f.ends_with(".tres"):
					var l := load(dir + "/" + f) as ScatterLayer
					if l != null:
						if l.is_forage():
							l.tags = PackedStringArray(Array(l.tags) + ["forage"])
						layers.append(l)
		var lines := PackedStringArray(["id,tags,x,z,scale"])
		for l in layers:
			var tags := "|".join(l.tags)
			var inst := l.instances
			for o in range(0, inst.size(), 5):
				lines.append("%s,%s,%.1f,%.1f,%.2f" % [l.id, tags, inst[o], inst[o + 2], inst[o + 4]])
		var fa := FileAccess.open("%s/%s.csv" % [out, r], FileAccess.WRITE)
		fa.store_string("\n".join(lines))
		fa.close()
		print("DUMP %s layers %d rows %d bounds %s" % [r, layers.size(), lines.size() - 1, bounds])
	quit(0)

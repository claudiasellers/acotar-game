## Prints the court's planting against the land (finish plan P2): per region,
## the trees per hectare on every landform (CourtLandHabitats) and overall,
## and the mix of tree roles. CourtPlanting.report()'s numbers.
##   tools/mq/godot.sh -s tools/court/court_tree_report.gd [region=<id>] [step=8]
extends SceneTree


func _initialize() -> void:
	var step := CourtPlanting.STEP
	var only := ""
	var map_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("region="):
			only = a.substr(7)
		elif a.begins_with("map="):
			map_dir = a.substr(4)   # a picture per region: the landforms, a dot per tree
	CourtHeight.prewarm()
	var header := "region".rpad(18) + "trees".lpad(7) + "  /ha".lpad(7)
	for n: StringName in CourtLandHabitats.NAMES:
		header += String(n).substr(0, 7).lpad(8)
	print(header)
	for id in CourtMap.region_ids():
		if only != "" and String(id) != only:
			continue
		var content := load("res://data/regions/spring_court/content/%s.tres" % id) as CourtRegionContent
		var layers := CourtPlanting.tree_layers(content)
		var rep := CourtPlanting.report(content, layers, step)
		if map_dir != "":
			_map(content, layers).save_png("%s/%s.png" % [map_dir, id])
		var line := String(id).rpad(18) + str(rep["trees"]).lpad(7) + ("%.1f" % rep["per_ha"]).lpad(7)
		for f in CourtLandHabitats.NAMES.size():
			line += ("%.0f" % rep["form_per_ha"][f]).lpad(8)
		print(line)
		var mix := ""
		for k: String in rep["kinds"]:
			mix += "%s %d  " % [k.trim_prefix("woods_").trim_prefix("flora_tree_"), rep["kinds"][k]]
		mix += "| densest hectare %d" % rep["densest_ha"]
		print("    " + mix)
	quit()


const MAP_PITCH := 4.0
const FORM_COLOURS := [Color(0.80, 0.90, 0.72), Color(0.86, 0.80, 0.62), Color(0.62, 0.60, 0.58), Color(0.74, 0.86, 0.90),
	Color(0.72, 0.62, 0.82), Color(0.95, 0.74, 0.50), Color(0.92, 0.50, 0.45), Color(1.0, 0.98, 0.86),
	Color(0.55, 0.85, 0.88), Color(0.50, 0.78, 0.90), Color(0.45, 0.66, 0.92), Color(0.30, 0.45, 0.85)]
const KIND_COLOURS := {"yew": Color(0.0, 0.2, 0.35), "ancient_oak": Color(0.45, 0.2, 0.0), "wild_cherry": Color(0.85, 0.1, 0.5),
	"crab_apple": Color(0.75, 0.25, 0.45), "silver_birch": Color(0.35, 0.35, 0.0), "willow": Color(0.0, 0.45, 0.45),
	"hawthorn": Color(0.5, 0.0, 0.6), "elder": Color(0.4, 0.0, 0.45), "lilac_tree": Color(0.45, 0.3, 0.8)}


## North up, MAP_PITCH m a pixel: the landform colours (floor green, slope
## sand, steep grey, valley pale blue, hollow mauve, crest orange, knoll red,
## verge cream, the banks and water blues), ground the region does not own
## white, a dark dot per tree (pines navy, twisted oaks brown, blossom pink).
func _map(content: CourtRegionContent, layers: Array[ScatterLayer]) -> Image:
	var r := content.bounding_rect()
	var w := ceili(r.size.x / MAP_PITCH)
	var h := ceili(r.size.y / MAP_PITCH)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in h:
		for x in w:
			var p := r.position + Vector2(x + 0.5, y + 0.5) * MAP_PITCH
			if content.owns(p):
				var c: Color = FORM_COLOURS[CourtLandHabitats.NAMES.find(CourtPlanting.form_name(content, p, true))]
				img.set_pixel(x, y, c if content.habitat_at(p) == content.default_habitat else c.darkened(0.12))
	for layer in layers:
		var kind := String(layer.id).substr(9).trim_prefix("woods_").trim_prefix("flora_tree_")
		var c: Color = KIND_COLOURS.get(kind, Color(0.0, 0.3, 0.0))
		for i in layer.count():
			var q := (Vector2(layer.position_of(i).x, layer.position_of(i).z) - r.position) / MAP_PITCH
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				img.set_pixel(int(q.x), int(q.y), c)
	return img

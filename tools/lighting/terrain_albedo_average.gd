## Prints the mean albedo of the terrain textures: the colour candy_lit's
## ground_bounce throws back into the shade band (render program T3a, L60).
## Averaged in linear light, printed as sRGB (what a source_color uniform takes).
## Run: tools/mq/godot.sh -s tools/lighting/terrain_albedo_average.gd
extends SceneTree


func _init() -> void:
	var sum := Vector3.ZERO
	var n := 0
	for entry: Array in TerrainSetup.TEXTURES:
		var path := "%s/%s_albedo.png" % [TerrainSetup.TEXTURE_DIR, entry[0]]
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img == null:
			continue
		var c := mean_linear(img)
		print("%-14s srgb %s" % [entry[0], _fmt(c.linear_to_srgb())])
		sum += Vector3(c.r, c.g, c.b)
		n += 1
	var avg := sum / maxf(n, 1)
	print("terrain albedo average (%d textures) srgb %s" % [n, _fmt(Color(avg.x, avg.y, avg.z).linear_to_srgb())])
	quit()


## Mean colour of an image in linear light, from a 64x64 box-filtered copy.
static func mean_linear(src: Image) -> Color:
	var img := src.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(64, 64, Image.INTERPOLATE_BILINEAR)
	var s := Vector3.ZERO
	for y in 64:
		for x in 64:
			var c := img.get_pixel(x, y).srgb_to_linear()
			s += Vector3(c.r, c.g, c.b)
	s /= 4096.0
	return Color(s.x, s.y, s.z)


static func _fmt(c: Color) -> String:
	return "(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b]

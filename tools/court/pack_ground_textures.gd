## Packs CC0 photo ground textures (Poly Haven 1k: <id>_diff/_disp/_nor_gl/_rough)
## into the terrain's slot format, in the court's own palette:
##   <slot>_albedo.png  rgb colour, a height     (512 px, tileable)
##   <slot>_normal.png  rgb OpenGL normal, a roughness
## The photo gives the structure (blades, pebbles, leaf litter, its height and
## normal); the colour is the slot's palette from gen_terrain_textures.gd LOOKS,
## with a little of the photo's own hue kept, softened and capped at the glare
## rule (albedo <= 0.85). Run from the project:
##   tools/mq/godot.sh -s tools/court/pack_ground_textures.gd -- <source dir> [slot...]
extends SceneTree

const SIZE := 512
const OUT := "res://world/shared/terrain/textures"
const ALBEDO_CAP := 0.85
## Slot -> [Poly Haven id, share of the photo's own colour kept, detail contrast, softening blur px].
## Spring picks only: the photo gives the shapes (blades, petals, pebbles, moss);
## its brown soil colour is mostly dropped for the slot's spring palette.
const SOURCES := {
	"spring_grass": ["leafy_grass", 0.22, 0.9, 1],
	"moss": ["forrest_ground_01", 0.15, 0.85, 1],
	"forest_floor": ["sparse_grass", 0.12, 0.85, 1],
	"path": ["flower_scattered_dirt", 0.40, 0.8, 0],
	"riverbed": ["river_small_rocks", 0.30, 0.9, 0],
	"rock": ["mossy_rock", 0.30, 1.0, 0],
	"blight": ["withered_grass", 0.25, 0.9, 1],
}
const TerrainTextures := preload("res://world/shared/terrain/gen_terrain_textures.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("pack_ground_textures: give the folder with the Poly Haven maps")
		quit(1)
		return
	var src: String = args[0]
	var slots: Array = Array(args.slice(1)) if args.size() > 1 else SOURCES.keys()
	var done := 0
	for slot: String in slots:
		if _pack(src, slot):
			done += 1
	print("pack_ground_textures: %d slots written" % done)
	quit(0 if done == slots.size() else 1)


func _pack(src: String, slot: String) -> bool:
	var spec: Array = SOURCES[slot]
	var id: String = spec[0]
	var diff := _load(src, id, ["diff", "diffuse"])
	var disp := _load(src, id, ["disp"])
	var nor := _load(src, id, ["nor_gl"])
	var rough := _load(src, id, ["rough"])
	if diff == null or disp == null or nor == null or rough == null:
		push_error("pack_ground_textures: missing maps for %s (%s)" % [slot, id])
		return false
	for img in [diff, disp, nor, rough]:
		img.convert(Image.FORMAT_RGBA8)
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var look: Array = TerrainTextures.LOOKS[slot]
	var base: Color = look[0]
	var accent: Color = look[1]
	var keep: float = spec[1]
	var contrast: float = spec[2]
	# Luminance statistics, so every photo maps onto the palette the same way.
	var mean := 0.0
	var sq := 0.0
	var hmin := 1.0
	var hmax := 0.0
	for y in SIZE:
		for x in SIZE:
			var l := diff.get_pixel(x, y).get_luminance()
			mean += l
			sq += l * l
			var h := disp.get_pixel(x, y).r
			hmin = minf(hmin, h)
			hmax = maxf(hmax, h)
	var n := float(SIZE * SIZE)
	mean /= n
	var sd := sqrt(maxf(sq / n - mean * mean, 1e-6))
	var photo_mean := _mean_color(diff)
	var albedo := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var normal := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var p := diff.get_pixel(x, y)
			var z := clampf((p.get_luminance() - mean) / sd * 0.5 * contrast, -1.0, 1.0)
			# Palette colour by the photo's light and dark, accent in the lights.
			var col := base.lerp(accent, smoothstep(0.1, 1.0, z) * float(look[5]))
			col = col.lightened(maxf(z, 0.0) * 0.18).darkened(maxf(-z, 0.0) * 0.28)
			# Keep a little of the photo's own hue shift (a petal, a dry blade).
			var tint := Color(p.r / maxf(photo_mean.r, 0.01), p.g / maxf(photo_mean.g, 0.01), p.b / maxf(photo_mean.b, 0.01))
			var photo_col := Color(col.r * tint.r, col.g * tint.g, col.b * tint.b)
			col = col.lerp(photo_col, keep)
			var h := clampf((disp.get_pixel(x, y).r - hmin) / maxf(hmax - hmin, 0.01), 0.0, 1.0)
			albedo.set_pixel(x, y, Color(minf(col.r, ALBEDO_CAP), minf(col.g, ALBEDO_CAP), minf(col.b, ALBEDO_CAP), h))
			var nc := nor.get_pixel(x, y)
			normal.set_pixel(x, y, Color(nc.r, nc.g, nc.b, rough.get_pixel(x, y).r))
	var blur: int = spec[3]
	if blur > 0:
		albedo = _soften(albedo, blur)
	albedo.save_png("%s/%s_albedo.png" % [OUT, slot])
	normal.save_png("%s/%s_normal.png" % [OUT, slot])
	print("  %s <- %s" % [slot, id])
	return true


func _load(src: String, id: String, kinds: Array) -> Image:
	for kind: String in kinds:
		for ext in ["jpg", "png"]:
			var path := "%s/%s_%s_1k.%s" % [src, id, kind, ext]
			if FileAccess.file_exists(path):
				return Image.load_from_file(path)
	return null


func _mean_color(img: Image) -> Color:
	var r := 0.0
	var g := 0.0
	var b := 0.0
	for y in range(0, SIZE, 4):
		for x in range(0, SIZE, 4):
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
			b += c.b
	var n := float((SIZE / 4) * (SIZE / 4))
	return Color(r / n, g / n, b / n)


## A small tileable box blur on the colour (not the height): painterly, not photographic.
func _soften(img: Image, radius: int) -> Image:
	var out := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var acc := Color(0, 0, 0, 0)
			var k := 0
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					acc += img.get_pixel((x + dx + SIZE) % SIZE, (y + dy + SIZE) % SIZE)
					k += 1
			var c := acc / k
			out.set_pixel(x, y, Color(c.r, c.g, c.b, img.get_pixel(x, y).a))
	return out

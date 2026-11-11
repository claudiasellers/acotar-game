## The packing behind tools/court/pack_ground_textures.gd (CC0 photo maps ->
## the terrain's slot format, in the court's palette), as a plain helper so the
## preview shots (tools/court/court_terrain_shots.gd) can pack looks at run time.
class_name GroundTexturePacker
extends RefCounted

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

## Look -> [detail contrast scale, photo colour kept scale, extra blur px,
## normal flatten 0-1, height contrast, bands (0 = none), use the pastel palette,
## optional value scale, optional saturation scale].
const LOOKS_ALT := {
	"photo": [1.0, 1.0, 0, 0.0, 1.0, 0, false],
	"soft": [0.4, 0.35, 2, 0.6, 0.5, 0, false],
	"pastel": [0.4, 0.3, 2, 0.6, 0.5, 0, true],
	"storybook": [0.8, 0.15, 4, 0.75, 0.45, 4, true],
	# Storybook a notch and two notches deeper: lower value, a little more
	# colour, so far hills keep their edge against the pale sky.
	"storybook_deep": [0.8, 0.15, 4, 0.75, 0.45, 4, true, 0.84, 1.12],
	"storybook_deeper": [0.85, 0.15, 4, 0.75, 0.45, 4, true, 0.72, 1.22],
}
## The pastel palette: the ground in the foliage's family (mint canopies,
## blossom pinks, lilac shade), lighter and fresher than the old olive.
## slot -> [base, accent].
const PASTEL := {
	"spring_grass": [Color(0.33, 0.56, 0.36), Color(0.56, 0.74, 0.48)],
	# Olive (owner 2026-11-11, wcterrain-37): hue 160 read teal in the Western
	# Woods; tools/court/recolour_moss.py turned the packed texture the same way.
	"moss": [Color(0.343, 0.56, 0.30), Color(0.613, 0.78, 0.58)],
	"forest_floor": [Color(0.44, 0.38, 0.34), Color(0.62, 0.50, 0.54)],
	"path": [Color(0.68, 0.54, 0.44), Color(0.86, 0.70, 0.68)],
	"riverbed": [Color(0.58, 0.63, 0.67), Color(0.75, 0.77, 0.83)],
	"rock": [Color(0.62, 0.60, 0.70), Color(0.79, 0.75, 0.85)],
	"blight": [Color(0.50, 0.48, 0.52), Color(0.60, 0.56, 0.62)],
}

var _look: Array = LOOKS_ALT["photo"]
var _out := OUT


func _init(look: String = "photo", out_dir: String = OUT) -> void:
	_look = LOOKS_ALT[look]
	_out = out_dir


func pack(src: String, slot: String) -> bool:
	return _pack(src, slot)



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
	if _look[6] and PASTEL.has(slot):
		base = PASTEL[slot][0]
		accent = PASTEL[slot][1]
	var keep: float = spec[1] * float(_look[1])
	var contrast: float = spec[2] * float(_look[0])
	var bands: int = _look[5]
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
			if bands > 0:
				# Soft painted bands: light and dark in a few gentle steps.
				var k := (z * 0.5 + 0.5) * bands
				z = ((floorf(k) + smoothstep(0.35, 0.65, k - floorf(k))) / bands) * 2.0 - 1.0
			# Palette colour by the photo's light and dark, accent in the lights.
			var col := base.lerp(accent, smoothstep(0.1, 1.0, z) * float(look[5]))
			col = col.lightened(maxf(z, 0.0) * 0.18).darkened(maxf(-z, 0.0) * 0.28)
			# Keep a little of the photo's own hue shift (a petal, a dry blade).
			var tint := Color(p.r / maxf(photo_mean.r, 0.01), p.g / maxf(photo_mean.g, 0.01), p.b / maxf(photo_mean.b, 0.01))
			var photo_col := Color(col.r * tint.r, col.g * tint.g, col.b * tint.b)
			col = col.lerp(photo_col, keep)
			if _look.size() > 7:
				col = Color.from_hsv(col.h, clampf(col.s * float(_look[8]), 0.0, 1.0), col.v * float(_look[7]))
			var h := clampf((disp.get_pixel(x, y).r - hmin) / maxf(hmax - hmin, 0.01), 0.0, 1.0)
			h = lerpf(0.5, h, float(_look[4]))
			albedo.set_pixel(x, y, Color(minf(col.r, ALBEDO_CAP), minf(col.g, ALBEDO_CAP), minf(col.b, ALBEDO_CAP), h))
			var nc := nor.get_pixel(x, y)
			var flat: float = _look[3]
			normal.set_pixel(x, y, Color(lerpf(nc.r, 0.5, flat), lerpf(nc.g, 0.5, flat), lerpf(nc.b, 1.0, flat), rough.get_pixel(x, y).r))
	var blur: int = int(spec[3]) + int(_look[2])
	if blur > 0:
		albedo = _soften(albedo, blur)
	albedo.save_png("%s/%s_albedo.png" % [_out, slot])
	normal.save_png("%s/%s_normal.png" % [_out, slot])
	print("  %s <- %s" % [slot, id])
	return true


func _load(src: String, id: String, kinds: Array) -> Image:
	for kind: String in kinds:
		for ext in ["jpg", "png"]:
			for prefix in ["", "acotar_tex_"]:
				var path := "%s/%s%s_%s_1k.%s" % [src, prefix, id, kind, ext]
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


## A small tileable box blur on the colour (not the height), in two passes on
## the raw bytes: painterly, not photographic.
func _soften(img: Image, radius: int) -> Image:
	var src := img.get_data()
	var tmp := src.duplicate()
	var k := float(2 * radius + 1)
	for pass_i in 2:
		var from := src if pass_i == 0 else tmp
		var to := tmp if pass_i == 0 else src.duplicate()
		for y in SIZE:
			for x in SIZE:
				var r := 0.0
				var g := 0.0
				var b := 0.0
				for d in range(-radius, radius + 1):
					var xx := (x + d + SIZE) % SIZE if pass_i == 0 else x
					var yy := y if pass_i == 0 else (y + d + SIZE) % SIZE
					var j := (yy * SIZE + xx) * 4
					r += from[j]
					g += from[j + 1]
					b += from[j + 2]
				var i := (y * SIZE + x) * 4
				to[i] = int(r / k)
				to[i + 1] = int(g / k)
				to[i + 2] = int(b / k)
				to[i + 3] = src[i + 3]
		if pass_i == 0:
			tmp = to
		else:
			src = to
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, src)

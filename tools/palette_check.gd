## Palette test (plans/experience-bar.md §3.2): fails a screenshot whose
## pixels stray into the banned lime family (#00FF00-#7FFF00: saturated,
## bright yellow-greens). Reusable by every lane:
##   godot --headless -s tools/palette_check.gd -- shot1.png shot2.png
## Prints the lime share per image; exits 1 if any image is over MAX_LIME.
extends SceneTree

## Share of pixels allowed in the lime family (antialiasing, specks).
const MAX_LIME := 0.005
## Lime family in HSV: hue 75-140 degrees, strongly saturated and bright.
const HUE_MIN := 75.0 / 360.0
const HUE_MAX := 140.0 / 360.0
const SAT_MIN := 0.55
const VAL_MIN := 0.45


func _initialize() -> void:
	var failed := false
	for path in OS.get_cmdline_user_args():
		var img := Image.load_from_file(path)
		if img == null:
			push_error("palette_check: cannot read %s" % path)
			failed = true
			continue
		var share := lime_share(img)
		var ok := share <= MAX_LIME
		failed = failed or not ok
		print("%s %s lime %.2f%%" % ["PASS" if ok else "FAIL", path.get_file(), share * 100.0])
	quit(1 if failed else 0)


## Share of pixels in the lime family, sampled on a 4 px grid.
static func lime_share(img: Image) -> float:
	var lime := 0
	var total := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			total += 1
			if c.h >= HUE_MIN and c.h <= HUE_MAX and c.s >= SAT_MIN and c.v >= VAL_MIN:
				lime += 1
	return float(lime) / maxf(total, 1.0)

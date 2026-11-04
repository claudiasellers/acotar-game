## Grade LUT parameter generator (render program T3b, L63).
##   tools/mq/godot.sh -s res://tools/env/make_lut.gd            (or `make luts`)
## For every GradePreset in world/shared/grades/:
##   - makes sure it points at a LutParams file data/grades/luts/<id>.tres
##     (identity if new), never overwriting numbers already there
##   - folds anything still on the preset into those parameters, so there is one
##     grade layer: its saturation/contrast/brightness (multiplied in, preset set
##     back to 1) and a legacy 1D GradientTexture `lut` (moved to `curve`)
##   - builds the 32³ LUT slices (the game builds the same Texture3D at load;
##     nothing baked to disk) and checks them against LutParams.apply on an off-grid sample set
##   - prints the docs/tuning.md rows for the LUT parameters and exposures
## Exit code 1 if a LUT does not reproduce its parameters.
extends SceneTree

const PRESET_DIR := "res://world/shared/grades/"
const LUT_DIR := "res://data/grades/luts/"
## Trilinear error is 0 on the affine parts; up to ~1.5% where a channel
## clamps inside a cell (high contrast and saturation) and on curve kinks.
const MAX_ERROR := 0.02


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LUT_DIR))
	var ok := true
	var rows: PackedStringArray = []
	for f in _preset_files():
		var path := PRESET_DIR + f
		var p := load(path) as GradePreset
		var id := f.get_basename()
		var params_path := LUT_DIR + id + ".tres"
		var params: LutParams = p.lut_params
		if params == null:
			params = load(params_path) if ResourceLoader.exists(params_path) else LutParams.new()
		var dirty := false
		if p.lut is GradientTexture1D and (p.lut as GradientTexture1D).gradient != null:
			params.curve = (p.lut as GradientTexture1D).gradient.duplicate()
			p.lut = null
			dirty = true
		for k: StringName in [&"saturation", &"contrast", &"brightness"]:
			var v: float = p.get(k)
			if not is_equal_approx(v, 1.0):
				params.set(k, params.get(k) * v)
				p.set(k, 1.0)
				dirty = true
		if dirty or not ResourceLoader.exists(params_path):
			ResourceSaver.save(params, params_path)
		if p.lut_params == null or p.lut_params.resource_path != params_path or dirty:
			p.lut_params = load(params_path)
			ResourceSaver.save(p, path)
			print("make_lut: %s -> %s%s" % [id, params_path, " (folded)" if dirty else ""])
		var t0 := Time.get_ticks_usec()
		var slices := p.lut_params.build_slices()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var err := _max_error(p.lut_params, slices)
		if err > MAX_ERROR:
			push_error("make_lut: %s LUT off by %.4f" % [id, err])
			ok = false
		rows.append(_row(id, p, ms, err))
	print("| Preset | exposure | brightness | contrast | saturation | curve (0 / 0.5 / 1) | lift / gamma / gain | hue | sat shadow / highlight | white | build ms | max err |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for r in rows:
		print(r)
	quit(0 if ok else 1)


## Largest channel error of the built LUT (trilinear, the way Godot samples it:
## raw colour, no half-texel offset) against the parameters, off the grid.
static func _max_error(params: LutParams, slices: Array[Image]) -> float:
	var n := LutParams.SIZE
	var worst := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 63
	for i in 400:
		var c := Color(rng.randf(), rng.randf(), rng.randf())
		# Stay off the outer half texel, where the LUT clamps by design.
		for ch in 3:
			c[ch] = lerpf(1.5 / n, 1.0 - 1.5 / n, c[ch])
		var want := params.apply(c)
		var got := _sample(slices, n, c)
		worst = maxf(worst, maxf(absf(want.r - got.r), maxf(absf(want.g - got.g), absf(want.b - got.b))))
	return worst


static func _sample(slices: Array[Image], n: int, c: Color) -> Color:
	var u := Vector3(clampf(c.r * n - 0.5, 0.0, n - 1.0), clampf(c.g * n - 0.5, 0.0, n - 1.0), clampf(c.b * n - 0.5, 0.0, n - 1.0))
	var i0 := Vector3i(floori(u.x), floori(u.y), floori(u.z))
	var i1 := Vector3i(mini(i0.x + 1, n - 1), mini(i0.y + 1, n - 1), mini(i0.z + 1, n - 1))
	var w := u - Vector3(i0)
	var out := Color(0, 0, 0)
	for dz in 2:
		for dy in 2:
			for dx in 2:
				var px := Vector3i(i1.x if dx else i0.x, i1.y if dy else i0.y, i1.z if dz else i0.z)
				var k := (w.x if dx else 1.0 - w.x) * (w.y if dy else 1.0 - w.y) * (w.z if dz else 1.0 - w.z)
				out += slices[px.z].get_pixel(px.x, px.y) * k
	return out


static func _row(id: String, p: GradePreset, ms: float, err: float) -> String:
	var l := p.lut_params
	var curve := "—"
	if l.curve != null:
		var parts: PackedStringArray = []
		for x in [0.0, 0.5, 1.0]:
			var c := l.curve.sample(x)
			parts.append("(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
		curve = " / ".join(parts)
	return "| `%s` | %.3f | %.3f | %.3f | %.3f | %s | %s / %s / %s | %.1f | %.3f / %.3f | %.2f | %.0f | %.4f |" % [
		id, p.exposure, l.brightness, l.contrast, l.saturation, curve, _c(l.lift), _c(l.gamma), _c(l.gain),
		l.hue_shift, l.shadow_saturation, l.highlight_saturation, l.white_level, ms, err]


static func _c(c: Color) -> String:
	return "(%.2f, %.2f, %.2f)" % [c.r, c.g, c.b]


static func _preset_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(PRESET_DIR):
		if f.ends_with(".tres"):
			out.append(f)
	out.sort()
	return out

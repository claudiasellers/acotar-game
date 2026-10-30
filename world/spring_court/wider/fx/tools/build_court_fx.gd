## Generates the Spring Court FX resources: grade presets (+ readme), ShaderMaterials
## and particle scenes. Deterministic content (no randomness; all values are tables).
## Run: godot --headless --path . -s res://world/spring_court/wider/fx/tools/build_court_fx.gd
extends SceneTree

const FX := "res://world/spring_court/wider/fx/"
const SH := FX + "shaders/"
const GRADE_SCRIPT := "res://world/shared/grades/grade_preset.gd"
## Tonal pass on the grade table, to the experience bar's tested spring grade
## (plans/experience-bar.md 2.1): LUT ramps blended this far from identity,
## fog thin, contrast 1.12, sun up to 1.8, shadows tinted lilac; glow per the
## book's light (see _tame).
## grade_blight is horror (bar 1.5): it withdraws instead.
const LUT_STRENGTH := 0.3
const FOG_CAP := 0.0012
const CONTRAST := 1.12
## Glow: daylight blooms only real highlights (threshold above white, no
## bloom wash); golden hour and night keep a soft glow for fire and lanterns.
const DAY_GLOW := 0.3
const DAY_THRESHOLD := 1.4
const NIGHT_GLOW := 0.7
const NIGHT_BLOOM := 0.04
const NIGHT_THRESHOLD := 1.1
## Foliage rim shimmer by day: faint before the glamour lifts (ch 23).
const DAY_MAGIC := 0.35
const VOLUMETRIC_CAP := 0.008
const SUN_GAIN := 1.15
const SUN_CAP := 1.8
const AMBIENT_SCALE := 0.75
const LILAC_SHADOW := Color("8C7FC4")
const EXPOSURE_CAP := 1.0
const BRIGHTNESS_CAP := 1.0
## Blight: saturation about 0.4, light 2-3 stops under the spring grade.
const BLIGHT_SATURATION := 0.4
const BLIGHT_SUN := 0.3


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FX + "grades"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FX + "materials"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FX + "particles"))
	var n_grades := _build_grades()
	var n_mats := _build_materials()
	var n_fx := _build_particles()
	print("court_fx: grades=%d materials=%d particles=%d" % [n_grades, n_mats, n_fx])
	quit(0)


# ---------------------------------------------------------------- grades

func _c(hex: String) -> Color:
	return Color(hex)


## Each row: id, purpose, sky/ground colours, sun, ambient, fog, post values, magic,
## lut (dark, mid, light hex for an embedded GradientTexture1D).
func _grade_rows() -> Array[Dictionary]:
	return [
		{"id": "grade_starlight_glen_day", "purpose": "Starlight Glen by day: lilac-blue sky, mint meadows, butter sun",
			"sky_top": "8fb4ff", "sky_horizon": "ffd6ec", "ground_horizon": "fbe3d6", "ground_bottom": "9fd6a0",
			"sun_color": "fff0d8", "sun_energy": 1.4, "ambient_color": "f7d9ff", "ambient_energy": 1.0,
			"fog_color": "fde3f4", "fog_density": 0.0022, "volumetric_density": 0.012, "volumetric_albedo": "fff0fa",
			"exposure": 1.08, "saturation": 1.38, "contrast": 0.95, "brightness": 1.06, "glow_intensity": 1.0, "glow_bloom": 0.2,
			"magic": 1.0, "lut": ["5a4a86", "e7a9cf", "fffaf2"]},
		{"id": "grade_starlight_pool_sparkle", "purpose": "Starlight Pool daytime swim: bright sun-glitter, pearly, pastel",
			"sky_top": "7fb0ff", "sky_horizon": "ffe0f2", "ground_horizon": "fff0e0", "ground_bottom": "a8e3c4",
			"sun_color": "fff6e2", "sun_energy": 1.6, "ambient_color": "e8e4ff", "ambient_energy": 1.1,
			"fog_color": "f6eaff", "fog_density": 0.0016, "volumetric_density": 0.008, "volumetric_albedo": "ffffff",
			"exposure": 1.12, "saturation": 1.4, "contrast": 0.94, "brightness": 1.08, "glow_intensity": 1.25, "glow_bloom": 0.28,
			"magic": 1.0, "lut": ["4e5a9a", "a9c8f2", "fffdf6"]},
		{"id": "grade_fells", "purpose": "Western Fells: airy periwinkle heights, cool pearl haze",
			"sky_top": "7d9cf0", "sky_horizon": "e6dcff", "ground_horizon": "e9e2f0", "ground_bottom": "9db8a8",
			"sun_color": "fff2e6", "sun_energy": 1.3, "ambient_color": "dcd8ff", "ambient_energy": 0.95,
			"fog_color": "e4e0ff", "fog_density": 0.0035, "volumetric_density": 0.016, "volumetric_albedo": "f2f0ff",
			"exposure": 1.04, "saturation": 1.22, "contrast": 0.97, "brightness": 1.03, "glow_intensity": 0.8, "glow_bloom": 0.14,
			"magic": 0.8, "lut": ["4a4e80", "a7a9e0", "fbf9ff"]},
		{"id": "grade_fae_village", "purpose": "Fae village at lantern-lit dusk: rose-gold sky, warm lanterns",
			"sky_top": "6f5fb8", "sky_horizon": "ffb38f", "ground_horizon": "f2a7a8", "ground_bottom": "6c5a7a",
			"sun_color": "ffbf8a", "sun_energy": 0.75, "ambient_color": "e0a8d8", "ambient_energy": 0.85,
			"fog_color": "f1b7c8", "fog_density": 0.003, "volumetric_density": 0.02, "volumetric_albedo": "ffd9c2",
			"exposure": 1.05, "saturation": 1.32, "contrast": 0.98, "brightness": 1.02, "glow_intensity": 1.3, "glow_bloom": 0.3,
			"magic": 1.0, "lut": ["40306a", "e2919b", "fff1d8"]},
		{"id": "grade_solstice", "purpose": "Solstice Meadow midsummer day: butter-gold, golden bloom",
			"sky_top": "86b6ff", "sky_horizon": "fff0b8", "ground_horizon": "ffe9c4", "ground_bottom": "a6d98f",
			"sun_color": "fff0c4", "sun_energy": 1.55, "ambient_color": "fff0dc", "ambient_energy": 1.05,
			"fog_color": "fff3d6", "fog_density": 0.002, "volumetric_density": 0.011, "volumetric_albedo": "fff8e8",
			"exposure": 1.1, "saturation": 1.36, "contrast": 0.95, "brightness": 1.07, "glow_intensity": 1.05, "glow_bloom": 0.22,
			"magic": 1.0, "lut": ["5d4d7a", "f2c48f", "fffbea"]},
		{"id": "grade_solstice_twilight", "purpose": "Solstice Meadow twilight: violet-peach sky, will-o'-the-wisps",
			"sky_top": "4f4aa8", "sky_horizon": "ff9fb8", "ground_horizon": "d792c4", "ground_bottom": "4f5a6e",
			"sun_color": "ffaa9a", "sun_energy": 0.45, "ambient_color": "b9a2f0", "ambient_energy": 0.8,
			"fog_color": "c8a6e6", "fog_density": 0.0035, "volumetric_density": 0.024, "volumetric_albedo": "e8d6ff",
			"exposure": 1.04, "saturation": 1.3, "contrast": 0.98, "brightness": 1.0, "glow_intensity": 1.45, "glow_bloom": 0.34,
			"magic": 1.0, "lut": ["2e2a66", "b27fc8", "ffe6f0"]},
		{"id": "grade_hill_of_the_rite_dusk", "purpose": "Hill of the Rite at dusk: deep rose sunset, ember gold",
			"sky_top": "5a4aa0", "sky_horizon": "ff8f7a", "ground_horizon": "e0838e", "ground_bottom": "4a3e58",
			"sun_color": "ff9c70", "sun_energy": 0.7, "ambient_color": "d08cb8", "ambient_energy": 0.75,
			"fog_color": "e5939e", "fog_density": 0.0032, "volumetric_density": 0.022, "volumetric_albedo": "ffc9b8",
			"exposure": 1.02, "saturation": 1.28, "contrast": 1.0, "brightness": 1.0, "glow_intensity": 1.2, "glow_bloom": 0.26,
			"magic": 0.9, "lut": ["362a58", "d97a86", "ffe2c8"]},
		{"id": "grade_rite_calanmai_night", "purpose": "Calanmai night: indigo sky, bonfire gold, heavy glow",
			"sky_top": "1e1c52", "sky_horizon": "6a3f8f", "ground_horizon": "4a2f66", "ground_bottom": "1c1828",
			"sun_color": "a9a8ff", "sun_energy": 0.25, "ambient_color": "7a62b8", "ambient_energy": 0.55,
			"fog_color": "5a3f80", "fog_density": 0.004, "volumetric_density": 0.03, "volumetric_albedo": "ffb48a",
			"exposure": 1.1, "saturation": 1.25, "contrast": 1.04, "brightness": 0.98, "glow_intensity": 1.6, "glow_bloom": 0.38,
			"magic": 1.0, "lut": ["140f30", "8a4f9c", "ffd7a0"]},
		{"id": "grade_rosewild", "purpose": "Rosewild: rose-pink haze, blush light, oversized blooms",
			"sky_top": "9aa8ff", "sky_horizon": "ffc6dc", "ground_horizon": "ffd0dc", "ground_bottom": "8fcf98",
			"sun_color": "ffe8e0", "sun_energy": 1.4, "ambient_color": "ffcfe6", "ambient_energy": 1.0,
			"fog_color": "ffcfe2", "fog_density": 0.0028, "volumetric_density": 0.016, "volumetric_albedo": "ffe2ee",
			"exposure": 1.07, "saturation": 1.42, "contrast": 0.95, "brightness": 1.05, "glow_intensity": 1.05, "glow_bloom": 0.22,
			"magic": 1.0, "lut": ["5e3a6e", "f09abc", "fff4f6"]},
		{"id": "grade_blossom_vale", "purpose": "Blossom Vale: cherry-blossom white-pink, pearl sky",
			"sky_top": "a4c0ff", "sky_horizon": "ffe4f0", "ground_horizon": "fff0f4", "ground_bottom": "a8dca8",
			"sun_color": "fff4ec", "sun_energy": 1.45, "ambient_color": "ffe6f2", "ambient_energy": 1.05,
			"fog_color": "ffeaf4", "fog_density": 0.0024, "volumetric_density": 0.013, "volumetric_albedo": "fff6fa",
			"exposure": 1.1, "saturation": 1.3, "contrast": 0.94, "brightness": 1.08, "glow_intensity": 1.0, "glow_bloom": 0.2,
			"magic": 1.0, "lut": ["5a4a80", "f1bcd6", "fffcfa"]},
		{"id": "grade_autumn_foothills", "purpose": "Autumn Foothills (sealed): amber-crimson glow, honey haze",
			"sky_top": "8a9ae8", "sky_horizon": "ffcc9a", "ground_horizon": "f2b088", "ground_bottom": "9a6a4a",
			"sun_color": "ffd2a0", "sun_energy": 1.25, "ambient_color": "ffcfb0", "ambient_energy": 0.9,
			"fog_color": "f6c8a8", "fog_density": 0.003, "volumetric_density": 0.016, "volumetric_albedo": "ffe2c8",
			"exposure": 1.05, "saturation": 1.3, "contrast": 0.98, "brightness": 1.03, "glow_intensity": 0.95, "glow_bloom": 0.18,
			"magic": 0.8, "lut": ["4a2a3a", "e08a5a", "fff0d8"]},
		{"id": "grade_blight", "purpose": "Blighted Reaches (HORROR): grey, desaturated, heavy fog, near-dark, low glow",
			"sky_top": "3e4044", "sky_horizon": "55575a", "ground_horizon": "45474a", "ground_bottom": "1c1d1f",
			"sun_color": "a8a6a0", "sun_energy": 0.4, "ambient_color": "4a4c50", "ambient_energy": 0.35,
			"fog_color": "4c4e50", "fog_density": 0.014, "volumetric_density": 0.05, "volumetric_albedo": "5a5c5e",
			"exposure": 0.82, "saturation": 0.22, "contrast": 1.18, "brightness": 0.86, "glow_intensity": 0.08, "glow_bloom": 0.0,
			"magic": 0.0, "lut": ["0c0d0e", "4e5052", "a4a5a6"]},
	]


func _tame(p: Resource, ramp: PackedColorArray) -> void:
	var identity := [Color(0, 0, 0), Color(0.5, 0.5, 0.5), Color(1, 1, 1)]
	for i in ramp.size():
		ramp[i] = (identity[i] as Color).lerp(ramp[i], LUT_STRENGTH)
	# Day skies toward the bar's #6B94FA top, golden-hour ones toward #7361D1.
	var golden := float(p.get("sun_energy")) < 1.0
	p.set("sky_top", (p.get("sky_top") as Color).lerp(Color("7361D1") if golden else Color("6B94FA"), 0.5))
	p.set("fog_density", minf(float(p.get("fog_density")), FOG_CAP))
	# Book light (Keeper, lore/08-aesthetic/tone-and-palette.md): rich, warm and
	# "thick", never glaring. Daylight has no glow but true highlights; dusk and
	# night keep a soft glow for fires and lanterns. Vibrancy is colour contrast.
	if golden:
		p.set("glow_intensity", NIGHT_GLOW)
		p.set("glow_bloom", NIGHT_BLOOM)
		p.set("glow_hdr_threshold", NIGHT_THRESHOLD)
	else:
		p.set("glow_intensity", DAY_GLOW)
		p.set("glow_bloom", 0.0)
		p.set("glow_hdr_threshold", DAY_THRESHOLD)
		p.set("magic", minf(float(p.get("magic")), DAY_MAGIC))
	p.set("volumetric_density", minf(float(p.get("volumetric_density")), VOLUMETRIC_CAP))
	p.set("contrast", CONTRAST)
	p.set("sun_energy", minf(float(p.get("sun_energy")) * SUN_GAIN, SUN_CAP))
	p.set("ambient_energy", float(p.get("ambient_energy")) * AMBIENT_SCALE)
	p.set("ambient_color", (p.get("ambient_color") as Color).lerp(LILAC_SHADOW, 0.2))
	p.set("exposure", minf(float(p.get("exposure")), EXPOSURE_CAP))
	p.set("brightness", minf(float(p.get("brightness")), BRIGHTNESS_CAP))


func _withdraw(p: Resource) -> void:
	p.set("saturation", BLIGHT_SATURATION)
	p.set("sun_energy", BLIGHT_SUN)


func _build_grades() -> int:
	var script: Script = load(GRADE_SCRIPT)
	var rows := _grade_rows()
	var md := PackedStringArray()
	md.append("# Spring Court grade presets\n")
	md.append("Generated by `world/spring_court/wider/fx/tools/build_court_fx.gd`; edit the table there, not the files.\n")
	md.append("GradePreset resources (`world/shared/grades/grade_preset.gd`) for the wider-court regions.")
	md.append("GradeDirector loads presets by id from `world/shared/grades/<id>.tres`, so the world lane copies")
	md.append("each file there unchanged (the id equals the file name). Regions then add a RegionGrade node:\n")
	md.append("```")
	md.append("RegionGrade  grade = &\"grade_rosewild\"  bounds = Rect2(-600, -800, 1100, 300)  blend_seconds = 4.0")
	md.append("```\n")
	md.append("`lut` is an embedded GradientTexture1D (dark, mid, light): a gentle pastel colour-correction ramp,")
	md.append("no image files. Recommended GradeDirector Environment for all of these: tonemap AgX, glow on")
	md.append("(hdr threshold 1.4 by day, 1.1 at dusk/night, no bloom wash by day), fog + volumetric fog on, SDFGI on, SSAO on at intensity ~0.8.")
	md.append("grade_blight is horror: keep it grey and silent, never tone it down.\n")
	md.append("| id | purpose | sky top / horizon | sun colour, energy | fog colour, density, volumetric | exposure | saturation | contrast | glow int / bloom | magic |")
	md.append("|---|---|---|---|---|---|---|---|---|---|")
	for r: Dictionary in rows:
		var p: Resource = script.new()
		p.set("id", StringName(r["id"]))
		for key: String in ["sky_top", "sky_horizon", "ground_horizon", "ground_bottom", "sun_color", "ambient_color", "fog_color", "volumetric_albedo"]:
			p.set(key, _c(r[key]))
		for key: String in ["sun_energy", "ambient_energy", "fog_density", "volumetric_density", "exposure", "saturation", "contrast", "brightness", "glow_intensity", "glow_bloom", "magic"]:
			p.set(key, float(r[key]))
		p.set("snow_cover", 0.0)
		var lut_cols: Array = r["lut"]
		var ramp := PackedColorArray([_c(lut_cols[0]), _c(lut_cols[1]), _c(lut_cols[2])])
		if r["id"] != "grade_blight":
			_tame(p, ramp)
		else:
			_withdraw(p)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = ramp
		var gt := GradientTexture1D.new()
		gt.gradient = g
		gt.width = 256
		p.set("lut", gt)
		_save(p, FX + "grades/" + String(r["id"]) + ".tres")
		md.append("| %s | %s | #%s / #%s | #%s, %.2f | #%s, %.4f, %.3f | %.2f | %.2f | %.2f | %.2f / %.2f | %.1f |" % [
			r["id"], r["purpose"], r["sky_top"], r["sky_horizon"], r["sun_color"], p.get("sun_energy"),
			r["fog_color"], p.get("fog_density"), r["volumetric_density"], p.get("exposure"), p.get("saturation"),
			p.get("contrast"), p.get("glow_intensity"), p.get("glow_bloom"), r["magic"]])
	md.append("\nSuggested region mapping: starlight_glen -> grade_starlight_glen_day (Starlight Pool area:")
	md.append("grade_starlight_pool_sparkle, a daytime swim), western_fells -> grade_fells, fae_village ->")
	md.append("grade_fae_village, solstice_meadow -> grade_solstice (story swap to grade_solstice_twilight for the")
	md.append("will-o'-the-wisps), hill_of_the_rite -> grade_hill_of_the_rite_dusk (story swap to")
	md.append("grade_rite_calanmai_night on Calanmai), rosewild -> grade_rosewild, blossom_vale ->")
	md.append("grade_blossom_vale, autumn_foothills -> grade_autumn_foothills, blighted_reaches -> grade_blight.")
	var f := FileAccess.open(FX + "grades/grades_readme.md", FileAccess.WRITE)
	f.store_string("\n".join(md) + "\n")
	f.close()
	return rows.size()


# ---------------------------------------------------------------- materials

func _mat(shader_file: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SH + shader_file)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


func _build_materials() -> int:
	var mats := {
		"mat_foliage_default": _mat("court_foliage.gdshader", {"blight": 0.0, "blight_affect": 1.0, "emission_glow": 1.5, "sparkle": 0.0}),
		"mat_foliage_glow": _mat("court_foliage.gdshader", {"blight": 0.0, "blight_affect": 1.0, "emission_glow": 4.0, "sparkle": 0.6, "rim_strength": 0.9, "translucency": 0.6}),
		"mat_foliage_blight": _mat("court_foliage.gdshader", {"blight": 1.0, "blight_affect": 0.0, "emission_glow": 0.0, "sparkle": 0.0, "rim_strength": 0.0, "translucency": 0.05, "saturation_boost": 0.3, "shade_tint": Color(0.3, 0.3, 0.32)}),
		"mat_prop_default": _mat("court_prop.gdshader", {"blight": 0.0, "blight_affect": 1.0}),
		"mat_prop_pearl": _mat("court_prop.gdshader", {"blight": 0.0, "blight_affect": 1.0, "pearl_strength": 1.0, "roughness_value": 0.25}),
		"mat_prop_glitter": _mat("court_prop.gdshader", {"blight": 0.0, "blight_affect": 1.0, "pearl_strength": 0.5, "glitter_strength": 4.0, "roughness_value": 0.3, "emission_glow": 3.5}),
		"mat_water_lake": _mat("court_water.gdshader", {"blight": 0.0, "blight_affect": 1.0}),
		"mat_water_river": _mat("court_water.gdshader", {"blight": 0.0, "blight_affect": 1.0, "flow_dir": Vector2(0.0, 1.0), "flow_speed": 0.6, "ripple_strength": 0.7, "foam_strength": 1.0, "clarity": 0.65}),
		"mat_water_starlight": _mat("court_water.gdshader", {"blight": 0.0, "blight_affect": 1.0, "starlight_mode": true, "shallow_color": Color(0.7, 0.95, 1.0), "deep_color": Color(0.62, 0.62, 1.0), "clarity": 0.75, "glitter_strength": 9.0}),
		"mat_glint": _mat("court_glint.gdshader", {"blight": 0.0, "blight_affect": 1.0}),
		"mat_terrain_tint": _mat("court_terrain_tint.gdshader", {"blight": 0.0, "blight_affect": 1.0, "vertex_color_srgb": true,
			"grass_a": Color("8DBF7A"), "grass_b": Color("B5E3C0"), "grass_c": Color("7CC29A"),
			"blossom_speck": Color("F4A6C0"), "rock_color": Color("D9CBD0")}),
		"mat_particle_lit": _mat("court_particle.gdshader", {}),
		"mat_particle_glow": _mat("court_particle_glow.gdshader", {}),
		"mat_butterfly": _mat("court_butterfly.gdshader", {}),
	}
	for id: String in mats:
		_save(mats[id], FX + "materials/" + id + ".tres")
	return mats.size()


# ---------------------------------------------------------------- particles

func _grad(cols: Array, offs: Array = []) -> GradientTexture1D:
	var g := Gradient.new()
	var o := PackedFloat32Array()
	var c := PackedColorArray()
	for i in cols.size():
		o.append(float(offs[i]) if offs.size() == cols.size() else float(i) / float(maxi(cols.size() - 1, 1)))
		c.append(cols[i] if cols[i] is Color else Color(String(cols[i])))
	g.offsets = o
	g.colors = c
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	return t


func _fade(peak: float, in_t: float, out_t: float) -> GradientTexture1D:
	return _grad([Color(1, 1, 1, 0), Color(1, 1, 1, peak), Color(1, 1, 1, peak), Color(1, 1, 1, 0)], [0.0, in_t, out_t, 1.0])


func _curve(points: Array) -> CurveTexture:
	var cv := Curve.new()
	cv.max_value = 2.0
	for p: Vector2 in points:
		cv.add_point(p)
	var t := CurveTexture.new()
	t.curve = cv
	return t


## Spec keys: amount, lifetime, box (extents) or sphere (radius), dir, spread, vel (min/max), gravity,
## ang_vel, scale, size (quad), shader ("lit" / "glow" / "butterfly"), shape (see court_fx_common),
## colors (initial ramp), fade [peak, in, out] alpha over life, tint_life (colour over life),
## turb + turb_scale, damping, one_shot, explosive, preprocess, aabb (half extents) + aabb_offset_y,
## intensity, twinkle, emission_boost, edge_tint, scale_curve, rotate_y.
func _fx_specs() -> Dictionary:
	return {
		"fx_rose_petals": {"amount": 320, "lifetime": 10.0, "box": Vector3(14, 3, 14), "dir": Vector3(1, -0.2, 0.3), "spread": 50.0,
			"vel": Vector2(0.3, 1.0), "gravity": Vector3(0, -0.22, 0), "ang_vel": Vector2(-90, 90), "scale": Vector2(0.7, 1.3), "size": 0.16,
			"shader": "lit", "shape": 2, "colors": ["ff7fa8", "ff9fbf", "ffc2d6", "f05f8f"], "turb": 1.2, "turb_scale": 6.0, "aabb": Vector3(20, 10, 20), "aabb_offset_y": -3.0},
		"fx_cherry_petals": {"amount": 400, "lifetime": 10.0, "box": Vector3(14, 3, 14), "dir": Vector3(1, -0.2, 0.3), "spread": 50.0,
			"vel": Vector2(0.3, 1.0), "gravity": Vector3(0, -0.2, 0), "ang_vel": Vector2(-120, 120), "scale": Vector2(0.6, 1.1), "size": 0.12,
			"shader": "lit", "shape": 2, "colors": ["ffe4ef", "ffd0e2", "fff6fa", "ffc0d8"], "turb": 1.3, "turb_scale": 6.0, "aabb": Vector3(20, 10, 20), "aabb_offset_y": -3.0},
		"fx_pollen_motes": {"amount": 600, "lifetime": 7.0, "box": Vector3(12, 2.5, 12), "dir": Vector3(0, 1, 0), "spread": 180.0,
			"vel": Vector2(0.02, 0.12), "gravity": Vector3(0, 0.01, 0), "scale": Vector2(0.5, 1.2), "size": 0.05,
			"shader": "glow", "shape": 0, "colors": ["fff2a8", "ffe58a", "fff8d6"], "turb": 0.6, "turb_scale": 3.0, "intensity": 3.0, "twinkle": 0.4, "aabb": Vector3(16, 6, 16)},
		"fx_faelights": {"amount": 40, "lifetime": 14.0, "box": Vector3(10, 2, 10), "dir": Vector3(0, 1, 0), "spread": 180.0,
			"vel": Vector2(0.05, 0.25), "gravity": Vector3(0, 0, 0), "scale": Vector2(0.8, 1.4), "size": 0.45,
			"shader": "glow", "shape": 0, "colors": ["b9ffe4", "e2c8ff", "b8c8ff", "ffd6ec"], "turb": 1.5, "turb_scale": 8.0, "intensity": 5.0, "twinkle": 0.15,
			"scale_curve": [Vector2(0, 0), Vector2(0.15, 1), Vector2(0.85, 1), Vector2(1, 0)], "aabb": Vector3(16, 6, 16)},
		"fx_will_o_wisps": {"amount": 18, "lifetime": 9.0, "box": Vector3(12, 1.2, 12), "dir": Vector3(1, 0.3, 0), "spread": 180.0,
			"vel": Vector2(0.4, 1.2), "gravity": Vector3(0, 0, 0), "scale": Vector2(0.8, 1.3), "size": 0.35, "damping": Vector2(0.1, 0.4),
			"shader": "glow", "shape": 0, "colors": ["a8f0ff", "c8ffe0", "e0d0ff"], "turb": 3.0, "turb_scale": 4.0, "intensity": 7.0, "twinkle": 0.5,
			"scale_curve": [Vector2(0, 0), Vector2(0.1, 1), Vector2(0.5, 0.8), Vector2(0.9, 1), Vector2(1, 0)], "aabb": Vector3(20, 6, 20), "aabb_offset_y": 1.0},
		"fx_fireflies": {"amount": 160, "lifetime": 8.0, "box": Vector3(12, 1.5, 12), "dir": Vector3(0, 1, 0), "spread": 180.0,
			"vel": Vector2(0.05, 0.3), "gravity": Vector3(0, 0, 0), "scale": Vector2(0.7, 1.1), "size": 0.07,
			"shader": "glow", "shape": 0, "colors": ["f6ff9a", "e8ffb0", "fff0a0"], "turb": 1.8, "turb_scale": 3.0, "intensity": 6.0, "twinkle": 1.0, "aabb": Vector3(16, 5, 16), "aabb_offset_y": 0.5},
		"fx_butterflies": {"amount": 24, "lifetime": 12.0, "box": Vector3(9, 1.2, 9), "dir": Vector3(1, 0.1, 0), "spread": 180.0,
			"vel": Vector2(0.4, 1.0), "gravity": Vector3(0, 0, 0), "scale": Vector2(0.8, 1.3), "size": 0.22, "rotate_y": true,
			"shader": "butterfly", "colors": ["ff8fc4", "c9a2ff", "8fd8ff", "ffe08a", "9ff0c8"], "turb": 2.0, "turb_scale": 5.0,
			"fade": [1.0, 0.05, 0.92], "aabb": Vector3(14, 5, 14), "aabb_offset_y": 0.5},
		"fx_dandelion_seeds": {"amount": 220, "lifetime": 11.0, "box": Vector3(12, 2, 12), "dir": Vector3(1, 0.4, 0.2), "spread": 40.0,
			"vel": Vector2(0.3, 0.8), "gravity": Vector3(0, 0.03, 0), "ang_vel": Vector2(-20, 20), "scale": Vector2(0.7, 1.2), "size": 0.14,
			"shader": "lit", "shape": 6, "colors": ["ffffff", "fff8f0", "f6f0ff"], "turb": 1.0, "turb_scale": 7.0, "emission_boost": 0.6, "aabb": Vector3(20, 8, 20), "aabb_offset_y": 2.0},
		"fx_sparkle_burst": {"amount": 60, "lifetime": 1.3, "sphere": 0.15, "dir": Vector3(0, 1, 0), "spread": 180.0,
			"vel": Vector2(1.5, 3.5), "gravity": Vector3(0, -2.0, 0), "ang_vel": Vector2(-180, 180), "scale": Vector2(0.6, 1.3), "size": 0.18, "damping": Vector2(1.5, 3.0),
			"shader": "glow", "shape": 1, "colors": ["ffe08a", "ffb8e0", "ffffff", "d8c0ff"], "intensity": 8.0, "twinkle": 0.6,
			"one_shot": true, "explosive": 1.0, "preprocess": 0.0, "fade": [1.0, 0.02, 0.6],
			"scale_curve": [Vector2(0, 1), Vector2(1, 0)], "aabb": Vector3(4, 4, 4)},
		"fx_starlight_sparkles": {"amount": 500, "lifetime": 1.8, "box": Vector3(9, 0.04, 9), "dir": Vector3(0, 1, 0), "spread": 0.0,
			"vel": Vector2(0.0, 0.02), "gravity": Vector3(0, 0, 0), "ang_vel": Vector2(-30, 30), "scale": Vector2(0.5, 1.4), "size": 0.16,
			"shader": "glow", "shape": 1, "colors": ["ffffff", "fff4d0", "ffe6f6", "e0ecff"], "intensity": 10.0, "twinkle": 0.7,
			"fade": [1.0, 0.25, 0.5], "scale_curve": [Vector2(0, 0), Vector2(0.4, 1), Vector2(1, 0)], "aabb": Vector3(11, 2, 11)},
		"fx_water_mist": {"amount": 90, "lifetime": 12.0, "box": Vector3(12, 0.3, 12), "dir": Vector3(1, 0.05, 0), "spread": 30.0,
			"vel": Vector2(0.05, 0.25), "gravity": Vector3(0, 0.01, 0), "ang_vel": Vector2(-8, 8), "scale": Vector2(0.8, 1.5), "size": 3.0,
			"shader": "lit", "shape": 5, "colors": ["f6f0ff", "ffeaf4", "eaf6ff"], "fade": [0.22, 0.25, 0.7], "emission_boost": 0.4, "aabb": Vector3(18, 4, 18), "aabb_offset_y": 1.0},
		"fx_bonfire_embers": {"amount": 220, "lifetime": 2.8, "box": Vector3(0.9, 0.2, 0.9), "dir": Vector3(0, 1, 0), "spread": 25.0,
			"vel": Vector2(1.5, 3.5), "gravity": Vector3(0, 0.3, 0), "scale": Vector2(0.5, 1.0), "size": 0.06, "damping": Vector2(0.2, 0.6),
			"shader": "glow", "shape": 0, "colors": ["ffd27a", "ffa860", "ff7f8f"], "turb": 1.6, "turb_scale": 2.0, "intensity": 9.0, "twinkle": 0.5,
			"fade": [1.0, 0.05, 0.6], "aabb": Vector3(4, 8, 4), "aabb_offset_y": 4.0},
		"fx_bonfire_flame": {"amount": 140, "lifetime": 1.1, "box": Vector3(0.6, 0.05, 0.6), "dir": Vector3(0, 1, 0), "spread": 10.0,
			"vel": Vector2(1.2, 2.2), "gravity": Vector3(0, 0.5, 0), "scale": Vector2(0.8, 1.3), "size": 0.9, "damping": Vector2(0.5, 1.0),
			"shader": "glow", "shape": 4, "colors": ["fff0b0", "ffd070", "ffa070"], "intensity": 3.5,
			"tint_life": ["fff6c8", "ffc060", "ff8098", "c070c0"],
			"scale_curve": [Vector2(0, 0.6), Vector2(0.3, 1), Vector2(1, 0.15)], "aabb": Vector3(2, 3, 2), "aabb_offset_y": 1.5},
		"fx_bonfire_smoke": {"amount": 60, "lifetime": 6.0, "box": Vector3(0.6, 0.1, 0.6), "dir": Vector3(0, 1, 0), "spread": 12.0,
			"vel": Vector2(0.8, 1.4), "gravity": Vector3(0.15, 0.1, 0), "ang_vel": Vector2(-15, 15), "scale": Vector2(0.8, 1.4), "size": 1.6,
			"shader": "lit", "shape": 5, "colors": ["d8c8e0", "c8bcd8", "e0d0dc"], "fade": [0.35, 0.15, 0.6], "turb": 0.6, "turb_scale": 4.0,
			"scale_curve": [Vector2(0, 0.4), Vector2(1, 2.0)], "aabb": Vector3(5, 10, 5), "aabb_offset_y": 5.0},
		"fx_autumn_leaves": {"amount": 260, "lifetime": 10.0, "box": Vector3(14, 3, 14), "dir": Vector3(1, -0.3, 0.2), "spread": 45.0,
			"vel": Vector2(0.4, 1.2), "gravity": Vector3(0, -0.35, 0), "ang_vel": Vector2(-140, 140), "scale": Vector2(0.7, 1.3), "size": 0.2,
			"shader": "lit", "shape": 7, "colors": ["c8202f", "e05a2a", "f0a030", "b8382a", "ffb84a"], "turb": 1.4, "turb_scale": 6.0, "edge_tint": 0.1, "aabb": Vector3(20, 10, 20), "aabb_offset_y": -3.0},
		"fx_blight_ash": {"amount": 500, "lifetime": 12.0, "box": Vector3(16, 4, 16), "dir": Vector3(0.3, -1, 0.1), "spread": 30.0,
			"vel": Vector2(0.1, 0.4), "gravity": Vector3(0, -0.12, 0), "ang_vel": Vector2(-60, 60), "scale": Vector2(0.6, 1.4), "size": 0.08,
			"shader": "lit", "shape": 3, "colors": ["3a3b3d", "4a4b4d", "2a2b2c", "5a5a5a"], "turb": 0.5, "turb_scale": 8.0, "emission_boost": 0.0, "edge_tint": 0.0,
			"fade": [0.85, 0.15, 0.8], "aabb": Vector3(22, 12, 22), "aabb_offset_y": -3.0},
		"fx_lantern_glow_motes": {"amount": 80, "lifetime": 6.0, "sphere": 1.2, "dir": Vector3(0, 1, 0), "spread": 180.0,
			"vel": Vector2(0.03, 0.15), "gravity": Vector3(0, 0.04, 0), "scale": Vector2(0.6, 1.2), "size": 0.06,
			"shader": "glow", "shape": 0, "colors": ["ffd890", "ffc0a0", "fff0c0"], "turb": 0.8, "turb_scale": 2.0, "intensity": 6.0, "twinkle": 0.35, "aabb": Vector3(3, 3, 3)},
	}


func _build_particles() -> int:
	var specs := _fx_specs()
	for id: String in specs:
		var s: Dictionary = specs[id]
		var pm := ParticleProcessMaterial.new()
		if s.has("sphere"):
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = float(s["sphere"])
		else:
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = s["box"]
		pm.direction = s["dir"]
		pm.spread = float(s["spread"])
		var vel: Vector2 = s["vel"]
		pm.initial_velocity_min = vel.x
		pm.initial_velocity_max = vel.y
		pm.gravity = s["gravity"]
		if s.has("ang_vel"):
			var av: Vector2 = s["ang_vel"]
			pm.angular_velocity_min = av.x
			pm.angular_velocity_max = av.y
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		var sc: Vector2 = s["scale"]
		pm.scale_min = sc.x
		pm.scale_max = sc.y
		if s.has("damping"):
			var dm: Vector2 = s["damping"]
			pm.damping_min = dm.x
			pm.damping_max = dm.y
		if s.has("turb"):
			pm.turbulence_enabled = true
			pm.turbulence_noise_strength = float(s["turb"])
			pm.turbulence_noise_scale = float(s["turb_scale"])
			pm.turbulence_influence_min = 0.05
			pm.turbulence_influence_max = 0.15
		pm.color_initial_ramp = _grad(s["colors"])
		if s.has("tint_life"):
			# Flame: colour over life (butter core -> gold -> rose -> lilac), fading out at the end.
			var tl: Array = s["tint_life"]
			var tc: Array = []
			for i in tl.size():
				var c := Color(String(tl[i]))
				c.a = 1.0 if i < tl.size() - 1 else 0.0
				tc.append(c)
			pm.color_ramp = _grad(tc)
		else:
			var fd: Array = s.get("fade", [1.0, 0.15, 0.75])
			pm.color_ramp = _fade(float(fd[0]), float(fd[1]), float(fd[2]))
		if s.has("scale_curve"):
			pm.scale_curve = _curve(s["scale_curve"])
		if s.get("rotate_y", false):
			pm.particle_flag_rotate_y = true

		var quad := QuadMesh.new()
		var sz := float(s["size"])
		quad.size = Vector2(sz, sz)
		var mat := ShaderMaterial.new()
		match String(s["shader"]):
			"glow":
				mat.shader = load(SH + "court_particle_glow.gdshader")
				mat.set_shader_parameter("shape", int(s.get("shape", 0)))
				mat.set_shader_parameter("intensity", float(s.get("intensity", 4.0)))
				mat.set_shader_parameter("twinkle", float(s.get("twinkle", 0.0)))
			"butterfly":
				mat.shader = load(SH + "court_butterfly.gdshader")
				quad.orientation = PlaneMesh.FACE_Y
				quad.subdivide_width = 2
			_:
				mat.shader = load(SH + "court_particle.gdshader")
				mat.set_shader_parameter("shape", int(s.get("shape", 2)))
				mat.set_shader_parameter("emission_boost", float(s.get("emission_boost", 0.25)))
				mat.set_shader_parameter("edge_tint", float(s.get("edge_tint", 0.25)))
		quad.material = mat

		var p := GPUParticles3D.new()
		p.name = id.to_pascal_case()
		p.amount = int(s["amount"])
		p.lifetime = float(s["lifetime"])
		p.one_shot = bool(s.get("one_shot", false))
		p.explosiveness = float(s.get("explosive", 0.0))
		p.randomness = 0.3
		p.preprocess = float(s.get("preprocess", float(s["lifetime"])))
		p.local_coords = false
		p.emitting = true
		p.process_material = pm
		p.draw_pass_1 = quad
		var he: Vector3 = s["aabb"]
		var oy := float(s.get("aabb_offset_y", 0.0))
		p.visibility_aabb = AABB(Vector3(-he.x, -he.y + oy, -he.z), he * 2.0)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.set_meta(&"court_fx_id", id)
		var packed := PackedScene.new()
		packed.pack(p)
		_save(packed, FX + "particles/" + id + ".tscn")
		p.free()

	# Collectible glint: a tiny billboard quad with mat_glint (place it at a collectible).
	var gm := MeshInstance3D.new()
	gm.name = "FxCollectibleGlint"
	var gq := QuadMesh.new()
	gq.size = Vector2(0.35, 0.35)
	gm.mesh = gq
	gm.material_override = load(FX + "materials/mat_glint.tres")
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gm.custom_aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))
	var gp := PackedScene.new()
	gp.pack(gm)
	_save(gp, FX + "particles/fx_collectible_glint.tscn")
	gm.free()
	return specs.size() + 1


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("court_fx: failed to save %s (%d)" % [path, err])

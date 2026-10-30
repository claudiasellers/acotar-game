## A colour grade: sky, sun, fog, bloom and LUT for one mood of the world
## (human_winter, spring, blight, ...). GradeDirector blends between them.
## Region lanes pick a preset per region with a RegionGrade node.
class_name GradePreset
extends Resource

@export var id: StringName
@export_group("Sky")
@export var sky_top := Color(0.55, 0.62, 0.72)
@export var sky_horizon := Color(0.78, 0.8, 0.84)
@export var ground_horizon := Color(0.62, 0.64, 0.68)
@export var ground_bottom := Color(0.3, 0.32, 0.36)
@export_group("Sun and ambient")
@export var sun_color := Color(0.92, 0.94, 1.0)
@export var sun_energy := 0.9
@export var ambient_color := Color(0.6, 0.66, 0.75)
@export var ambient_energy := 0.6
@export_group("Fog")
@export var fog_color := Color(0.75, 0.78, 0.83)
@export var fog_density := 0.004
@export var volumetric_density := 0.01
@export var volumetric_albedo := Color(0.9, 0.92, 0.96)
@export_group("Post")
@export var exposure := 1.0
@export var saturation := 1.0
@export var contrast := 1.0
@export var brightness := 1.0
@export var glow_intensity := 0.4
@export var glow_bloom := 0.05
## The per-region LUT slot (Texture3D or a 1D gradient). Swapped at mid-blend.
@export var lut: Texture
@export_group("Shader globals")
## 1 = everything snow-capped (human winter), 0 = none.
@export_range(0.0, 1.0) var snow_cover := 0.0
## Sparkle, glints and bloom tint on stylized materials (Spring Court magic).
@export_range(0.0, 1.0) var magic := 0.0


const _FLOATS := [&"sun_energy", &"ambient_energy", &"fog_density", &"volumetric_density", &"exposure",
	&"saturation", &"contrast", &"brightness", &"glow_intensity", &"glow_bloom", &"snow_cover", &"magic"]
const _COLORS := [&"sky_top", &"sky_horizon", &"ground_horizon", &"ground_bottom", &"sun_color",
	&"ambient_color", &"fog_color", &"volumetric_albedo"]


## A new preset `t` of the way from `a` to `b`. The LUT switches at t = 0.5.
static func mix(a: GradePreset, b: GradePreset, t: float) -> GradePreset:
	var out := GradePreset.new()
	out.id = b.id if t >= 0.5 else a.id
	for f in _FLOATS:
		out.set(f, lerpf(a.get(f), b.get(f), t))
	for c in _COLORS:
		out.set(c, (a.get(c) as Color).lerp(b.get(c), t))
	out.lut = b.lut if t >= 0.5 else a.lut
	return out

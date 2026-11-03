## One preset's colour grade as numbers (render program T3b). The 32³
## colour-correction LUT is built from these at load and cached; nothing is
## baked to disk (R15). Every value is listed in docs/tuning.md.
## The LUT takes the tonemapped display (sRGB) value and applies, in order:
##   1. the preset's pre-T3b grade, folded in so the look is unchanged:
##      brightness (on linear light), contrast and saturation (on sRGB, even
##      weights), exactly Godot 4.7's adjustment maths, then the old 1D
##      per-channel curve
##   2. lift / gamma / gain per channel
##   3. hue shift around the grey axis
##   4. saturation curve: shadow and highlight saturation, blended by luma
## 2 to 4 ship as identity; the owner tunes them.
class_name LutParams
extends Resource

const SIZE := 32

@export_group("Folded (pre-T3b grade)")
@export var brightness := 1.0
@export var contrast := 1.0
@export var saturation := 1.0
## The old 1D colour correction, sampled per channel (null = none).
@export var curve: Gradient
@export_group("Lift gamma gain")
@export var lift := Color(0.0, 0.0, 0.0)
@export var gamma := Color(1.0, 1.0, 1.0)
@export var gain := Color(1.0, 1.0, 1.0)
@export_group("Hue and saturation")
@export_range(-180.0, 180.0) var hue_shift := 0.0
@export_range(0.0, 2.0) var shadow_saturation := 1.0
@export_range(0.0, 2.0) var highlight_saturation := 1.0

## Texture3D per distinct parameter set (main thread only).
static var _cache := {}


## The LUT for these numbers, built once per distinct set: ~60-130 ms in one go
## if nobody built it ahead (GradeDirector builds a swap's target a slice per
## frame with build_slice() and store()).
func texture() -> ImageTexture3D:
	var key := _key()
	if not _cache.has(key):
		store(build_slices())
	return _cache[key]


## True once texture() costs nothing.
func is_built() -> bool:
	return _cache.has(_key())


## Makes `slices` (all SIZE of them, from build_slice) this set's texture.
func store(slices: Array[Image]) -> void:
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBAH, SIZE, SIZE, SIZE, false, slices)
	_cache[_key()] = tex


## The LUT's SIZE slices (blue = slice, red = x, green = y).
func build_slices() -> Array[Image]:
	var slices: Array[Image] = []
	for b in SIZE:
		slices.append(build_slice(b))
	return slices


## Slice `b` (blue = texel_input(b)).
func build_slice(b: int) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBAH)
	for g in SIZE:
		for r in SIZE:
			img.set_pixel(r, g, apply(Color(texel_input(r), texel_input(g), texel_input(b))))
	return img


## The input a texel stands for. Godot samples the LUT at the raw colour with
## no half-texel offset, so interior texels hold their texel centres (exact
## mid-tones) and the end texels hold 0 and 1 (exact black and white).
static func texel_input(i: int) -> float:
	if i <= 0:
		return 0.0
	if i >= SIZE - 1:
		return 1.0
	return (i + 0.5) / SIZE


## The grade applied to one display colour (0..1 per channel).
func apply(c: Color) -> Color:
	var v := Vector3(c.r, c.g, c.b)
	# 1. Godot 4.7 adjustment maths (tonemap.glsl), then the old curve.
	if not is_equal_approx(brightness, 1.0):
		v = _to_srgb(_to_linear(v) * brightness)
	v = (v - Vector3(0.5, 0.5, 0.5)) * contrast + Vector3(0.5, 0.5, 0.5)
	var avg := (v.x + v.y + v.z) / 3.0
	v = Vector3(avg, avg, avg).lerp(v, saturation)
	v = v.clamp(Vector3.ZERO, Vector3.ONE)
	if curve != null:
		v = Vector3(curve.sample(v.x).r, curve.sample(v.y).g, curve.sample(v.z).b)
	# 2. Lift, gamma, gain.
	v = Vector3(_lgg(v.x, lift.r, gamma.r, gain.r), _lgg(v.y, lift.g, gamma.g, gain.g), _lgg(v.z, lift.b, gamma.b, gain.b))
	# 3. Hue shift: rotate about the grey axis (Rodrigues).
	if not is_zero_approx(hue_shift):
		var k := Vector3.ONE.normalized()
		var a := deg_to_rad(hue_shift)
		v = v * cos(a) + k.cross(v) * sin(a) + k * k.dot(v) * (1.0 - cos(a))
	# 4. Saturation curve.
	if not (is_equal_approx(shadow_saturation, 1.0) and is_equal_approx(highlight_saturation, 1.0)):
		var luma := 0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z
		var s := lerpf(shadow_saturation, highlight_saturation, smoothstep(0.0, 1.0, luma))
		v = Vector3(luma, luma, luma).lerp(v, s)
	v = v.clamp(Vector3.ZERO, Vector3.ONE)
	return Color(v.x, v.y, v.z)


## True when every tunable (steps 2 to 4) is at identity.
func is_identity_look() -> bool:
	return lift == Color(0.0, 0.0, 0.0) and gamma == Color(1.0, 1.0, 1.0) and gain == Color(1.0, 1.0, 1.0) \
		and is_zero_approx(hue_shift) and is_equal_approx(shadow_saturation, 1.0) \
		and is_equal_approx(highlight_saturation, 1.0)


static func _lgg(x: float, l: float, g: float, gn: float) -> float:
	var y := gn * (x + l * (1.0 - x))
	return pow(maxf(y, 0.0), 1.0 / maxf(g, 0.01))


static func _to_linear(v: Vector3) -> Vector3:
	return Vector3(_lin(v.x), _lin(v.y), _lin(v.z))


static func _to_srgb(v: Vector3) -> Vector3:
	return Vector3(_srgb(v.x), _srgb(v.y), _srgb(v.z))


static func _lin(x: float) -> float:
	return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)


static func _srgb(x: float) -> float:
	x = maxf(x, 0.0)
	return x * 12.92 if x <= 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055


func _key() -> String:
	var pts := ""
	if curve != null:
		pts = "%s|%s" % [curve.offsets, curve.colors]
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [brightness, contrast, saturation, lift, gamma, gain,
		hue_shift, shadow_saturation, highlight_saturation, pts, curve.interpolation_mode if curve else -1]

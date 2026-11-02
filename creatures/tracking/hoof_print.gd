## A cloven hoof print pressed into snow, as a Decal: it projects onto
## whatever ground is under it (terrain LOD, drifts, snow cover), so a print
## is never buried by a mesh that sits a few centimetres off. Two dark,
## deep lobes, a packed lighter rim with a little snow kicked out past the
## toe, and an icy, wet sheen on the packed rim that catches the light (R3,
## through specular only: no emission, nothing that reads as a marker).
##
## Shared by the creatures' own trails (TrackLayer) and the Act I doe line.
class_name HoofPrint
extends RefCounted

## Snow is ~0.9; the lobes sit well under half of that, in shadow blue.
const DEEP := Color(0.16, 0.2, 0.31)
const RIM := Color(0.74, 0.8, 0.9)
## Roughness of loose snow and of the packed, icy rim.
const ROUGH_SNOW := 0.9
const ROUGH_ICE := 0.12
const RES := Vector2i(64, 96)

static var _albedo: ImageTexture
static var _normal: ImageTexture
static var _orm: ImageTexture


## A print decal `length` metres long, its toe pointing along local -Z.
## `fade_from`: distance where it starts to fade out (0 keeps it always on).
static func make(length: float = 0.24, fade_from: float = 45.0) -> Decal:
	_ensure()
	var d := Decal.new()
	# Shallow box: it paints the snow it sits on, not a log or rock beside it.
	d.size = Vector3(length * 0.66, 0.3, length * 1.25)
	d.texture_albedo = _albedo
	d.texture_normal = _normal
	d.texture_orm = _orm
	d.normal_fade = 0.5
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 1
	if fade_from > 0.0:
		d.distance_fade_enabled = true
		d.distance_fade_begin = fade_from
		d.distance_fade_length = 12.0
	return d


## How deep (0 to 1) the print is at texture uv in [-1, 1]: two lobes
## split down the middle, pointed at the toe (v < 0).
static func depth(u: float, v: float) -> float:
	var d := 0.0
	for side: float in [-1.0, 1.0]:
		var cu: float = (u - side * 0.42) / 0.5
		var cv: float = v / 0.92
		# Narrower toward the toe: a teardrop, not an oval.
		cu /= clampf(0.55 + 0.45 * (cv + 1.0) * 0.5 + 0.2, 0.4, 1.0)
		var r: float = cu * cu + cv * cv
		d = maxf(d, 1.0 - smoothstep(0.55, 1.0, r))
	# The split between the toes.
	d *= smoothstep(0.03, 0.12, absf(u))
	return d


static func _ensure() -> void:
	if _albedo:
		return
	var w := RES.x
	var h := RES.y
	var height := PackedFloat32Array()
	height.resize(w * h)
	var col := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var orm := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in h:
		for x in w:
			var u := (x - w * 0.5) / (w * 0.5)
			# The texture is 1.25x the print's length: the extra is the kick.
			var v := (y - h * 0.5) / (h * 0.5) * 1.25
			var dd := depth(u, v)
			height[y * w + x] = dd
			# The rim: snow pushed up and packed just outside the lobes.
			var rim := clampf(depth(u * 0.86, v * 0.88) - dd, 0.0, 1.0)
			# Snow kicked out past the toe: a few loose clots, brighter than the drift.
			var kick := 0.0
			if v < -0.95 and v > -1.25 and absf(u) < 0.7 and rng.randf() < 0.18:
				kick = rng.randf_range(0.4, 0.7)
			var c := DEEP.lerp(RIM, 1.0 - dd)
			if kick > 0.0:
				c = RIM.lightened(0.15)
			var a := clampf(dd * 1.15 + rim * 0.6 + kick, 0.0, 0.95)
			col.set_pixel(x, y, Color(c.r, c.g, c.b, a))
			# Icy sheen: the packed rim and the wet floor of the slot are smooth.
			var ice := rim > 0.2 and rng.randf() < 0.35
			var rough := ROUGH_ICE if ice else lerpf(ROUGH_SNOW, 0.45, dd)
			orm.set_pixel(x, y, Color(1.0, rough, 0.0))
	var nrm := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var l := height[y * w + clampi(x - 1, 0, w - 1)]
			var r := height[y * w + clampi(x + 1, 0, w - 1)]
			var t := height[clampi(y - 1, 0, h - 1) * w + x]
			var b := height[clampi(y + 1, 0, h - 1) * w + x]
			# A dent: the walls face inward.
			var n := Vector3((r - l) * 2.5, (b - t) * 2.5, 1.0).normalized()
			nrm.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	col.generate_mipmaps()
	nrm.generate_mipmaps()
	orm.generate_mipmaps()
	_albedo = ImageTexture.create_from_image(col)
	_normal = ImageTexture.create_from_image(nrm)
	_orm = ImageTexture.create_from_image(orm)

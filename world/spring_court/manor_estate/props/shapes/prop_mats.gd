## Materials for procedural props (R3 princess look): glossy pearl, gold accents,
## candy colours, glowing candle flames and faelights. All cached and shared.
class_name PropMats
extends RefCounted

const FLAME := Color(1.0, 0.80, 0.55)
const PLUM := Color(0.48, 0.26, 0.44)
const BERRY := Color(0.80, 0.25, 0.45)
const TEAL := Color(0.36, 0.70, 0.72)
const SKY := Color(0.62, 0.82, 1.0)
const COPPER := Color(0.93, 0.58, 0.40)
const LEAF := Color(0.42, 0.74, 0.40)
const STRAW := Color(1.0, 0.88, 0.55)
const STEEL := Color(0.62, 0.60, 0.80)          # lilac steel, never grey
const IRON := Color(0.45, 0.40, 0.52)
const BOOKS := [Color(0.98, 0.55, 0.70), Color(0.80, 0.68, 0.96), Color(0.66, 0.93, 0.80),
		Color(0.67, 0.72, 1.0), Color(1.0, 0.92, 0.58), Color(0.48, 0.26, 0.44),
		Color(0.80, 0.25, 0.45), Color(0.36, 0.70, 0.72), Color(0.58, 0.36, 0.30)]

static var _cache: Dictionary = {}


static func gold() -> StandardMaterial3D:
	return EstateKit.mat(EstateKit.GOLD, 0.22, 0.9, "prop|gold")


static func pearl(c: Color = EstateKit.PEARL) -> StandardMaterial3D:
	return EstateKit.pearl(c)


static func gloss(c: Color) -> StandardMaterial3D:
	return EstateKit.mat(c, 0.28)


static func satin(c: Color) -> StandardMaterial3D:
	return EstateKit.mat(c, 0.55)


static func fabric(c: Color) -> StandardMaterial3D:
	return EstateKit.mat(c, 0.9)


static func wood(c: Color) -> StandardMaterial3D:
	return EstateKit.mat(c, 0.6)


static func metal(c: Color) -> StandardMaterial3D:
	return EstateKit.mat(c, 0.3, 0.75)


## The natural material for a catalogue colour: gold stays metallic gold, near-white
## goes pearlescent, everything else glossy satin.
static func body(c: Color) -> StandardMaterial3D:
	if absf(c.r - EstateKit.GOLD.r) < 0.02 and absf(c.g - EstateKit.GOLD.g) < 0.02 and absf(c.b - EstateKit.GOLD.b) < 0.02:
		return gold()
	if c.s < 0.1 and c.v > 0.9:
		return pearl(c)
	if c.a < 0.99:
		return EstateKit.mat(c, 0.08)
	return satin(c)


static func glow(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var k := "glow|%s|%.1f" % [c.to_html(), energy]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_cache[k] = m
	return m


static func flame() -> StandardMaterial3D:
	return glow(FLAME, 3.0)


static func glass(c: Color = Color(0.92, 0.96, 1.0, 0.3)) -> StandardMaterial3D:
	var k := "glass|" + c.to_html()
	if _cache.has(k):
		return _cache[k]
	var m := EstateKit.mat(c, 0.05, 0.0, k + "|b").duplicate() as StandardMaterial3D
	m.rim_enabled = true
	m.rim = 0.5
	_cache[k] = m
	return m


static func crystal() -> StandardMaterial3D:
	var k := "crystal"
	if _cache.has(k):
		return _cache[k]
	var m := glass(Color(0.96, 0.88, 1.0, 0.6)).duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.95)
	m.emission_energy_multiplier = 0.35
	_cache[k] = m
	return m


static func water() -> StandardMaterial3D:
	return EstateKit.mat(EstateKit.WATER, 0.04, 0.0, "prop|water")


static func mirror() -> StandardMaterial3D:
	return EstateKit.mat(Color(0.94, 0.90, 0.97), 0.04, 1.0, "prop|mirror")


static func book(i: int) -> StandardMaterial3D:
	return satin(BOOKS[posmod(i, BOOKS.size())])

## Flammable ground for one region (T5): its dry grass, reeds and hay scatter
## folded into a STEP-metre grid, so a fire arrow in a meadow finds fuel and a
## fire runs through the grass and stops at paths, water and bare ground.
## Grass clumps stand 2-4 m apart, the meadow between them is the terrain's
## grass, so a square counts as grassy when a clump is in it or next to it.
## Plain data: built off the main thread from copies of the layers' instance
## arrays, then read by ElementField, which turns squares into burnable cells
## only where fire or water arrives (a meadow is ~100k squares; a fire touches
## a few hundred).
class_name GroundFuel
extends RefCounted

const STEP := 2.0
const NONE := 0
const GRASS := 1
const HAY := 2
const MATERIALS: Array[StringName] = [&"", &"grass", &"hay"]
## Layer ids that are fuel. Forageables never are (rule 3: they react only in
## a pot), and neither are trees, ferns or flowers (green, not dry).
const GRASS_WORDS := ["grass", "reed", "bulrush", "cattail", "sedge", "bracken", "tuft"]
const HAY_WORDS := ["hay", "straw"]

var region_id: StringName
## Grid key of the first square, and the grid's size in squares.
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var material := PackedByteArray()
var height := PackedFloat32Array()


## Fuel code for a layer: GRASS, HAY or NONE.
static func code_for(layer: ScatterLayer) -> int:
	if layer == null or layer.ingredient_id != &"" or layer.tags.has("tree"):
		return NONE
	var s := String(layer.id)
	for w: String in HAY_WORDS:
		if s.contains(w):
			return HAY
	for w: String in GRASS_WORDS:
		if s.contains(w):
			return GRASS
	return NONE


## The fuel layers of `layers` as [[code, instances], ...]. The packed arrays
## are copies, so build() can read them on any thread.
static func pick(layers: Array) -> Array:
	var out := []
	for layer in layers:
		var code := code_for(layer as ScatterLayer)
		if code != NONE and (layer as ScatterLayer).count() > 0:
			out.append([code, (layer as ScatterLayer).instances.duplicate()])
	return out


static func key_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / STEP), floori(pos.z / STEP))


## Pure and thread-safe. Hay wins a square over grass; empty squares next to
## a clump become grass at the clump's height.
static func build(id: StringName, picked: Array) -> GroundFuel:
	var fuel := GroundFuel.new()
	fuel.region_id = id
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for entry: Array in picked:
		var inst: PackedFloat32Array = entry[1]
		for o in range(0, inst.size(), ScatterLayer.STRIDE):
			var k := Vector2i(floori(inst[o] / STEP), floori(inst[o + 2] / STEP))
			lo = lo.min(k)
			hi = hi.max(k)
	if lo.x > hi.x:
		return fuel
	fuel.origin = lo - Vector2i.ONE
	fuel.size = hi - lo + Vector2i(3, 3)
	var n := fuel.size.x * fuel.size.y
	var count := PackedInt32Array()
	count.resize(n)
	var ysum := PackedFloat32Array()
	ysum.resize(n)
	fuel.material.resize(n)
	fuel.height.resize(n)
	for entry: Array in picked:
		var code: int = entry[0]
		var inst: PackedFloat32Array = entry[1]
		for o in range(0, inst.size(), ScatterLayer.STRIDE):
			var i := fuel._index(Vector2i(floori(inst[o] / STEP), floori(inst[o + 2] / STEP)))
			count[i] += 1
			ysum[i] += inst[o + 1]
			fuel.material[i] = maxi(fuel.material[i], code)
	var own := PackedInt32Array()
	for i in n:
		if count[i] > 0:
			fuel.height[i] = ysum[i] / count[i]
			own.append(i)
	var w := fuel.size.x
	for i in own:
		for d: int in [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]:
			var j := i + d
			if count[j] == 0 and fuel.material[j] == NONE:
				fuel.material[j] = GRASS
				fuel.height[j] = fuel.height[i]
	return fuel


## Fuel code of the square at grid key `k` (NONE outside the grid).
func at(k: Vector2i) -> int:
	var i := _index(k)
	return fuel_code(i)


func fuel_code(i: int) -> int:
	return material[i] if i >= 0 else NONE


## Ground height of the square at `k` (mean of its clumps).
func height_at(k: Vector2i) -> float:
	var i := _index(k)
	return height[i] if i >= 0 else 0.0


## Squares that hold fuel.
func square_count() -> int:
	return material.size() - material.count(NONE)


func _index(k: Vector2i) -> int:
	var x := k.x - origin.x
	var z := k.y - origin.y
	if x < 0 or z < 0 or x >= size.x or z >= size.y:
		return -1
	return z * size.x + x

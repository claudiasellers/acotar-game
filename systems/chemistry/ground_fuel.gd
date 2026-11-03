## Flammable ground for one region (T5): its dry grass, reeds and hay scatter
## folded into a STEP-metre grid, so a fire arrow in a meadow finds fuel and a
## fire runs through the grass and stops at paths, water and bare ground.
## Grass clumps stand 2-4 m apart, the meadow between them is the terrain's
## grass, so a square counts as grassy when a clump is in it or next to it.
## Plain data: built off the main thread from copies of the layers' instance
## arrays (never a mesh, a gltf or CourtAssets: the loader can need the main
## thread while it waits on a worker), then read by ElementField, which turns
## squares into burnable cells only where fire or water arrives (a meadow is
## ~100k squares; a fire touches a few hundred).
## Each square also lists its clumps (layer entry, instance, place in its
## chunk's MultiMesh), so a burnt square can hide them (GroundScorch).
## Story anchors keep their clearings: no fuel within CLEAR_RADIUS (the
## Calanmai fires, CLEAR_RADIUS_FIRES) of one, so no fire reaches a scene.
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
const CLEAR_RADIUS := 12.0
const CLEAR_RADIUS_FIRES := 25.0
const FIRES_WORDS := ["calanmai", "rite", "bonfire"]

var region_id: StringName
## Grid key of the first square, and the grid's size in squares.
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var material := PackedByteArray()
var height := PackedFloat32Array()
## Clumps per square: square i holds refs clump_start[i] .. clump_start[i + 1] - 1;
## each ref is an entry (index into `refs`), an instance and its place in its chunk.
var clump_start := PackedInt32Array()
var clump_entry := PackedInt32Array()
var clump_index := PackedInt32Array()
var clump_slot := PackedInt32Array()
## Main thread only, set after build: per entry [ScatterField WeakRef, ScatterLayer].
var refs: Array = []


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


## The fuel layers of `fields` (ScatterFields): {"data": [[code, instances,
## chunk size], ...] for build() on any thread (the arrays are copies), "refs":
## [[field WeakRef, layer], ...] for the main thread}.
static func pick(fields: Array) -> Dictionary:
	var data := []
	var picked_refs := []
	for f in fields:
		var field := f as ScatterField
		for layer in field.layers:
			var code := code_for(layer)
			if code != NONE and layer.count() > 0:
				data.append([code, layer.instances.duplicate(), field.chunk_size])
				picked_refs.append([weakref(field), layer])
	return {"data": data, "refs": picked_refs}


## The story anchors under a region root as clearings [Vector3(x, z, radius)].
static func clearings(root: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not root.is_inside_tree():
		return out
	for n in root.get_tree().get_nodes_in_group(&"story_anchor"):
		var m := n as Node3D
		if m == null or not root.is_ancestor_of(m):
			continue
		var id := String(m.get_meta(&"anchor_id", m.name))
		var r := CLEAR_RADIUS
		for w: String in FIRES_WORDS:
			if id.contains(w):
				r = CLEAR_RADIUS_FIRES
		r = maxf(r, float(m.get_meta(&"radius", 0.0)))
		out.append(Vector3(m.global_position.x, m.global_position.z, r))
	return out


static func key_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / STEP), floori(pos.z / STEP))


## Pure and thread-safe. Hay wins a square over grass; empty squares next to
## a clump become grass at the clump's height.
static func build(id: StringName, picked: Array, clear: Array[Vector3] = []) -> GroundFuel:
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
	# Each clump's square and its place in its chunk (chunks list instances in order).
	var square_of := []
	var slot_of := []
	for entry: Array in picked:
		var code: int = entry[0]
		var inst: PackedFloat32Array = entry[1]
		var chunk: float = entry[2]
		var squares := PackedInt32Array()
		var slots := PackedInt32Array()
		var next_slot := {}
		for o in range(0, inst.size(), ScatterLayer.STRIDE):
			var ck := Vector2i(floori(inst[o] / chunk), floori(inst[o + 2] / chunk))
			var slot: int = next_slot.get(ck, 0)
			next_slot[ck] = slot + 1
			slots.append(slot)
			var i := fuel._index(Vector2i(floori(inst[o] / STEP), floori(inst[o + 2] / STEP)))
			if _cleared(clear, inst[o], inst[o + 2]):
				squares.append(-1)
				continue
			squares.append(i)
			count[i] += 1
			ysum[i] += inst[o + 1]
			fuel.material[i] = maxi(fuel.material[i], code)
		square_of.append(squares)
		slot_of.append(slots)
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
	if not clear.is_empty():
		for i in n:
			if fuel.material[i] != NONE:
				var c := (Vector2(i % w, i / w) + Vector2(fuel.origin) + Vector2(0.5, 0.5)) * STEP
				if _cleared(clear, c.x, c.y):
					fuel.material[i] = NONE
	# Clump lists per square (counting sort).
	fuel.clump_start.resize(n + 1)
	for i in n:
		fuel.clump_start[i + 1] = fuel.clump_start[i] + count[i]
	var fill := fuel.clump_start.duplicate()
	var total := fuel.clump_start[n]
	fuel.clump_entry.resize(total)
	fuel.clump_index.resize(total)
	fuel.clump_slot.resize(total)
	for e in square_of.size():
		var squares: PackedInt32Array = square_of[e]
		var slots: PackedInt32Array = slot_of[e]
		for k in squares.size():
			var i := squares[k]
			if i < 0:
				continue
			var at := fill[i]
			fill[i] = at + 1
			fuel.clump_entry[at] = e
			fuel.clump_index[at] = k
			fuel.clump_slot[at] = slots[k]
	return fuel


static func _cleared(clear: Array[Vector3], x: float, z: float) -> bool:
	for c in clear:
		if Vector2(x - c.x, z - c.y).length_squared() < c.z * c.z:
			return true
	return false


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


## The clumps standing in square `k`: [[ScatterField, ScatterLayer, instance, slot], ...]
## (fields that have gone are left out). Main thread.
func clumps_at(k: Vector2i) -> Array:
	var out := []
	var i := _index(k)
	if i < 0 or clump_start.is_empty():
		return out
	for at in range(clump_start[i], clump_start[i + 1]):
		var ref: Array = refs[clump_entry[at]]
		var field := (ref[0] as WeakRef).get_ref() as ScatterField
		if field:
			out.append([field, ref[1], clump_index[at], clump_slot[at]])
	return out


## Squares that hold fuel.
func square_count() -> int:
	return material.size() - material.count(NONE)


func _index(k: Vector2i) -> int:
	var x := k.x - origin.x
	var z := k.y - origin.y
	if x < 0 or z < 0 or x >= size.x or z >= size.y:
		return -1
	return z * size.x + x

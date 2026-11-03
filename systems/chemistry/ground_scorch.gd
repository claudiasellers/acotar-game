## What a ground fire leaves (T5): the grass clumps of a burnt square drop out
## of their scatter MultiMesh (collapsed to nothing, and the far impostor with
## them) and a dark ash scorch with grey flecks lies on the ground. Scorches
## are pooled Decals (at most MAX_DECALS; one covers a few squares) and fade
## over ElementField.REGROW_HOURS in-game hours, when the grass grows back.
## Clumps come back on regrow, or when their region streams out.
class_name GroundScorch
extends Node3D

const MAX_DECALS := 64
## A new scorch only where no live one is nearer than this (m).
const DECAL_SPACING := 3.0
const DECAL_SIZE := Vector3(5.0, 3.0, 5.0)

## square Vector2i -> Array of [chunk WeakRef, far WeakRef, slot, transform]
var _hidden: Dictionary = {}
var _region_of: Dictionary = {}  # square -> region id
var _decals: Array[Decal] = []
var _born: Dictionary = {}  # Decal -> in-game hour it last scorched
static var _ash: ImageTexture


## A square burnt at in-game hour `hours`: hide its clumps, scorch the ground.
func burn(region_id: StringName, fuel: GroundFuel, key: Vector2i, at: Vector3, hours: float) -> void:
	if _hidden.has(key):
		return
	var hidden := []
	for c: Array in fuel.clumps_at(key):
		var field := c[0] as ScatterField
		var layer := c[1] as ScatterLayer
		var i: int = c[2]
		var slot: int = c[3]
		var ck := field.chunk_key(layer.position_of(i))
		var chunk_name := "%s_%d_%d" % [layer.id, ck.x, ck.y]
		var chunk := field.get_node_or_null(NodePath(chunk_name)) as MultiMeshInstance3D
		if chunk == null or chunk.multimesh == null or slot >= chunk.multimesh.instance_count:
			continue
		var far := field.get_node_or_null(NodePath(chunk_name + "_far")) as MultiMeshInstance3D
		var t := layer.transform_of(i)
		t.origin -= chunk.position
		var gone := t.scaled_local(Vector3.ZERO)
		chunk.multimesh.set_instance_transform(slot, gone)
		if far and far.multimesh and slot < far.multimesh.instance_count:
			far.multimesh.set_instance_transform(slot, gone)
		hidden.append([weakref(chunk), weakref(far) if far else null, slot, t])
	_hidden[key] = hidden
	_region_of[key] = region_id
	_scorch(at, hours)


## The grass is back: its clumps show again.
func regrow(key: Vector2i) -> void:
	for h: Array in _hidden.get(key, []):
		for ref in [h[0], h[1]]:
			var mmi := (ref as WeakRef).get_ref() as MultiMeshInstance3D if ref else null
			if mmi and mmi.multimesh:
				mmi.multimesh.set_instance_transform(h[2], h[3])
	_hidden.erase(key)
	_region_of.erase(key)


## A region streamed out: show its clumps again (if its nodes are still about)
## and lift the scorches over it.
func clear_region(region_id: StringName, fuel: GroundFuel) -> void:
	for key: Vector2i in _region_of.keys():
		if _region_of[key] == region_id:
			regrow(key)
	if fuel == null:
		return
	for d in _decals:
		if d.visible and fuel.at(GroundFuel.key_of(d.global_position)) != GroundFuel.NONE:
			_retire(d)


## Fades scorches by the in-game hour; retired ones go back to the pool.
func fade(hours: float, regrow_hours: float) -> void:
	for d in _decals:
		if not d.visible:
			continue
		var a := 1.0 - (hours - float(_born[d])) / regrow_hours
		if a <= 0.0:
			_retire(d)
		else:
			d.modulate.a = clampf(a, 0.0, 1.0)


func hidden_count() -> int:
	var n := 0
	for key: Vector2i in _hidden:
		n += (_hidden[key] as Array).size()
	return n


func is_hidden(key: Vector2i) -> bool:
	return _hidden.has(key)


func decal_count() -> int:
	var n := 0
	for d in _decals:
		if d.visible:
			n += 1
	return n


func _scorch(at: Vector3, hours: float) -> void:
	var free_one: Decal = null
	var oldest: Decal = null
	for d in _decals:
		if not d.visible:
			free_one = d
			continue
		if d.global_position.distance_to(at + Vector3.UP) < DECAL_SPACING:
			_born[d] = hours  # the fire passed again: fully dark
			d.modulate.a = 1.0
			return
		if oldest == null or float(_born[d]) < float(_born[oldest]):
			oldest = d
	var d := free_one
	if d == null and _decals.size() < MAX_DECALS:
		d = _make_decal()
	if d == null:
		d = oldest
	d.visible = true
	d.global_position = at + Vector3.UP
	d.rotation.y = fposmod(at.x * 1.7 + at.z * 2.3, TAU)
	d.modulate.a = 1.0
	_born[d] = hours


func _retire(d: Decal) -> void:
	d.visible = false


func _make_decal() -> Decal:
	var d := Decal.new()
	d.size = DECAL_SIZE
	d.texture_albedo = _ash_texture()
	d.albedo_mix = 1.0
	d.upper_fade = 0.3
	d.lower_fade = 0.3
	d.cull_mask = 1
	add_child(d)
	_decals.append(d)
	return d


## Dark ash, soft at the edge, with grey flecks (made once, no asset needed).
static func _ash_texture() -> ImageTexture:
	if _ash:
		return _ash
	const N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 59
	var noise := FastNoiseLite.new()
	noise.seed = 59
	noise.frequency = 0.06
	for y in N:
		for x in N:
			var d := Vector2(x - N * 0.5, y - N * 0.5).length() / (N * 0.5)
			var edge := clampf((1.0 - d) * 2.2 + noise.get_noise_2d(x, y) * 0.9, 0.0, 1.0)
			var c := Color(0.07, 0.06, 0.055)
			if rng.randf() < 0.06:
				c = Color(0.42, 0.4, 0.38)  # ash flecks
			c.a = edge * 0.92
			img.set_pixel(x, y, c)
	_ash = ImageTexture.create_from_image(img)
	return _ash

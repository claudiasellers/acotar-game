## Footprints and tracks pressed into snow, fading as new snow falls.
## Anyone can stamp: SnowPrints.stamp_at(tree, pos, yaw, kind). Feyre (group
## "player") is stamped automatically every `stride` metres while on snow.
## A fixed pool of Decals, recycled oldest-first; no per-print allocations.
class_name SnowPrints
extends Node3D

const GROUP := &"snow_prints"

@export var pool_size := 160
@export var stride := 0.75
## Seconds a print lasts in still weather; heavy snowfall shortens it.
@export var lifetime := 240.0
## 0 = clear, 1 = heavy snowfall. Weather/story can set this.
@export_range(0.0, 1.0) var snowfall := 0.3

var _decals: Array[Decal] = []
var _ages: PackedFloat32Array = []
var _next := 0
var _last_step := {}
var _textures := {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	for kind in [&"boot", &"hoof", &"paw"]:
		_textures[kind] = _make_texture(kind)
	for i in pool_size:
		var d := Decal.new()
		d.size = Vector3(0.22, 0.6, 0.34)
		d.visible = false
		d.cull_mask = 1
		d.upper_fade = 0.3
		d.lower_fade = 0.3
		add_child(d)
		_decals.append(d)
	_ages.resize(pool_size)
	_ages.fill(INF)


static func stamp_at(tree: SceneTree, pos: Vector3, yaw: float, kind: StringName = &"boot") -> void:
	var prints := tree.get_first_node_in_group(GROUP) as SnowPrints
	if prints != null:
		prints.stamp(pos, yaw, kind)


func stamp(pos: Vector3, yaw: float, kind: StringName = &"boot") -> void:
	if pos.z < WorldMap.WALL_Z:
		return  # no snow north of the Wall
	var d := _decals[_next]
	d.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	d.texture_albedo = _textures.get(kind, _textures[&"boot"])
	d.albedo_mix = 1.0
	d.modulate = Color(0.78, 0.83, 0.92, 1.0)
	d.visible = true
	_ages[_next] = 0.0
	_next = (_next + 1) % pool_size


func _process(delta: float) -> void:
	var life := lifetime / (1.0 + snowfall * 5.0)
	for i in pool_size:
		if _ages[i] == INF:
			continue
		_ages[i] += delta
		var a := 1.0 - _ages[i] / life
		if a <= 0.0:
			_ages[i] = INF
			_decals[i].visible = false
		else:
			_decals[i].modulate.a = a
	for walker in get_tree().get_nodes_in_group(&"player"):
		_step(walker as Node3D)


## Fraction of the pool currently showing (for tests and debug).
func active_count() -> int:
	var n := 0
	for a in _ages:
		if a != INF:
			n += 1
	return n


func _step(walker: Node3D) -> void:
	if walker == null:
		return
	var p := walker.global_position
	var last: Vector3 = _last_step.get(walker.get_instance_id(), p + Vector3(stride * 2.0, 0.0, 0.0))
	if p.distance_to(last) < stride:
		return
	_last_step[walker.get_instance_id()] = p
	var dir := p - last
	var yaw := atan2(dir.x, dir.z)
	var side := walker.global_transform.basis.x.normalized() * 0.12
	var left := int(p.length() / stride) % 2 == 0
	stamp(p + (side if left else -side), yaw, &"boot")


func _make_texture(kind: StringName) -> ImageTexture:
	var img := Image.create_empty(64, 96, false, Image.FORMAT_RGBA8)
	for y in 96:
		for x in 64:
			var u := (x - 32.0) / 32.0
			var v := (y - 48.0) / 48.0
			var a := 0.0
			match kind:
				&"boot":
					a = 1.0 - smoothstep(0.75, 1.0, u * u / 0.55 + v * v)
				&"hoof":
					a = 1.0 - smoothstep(0.7, 1.0, u * u + v * v * 1.8)
					a *= smoothstep(0.02, 0.12, absf(u))
				_:
					a = 1.0 - smoothstep(0.6, 1.0, u * u + (v - 0.2) * (v - 0.2) * 2.0)
			img.set_pixel(x, y, Color(0.55, 0.62, 0.75, a * 0.75))
	return ImageTexture.create_from_image(img)

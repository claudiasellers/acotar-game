## Brings a region's spawn table to life inside `bounds` (world x/z). Every
## few seconds it checks each entry against the clock, story flags and the
## glamour, and spawns or clears that entry's creatures. Placement is seeded,
## so a region always fills the same way.
class_name CreatureSpawner
extends Node3D

const CHECK_INTERVAL := 5.0

@export var table: CreatureSpawnTable
## World-space area: Rect2(min_x, min_z, width, depth).
@export var bounds: Rect2 = Rect2(-50, -50, 100, 100)
## Height of the water surface for `on_water` entries (ponds, river reaches).
@export var water_level: float = 0.0
## Where on-water entries go: Rect2 in world x/z. Empty uses `bounds`.
@export var water_bounds: Rect2 = Rect2()
@export var seed: int = 1

## Ground height lookup; WorldHeight by default, swappable for tests and demos.
var height_func: Callable = func(x: float, z: float) -> float: return WorldHeight.height_at(x, z)

var spawned: Dictionary = {}
var _check_left: float = 0.0


func _ready() -> void:
	refresh()


func _process(delta: float) -> void:
	_check_left -= delta
	if _check_left <= 0.0:
		_check_left = CHECK_INTERVAL
		refresh()


func refresh() -> void:
	if table == null:
		return
	var hour := Clock.hour()
	var lifted := GlamourLayer.is_lifted()
	for i in table.entries.size():
		var entry := table.entries[i]
		var want := entry.allowed(hour, WorldState.has_flag, lifted)
		var have := spawned.has(entry.id) and not (spawned[entry.id] as Array).is_empty()
		if want and not have:
			spawned[entry.id] = _spawn_entry(entry, i)
		elif not want and have:
			for node in spawned[entry.id]:
				if is_instance_valid(node):
					(node as Node).queue_free()
			spawned.erase(entry.id)


## Deterministic positions for one entry: `groups` clusters of `count`.
func positions_for(entry: SpawnEntry, index: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, index, String(entry.id)])
	var area := water_bounds if entry.on_water and water_bounds.has_area() else bounds
	var out: Array[Vector3] = []
	var anchors := _anchors(entry.near_group, area)
	for g in entry.groups:
		var c := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if not anchors.is_empty():
			c = anchors[(g + rng.randi()) % anchors.size()]
		for n in entry.count:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * entry.cluster_radius
			var p := c + Vector2(cos(a), sin(a)) * r
			p = Vector2(clampf(p.x, area.position.x, area.end.x), clampf(p.y, area.position.y, area.end.y))
			var y := water_level if entry.on_water else float(height_func.call(p.x, p.y)) + 0.2
			out.append(Vector3(p.x, y, p.y))
	return out


## World x/z of the nodes in `group` inside `area`, sorted so placement stays seeded.
func _anchors(group: StringName, area: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if group == &"" or not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node3D
		if n:
			var p := Vector2(n.global_position.x, n.global_position.z)
			if area.has_point(p):
				out.append(p)
	out.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out


func _spawn_entry(entry: SpawnEntry, index: int) -> Array:
	var nodes: Array = []
	if entry.scene == null:
		return nodes
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, index, "yaw"])
	for p in positions_for(entry, index):
		var node := entry.scene.instantiate() as Node3D
		if entry.on_water and &"water_level" in node:
			node.set(&"water_level", water_level)
		# Placed before entering the tree, so _ready() sees its real home.
		node.position = to_local(p) if is_inside_tree() else p
		node.rotation.y = rng.randf() * TAU
		add_child(node)
		nodes.append(node)
	return nodes

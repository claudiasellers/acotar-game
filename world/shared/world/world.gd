## The persistent World scene: one Terrain3D for the whole map, sky, sun,
## grade, wind, snow and footprints. Never streamed. Region content streams in
## under `regions` (hand it to WorldStreamer.configure*).
class_name World
extends Node3D

const GROUP := &"world"

@onready var regions: Node3D = $Regions
@onready var grade: GradeDirector = $GradeDirector
@onready var wind: WindDriver = $WindDriver

var terrain: Node3D
var _terrain_anchor: Node3D


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	if TerrainSetup.available():
		terrain = TerrainSetup.make_terrain()
		if TerrainSetup.has_baked_data():
			terrain.set(&"data_directory", TerrainSetup.DATA_DIR)
		# Follow Feyre (or the camera) for clipmap LODs and collision; until
		# one exists, a fixed anchor keeps Terrain3D from complaining.
		_terrain_anchor = Node3D.new()
		_terrain_anchor.name = "TerrainAnchor"
		_terrain_anchor.position = _focus_position()
		add_child(_terrain_anchor)
		terrain.set(&"clipmap_target", _terrain_anchor)
		terrain.set(&"collision_target", _terrain_anchor)
		add_child(terrain)
		if not TerrainSetup.has_baked_data():
			push_warning("World: no baked terrain in %s; baking nearby regions in memory (run bake_terrain.gd)" % TerrainSetup.DATA_DIR)
			bake_near(_focus_position(), 1)
	else:
		push_warning("World: Terrain3D extension not loaded; regions keep their TerrainFallback meshes")
	if has_node(^"/root/WorldStreamer") and WorldStreamer.has_signal(&"region_loaded"):
		WorldStreamer.region_loaded.connect(_on_region_loaded)
	_disable_fallbacks(self)


func _process(_delta: float) -> void:
	if grade.focus == null:
		grade.focus = get_tree().get_first_node_in_group(&"player") as Node3D
	if _terrain_anchor != null:
		var cam := get_viewport().get_camera_3d()
		var follow: Node3D = grade.focus if grade.focus != null else cam
		if follow != null:
			_terrain_anchor.global_position = follow.global_position


## Bake the Terrain3D regions within `radius` regions of `pos` from WorldHeight.
func bake_near(pos: Vector3, radius: int) -> void:
	var size := float(WorldMap.BAKE_TILE) * WorldMap.TERRAIN_VERTEX_SPACING
	var centre := Vector2i(floori(pos.x / size), floori(pos.z / size))
	for loc in TerrainBaker.region_locations():
		if absi(loc.x - centre.x) <= radius and absi(loc.y - centre.y) <= radius:
			TerrainSetup.import_region(terrain, loc, TerrainBaker.bake_region(loc))


func _focus_position() -> Vector3:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		return player.global_position
	return Vector3(HumanRealmLayout.COTTAGE.x, 0.0, HumanRealmLayout.COTTAGE.y)


func _on_region_loaded(_id: StringName, root: Node) -> void:
	_disable_fallbacks(root)


## Stand-in terrain meshes (contract §2) go away once Terrain3D is active.
func _disable_fallbacks(root: Node) -> void:
	if terrain == null:
		return
	for node in root.find_children("TerrainFallback", "", true, false):
		node.queue_free()

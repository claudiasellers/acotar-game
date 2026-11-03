## A loose physical prop built from a PropData (T5). Lives on the world
## collision layer so Feyre bumps into it, stands on it and the camera keeps
## clear of it. She shoves it by walking into it (PropCarrier), and lifts it
## with interact like any station (group "station", use(user)).
##
## PropField pools these: a Prop exists only near Feyre; elsewhere the same
## prop is one instance of a MultiMesh.
class_name Prop
extends RigidBody3D

signal broke(prop: Prop)

const GROUP := &"prop"
const STATION_ID := &"prop"
const WORLD_LAYER := 1 << 0

@export var data: PropData

## Set by PropField: which pooled placement this body stands for.
var placement: int = -1
## Element state, driven by ElementField (systems/chemistry/element_field.gd).
var wet: float = 0.0
var burning: float = 0.0
var carried: bool = false
var mesh_instance: MeshInstance3D
## Station contract (Interactor reads it).
var station_id: StringName = STATION_ID
var _last_speed: float = 0.0

static var _mesh_cache: Dictionary = {}


static func make(prop_data: PropData) -> Prop:
	var p := Prop.new()
	p.data = prop_data
	p.name = String(prop_data.id).to_pascal_case()
	return p


func _init() -> void:
	collision_layer = WORLD_LAYER
	collision_mask = WORLD_LAYER
	continuous_cd = true
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 2


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		return
	mass = data.mass
	# Round things roll, but settle: no pot rolls the length of the yard.
	angular_damp = 2.5
	linear_damp = 0.15
	var mat := PhysicsMaterial.new()
	mat.friction = data.friction
	mat.bounce = data.bounce
	physics_material_override = mat
	wet = data.wetness
	var col := CollisionShape3D.new()
	col.shape = data.make_shape()
	col.position.y = data.half_height()
	add_child(col)
	# Centre of mass at the middle of the body, not at its feet.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, data.half_height(), 0.0)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh_for(data)
	add_child(mesh_instance)
	if data.carryable:
		add_to_group(&"station")
	body_entered.connect(_on_body_entered)


## Shared, cached per PropData: one mesh resource for every body and the MultiMesh.
static func mesh_for(prop_data: PropData) -> Mesh:
	if _mesh_cache.has(prop_data.id):
		return _mesh_cache[prop_data.id]
	var mesh := prop_data.load_mesh()
	if mesh is ArrayMesh:
		mesh = _with_finishes(mesh as ArrayMesh)
	if mesh == null:
		# A visible stand-in rather than nothing (never shipped: data points at real glbs).
		var box := BoxMesh.new()
		box.size = prop_data.size
		var m := StandardMaterial3D.new()
		m.albedo_color = prop_data.sparkle
		box.material = m
		mesh = box
	_mesh_cache[prop_data.id] = mesh
	return mesh


## Kit-built models (tools/blender/prop_kit.py) carry "opaque"/"clear"
## placeholder materials; give them the shared finish shader like the manor does.
static func _with_finishes(mesh: ArrayMesh) -> ArrayMesh:
	var out: ArrayMesh = null
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		var surface_name := StringName(m.resource_name) if m else &""
		if surface_name != &"opaque" and surface_name != &"clear":
			continue
		if out == null:
			out = mesh.duplicate() as ArrayMesh
		out.surface_set_material(s, PropFinishes.material(surface_name))
	return out if out else mesh


## Interact (the station contract): lift it.
func use(user: Node) -> void:
	if carried or data == null or not data.carryable:
		return
	var carrier := PropCarrier.for_body(user as Node3D)
	if carrier:
		carrier.pick_up(self)


## The prop's footprint radius on the ground.
func radius() -> float:
	return maxf(data.size.x, data.size.z) * 0.5 if data else 0.3


func _physics_process(_delta: float) -> void:
	_last_speed = linear_velocity.length()


func _on_body_entered(_body: Node) -> void:
	if data == null or not data.breakable or carried:
		return
	# The speed it hit at (the solver has already slowed it by now).
	if maxf(_last_speed, linear_velocity.length()) >= data.break_speed:
		shatter()


## Breaks apart in a burst of sparkles (a dropped pot, a thrown jar).
func shatter() -> void:
	Juice.burst(null, &"pickup", global_position + Vector3.UP * 0.3, 0.7)
	broke.emit(self)
	queue_free()

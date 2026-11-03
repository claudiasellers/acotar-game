## A region's loose props (T5), pooled so the chunk budget holds: every prop
## is drawn as one MultiMesh instance per kind (one draw per kind), and only
## the few near Feyre become real RigidBody3D Props. A prop she moved keeps
## its new place when it goes back to sleep (for this session).
class_name PropField
extends Node3D

## Real bodies within this distance of the player; back to the MultiMesh past SLEEP_DISTANCE.
const WAKE_DISTANCE := 22.0
const SLEEP_DISTANCE := 30.0
## Most live bodies at once per field.
const POOL := 16
const TICK := 0.25

@export var placements: PropPlacements
## Who wakes the props. Defaults to the node in group "player".
@export var player: Node3D

## Per placement: kind index, transform, live body (or null), broken.
var _kind: PackedInt32Array = []
var _xf: Array[Transform3D] = []
var _body: Array = []
var _broken: PackedByteArray = []
var _datas: Array[PropData] = []
var _multis: Array[MultiMeshInstance3D] = []
var _slot: PackedInt32Array = []
var _tick_left := 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	if placements:
		build(placements)


func build(p: PropPlacements) -> void:
	placements = p
	for layer in p.layers:
		var data := PropPlacements.prop_data(layer.id)
		if data == null:
			push_warning("PropField: no data/props/%s.tres" % layer.id)
			continue
		var k := _datas.size()
		_datas.append(data)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Prop.mesh_for(data)
		mm.instance_count = layer.count()
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Sleeping_%s" % layer.id
		mmi.multimesh = mm
		add_child(mmi)
		_multis.append(mmi)
		for i in layer.count():
			var o := i * ScatterLayer.STRIDE
			var v := layer.instances
			var xf := Transform3D(Basis(Vector3.UP, v[o + 3]), Vector3(v[o], v[o + 1], v[o + 2]))
			_kind.append(k)
			_slot.append(i)
			_xf.append(xf)
			_body.append(null)
			_broken.append(0)
			mm.set_instance_transform(i, xf)


func count() -> int:
	return _xf.size()


func active_count() -> int:
	var n := 0
	for b in _body:
		if b != null:
			n += 1
	return n


## MultiMeshes (one per kind) plus live bodies.
func draw_calls() -> int:
	return _multis.size() + active_count()


func _physics_process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = TICK
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		update_for(player.global_position)


## Wakes props near `pos` and puts far, resting ones back to sleep.
func update_for(pos: Vector3) -> void:
	var live := active_count()
	for i in _xf.size():
		if _broken[i]:
			continue
		var body := _body[i] as Prop
		if body != null and not is_instance_valid(body):
			_body[i] = null
			body = null
		if body == null:
			if live < POOL and _xf[i].origin.distance_to(pos) < WAKE_DISTANCE:
				_wake(i)
				live += 1
		elif not body.carried and body.global_position.distance_to(pos) > SLEEP_DISTANCE:
			_sleep(i)
			live -= 1


## The live body for placement i (null while it sleeps).
func body_at(i: int) -> Prop:
	return _body[i] as Prop


func _wake(i: int) -> void:
	var data := _datas[_kind[i]]
	var prop := Prop.make(data)
	prop.placement = i
	add_child(prop)
	# Rest on whatever is really there (a paved yard, a stack) when the
	# generator's ground height differs from the built ground.
	var xf := _xf[i]
	var ground := _ground_at(xf.origin, prop)
	if not is_nan(ground):
		xf.origin.y = ground
	prop.global_transform = xf.translated(Vector3.UP * 0.02)
	prop.broke.connect(_on_broke.bind(i))
	var elements := ElementField.find(get_tree())
	if elements and data.flammable:
		elements.track_prop(prop)
	_body[i] = prop
	_set_shown(i, false)
	if player:
		PropCarrier.for_body(player)


func _ground_at(at: Vector3, prop: Prop) -> float:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return NAN
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at + Vector3.DOWN * 3.0, Prop.WORLD_LAYER)
	q.exclude = [prop.get_rid()]
	var hit := space.intersect_ray(q)
	return float(hit.position.y) if hit else NAN


func _sleep(i: int) -> void:
	var prop := _body[i] as Prop
	var xf := prop.global_transform
	# Settle upright-ish if it was left tipped: keep its yaw, keep where it lies.
	_xf[i] = xf.orthonormalized()
	_body[i] = null
	prop.queue_free()
	_set_shown(i, true)


func _set_shown(i: int, shown: bool) -> void:
	var mm := _multis[_kind[i]].multimesh
	var xf := _xf[i] if shown else Transform3D(Basis().scaled(Vector3.ZERO), _xf[i].origin)
	mm.set_instance_transform(_slot[i], xf)


func _on_broke(_prop: Prop, i: int) -> void:
	_broken[i] = 1
	_body[i] = null
	_set_shown(i, false)

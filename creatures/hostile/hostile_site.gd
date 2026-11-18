## A hostile camp, lair or den (docs/contracts/hostiles.md). Spawned by its
## region's CreatureSpawner, it moves to its core on the terrain, raises its
## members on a home ring, keeps the camp blackboard (reports land after a
## delay, so a silent kill stays silent) and settles when the last one dies:
## a fact, a celebration, and nothing spawns again (until the blight, P6).
class_name HostileSite
extends Node3D

signal settled(site_id: StringName)
signal alerted(level: float)

const GROUP := &"hostile_site"
const ALERT_DECAY := 0.05

@export var data: HostileSiteData

## Ground height lookup; WorldHeight by default, swappable for tests.
var height_func: Callable = func(x: float, z: float) -> float: return WorldHeight.height_at(x, z)
## Off for tests that place the site themselves.
var snap_to_core: bool = true

var members: Array[Creature] = []
var alert_level: float = 0.0
var last_known: Vector3 = Vector3.INF
var is_settled: bool = false
## {member: Creature, at: Vector3, left: float}
var _pending: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		push_warning("HostileSite %s has no data" % name)
		return
	# A court region makes one spawner per bounds rect; the camp exists once.
	for other in get_tree().get_nodes_in_group(GROUP):
		var twin := other as HostileSite
		if twin and twin != self and not twin.is_queued_for_deletion() and twin.data \
				and twin.data.id == data.id:
			is_settled = true
			queue_free()
			return
	if snap_to_core:
		global_position = Vector3(data.core.x, float(height_func.call(data.core.x, data.core.y)), data.core.y)
	if HostileSite.stays_settled(WorldState.get_flag(settle_flag(data.id)), Clock.day,
			data.settle_days, WorldState.has_flag("glamour_lifted")):
		is_settled = true
		return
	for i in data.count:
		_spawn_member(i)


static func settle_flag(site_id: StringName) -> String:
	return "fact.site_settled.%s" % site_id


## Before the blight (glamour_lifted) a settled site stays settled; after it,
## the site re-seeds `days` after it settled.
static func stays_settled(settled_day: Variant, today: int, days: int, blight: bool) -> bool:
	if settled_day == null or not (settled_day is int or settled_day is float):
		return false
	if not blight:
		return true
	return today - int(settled_day) < days


func leash_radius() -> float:
	return data.leash_radius() if data else 0.0


## Inside the chase leash, flat distance from the core.
func in_leash(pos: Vector3) -> bool:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() <= leash_radius()


## A member saw her at `at`: the rest of the camp hears in report_delay seconds,
## unless the member dies first.
func report(member: Creature, at: Vector3) -> void:
	for p in _pending:
		if p.member == member:
			p.at = at
			return
	_pending.append({"member": member, "at": at, "left": data.report_delay if data else 0.8})


func living_count() -> int:
	var n := 0
	for m in members:
		if is_instance_valid(m) and m.alive:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	alert_level = maxf(alert_level - ALERT_DECAY * delta, 0.0)
	for i in range(_pending.size() - 1, -1, -1):
		var p: Dictionary = _pending[i]
		p.left -= delta
		if p.left > 0.0:
			continue
		_pending.remove_at(i)
		var m := p.member as Creature
		if is_instance_valid(m) and m.alive:
			_raise(p.at)


func _raise(at: Vector3) -> void:
	alert_level = 1.0
	last_known = at
	for m in members:
		if is_instance_valid(m) and m.alive and m.has_method(&"on_camp_alert"):
			m.call(&"on_camp_alert", at)
	alerted.emit(alert_level)
	if EventBus.has_signal(&"hostile_alerted"):
		EventBus.emit_signal(&"hostile_alerted", data.id, alert_level)


func _spawn_member(index: int) -> void:
	if data.member_scene == null:
		return
	var m := data.member_scene.instantiate() as Creature
	if m == null:
		return
	var home2 := data.home_point(index)
	var home := Vector3(home2.x, float(height_func.call(home2.x, home2.y)), home2.y)
	m.name = "%s_%d" % [String(data.id), index + 1]
	m.creature_id = StringName(m.name)
	if &"site" in m:
		m.set(&"site", self)
	if &"home" in m:
		m.set(&"home", home)
	if &"member_index" in m:
		m.set(&"member_index", index)
	m.top_level = true
	add_child(m)
	m.global_position = home
	members.append(m)
	m.died.connect(_on_member_died.bind(m))


func _on_member_died(_cause: StringName, member: Creature) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		if _pending[i].member == member:
			_pending.remove_at(i)
	if living_count() == 0 and not is_settled:
		settle()


## Every member is gone: the place settles. Birdsong and sparkle come back
## (DreadFields leave with their members; the celebration is the chime).
func settle() -> void:
	is_settled = true
	WorldState.set_flag(settle_flag(data.id), Clock.day)
	if EventBus.has_signal(&"celebration_requested"):
		EventBus.emit_signal(&"celebration_requested", &"site_settled", global_position)
	if EventBus.has_signal(&"site_settled"):
		EventBus.emit_signal(&"site_settled", data.id)
	settled.emit(data.id)

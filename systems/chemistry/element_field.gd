## World chemistry (T5): the elements FIRE, WATER and WIND acting on
## materials in the world, with three rules (BotW-style, kept small):
## 1. Elements change materials: fire burns what is flammable and dry, water
##    wets it, wind shoves light loose props.
## 2. Elements change each other: water puts fire out, fire dries water, wind
##    carries fire further downwind.
## 3. Materials never change each other: a crate never "does" anything to the
##    grass; only the fire on it can reach the grass.
## Things that can burn are cells in a spatial hash (CELL metres); the field
## ticks at 10 Hz. Cells are points (a tuft of dry grass) or follow a node
## (a flammable Prop). Heat sources (group "heat_source", a hearth, a
## campfire) light cells they touch. Cooking chemistry is chemistry.gd; the
## per-thing fire/wet/cold model for Feyre and her things is ElementState.
## Ground fuel: each loaded Spring region's grass, reeds and hay
## (add_ground / remove_ground, a GroundFuel grid built off the main thread);
## its squares become cells only where fire or water arrives. A burnt square
## loses its clumps under an ash scorch (GroundScorch) and grows back after
## REGROW_HOURS in-game hours. While a story scene runs (the weather's `held`)
## fires burn down but do not spread.
## Rain raises one shared soak level instead of touching every cell, and the
## tick walks only the burning and node-following cells, so a region's worth
## of ground costs nothing until something happens there.
class_name ElementField
extends Node3D

signal ignited(cell: int)
signal extinguished(cell: int)
signal burnt_out(cell: int)

const GROUP := &"element_field"
const TICK := 0.1
const CELL := 2.0
## Fire reaches dry neighbours within this distance, plus wind reach downwind.
const SPREAD := 1.6
const WIND_REACH := 1.2
## Heat a neighbour gains per second next to a full fire (ignites at 1.0).
const HEAT_RATE := 0.9
## Wet at or above this never lights.
const WET_STOPS := 0.5
## Fire dries neighbours at this rate per second; rain raises the soak of
## everything out in it at RAIN_WET_RATE x rain, and it dries at SOAK_DRY.
const DRY_RATE := 0.04
const RAIN_WET_RATE := 0.08
const SOAK_DRY := 1.0 / 150.0
## Wind pushes loose props lighter than this (kg) at gusts above WIND_PUSH_SPEED (m/s).
const WIND_PUSH_MASS := 6.0
const WIND_PUSH_SPEED := 6.0
## Seconds of fuel per material (how long it burns), and if it is flammable.
const MATERIALS := {
	&"grass": {"fuel": 2.5, "flammable": true},
	&"hay": {"fuel": 4.0, "flammable": true},
	&"wood": {"fuel": 12.0, "flammable": true},
	&"cloth": {"fuel": 5.0, "flammable": true},
	&"stone": {"fuel": 0.0, "flammable": false},
}
const MAX_BURNING := 64
## In-game hours until burnt grass grows back (the scorch fades over the same time).
const REGROW_HOURS := 4.0
## Stations with a live fire (manor hearths, the bread oven) and how far they reach.
const FIRE_STATIONS: Array[StringName] = [&"hearth", &"bread_oven"]
const FIRE_STATION_REACH := 1.1

## Per cell (index = id; freed ids are reused).
var _pos: PackedVector3Array = []
var _material: Array[StringName] = []
var _fuel: PackedFloat32Array = []
var _fire: PackedFloat32Array = []
var _heat: PackedFloat32Array = []
var _wet: PackedFloat32Array = []
var _node: Array = []
var _alive: PackedByteArray = []
var _free_ids: PackedInt32Array = []
var _hash: Dictionary = {}  # Vector3i -> PackedInt32Array
var _burning: Dictionary = {}  # id -> true
var _tracked: Dictionary = {}  # id -> true (cells that follow a node)
var _tick_left := 0.0
## Rain on exposed cells, 0..1 (SpringWeather sets it).
var rain: float = 0.0
## How soaked everything out in the weather is, 0..1: rises in rain, dries slowly.
var soak: float = 0.0
## Ground fuel per region, the squares turned into cells and builds in flight.
var _ground: Dictionary = {}  # region id -> GroundFuel
var _woken: Dictionary = {}  # Vector2i square -> [region id, PackedInt32Array cells]
var _ground_gen: Dictionary = {}  # region id -> int (a newer add or a remove drops older builds)
var _ground_tasks: Dictionary = {}  # task id -> true
var _cell_square: Dictionary = {}  # ground cell id -> Vector2i square
var _burnt_at: Dictionary = {}  # Vector2i square -> in-game hour it burnt
## True while a story scene runs (SpringWeather.held): fires do not spread.
var held := false
var scorch: GroundScorch
var _slow_left := 0.0
## Horizontal wind in m/s, read from the world each tick unless follow_world_wind is off.
var wind: Vector3 = Vector3.ZERO
var follow_world_wind := true
var _overlay: ElementOverlay
var _fx: FireFx


static func find(tree: SceneTree) -> ElementField:
	return tree.get_first_node_in_group(GROUP) as ElementField if tree else null


func _ready() -> void:
	add_to_group(GROUP)
	top_level = true
	_ensure_action()
	_fx = FireFx.new()
	_fx.name = "FireFx"
	add_child(_fx)
	scorch = GroundScorch.new()
	scorch.name = "Scorch"
	add_child(scorch)
	ignited.connect(func(id: int) -> void: _fx.light(id, _pos[id], _node[id] as Node3D))
	extinguished.connect(func(id: int) -> void: _fx.douse(id, true))
	burnt_out.connect(_on_burnt_out)


# --- cells -----------------------------------------------------------------

## Adds a burnable thing at `pos` (or following `node`). Returns its id.
func add_cell(pos: Vector3, material: StringName, wet: float = 0.0, node: Node3D = null) -> int:
	var spec: Dictionary = MATERIALS.get(material, MATERIALS[&"stone"])
	var id := -1
	if not _free_ids.is_empty():
		id = _free_ids[_free_ids.size() - 1]
		_free_ids.resize(_free_ids.size() - 1)
	else:
		id = _pos.size()
		_pos.append(Vector3.ZERO)
		_material.append(&"")
		_fuel.append(0.0)
		_fire.append(0.0)
		_heat.append(0.0)
		_wet.append(0.0)
		_node.append(null)
		_alive.append(0)
	_pos[id] = node.global_position if node else pos
	_material[id] = material
	_fuel[id] = float(spec.fuel)
	_fire[id] = 0.0
	_heat[id] = 0.0
	_wet[id] = clampf(wet, 0.0, 1.0)
	_node[id] = node
	_alive[id] = 1
	_hash_add(id)
	if node:
		_tracked[id] = true
	return id


## A patch of cells on a grid (a stretch of dry grass, a hay heap).
func add_patch(centre: Vector3, radius: float, material: StringName, spacing: float = 1.0, wet: float = 0.0) -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := int(ceil(radius / spacing))
	for ix in range(-n, n + 1):
		for iz in range(-n, n + 1):
			var off := Vector3(ix * spacing, 0.0, iz * spacing)
			if off.length() <= radius:
				out.append(add_cell(centre + off, material, wet))
	return out


func remove_cell(id: int) -> void:
	if id < 0 or id >= _alive.size() or not _alive[id]:
		return
	_hash_remove(id)
	if _burning.has(id):
		_burning.erase(id)
		if _fx:
			_fx.douse(id, false)
	_tracked.erase(id)
	_cell_square.erase(id)
	_alive[id] = 0
	_node[id] = null
	_fire[id] = 0.0
	_free_ids.append(id)


## Follows a flammable Prop while it is a live body; the Prop carries its wetness.
func track_prop(prop: Prop) -> int:
	if prop == null or prop.data == null:
		return -1
	var material := &"wood" if prop.data.flammable else &"stone"
	var id := add_cell(prop.global_position, material, prop.wet, prop)
	prop.tree_exiting.connect(remove_cell.bind(id), CONNECT_ONE_SHOT)
	return id


func fire(id: int) -> float:
	return _fire[id] if _ok(id) else 0.0


## How wet a cell is: its own wetness or the weather's soak, whichever is more.
func wet(id: int) -> float:
	return maxf(_wet[id], soak) if _ok(id) else 0.0


func is_burning(id: int) -> bool:
	return _ok(id) and _fire[id] > 0.0


func is_burnt(id: int) -> bool:
	return _ok(id) and _fuel[id] <= 0.0 and _fire[id] <= 0.0 and bool(MATERIALS.get(_material[id], {}).get("flammable", false))


func cell_count() -> int:
	return _alive.count(1)


func burning_count() -> int:
	return _burning.size()


# --- ground fuel --------------------------------------------------------------

## Registers a region's flammable scatter (the grass, reeds and hay of its
## ScatterFields, GroundFuel.pick) with story anchor `clear`ings left out.
## The grid is built on a worker thread unless `threaded` is off; until it
## lands the region's ground does not burn.
func add_ground(region_id: StringName, fields: Array, clear: Array[Vector3] = [], threaded: bool = true) -> void:
	var gen: int = _ground_gen.get(region_id, 0) + 1
	_ground_gen[region_id] = gen
	var picked := GroundFuel.pick(fields)
	var data: Array = picked["data"]
	var refs: Array = picked["refs"]
	if data.is_empty():
		return
	if not threaded:
		_land_ground(region_id, gen, GroundFuel.build(region_id, data, clear), refs, [-1])
		return
	var me: WeakRef = weakref(self)
	var task_box: Array = [-1]  # read on the main thread, after add_task has returned
	task_box[0] = WorkerThreadPool.add_task(func() -> void:
		var fuel := GroundFuel.build(region_id, data, clear)
		var field := me.get_ref() as ElementField
		if field:
			field._land_ground.call_deferred(region_id, gen, fuel, refs, task_box))
	_ground_tasks[task_box[0]] = true


## Drops a region's ground and every cell made from it (it streamed out).
func remove_ground(region_id: StringName) -> void:
	_ground_gen[region_id] = int(_ground_gen.get(region_id, 0)) + 1
	scorch.clear_region(region_id, _ground.get(region_id) as GroundFuel)
	_ground.erase(region_id)
	for key: Vector2i in _woken.keys():
		var entry: Array = _woken[key]
		if entry[0] == region_id:
			for id in (entry[1] as PackedInt32Array):
				remove_cell(id)
			_woken.erase(key)
			_burnt_at.erase(key)


func has_ground(region_id: StringName) -> bool:
	return _ground.has(region_id)


func ground(region_id: StringName) -> GroundFuel:
	return _ground.get(region_id) as GroundFuel


## True while a ground build is still on a worker thread.
func ground_pending() -> bool:
	return not _ground_tasks.is_empty()


func _land_ground(region_id: StringName, gen: int, fuel: GroundFuel, refs: Array, task_box: Array) -> void:
	var task: int = task_box[0]
	if _ground_tasks.has(task):
		WorkerThreadPool.wait_for_task_completion(task)
		_ground_tasks.erase(task)
	if gen != int(_ground_gen.get(region_id, 0)) or fuel.square_count() == 0:
		return
	fuel.refs = refs
	_ground[region_id] = fuel


## Burnt squares older than REGROW_HOURS grow back: clumps show, the square's
## cells go and it can burn again. Returns how many grew back.
func regrow_due(hours: float) -> int:
	var n := 0
	for key: Vector2i in _burnt_at.keys():
		if hours - float(_burnt_at[key]) < REGROW_HOURS:
			continue
		scorch.regrow(key)
		_burnt_at.erase(key)
		var entry: Array = _woken.get(key, [])
		if not entry.is_empty():
			for id in (entry[1] as PackedInt32Array):
				remove_cell(id)
			_woken.erase(key)
		n += 1
	return n


## The in-game hour (Clock: day x 24 + hour); one real minute per hour without it.
func game_hours() -> float:
	var clock := Gameplay.autoload(&"Clock")
	if clock:
		return float(clock.get(&"day")) * 24.0 + float(clock.call(&"hour"))
	return Time.get_ticks_msec() / 60000.0


## Turns the fuel squares within `radius` of `pos` into cells (four per
## square, 1 m apart, at the weather's soak), once.
func _wake_ground(pos: Vector3, radius: float) -> void:
	if _ground.is_empty():
		return
	var lo := GroundFuel.key_of(pos - Vector3.ONE * radius)
	var hi := GroundFuel.key_of(pos + Vector3.ONE * radius)
	var quarter := GroundFuel.STEP * 0.25
	for x in range(lo.x, hi.x + 1):
		for z in range(lo.y, hi.y + 1):
			var key := Vector2i(x, z)
			if _woken.has(key):
				continue
			for region_id: StringName in _ground:
				var fuel: GroundFuel = _ground[region_id]
				var code := fuel.at(key)
				if code == GroundFuel.NONE:
					continue
				var y := fuel.height_at(key)
				var ids := PackedInt32Array()
				for q: Vector2 in [Vector2(1, 1), Vector2(3, 1), Vector2(1, 3), Vector2(3, 3)]:
					var at := Vector3(x * GroundFuel.STEP + q.x * quarter, y, z * GroundFuel.STEP + q.y * quarter)
					var cell := add_cell(at, GroundFuel.MATERIALS[code])
					_cell_square[cell] = key
					ids.append(cell)
				_woken[key] = [region_id, ids]
				break


func _exit_tree() -> void:
	for task: int in _ground_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(task)
	_ground_tasks.clear()


# --- elements arriving -------------------------------------------------------

## FIRE at a point: lights every dry, flammable cell within `radius`. Returns how many lit.
func ignite_at(pos: Vector3, radius: float = 0.8) -> int:
	_wake_ground(pos, radius)
	var lit := 0
	for id in cells_near(pos, radius):
		if _try_ignite(id):
			lit += 1
	return lit


## WATER at a point (a thrown bucket, a splash): soaks and puts out fires within `radius`.
func soak_at(pos: Vector3, radius: float = 1.5, amount: float = 1.0) -> int:
	_wake_ground(pos, radius)
	var hit := 0
	for id in cells_near(pos, radius):
		_wet[id] = clampf(_wet[id] + amount, 0.0, 1.0)
		_heat[id] = 0.0
		if _fire[id] > 0.0:
			_put_out(id)
		_sync_node(id)
		hit += 1
	return hit


func cells_near(pos: Vector3, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var lo := _key(pos - Vector3.ONE * radius)
	var hi := _key(pos + Vector3.ONE * radius)
	for x in range(lo.x, hi.x + 1):
		for y in range(lo.y, hi.y + 1):
			for z in range(lo.z, hi.z + 1):
				for id in _hash.get(Vector3i(x, y, z), PackedInt32Array()):
					if _pos[id].distance_to(pos) <= radius:
						out.append(id)
	return out


# --- the tick ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += TICK
	if follow_world_wind:
		wind = _world_wind()
	held = _story_held()
	step(TICK)
	_slow_left -= TICK
	if _slow_left <= 0.0:
		_slow_left = 1.0
		var hours := game_hours()
		scorch.fade(hours, REGROW_HOURS)
		regrow_due(hours)
	if _overlay and _overlay.visible:
		_overlay.redraw(self)


## One chemistry step of `dt` seconds. Pure enough for tests to drive.
func step(dt: float) -> void:
	_follow_nodes()
	_heat_sources()
	var wind_dir := Vector3(wind.x, 0.0, wind.z)
	var wind_k := clampf(wind_dir.length() / 8.0, 0.0, 1.0)
	wind_dir = wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector3.ZERO
	var reach := SPREAD + WIND_REACH * wind_k
	# Rain soaks everything out in it (rule 1), and dries off slowly after.
	if rain > 0.0:
		soak = clampf(soak + rain * RAIN_WET_RATE * dt, 0.0, 1.0)
	else:
		soak = maxf(soak - SOAK_DRY * dt, 0.0)
	var to_light: Array[int] = []
	for id: int in _burning.keys():
		if not _burning.has(id):
			continue
		# Rain puts fires out (rule 2).
		if soak >= WET_STOPS:
			_wet[id] = maxf(_wet[id], soak)
			_put_out(id)
			continue
		# Fire burns its material's fuel (rule 1)...
		_fuel[id] -= dt
		if _fuel[id] <= 0.0:
			_fire[id] = 0.0
			_burning.erase(id)
			burnt_out.emit(id)
			_sync_node(id)
			continue
		if held:
			continue  # a story scene runs: fires burn down but do not spread
		# ...and heats and dries the dry neighbours, further downwind (rule 2).
		for n in cells_near(_pos[id], reach):
			if n == id or _fire[n] > 0.0 or _fuel[n] <= 0.0:
				continue
			var to := _pos[n] - _pos[id]
			to.y = 0.0
			var d := to.length()
			var along := to.normalized().dot(wind_dir) if d > 0.001 else 0.0
			var limit := SPREAD + WIND_REACH * wind_k * maxf(along, 0.0)
			if d > limit:
				continue
			_wet[n] = maxf(_wet[n] - DRY_RATE * dt, 0.0)
			var wet_n := maxf(_wet[n], soak)
			if wet_n >= WET_STOPS:
				continue
			var gain := HEAT_RATE * dt * _fire[id] * (1.0 + wind_k * along) * (1.0 - wet_n)
			_heat[n] += maxf(gain, 0.0)
			if _heat[n] >= 1.0:
				to_light.append(n)
	for n in to_light:
		_try_ignite(n)
	if wind_k > 0.0 and wind.length() >= WIND_PUSH_SPEED:
		_wind_on_props(dt)


func _try_ignite(id: int) -> bool:
	if not _ok(id) or _fire[id] > 0.0 or _fuel[id] <= 0.0 or wet(id) >= WET_STOPS:
		return false
	if not bool(MATERIALS.get(_material[id], {}).get("flammable", false)):
		return false
	if _burning.size() >= MAX_BURNING:
		return false
	_fire[id] = 1.0
	_heat[id] = 0.0
	_burning[id] = true
	ignited.emit(id)
	_sync_node(id)
	# The ground it could reach becomes cells now, at the widest windy reach.
	_wake_ground(_pos[id], SPREAD + WIND_REACH)
	return true


func _put_out(id: int) -> void:
	_fire[id] = 0.0
	_burning.erase(id)
	extinguished.emit(id)
	_sync_node(id)


## Lit fires light what is pushed into them: heat sources (group
## "heat_source" with heat_at) and the fire stations (hearths, ovens).
func _heat_sources() -> void:
	if not is_inside_tree():
		return
	for source in get_tree().get_nodes_in_group(ElementState.HEAT_GROUP):
		if source is Node3D and source.has_method(&"heat_at"):
			var at := (source as Node3D).global_position
			_wake_ground(at, 1.0)
			for id in cells_near(at, 1.0):
				if float(source.heat_at(_pos[id])) >= 0.6:
					_ignite_loose(id)
	for station in get_tree().get_nodes_in_group(&"station"):
		if station is Node3D and FIRE_STATIONS.has(station.get(&"station_id")):
			for id in cells_near((station as Node3D).global_position, FIRE_STATION_REACH):
				_ignite_loose(id)


## Fire reaches a cell unless it is in her arms.
func _ignite_loose(id: int) -> void:
	var prop := _node[id] as Prop
	if prop and is_instance_valid(prop) and prop.carried:
		return
	_try_ignite(id)


## Wind shoves light loose props (rule 1) at gusts.
func _wind_on_props(dt: float) -> void:
	if not is_inside_tree():
		return
	var push := Vector3(wind.x, 0.0, wind.z) * 0.35
	for p in get_tree().get_nodes_in_group(Prop.GROUP):
		var prop := p as Prop
		if prop == null or prop.carried or prop.freeze or prop.mass > WIND_PUSH_MASS:
			continue
		prop.apply_central_impulse(push * prop.mass * dt)


func _follow_nodes() -> void:
	for id: int in _tracked.keys():
		var node := _node[id] as Node3D
		if not is_instance_valid(node):
			remove_cell(id)
			continue
		var at := node.global_position
		if at.distance_squared_to(_pos[id]) > 0.04:
			_hash_remove(id)
			_pos[id] = at
			_hash_add(id)
		if node is Prop:
			_wet[id] = maxf(_wet[id], (node as Prop).wet)


## Mirrors a cell's state onto the Prop it follows.
func _sync_node(id: int) -> void:
	var prop := _node[id] as Prop
	if prop and is_instance_valid(prop):
		prop.burning = _fire[id]
		prop.wet = _wet[id]


## A story scene runs (the spring weather steps aside for it, and so does fire).
func _story_held() -> bool:
	var spring := get_tree().get_first_node_in_group(&"spring_weather") if is_inside_tree() else null
	return spring != null and bool(spring.get(&"held"))


## Wind in m/s: a Weather node's when there is one, else the spring weather's gusts.
func _world_wind() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var weather := Weather.find(get_tree())
	if weather:
		return weather.wind_at(global_position)
	var spring := get_tree().get_first_node_in_group(&"spring_weather")
	if spring and spring.has_method(&"wind_ms"):
		return spring.call(&"wind_ms")
	return Vector3.ZERO


func _on_burnt_out(id: int) -> void:
	_fx.douse(id, false)
	# Burnt grass: the square's clumps go and the ground is scorched.
	var key: Variant = _cell_square.get(id)
	if key != null and not _burnt_at.has(key):
		var entry: Array = _woken.get(key, [])
		var fuel := _ground.get(entry[0]) as GroundFuel if not entry.is_empty() else null
		if fuel:
			var k: Vector2i = key
			var at := Vector3((k.x + 0.5) * GroundFuel.STEP, fuel.height_at(k), (k.y + 0.5) * GroundFuel.STEP)
			var hours := game_hours()
			_burnt_at[k] = hours
			scorch.burn(entry[0], fuel, k, at, hours)
	# A burnt-out crate or log falls to ash.
	var prop := _node[id] as Prop
	if prop and is_instance_valid(prop):
		prop.shatter()


func _ok(id: int) -> bool:
	return id >= 0 and id < _alive.size() and _alive[id] == 1


func _key(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.y / CELL), floori(p.z / CELL))


func _hash_add(id: int) -> void:
	var k := _key(_pos[id])
	var arr: PackedInt32Array = _hash.get(k, PackedInt32Array())
	arr.append(id)
	_hash[k] = arr


func _hash_remove(id: int) -> void:
	var k := _key(_pos[id])
	var arr: PackedInt32Array = _hash.get(k, PackedInt32Array())
	var i := arr.find(id)
	if i >= 0:
		arr.remove_at(i)
	if arr.is_empty():
		_hash.erase(k)
	else:
		_hash[k] = arr


# --- debug overlay ----------------------------------------------------------

const DEBUG_ACTION := &"debug_chemistry"


## F8 toggles the chemistry overlay: a dot per cell (red burning, blue wet, grey burnt, green fuel).
func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action(DEBUG_ACTION) and event.is_action_pressed(DEBUG_ACTION):
		toggle_overlay()


func toggle_overlay() -> bool:
	if _overlay == null:
		_overlay = ElementOverlay.new()
		_overlay.name = "Overlay"
		add_child(_overlay)
		_overlay.visible = false
	_overlay.visible = not _overlay.visible
	if _overlay.visible:
		_overlay.redraw(self)
	return _overlay.visible


## The overlay's view of one cell: [position, colour].
func debug_cells() -> Array:
	var out := []
	for id in _alive.size():
		if not _alive[id]:
			continue
		var c := Color(0.5, 0.9, 0.55)
		if _fire[id] > 0.0:
			c = Color(1.0, 0.3, 0.2)
		elif is_burnt(id):
			c = Color(0.35, 0.33, 0.36)
		elif wet(id) >= WET_STOPS:
			c = Color(0.35, 0.55, 1.0)
		out.append([_pos[id], c])
	return out


func _ensure_action() -> void:
	if InputMap.has_action(DEBUG_ACTION):
		return
	InputMap.add_action(DEBUG_ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	InputMap.action_add_event(DEBUG_ACTION, key)

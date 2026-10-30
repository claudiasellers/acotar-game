## The estate's ward (canon: the manor is warded): a glamour veil along every
## stretch of the estate's edge that faces a region Feyre can walk while the
## grounds are still locked. Seen from afar it is barely there; close up it
## shimmers rose-gold and rings where she touches it. It blocks from the
## ground to RegionGate.min_height() and fades away when manor_grounds unlocks.
## The sentry gate stays the visible front door: the veil runs along the gate
## line and leaves the gate's own span to the gilt leaves.
##
## Which edges get a veil is read from data, not hand-placed: the estate's
## RegionDef neighbours, the phase table (a neighbour is open while the grounds
## are locked when it unlocks in an earlier phase) and ManorSitePlan.BOUNDS.
class_name ManorWardVeil
extends RegionGate

const ESTATE_DEF := "res://data/regions/spring_court/manor_estate.tres"
const REGION_DIR := "res://data/regions/spring_court/"
const PHASES := "res://data/phases/spring_court_phases.tres"
const SHADER := preload("res://world/spring_court/manor_estate/grounds/ward_veil.gdshader")
## Chunk length (m) along a segment: each chunk sits on the ground under it.
const CHUNK := 20.0
const THICKNESS := 0.6
const FADE_SECONDS := 1.6
## How close (m) to the veil plane counts as touching it.
const TOUCH := 0.9

var material := ShaderMaterial.new()
var segments_cache: Array = []
var _player: Node3D
var _fade: Tween
## Seconds since she last touched the veil (drives the ripple ring).
var _contact_age: float = 100.0


static func build(parent: Node3D) -> ManorWardVeil:
	var veil := ManorWardVeil.new()
	veil.name = "WardVeil"
	veil.region_id = ManorSitePlan.REGION_GROUNDS
	veil.material.shader = SHADER
	var height := RegionGate.min_height()
	var i := 0
	for seg: Array in segments():
		veil._build_segment(i, seg[0], seg[1], height)
		i += 1
	parent.add_child(veil)
	return veil


## Neighbouring regions that can be open while manor_grounds is locked.
static func open_neighbours() -> PackedStringArray:
	var order := _unlock_order()
	var grounds: int = order.get(String(ManorSitePlan.REGION_GROUNDS), 1 << 30)
	var out := PackedStringArray()
	var estate := load(ESTATE_DEF) as RegionDef
	for n in estate.neighbors:
		if int(order.get(n, 1 << 30)) < grounds:
			out.append(n)
	return out


## Veil segments as [Vector2 from, Vector2 to] in world x/z. The side of the
## bounds facing each open neighbour gets a veil; the side holding the sentry
## gate runs along the gate line instead, leaving the gate opening.
static func segments() -> Array:
	var b := ManorSitePlan.BOUNDS
	var gate := ManorSitePlan.SENTRY_GATE
	var gap := ManorForecourt.PIER_X
	var out: Array = []
	var sides := {}
	for n in open_neighbours():
		var def := load(REGION_DIR + n + ".tres") as RegionDef
		if def == null:
			continue
		var c := Vector2(def.center.x, def.center.z)
		var off := (c - b.get_center()) / (b.size * 0.5)
		sides[(&"south" if off.y > 0.0 else &"north") if absf(off.y) >= absf(off.x) \
				else (&"east" if off.x > 0.0 else &"west")] = true
	for side: StringName in sides:
		match side:
			&"south":
				var z := gate.y if b.has_point(gate) else b.end.y
				out.append([Vector2(b.position.x, z), Vector2(gate.x - gap, z)])
				out.append([Vector2(gate.x + gap, z), Vector2(b.end.x, z)])
			&"north":
				out.append([Vector2(b.position.x, b.position.y), Vector2(b.end.x, b.position.y)])
			&"east":
				out.append([Vector2(b.end.x, b.position.y), Vector2(b.end.x, b.end.y)])
			&"west":
				out.append([Vector2(b.position.x, b.position.y), Vector2(b.position.x, b.end.y)])
	return out


## Region id -> index of the phase that unlocks it, following the phase chain.
static func _unlock_order() -> Dictionary:
	var phase_set := load(PHASES) as PhaseSet
	var order := {}
	var id := phase_set.start_phase
	var i := 0
	while id != &"" and i < 64:
		var phase := phase_set.get_phase(id)
		if phase == null:
			break
		for r in phase.unlocked_regions:
			if not order.has(r):
				order[r] = i
		id = phase.next_phase
		i += 1
	return order


func _ready() -> void:
	super()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D


func _physics_process(delta: float) -> void:
	if not visible:
		return
	if _contact_age < 2.0:
		_contact_age += delta
		material.set_shader_parameter(&"contact_age", _contact_age)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	var p := _player.global_position + Vector3.UP
	material.set_shader_parameter(&"player_position", p)
	for seg: Array in segments_cache:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
		if q.distance_to(Vector2(p.x, p.z)) < TOUCH and _contact_age > 0.6:
			_contact_age = 0.0
			material.set_shader_parameter(&"contact_position", Vector3(q.x, p.y, q.y))


## Fades out (instead of vanishing) when the grounds unlock.
func refresh() -> void:
	var locked := is_locked()
	for body in find_children("*", "CollisionObject3D", true, false):
		body.process_mode = Node.PROCESS_MODE_INHERIT if locked else Node.PROCESS_MODE_DISABLED
	if _fade and _fade.is_valid():
		_fade.kill()
	if locked:
		visible = true
		material.set_shader_parameter(&"fade", 1.0)
	elif visible and is_inside_tree():
		_fade = create_tween()
		_fade.tween_method(func(f: float) -> void: material.set_shader_parameter(&"fade", f), 1.0, 0.0, FADE_SECONDS)
		_fade.tween_callback(func() -> void: visible = false)
	else:
		visible = false


func _build_segment(index: int, from: Vector2, to: Vector2, height: float) -> void:
	segments_cache.append([from, to])
	var length := from.distance_to(to)
	var steps := maxi(1, ceili(length / CHUNK))
	var dir := (to - from).normalized()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "VeilBody%d" % index
	body.collision_layer = 1
	body.collision_mask = 0
	for k in steps:
		var a := from.lerp(to, float(k) / steps)
		var b := from.lerp(to, float(k + 1) / steps)
		var ya := ManorGrounds.ground(a.x, a.y)
		var yb := ManorGrounds.ground(b.x, b.y)
		var base := minf(ya, yb) - 0.5
		var top := maxf(ya, yb) + height
		var u0 := float(k) / steps
		var u1 := float(k + 1) / steps
		var p00 := Vector3(a.x, ya - 0.5, a.y)
		var p10 := Vector3(b.x, yb - 0.5, b.y)
		var p01 := Vector3(a.x, ya + height, a.y)
		var p11 := Vector3(b.x, yb + height, b.y)
		for v: Array in [[p00, Vector2(u0, 0)], [p10, Vector2(u1, 0)], [p11, Vector2(u1, 1)],
				[p00, Vector2(u0, 0)], [p11, Vector2(u1, 1)], [p01, Vector2(u0, 1)]]:
			st.set_uv(v[1])
			st.add_vertex(v[0])
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(a.distance_to(b), top - base, THICKNESS)
		cs.shape = box
		var mid := (a + b) * 0.5
		cs.position = Vector3(mid.x, (base + top) * 0.5, mid.y)
		cs.rotation.y = -atan2(dir.y, dir.x)
		body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "Veil%d" % index
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	add_child(body)

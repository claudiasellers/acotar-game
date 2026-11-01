## The things on and around the long table in the entrance hall (ch 17),
## built in code like the other p3 spaces. Local frame: the table's centre on
## the floor, +X along the table (his head at -X), Feyre's side -Z (the
## stairs), Tamlin's +Z (the front doors).
##   Table: "the long table in the center of the hall" [C], gilded rosewood [X].
##   Vase: Lucien shoves it off; glass and petals on the marble [C].
##   Bowl and linen: "steaming water and bandages just appeared" [C].
##   Blood: on the table, dripping, and the puddle she stands in "until it
##   grew cold" [C].
class_name TriageProps
extends RefCounted

const TABLE_SIZE := Vector3(2.8, 0.8, 1.0)
const ROSEWOOD := Color(0.42, 0.20, 0.18)
const GILT := Color(0.93, 0.76, 0.38)
const PEARL := Color(0.96, 0.93, 0.90)
const SILVER := Color(0.82, 0.84, 0.88)
const BLOOD := Color(0.46, 0.0, 0.02)
const BLOOD_GLOW := Color(0.32, 0.0, 0.015)
const PETALS: Array[Color] = [Color(0.98, 0.70, 0.78), Color(0.86, 0.74, 0.96), Color(0.99, 0.93, 0.70)]
## Where the bowl, the linen, his hand and the stumps sit, table-local.
const BOWL_AT := Vector3(0.95, 0.8, -0.28)
const LINEN_AT := Vector3(1.25, 0.8, -0.2)
const HAND_AT := Vector3(-1.35, 0.72, -0.5)
const WOUNDS_AT := Vector3(-0.35, 1.0, 0.0)
## The puddle's radius (m) as soon as it shows, and when he has bled out.
const POOL_MIN := 0.35
const POOL_MAX := 1.5
## Under the head end, Feyre's side, off the runner's edge onto the marble.
const POOL_AT := Vector3(-1.05, 0.004, -0.75)
const DRIP_COUNT := 5
## The rose runner under the table: half its width (prop_catalog rug_runner).
const RUNNER_HALF := 0.7
## The trail from the front doors, on the marble just past the runner.
const TRAIL_X := 1.05
const TRAIL_TO_Z := 6.3


static func mat(color: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func box(size: Vector3, m: Material, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	return mi


static func cylinder(r_top: float, r_bottom: float, h: float, m: Material, at: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = h
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	return mi


## The table with gilt rails and four turned legs, plus collision.
static func table() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "HallTable"
	var top_y := TABLE_SIZE.y
	body.add_child(box(Vector3(TABLE_SIZE.x, 0.08, TABLE_SIZE.z), mat(ROSEWOOD, 0.25), Vector3(0, top_y - 0.04, 0)))
	var gilt := mat(GILT, 0.3, 0.8)
	for z in [-1.0, 1.0]:
		body.add_child(box(Vector3(TABLE_SIZE.x + 0.04, 0.05, 0.03), gilt, Vector3(0, top_y - 0.1, z * (TABLE_SIZE.z * 0.5 + 0.01))))
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			var leg := cylinder(0.05, 0.035, top_y - 0.08, mat(ROSEWOOD, 0.3), Vector3(x * 1.25, (top_y - 0.08) * 0.5, z * 0.4))
			body.add_child(leg)
			body.add_child(cylinder(0.06, 0.06, 0.05, gilt, Vector3(x * 1.25, 0.03, z * 0.4)))
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = TABLE_SIZE
	shape.shape = b
	shape.position = Vector3(0, top_y * 0.5, 0)
	body.add_child(shape)
	return body


## A green-glass vase of roses, lilac and butter blooms on the table.
static func vase() -> Node3D:
	var v := Node3D.new()
	v.name = "Vase"
	var glass := mat(Color(0.55, 0.85, 0.70, 0.55), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	v.add_child(cylinder(0.07, 0.1, 0.32, glass, Vector3(0, 0.16, 0)))
	for i in 7:
		var a := TAU * i / 7.0
		var bloom := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.06
		s.height = 0.1
		bloom.mesh = s
		bloom.material_override = mat(PETALS[i % PETALS.size()], 0.5)
		bloom.position = Vector3(cos(a) * 0.08, 0.38 + 0.03 * (i % 2), sin(a) * 0.08)
		v.add_child(bloom)
	v.position = Vector3(0.2, TABLE_SIZE.y, 0)
	return v


## Glass and petals on the floor where the vase landed (Feyre's side).
static func shatter(seed_value: int = 17) -> Node3D:
	var n := Node3D.new()
	n.name = "Shattered"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var glass := mat(Color(0.6, 0.9, 0.75, 0.6), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 14:
		var shard := box(Vector3(rng.randf_range(0.03, 0.09), 0.006, rng.randf_range(0.02, 0.06)), glass,
			Vector3(rng.randf_range(-0.6, 0.9), 0.004, -0.8 - rng.randf_range(0.0, 0.9)))
		shard.rotation.y = rng.randf() * TAU
		n.add_child(shard)
	for i in 22:
		var petal := box(Vector3(0.05, 0.004, 0.035), mat(PETALS[i % PETALS.size()], 0.5),
			Vector3(rng.randf_range(-0.8, 1.1), 0.006, -0.7 - rng.randf_range(0.0, 1.2)))
		petal.rotation.y = rng.randf() * TAU
		n.add_child(petal)
	return n


## Tamlin's conjured bowl of steaming water, and the folded linen.
static func supplies() -> Node3D:
	var n := Node3D.new()
	n.name = "Supplies"
	n.add_child(cylinder(0.16, 0.1, 0.09, mat(SILVER, 0.2, 0.9), BOWL_AT + Vector3(0, 0.045, 0)))
	var water := cylinder(0.14, 0.14, 0.01, mat(Color(0.75, 0.82, 0.88), 0.05), BOWL_AT + Vector3(0, 0.08, 0))
	water.name = "Water"
	n.add_child(water)
	var steam := GPUParticles3D.new()
	steam.name = "Steam"
	steam.amount = 12
	steam.lifetime = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0, 0.05, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color = Color(1, 1, 1, 0.25)
	steam.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var qm := mat(Color(1, 1, 1, 0.25), 1.0)
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	q.material = qm
	steam.draw_pass_1 = q
	steam.position = BOWL_AT + Vector3(0, 0.1, 0)
	n.add_child(steam)
	var linen := Node3D.new()
	linen.name = "Linen"
	for i in TriageState.LINEN_STRIPS:
		linen.add_child(box(Vector3(0.24, 0.025, 0.12), mat(PEARL, 0.8), LINEN_AT + Vector3(0, 0.013 + 0.026 * i, 0)))
	n.add_child(linen)
	return n


## The blood: a spreading slick on the tabletop round the stumps, streams
## off the head end of the table, the puddle on the marble she stands in, and
## the trail they carried him in on, from the front doors. Grow it with
## set_pool(); it shows from the first seconds (R3: horror is never toned down).
##   The rose runner lies under the table along Z, |x| < RUNNER_HALF, so the
##   puddle and the trail sit on the pale marble beside it, where red reads.
##   The hall is dark at night: the blood is a saturated wet red with a little
##   emission so it still reads at gameplay distance without a lamp on it.
static func pool() -> Node3D:
	var n := Node3D.new()
	n.name = "BloodPool"
	var wet := blood_mat()
	n.add_child(_disc("TableSlick", wet, Vector3(WOUNDS_AT.x - 0.2, TABLE_SIZE.y + 0.004, 0.0)))
	n.add_child(_disc("FloorPool", wet, POOL_AT))
	var drips := Node3D.new()
	drips.name = "Drips"
	var h := TABLE_SIZE.y - 0.02
	for i in DRIP_COUNT:
		var x := -TABLE_SIZE.x * 0.5 + 0.12 + 0.11 * i
		var r := 0.016 + 0.006 * float(i % 2)
		drips.add_child(cylinder(r, r * 0.7, h, wet, Vector3(x, h * 0.5, -TABLE_SIZE.z * 0.5 - 0.015)))
	n.add_child(drips)
	n.add_child(trail(wet))
	set_pool(n, 0.0)
	return n


## Drops and smears on the marble from the front doors to the table, beside the
## runner: they carried him in bleeding. Fixed seed, so every night matches.
static func trail(m: Material) -> Node3D:
	var t := Node3D.new()
	t.name = "Trail"
	var rng := RandomNumberGenerator.new()
	rng.seed = 1717
	var z := TABLE_SIZE.z * 0.5 + 0.3
	while z < TRAIL_TO_Z:
		var d := _disc("Drop", m, Vector3(TRAIL_X + rng.randf_range(-0.18, 0.18), 0.003, z))
		var r := rng.randf_range(0.05, 0.11)
		d.scale = Vector3(r, 1.0, r * rng.randf_range(1.0, 1.8))
		t.add_child(d)
		z += rng.randf_range(0.22, 0.42)
	return t


static func blood_mat() -> StandardMaterial3D:
	var m := mat(BLOOD, 0.04, 0.0)
	m.metallic_specular = 0.9
	m.emission_enabled = true
	m.emission = BLOOD_GLOW
	m.emission_energy_multiplier = 0.55
	return m


static func _disc(disc_name: String, m: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = disc_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.004
	mesh.radial_segments = 24
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	return mi


## lost: blood lost so far, 0..100.
static func set_pool(pool_node: Node3D, lost: float) -> void:
	var f := clampf(lost / 100.0, 0.0, 1.0)
	var slick := pool_node.get_node_or_null(^"TableSlick") as Node3D
	if slick:
		# Already soaked when he's laid down; spreads to the table's edges.
		var r := clampf(0.3 + 1.6 * sqrt(f), 0.3, 0.48)
		slick.scale = Vector3(r * 2.2, 1.0, r)
		slick.visible = lost > 0.2
	var floor_pool := pool_node.get_node_or_null(^"FloorPool") as Node3D
	if floor_pool:
		var fr := maxf(POOL_MIN + (POOL_MAX - POOL_MIN) * sqrt(f), 0.01)
		floor_pool.scale = Vector3(fr, 1.0, fr * 0.8)
		floor_pool.visible = lost > 0.5
	var drips := pool_node.get_node_or_null(^"Drips") as Node3D
	if drips:
		drips.visible = lost > 0.2


## A rag she has wet, shown in her hand's place on the table edge.
static func rag() -> MeshInstance3D:
	var r := box(Vector3(0.14, 0.02, 0.1), mat(Color(0.93, 0.88, 0.85), 0.9), BOWL_AT + Vector3(-0.25, 0.01, 0))
	r.name = "Rag"
	return r

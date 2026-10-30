## Everything outside the house: gardens, structures, ambient life and the
## manor grade. Called from ManorEstate._ready(). Each part builds itself from
## code with fixed seeds (R15) through a GroundsBatch, so a part is a handful of
## merged meshes, prop multimeshes and one StaticBody3D on layer 1.
class_name ManorGrounds
extends RefCounted

## Landmarks visible from 200 m+ (node names under Grounds, group "landmark").
const LANDMARK_GROUP := &"landmark"


static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Grounds"
	parent.add_child(root)
	ManorForecourt.build(root)
	ManorTerraceBuilder.build(root)
	ManorRoseGarden.build(root)
	ManorHedgeMaze.build(root)
	ManorGlassHouses.build(root)
	ManorKitchenGarden.build(root)
	ManorStables.build(root)
	ManorPond.build(root)
	ManorOrchard.build(root)
	ManorBelvedere.build(root)
	ManorAmbientLife.build(root)
	var grade := RegionGrade.new()
	grade.name = "ManorGrade"
	grade.grade = &"manor"
	grade.bounds = ManorSitePlan.BOUNDS
	grade.blend_seconds = 4.0
	root.add_child(grade)
	return root


## Marks a node as a named landmark (counted by the coverage report).
static func landmark(node: Node3D, landmark_name: String) -> void:
	node.add_to_group(LANDMARK_GROUP)
	node.set_meta(&"landmark", landmark_name)


## Landmarks of the estate for the coverage report (manor towers are the house lane's).
const LANDMARKS := ["manor_towers", "belvedere", "palm_house_dome", "stable_clock_tower"]


# --- Shared materials (R3: pearl, blush, gold; glossy; never grey) -------------

static func stone() -> Material:
	return EstateKit.mat(EstateKit.WARM_STONE, 0.75)


static func marble() -> Material:
	return EstateKit.pearl(EstateKit.MARBLE, "grounds_marble")


static func pearl() -> Material:
	return EstateKit.pearl(EstateKit.PEARL)


static func gold() -> Material:
	return EstateKit.mat(EstateKit.GOLD, 0.25, 0.85, "grounds_gold")


static func iron_gold() -> Material:
	return EstateKit.mat(Color(0.95, 0.74, 0.40), 0.3, 0.8, "grounds_iron_gold")


static func wood() -> Material:
	return EstateKit.mat(EstateKit.OAK, 0.7)


static func wood_dark() -> Material:
	return EstateKit.mat(EstateKit.OAK_DARK, 0.7)


static func gravel() -> Material:
	return EstateKit.mat(EstateKit.GRAVEL, 0.95, 0.0, "grounds_gravel")


static func hedge() -> Material:
	return EstateKit.mat(EstateKit.HEDGE, 0.9, 0.0, "grounds_hedge")


static func roof() -> Material:
	return EstateKit.mat(EstateKit.SLATE, 0.5, 0.0, "grounds_roof")


static func rose_roof() -> Material:
	return EstateKit.mat(Color(0.95, 0.56, 0.66), 0.5, 0.0, "grounds_rose_roof")


static func brick() -> Material:
	return EstateKit.mat(Color(0.98, 0.74, 0.70), 0.85, 0.0, "grounds_brick")


static func plaster() -> Material:
	return EstateKit.mat(EstateKit.CREAM, 0.8, 0.0, "grounds_plaster")


static func soil() -> Material:
	return EstateKit.mat(Color(0.55, 0.38, 0.30), 0.95, 0.0, "grounds_soil")


static func grass() -> Material:
	return EstateKit.mat(Color(0.52, 0.82, 0.44), 0.9, 0.0, "grounds_grass")


static func glass() -> Material:
	var key := "grounds_glass"
	if EstateKit._materials.has(key):
		return EstateKit._materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.95, 1.0, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.04
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 0.5
	EstateKit._materials[key] = m
	return m


## Glossy periwinkle water (R3).
static func water() -> Material:
	var key := "grounds_water"
	if EstateKit._materials.has(key):
		return EstateKit._materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.70, 1.0, 0.84)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.03
	m.metallic = 0.3
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.05
	m.rim_enabled = true
	m.rim = 0.4
	m.rim_tint = 0.8
	EstateKit._materials[key] = m
	return m


## Soft glowing material for lamps and faelight globes.
static func glow(color: Color = Color(1.0, 0.9, 0.6)) -> Material:
	var key := "grounds_glow|" + color.to_html()
	if EstateKit._materials.has(key):
		return EstateKit._materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	EstateKit._materials[key] = m
	return m


static func ground(x: float, z: float) -> float:
	return WorldHeight.height_at(x, z)


## A small building: four walls with a door gap on one side, gable roof.
## `door_side` is "n", "s", "e" or "w". Returns the floor height.
static func cottage(b: GroundsBatch, rect: Rect2, wall_h: float, wall_mat: Material, roof_mat: Material,
		door_side: String = "s", door_w: float = 1.8, floor_mat: Material = null) -> float:
	var y := ground(rect.get_center().x, rect.get_center().y)
	var t := 0.4
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	var base := y - 0.6
	var h := wall_h + 0.6
	_wall_with_gap(b, Vector3(x0, base, z0), Vector3(x1, base, z0), t, h, wall_mat, door_w if door_side == "n" else 0.0)
	_wall_with_gap(b, Vector3(x0, base, z1), Vector3(x1, base, z1), t, h, wall_mat, door_w if door_side == "s" else 0.0)
	_wall_with_gap(b, Vector3(x0, base, z0), Vector3(x0, base, z1), t, h, wall_mat, door_w if door_side == "w" else 0.0)
	_wall_with_gap(b, Vector3(x1, base, z0), Vector3(x1, base, z1), t, h, wall_mat, door_w if door_side == "e" else 0.0)
	b.box(Vector3(rect.get_center().x, y + 0.05, rect.get_center().y), Vector3(rect.size.x, 0.1, rect.size.y),
			floor_mat if floor_mat else wood(), true)
	var along_x := rect.size.x >= rect.size.y
	var roof_size := Vector3(rect.size.x + 0.8, minf(rect.size.x, rect.size.y) * 0.45, rect.size.y + 0.8)
	if along_x:
		b.gable(Vector3(rect.get_center().x, y + wall_h, rect.get_center().y), Vector3(roof_size.x, roof_size.y, roof_size.z), roof_mat)
	else:
		b.gable(Vector3(rect.get_center().x, y + wall_h, rect.get_center().y), Vector3(roof_size.z, roof_size.y, roof_size.x), roof_mat, PI * 0.5)
	# trim under the eaves
	b.box(Vector3(rect.get_center().x, y + wall_h - 0.1, rect.get_center().y), Vector3(rect.size.x + 0.5, 0.2, rect.size.y + 0.5), pearl(), false)
	return y


## A wall from a to b (ground plane points with base y), with a centred gap.
static func _wall_with_gap(b: GroundsBatch, a: Vector3, c: Vector3, t: float, h: float, m: Material, gap: float, gap_h: float = 2.6) -> void:
	if gap <= 0.0:
		b.span(a, c, t, h, m)
		return
	var mid := (a + c) * 0.5
	var dir := (c - a).normalized()
	b.span(a, mid - dir * gap * 0.5, t, h, m)
	b.span(mid + dir * gap * 0.5, c, t, h, m)
	var lintel_a := mid - dir * gap * 0.5 + Vector3.UP * (0.6 + gap_h)
	var lintel_b := mid + dir * gap * 0.5 + Vector3.UP * (0.6 + gap_h)
	b.span(lintel_a, lintel_b, t, h - 0.6 - gap_h, m)


## A run of fence: posts every `step` with two rails, colliding.
static func fence(b: GroundsBatch, points: PackedVector2Array, step: float = 3.0, height: float = 1.3,
		post_mat: Material = null, rail_mat: Material = null, gaps: Array = []) -> void:
	var pm := post_mat if post_mat else pearl()
	var rm := rail_mat if rail_mat else pearl()
	for i in points.size() - 1:
		var a := points[i]
		var c := points[i + 1]
		var n := maxi(1, ceili(a.distance_to(c) / step))
		for k in n:
			var p0 := a.lerp(c, float(k) / n)
			var p1 := a.lerp(c, float(k + 1) / n)
			var skip := false
			for g: Vector2 in gaps:
				if p0.lerp(p1, 0.5).distance_to(g) < step * 0.75:
					skip = true
			var y0 := ground(p0.x, p0.y)
			var y1 := ground(p1.x, p1.y)
			b.box(Vector3(p0.x, y0 + height * 0.5, p0.y), Vector3(0.18, height + 0.2, 0.18), pm, true)
			if skip:
				continue
			var ym := (y0 + y1) * 0.5
			var d := p1 - p0
			var yaw := atan2(-d.y, d.x)
			var len := d.length()
			var pitch := atan2(y1 - y0, len)
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, pitch)
			for r: float in [0.45, 0.95]:
				b.box(Vector3((p0.x + p1.x) * 0.5, ym + height * r, (p0.y + p1.y) * 0.5), Vector3(len, 0.1, 0.07), rm, false, 0.0, basis)
			b.add_box_shape(Transform3D(Basis(Vector3.UP, yaw), Vector3((p0.x + p1.x) * 0.5, ym + height * 0.5, (p0.y + p1.y) * 0.5)), Vector3(len, height, 0.2))
	if points.size() > 0:
		var e := points[points.size() - 1]
		b.box(Vector3(e.x, ground(e.x, e.y) + height * 0.5, e.y), Vector3(0.18, height + 0.2, 0.18), pm, true)


## A lamp post with a glowing globe (shared look; the props lane's lamp_post when it lands).
static func lamp(b: GroundsBatch, x: float, z: float) -> void:
	b.prop_on_ground(&"lamp_post", x, z)


## Rect2 of a circle, for footprints.
static func circle_rect(c: Vector2, r: float) -> Rect2:
	return Rect2(c - Vector2.ONE * r, Vector2.ONE * r * 2.0)

## Generates the village region (deterministic, seeded):
##   godot --headless -s res://world/human_realm/village/village_gen.gd
## Writes scatter/<layer>.tres, village_report.json and village.tscn.
## Assets come from tools/blender/human_realm/village_buildings.py and
## village_props.py (run those first when they change).
extends SceneTree

const DIR := "res://world/human_realm/village"
const SCENE := DIR + "/village.tscn"
const REPORT := DIR + "/village_report.json"


## Landmark markers that double as Act I story anchors (world.md).
const VILLAGE_ANCHORS := {"PeltCustomerSpot": "act1_fur_stall"}


func _initialize() -> void:
	var plan_script: GDScript = load("res://world/human_realm/village/village_plan.gd")
	if plan_script == null or not plan_script.can_instantiate():
		push_error("village_gen: village_plan.gd failed to compile")
		quit(1)
		return
	var plan: VillagePlan = plan_script.new()
	plan.verbose = true
	plan.generate()
	DirAccess.make_dir_recursive_absolute(DIR + "/scatter")
	for f in DirAccess.get_files_at(DIR + "/scatter"):
		DirAccess.remove_absolute(DIR + "/scatter/" + f)
	var saved: Array[ScatterLayer] = []
	for layer in plan.layer_list():
		var path := "%s/scatter/%s.tres" % [DIR, layer.id]
		layer.mesh = null
		layer.impostor_mesh = null
		var err := ResourceSaver.save(layer, path, ResourceSaver.FLAG_CHANGE_PATH)
		if err != OK:
			push_error("village_gen: cannot save %s (%d)" % [path, err])
		saved.append(layer)
	var report := plan.report()
	ScatterReport.save(report, REPORT)
	_save_region_def(plan)
	var root := _build_scene(plan, saved)
	var packed := PackedScene.new()
	packed.pack(root)
	var err := ResourceSaver.save(packed, SCENE)
	root.free()
	var total := 0
	for l in saved:
		total += l.count()
	print("village_gen: %d layers, %d instances, %d buildings, %d landmarks, %d lights, %d smokes -> %s" % [
		saved.size(), total, plan.buildings.size(), plan.landmark_count(), plan.lights.size(), plan.smokes.size(),
		JSON.stringify(report)])
	quit(0 if err == OK else 1)


## data/regions/human_realm/village.tres. Neighbours are left for the world
## lane to fill at integration (a neighbour without a RegionDef fails the smoke).
func _save_region_def(plan: VillagePlan) -> void:
	var def := RegionDef.new()
	def.id = VillagePlan.REGION_ID
	def.scene_path = SCENE
	var c := plan.rect.get_center()
	def.center = Vector3(c.x, WorldHeight.height_at(c.x, c.y), c.y)
	def.radius = plan.rect.size.length() * 0.5
	def.neighbors = PackedStringArray(["cottage", "hunting_forest"])
	def.report_path = REPORT
	DirAccess.make_dir_recursive_absolute("res://data/regions/human_realm")
	ResourceSaver.save(def, "res://data/regions/human_realm/village.tres")


func _own(node: Node, root: Node) -> void:
	node.owner = root
	for c in node.get_children():
		_own(c, root)


func _build_scene(plan: VillagePlan, saved: Array[ScatterLayer]) -> Node3D:
	var root := Node3D.new()
	root.name = "Village"

	var field := ScatterField.new()
	field.name = "Scatter"
	field.region_id = VillagePlan.REGION_ID
	field.layers = saved
	root.add_child(field)

	root.add_child(_build_collision(plan))

	var lm := Node3D.new()
	lm.name = "Landmarks"
	root.add_child(lm)
	for d in plan.landmarks:
		var n := Node3D.new()
		n.name = d.name
		n.transform = d.xf
		n.add_to_group(&"landmark", true)
		lm.add_child(n)
		for m: String in d.markers:
			var mk := Marker3D.new()
			mk.name = m
			mk.transform = d.markers[m]
			n.add_child(mk)
			if VILLAGE_ANCHORS.has(m):
				mk.set_meta(&"anchor_id", VILLAGE_ANCHORS[m])
				mk.add_to_group(&"story_anchor", true)

	var lights := Node3D.new()
	lights.name = "Lights"
	root.add_child(lights)
	var i := 0
	for l in plan.lights:
		var o := OmniLight3D.new()
		o.name = "%s%d" % [l.name, i]
		o.position = l.pos
		o.omni_range = l.range
		o.light_energy = l.energy
		o.light_color = l.color
		o.shadow_enabled = false
		o.distance_fade_enabled = true
		o.distance_fade_begin = 90.0
		o.distance_fade_length = 30.0
		lights.add_child(o)
		i += 1

	var smoke := Node3D.new()
	smoke.name = "ChimneySmoke"
	root.add_child(smoke)
	i = 0
	for s in plan.smokes:
		# Soft sprite plumes (quality audit B3; world/shared/fx/chimney_smoke.gd).
		smoke.add_child(ChimneySmoke.make(s, "Smoke%d" % i))
		i += 1

	var mood := Node3D.new()
	mood.name = "Mood"
	root.add_child(mood)
	for f in plan.fogs:
		var fv := FogVolume.new()
		fv.name = f.name
		fv.position = f.pos
		fv.size = f.size
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		var fm := FogMaterial.new()
		fm.density = f.density
		fm.albedo = Color(0.82, 0.85, 0.9)
		fm.edge_fade = 0.6
		fv.material = fm
		mood.add_child(fv)

	_own_children(root)
	return root


func _own_children(root: Node) -> void:
	for c in root.get_children():
		_own(c, root)


## One StaticBody3D per (collision kind, 64 m chunk) on layer 1, with a
## CollisionShape3D per instance.
func _build_collision(plan: VillagePlan) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Collision"
	var bodies := {}
	var shapes := {}
	for id: StringName in plan.layer_kind:
		var kind: StringName = plan.layer_kind[id]
		var layer: ScatterLayer = plan.layers[id]
		var specs: Array = VillagePlan.COLLIDE[kind]
		for idx in layer.count():
			var xf := layer.transform_of(idx)
			var s := xf.basis.get_scale().x
			var rot := Basis(Vector3.UP, layer.instances[idx * ScatterLayer.STRIDE + 3])
			var key := "%s_%d_%d" % [kind, floori(xf.origin.x / VillagePlan.CHUNK), floori(xf.origin.z / VillagePlan.CHUNK)]
			if not bodies.has(key):
				var b := StaticBody3D.new()
				b.name = key
				b.collision_layer = 1
				b.collision_mask = 0
				holder.add_child(b)
				bodies[key] = b
			var body: StaticBody3D = bodies[key]
			for spec: Array in specs:
				var size: Variant = spec[1]
				var sk := "%s_%s_%.1f" % [kind, str(size), s]
				if not shapes.has(sk):
					if size is Vector3:
						var bs := BoxShape3D.new()
						bs.size = size * s
						shapes[sk] = bs
					else:
						var cs := CylinderShape3D.new()
						cs.radius = size.x * s
						cs.height = size.y * s
						shapes[sk] = cs
				var cshape := CollisionShape3D.new()
				cshape.shape = shapes[sk]
				cshape.transform = Transform3D(rot, xf.origin + rot * ((spec[0] as Vector3) * s))
				body.add_child(cshape)
	return holder

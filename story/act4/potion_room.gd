## The fae village's potion room (L44; GAME_DESIGN_PLAN §5 stations: "fae
## potion room P4 (safe fae combining, tinctures)"). The Potion House stands
## on a steep bank above the village green, so the potion-maker's stillroom is
## a level stone terrace at the foot of its path [X]: a flagged floor, a low
## balustrade over the green, wisteria each side, the bench, cabinet, drying
## herbs, alembic and the copper cauldron that glows mint. The cauldron is the
## station (CookingStation with data/stations/fae_potion_room.tres): infuse,
## tincture, salve and steep, five ingredients, fae-safe.
## Anchor-local: the cauldron at the origin, -Z up the path to the house (the
## open, uphill edge; the west edge is open too), +Z and +X over the green
## behind the balustrade.
class_name PotionRoom
extends Node3D

const STATION := preload("res://data/stations/fae_potion_room.tres")
## The terrace model: deck top this far above its base; footprint half-sizes.
const DECK := 6.0
const HALF := Vector2(4.2, 3.5)

var station: CookingStation
## World height of the terrace floor.
var floor_y := 0.0


func _ready() -> void:
	floor_y = _floor_height() + 0.03
	var o := func(x: float, z: float) -> Vector3: return to_global(Vector3(x, 0.0, z))
	var c: Vector3 = o.call(0.0, 0.0)
	c.y = floor_y
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	add_child(dressing)
	_terrace(dressing)
	# The room: a rug, a wisteria canopy each side, the cabinet and drying
	# rack along the balustrade, facing up the path to the house.
	Act4Props.place(dressing, &"rug_round", c, o.call(0.0, -5.0), 1.3)
	Act4Props.place(dressing, &"wisteria_bay", o.call(-2.9, 0.6), o.call(-2.9, -5.0))
	Act4Props.place(dressing, &"wisteria_bay", o.call(2.9, 0.6), o.call(2.9, -5.0))
	Act4Props.place(dressing, &"apothecary_cabinet", o.call(-2.4, 2.1), o.call(-2.4, -5.0))
	Act4Props.place(dressing, &"drying_rack_herbs", o.call(2.3, 2.2), o.call(2.3, -5.0))
	Act4Props.place(dressing, &"stillroom_bench", o.call(-2.9, -1.0), o.call(0.0, -1.0))
	var bench_top := 0.95
	_on_top(dressing, &"alembic", o.call(-2.9, -1.6), bench_top)
	_on_top(dressing, &"vial_rack", o.call(-3.0, -0.4), bench_top)
	_on_top(dressing, &"mortar_pestle", o.call(-2.8, 0.2), bench_top)
	Act4Props.place(dressing, &"table_round", o.call(2.7, -1.2), c)
	_on_top(dressing, &"pigment_jars", o.call(2.7, -1.2), 0.75)
	_on_top(dressing, &"book_stack", o.call(2.4, -0.8), 0.75)
	Act4Props.place(dressing, &"stool", o.call(1.8, -1.9), c)
	Act4Props.place(dressing, &"basket_produce", o.call(1.2, 1.6), c)
	Act4Props.place(dressing, &"potted_roses", o.call(-1.4, 2.4), c)
	Act4Props.place(dressing, &"fern_pot", o.call(1.0, 2.5), c)
	Act4Props.place(dressing, &"faelight_lantern", o.call(-1.6, -2.6), o.call(0.0, -6.0))
	Act4Props.place(dressing, &"faelight_lantern", o.call(1.6, -2.6), o.call(0.0, -6.0))
	Act4Props.place(dressing, &"herb_bundle_hanging", o.call(0.0, 2.6), o.call(0.0, -5.0))
	# The cauldron is the station.
	var cauldron := Act4Props.place(dressing, &"fae_cauldron", c, o.call(0.0, -5.0))
	cauldron.name = "Cauldron"
	station = CookingStation.new()
	station.name = "PotionStation"
	station.station = STATION
	station.heat_radius = 2.0
	add_child(station)
	station.global_position = c + Vector3.UP * 0.5
	_glow(c + Vector3.UP * 1.1)
	_steam(c + Vector3.UP * 0.95)
	# Everything stands on the terrace floor, not the bank under it.
	for n: Node3D in dressing.get_children():
		if n.name != "Terrace":
			n.global_position.y = floor_y + float(n.get_meta(&"lift", 0.0))


## The highest ground under the terrace, so its floor never has the bank
## poking through; the downhill faces show their stone.
func _floor_height() -> float:
	var top := -INF
	for i in 5:
		for j in 5:
			var p := to_global(Vector3(lerpf(-HALF.x, HALF.x, i / 4.0), 0.0, lerpf(-HALF.y, HALF.y, j / 4.0)))
			top = maxf(top, WorldHeight.height_at(p.x, p.z))
	return top


## The terrace model with its deck and two balustrade walls as collision.
func _terrace(parent: Node3D) -> void:
	var t := Act4Props.model(&"stillroom_terrace")
	t.name = "Terrace"
	parent.add_child(t)
	t.global_transform = Transform3D(global_basis, Vector3(global_position.x, floor_y - 0.03 - DECK, global_position.z))
	var body := StaticBody3D.new()
	body.name = "TerraceBody"
	body.collision_layer = 1
	body.collision_mask = 0
	t.add_child(body)
	var shapes := [
		[Vector3(HALF.x * 2.0, DECK, HALF.y * 2.0), Vector3(0.0, DECK * 0.5, 0.0)],
		[Vector3(HALF.x * 2.0, 1.0, 0.3), Vector3(0.0, DECK + 0.5, HALF.y - 0.05)],
		[Vector3(0.3, 1.0, HALF.y * 2.0), Vector3(HALF.x - 0.05, DECK + 0.5, 0.0)],
	]
	for spec: Array in shapes:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		cs.shape = box
		cs.position = spec[1]
		body.add_child(cs)


## A small prop set on a surface `height` metres up (the bench, the table).
func _on_top(parent: Node3D, id: StringName, at: Vector3, height: float) -> void:
	var node := Act4Props.place(parent, id, at, to_global(Vector3(0, 0, -5)))
	node.set_meta(&"lift", height)


## The brew's mint light on the canopy.
func _glow(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "BrewGlow"
	light.light_color = Color(0.70, 1.0, 0.86)
	light.light_energy = 1.4
	light.omni_range = 4.5
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at


## Pearly wisps curling off the brew.
func _steam(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.name = "Steam"
	p.amount = 24
	p.lifetime = 2.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.22
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 1.0, 0.92, 0.0))
	ramp.add_point(0.3, Color(0.9, 1.0, 0.95, 0.35))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.95, 1.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	pm.color_ramp = tex
	p.process_material = pm
	p.draw_pass_1 = Act4Props._droplet_mesh(Color(0.92, 1.0, 0.96))
	add_child(p)
	p.global_position = at

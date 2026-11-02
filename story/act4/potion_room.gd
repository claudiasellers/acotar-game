## The fae village's potion room (L44; GAME_DESIGN_PLAN §5 stations: "fae
## potion room P4 (safe fae combining, tinctures)"). A room under wisteria in
## front of the Potion House [X]: the potion-maker's bench, cabinet, drying
## herbs, alembic and the copper cauldron that glows mint. The cauldron is
## the station (CookingStation with data/stations/fae_potion_room.tres):
## infuse, tincture, salve and steep, five ingredients, fae-safe.
## Anchor-local: the cauldron at the origin, the house behind (+Z).
class_name PotionRoom
extends Node3D

const STATION := preload("res://data/stations/fae_potion_room.tres")

var station: CookingStation


func _ready() -> void:
	var o := func(x: float, z: float) -> Vector3: return to_global(Vector3(x, 0.0, z))
	var c: Vector3 = o.call(0.0, 0.0)
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	add_child(dressing)
	# The room: a rug, a wisteria canopy each side, the house wall behind.
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


## A small prop set on a surface `height` metres up (the bench, the table).
func _on_top(parent: Node3D, id: StringName, at: Vector3, height: float) -> void:
	var node := Act4Props.place(parent, id, at, to_global(Vector3(0, 0, -5)))
	node.global_position.y += height


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

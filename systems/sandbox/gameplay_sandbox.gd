## Gameplay systems on the test hill: weather, a hearth, winter forage, a few
## notice moments, a stone to break arrows on, and a wardrobe and mirror for
## the dressing room. Placeholder shapes only; real regions come from the
## world lanes.
class_name GameplaySandbox
extends Node3D

## Winter human-realm forage shown on the hill, by ingredient id.
const FORAGE: Array[StringName] = [
	&"ing_snowdrop", &"ing_blackberry", &"ing_pine_resin", &"ing_willow_bark", &"ing_hazel_rod",
	&"ing_flint", &"ing_crow_feather", &"ing_hawk_feather", &"ing_pine_needles", &"ing_hawthorn_haw",
	&"ing_juniper_berry", &"ing_rose_hip", &"ing_wintergreen", &"ing_chaga", &"ing_woad", &"ing_ash_wood",
	&"ing_snowmelt_water", &"ing_hazelnut",
]
const NOTICES := [
	["sketch_snowdrop_in_snow", "A snowdrop where nothing else grows", Vector2(-6.0, 58.0)],
	["sketch_summit_light", "Light on the summit", Vector2(30.0, -40.0)],
	["sketch_thorns", "Thorns that move when you don't look", Vector2(-38.0, 22.0)],
]

## Terrain height callback (the hill's height_at).
var height_at: Callable


func _ready() -> void:
	_weather()
	_hearth(Vector2(8.0, 62.0))
	_forage()
	_notices()
	_stone(Vector2(24.0, 31.0))
	_station(&"wardrobe", Vector2(-14.0, 64.0), Color(0.96, 0.75, 0.85), Vector3(1.4, 2.2, 0.6))
	_station(&"dressing_mirror", Vector2(-17.0, 64.0), Color(0.95, 0.88, 0.6), Vector3(0.9, 1.9, 0.2))


func _y(x: float, z: float) -> float:
	return float(height_at.call(x, z)) if height_at.is_valid() else 0.0


func _weather() -> void:
	var weather := Weather.new()
	weather.name = "Weather"
	weather.base_temperature_c = 1.0
	add_child(weather)


func _hearth(at: Vector2) -> void:
	var hearth := CookingStation.new()
	hearth.name = "Campfire"
	hearth.station = load("res://data/stations/campfire.tres")
	hearth.position = Vector3(at.x, _y(at.x, at.y), at.y)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.62, 0.58, 0.56)
	for i in 8:
		var a := TAU * i / 8.0
		var rock := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.18
		s.height = 0.26
		rock.mesh = s
		rock.material_override = stone
		rock.position = Vector3(cos(a) * 0.55, 0.08, sin(a) * 0.55)
		hearth.add_child(rock)
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.65, 0.35)
	flame.light_energy = 2.5
	flame.omni_range = 7.0
	flame.position.y = 0.5
	hearth.add_child(flame)
	var fire := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.25
	cone.height = 0.5
	fire.mesh = cone
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.55, 0.2)
	glow.emission_energy_multiplier = 3.0
	glow.albedo_color = Color(1.0, 0.6, 0.25)
	fire.material_override = glow
	fire.position.y = 0.25
	hearth.add_child(fire)
	add_child(hearth)


func _forage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for n in FORAGE.size():
		var id := FORAGE[n]
		var item := ItemCatalog.get_item(id)
		var field := ForageScatter.new()
		field.name = "Forage_%s" % id
		field.item_id = id
		field.region_id = &"test_hill"
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var bloom := SphereMesh.new()
		bloom.radius = 0.09
		bloom.height = 0.16
		bloom.radial_segments = 8
		bloom.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = item.color if item else Color.WHITE
		mat.emission_enabled = true
		mat.emission = mat.albedo_color * 0.25
		bloom.material = mat
		mm.mesh = bloom
		mm.instance_count = 14
		# Each kind grows in its own patch around the spawn meadow.
		var angle := TAU * n / FORAGE.size()
		var centre := Vector2(cos(angle), sin(angle)) * 16.0 + Vector2(0.0, 62.0)
		for i in mm.instance_count:
			var p := centre + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-3.5, 3.5))
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, _y(p.x, p.y) + 0.1, p.y)))
		field.multimesh = mm
		add_child(field)


func _notices() -> void:
	for spec in NOTICES:
		var point := NoticePoint.new()
		point.sketch_id = StringName(spec[0])
		point.title = spec[1]
		var at: Vector2 = spec[2]
		point.position = Vector3(at.x, _y(at.x, at.y) + 0.4, at.y)
		add_child(point)


func _stone(at: Vector2) -> void:
	var rock := StaticBody3D.new()
	rock.name = "Boulder"
	rock.add_to_group(Arrow.STONE_GROUP)
	rock.position = Vector3(at.x, _y(at.x, at.y) + 0.6, at.y)
	var mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.2
	s.height = 1.8
	mesh.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.66, 0.64, 0.68)
	mesh.material_override = mat
	rock.add_child(mesh)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	rock.add_child(shape)
	add_child(rock)


func _station(id: StringName, at: Vector2, color: Color, size: Vector3) -> void:
	var station := SimpleStation.new()
	station.name = String(id).capitalize().replace(" ", "")
	station.station_id = id
	station.position = Vector3(at.x, _y(at.x, at.y) + size.y * 0.5, at.y)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.35
	mesh.material_override = mat
	station.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	station.add_child(shape)
	add_child(station)

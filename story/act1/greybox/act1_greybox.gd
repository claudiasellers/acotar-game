## Act I greybox: phases 0 and 1 playable start to finish on stand-ins, before
## the world, systems and creatures lanes land. Everything is built in code.
##
## Layout (-Z is north): the cottage at the origin, the village to the east,
## the hunting forest north, the wall at z = -380, the Border Woods beyond.
## When the real lanes merge, their regions, inventory and creatures answer
## the same EventBus signals and the stubs here go quiet (see _stub_*).
##
## Stub loop: shoot hares in the forest to fill the larder (food tally),
## meet the doe and the wolf in the clearing, E on the dead wolf to skin it,
## E at the fur stall to sell the pelt, E on the bed to sleep until night,
## and the beast comes.
extends Node3D

const FEYRE_SCENE := preload("res://characters/feyre/feyre.tscn")
const HUD_SCRIPT := preload("res://ui/debug_hud.gd")
const PHASES := preload("res://data/phases/spring_court_phases.tres")

const WALL_Z := -380.0
const CLEARING := Vector3(-20, 0, -230)
const STALL := Vector3(160, 0, 20)
const BED := Vector3(-2.2, 0, -1.6)
const INTERACT_REACH := 3.0

## The cold human-realm grade and the spring grade past the wall.
const WINTER := {"sky_top": Color(0.42, 0.48, 0.56), "horizon": Color(0.70, 0.73, 0.77),
		"fog": Color(0.66, 0.70, 0.76), "sun": Color(0.80, 0.85, 0.95), "sun_energy": 0.7,
		"saturation": 0.55}
const SPRING := {"sky_top": Color(0.40, 0.62, 0.92), "horizon": Color(1.0, 0.86, 0.80),
		"fog": Color(1.0, 0.88, 0.86), "sun": Color(1.0, 0.90, 0.74), "sun_energy": 1.35,
		"saturation": 1.25}

var feyre: Feyre
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var hearth_light: OmniLight3D
var rng := RandomNumberGenerator.new()

var _grade: float = 0.0  # 0 winter, 1 spring
var _dread: float = 0.0
var _food_days: float = 2.0
var _has_pelt: bool = false
var _pelt_sold: bool = false
var _wolf_corpse: Node3D


func _ready() -> void:
	rng.seed = 1817
	if PhaseManager.phase_set == null:
		PhaseManager.start(PHASES)
	_build_environment()
	_build_ground()
	_build_cottage()
	_build_forest()
	_build_village()
	_build_wall_and_border_woods()
	_build_spaces()
	# Real wolf, doe, beast and family from the creatures lane, once merged.
	if ResourceLoader.exists("res://creatures/story_spawner.gd"):
		var spawner := Node3D.new()
		spawner.name = "StorySpawner"
		spawner.set_script(load("res://creatures/story_spawner.gd"))
		add_child(spawner)
	feyre = FEYRE_SCENE.instantiate()
	feyre.position = Vector3(0, 0.2, 8)
	add_child(feyre)
	var hud := CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	EventBus.grade_swap_requested.connect(_on_grade_swap)
	EventBus.mood_requested.connect(_on_mood)
	EventBus.creature_killed.connect(_stub_on_creature_killed)
	EventBus.food_stock_changed.emit.call_deferred(_food_days)


func _process(_delta: float) -> void:
	var angle := (Clock.time_of_day - 0.25) * TAU
	sun.rotation = Vector3(-sin(angle) * deg_to_rad(70.0) - 0.05, deg_to_rad(-35.0), 0.0)
	var day_light := clampf(sin(angle) * 1.6, 0.05, 1.0)
	var g := _grade_values()
	sun.light_color = g["sun"]
	sun.light_energy = day_light * float(g["sun_energy"]) * (1.0 - 0.7 * _dread)
	sky_mat.sky_top_color = g["sky_top"]
	sky_mat.sky_horizon_color = g["horizon"]
	env.fog_light_color = g["fog"]
	env.adjustment_saturation = float(g["saturation"]) * (1.0 - 0.4 * _dread)
	env.fog_density = lerpf(0.004, 0.0015, _grade) + 0.006 * _dread
	# The fire gutters when the beast is near.
	hearth_light.light_energy = (1.6 + 0.25 * sin(Time.get_ticks_msec() * 0.011)) * (1.0 - 0.75 * _dread)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"interact") or not StoryControl.can_interact() or feyre == null:
		return
	var at := feyre.global_position
	if _wolf_corpse and is_instance_valid(_wolf_corpse) and not _has_pelt and not _pelt_sold \
			and at.distance_to(_wolf_corpse.global_position) < INTERACT_REACH + 1.0:
		_stub_skin_wolf()
	elif _has_pelt and at.distance_to(STALL) < INTERACT_REACH + 1.0:
		_stub_sell_pelt()
	elif at.distance_to(BED) < INTERACT_REACH:
		_stub_sleep_until_night()


func _grade_values() -> Dictionary:
	var out := {}
	for key in WINTER:
		var a: Variant = WINTER[key]
		var b: Variant = SPRING[key]
		out[key] = (a as Color).lerp(b, _grade) if a is Color else lerpf(a, b, _grade)
	return out


# --- Fallbacks for the world lane's GradeDirector and the mood layer --------

func _on_grade_swap(to_grade: StringName, seconds: float) -> void:
	if get_tree().get_first_node_in_group(&"grade_director"):
		return
	var target := 1.0 if to_grade == &"spring" else 0.0
	create_tween().tween_property(self, ^"_grade", target, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_mood(mood: StringName, intensity: float, seconds: float) -> void:
	var target := intensity if mood == &"dread" else 0.0
	if mood == &"enchanted_sleep":
		target = 0.95 * intensity
	create_tween().tween_property(self, ^"_dread", target, maxf(seconds, 0.05))


# --- Stubs for systems/creatures until those lanes merge ---------------------

func _stub_on_creature_killed(_id: StringName, kind: StringName, _cause: StringName, _at: Vector3) -> void:
	match kind:
		&"hare":
			_food_days += 1.5
		&"deer":
			_food_days += 4.0
		&"great_wolf":
			_wolf_corpse = get_tree().get_first_node_in_group(&"story_actor_great_wolf") as Node3D
			return
		_:
			return
	EventBus.food_stock_changed.emit(_food_days)


func _stub_skin_wolf() -> void:
	_has_pelt = true
	EventBus.creature_harvested.emit(&"andras", &"great_wolf", PackedStringArray(["obj_wolf_pelt"]))
	EventBus.item_acquired.emit(&"obj_wolf_pelt", 1)


func _stub_sell_pelt() -> void:
	_has_pelt = false
	_pelt_sold = true
	EventBus.item_sold.emit(&"obj_wolf_pelt", 40)


func _stub_sleep_until_night() -> void:
	if Clock.is_night():
		return
	var target := 21.5 / 24.0
	var advance := target - Clock.time_of_day
	if advance < 0.0:
		advance += 1.0
	Clock.advance(advance * Clock.DAY_LENGTH_SECONDS)


# --- Building ----------------------------------------------------------------

func _mat(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, solid: bool = true) -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	body.position = at
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.fog_enabled = true
	env.adjustment_enabled = true
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)


func _build_ground() -> void:
	# Snow south of the wall, meadow north of it.
	_box(self, Vector3(900, 1, 600), Vector3(0, -0.5, -80), Color(0.86, 0.89, 0.93))
	_box(self, Vector3(900, 1, 300), Vector3(0, -0.5, WALL_Z - 150), Color(0.42, 0.62, 0.30))


func _build_cottage() -> void:
	var cottage := Node3D.new()
	cottage.name = "Cottage"
	add_child(cottage)
	var stone := Color(0.42, 0.42, 0.44)
	_box(cottage, Vector3(8, 3, 0.4), Vector3(0, 1.5, -3), stone)        # north wall
	_box(cottage, Vector3(0.4, 3, 6), Vector3(-4, 1.5, 0), stone)        # west
	_box(cottage, Vector3(0.4, 3, 6), Vector3(4, 1.5, 0), stone)         # east
	_box(cottage, Vector3(3.2, 3, 0.4), Vector3(-2.4, 1.5, 3), stone)    # south, left of door
	_box(cottage, Vector3(3.2, 3, 0.4), Vector3(2.4, 1.5, 3), stone)     # south, right of door
	_box(cottage, Vector3(8.6, 0.3, 6.6), Vector3(0, 3.1, 0), Color(0.30, 0.26, 0.22))  # roof
	# The door: whole until the beast, splinters after.
	var whole := StateVisibility.new()
	whole.name = "DoorWhole"
	whole.hide_when_flag = "fact.cottage_door_broken"
	cottage.add_child(whole)
	_box(whole, Vector3(1.6, 2.4, 0.15), Vector3(0, 1.2, 3), Color(0.36, 0.26, 0.18))
	var broken := StateVisibility.new()
	broken.name = "DoorBroken"
	broken.show_when_flag = "fact.cottage_door_broken"
	cottage.add_child(broken)
	for i in 4:
		_box(broken, Vector3(0.25, 0.08, 1.4), Vector3(-0.6 + i * 0.4, 0.05, 1.8 + 0.2 * i),
				Color(0.36, 0.26, 0.18), false)
	# Hearth, bed, table.
	_box(cottage, Vector3(1.6, 1.0, 0.8), Vector3(0, 0.5, -2.4), Color(0.25, 0.22, 0.20))
	hearth_light = OmniLight3D.new()
	hearth_light.light_color = Color(1.0, 0.62, 0.32)
	hearth_light.omni_range = 9.0
	hearth_light.position = Vector3(0, 1.0, -1.8)
	cottage.add_child(hearth_light)
	_box(cottage, Vector3(2.0, 0.5, 1.4), BED + Vector3(0, 0.25, 0), Color(0.48, 0.44, 0.38))
	_box(cottage, Vector3(1.4, 0.8, 0.9), Vector3(2.2, 0.4, 0.2), Color(0.40, 0.31, 0.22))
	# Feyre's painted vines: the only saturated colour in the house.
	var paint := [Color(0.85, 0.25, 0.35), Color(0.95, 0.75, 0.25), Color(0.35, 0.65, 0.35), Color(0.55, 0.40, 0.85)]
	for i in 9:
		_box(cottage, Vector3(0.18, 0.18, 0.02), Vector3(-3.0 + i * 0.7, 2.2 + 0.25 * sin(i * 1.3), -2.78),
				paint[i % paint.size()], false)
	_family_stand_ins(cottage)


func _family_stand_ins(cottage: Node3D) -> void:
	# Nesta, Elain, their father: placeholders (main characters stay capsules).
	var spots := [Vector3(-1.2, 0, -1.2), Vector3(1.2, 0, -1.0), Vector3(0.6, 0, -1.6)]
	var colors := [Color(0.35, 0.40, 0.55), Color(0.80, 0.70, 0.55), Color(0.40, 0.36, 0.30)]
	for i in spots.size():
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.25
		capsule.height = 1.6 if i < 2 else 1.7
		mesh.mesh = capsule
		mesh.material_override = _mat(colors[i])
		mesh.position = spots[i] + Vector3.UP * capsule.height * 0.5
		cottage.add_child(mesh)


func _build_forest() -> void:
	# Bare winter trees as one MultiMesh (no per-instance nodes).
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.32
	trunk.height = 11.0
	trunk.material = _mat(Color(0.24, 0.21, 0.19))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = trunk
	var spots: Array[Vector3] = []
	for i in 900:
		var p := Vector3(rng.randf_range(-300, 300), 0, rng.randf_range(-360, -40))
		if p.distance_to(CLEARING) < 22.0 or absf(p.x) < 4.0:
			continue
		spots.append(p)
	mm.instance_count = spots.size()
	for i in spots.size():
		var s := rng.randf_range(0.7, 1.3)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, s, s)), spots[i] + Vector3.UP * 5.5 * s))
	var trees := MultiMeshInstance3D.new()
	trees.name = "WinterTrees"
	trees.multimesh = mm
	add_child(trees)
	# Hares to hunt for the larder.
	for i in 10:
		var hare := StandIns.creature(&"hare", Vector3(0.3, 0.35, 0.5), Color(0.62, 0.58, 0.52))
		hare.position = Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-200, -60))
		add_child(hare)


func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Village"
	village.position = STALL
	add_child(village)
	_box(village, Vector3(3, 2.2, 1.6), Vector3.ZERO + Vector3.UP * 1.1, Color(0.45, 0.36, 0.28))  # fur stall
	for i in 6:
		_box(village, Vector3(6, 4, 6), Vector3(-14 + (i % 3) * 14, 2, -14 - 14 * float(i / 3)),
				Color(0.40, 0.38, 0.36))


func _build_wall_and_border_woods() -> void:
	# The wall: barely visible, a heat-haze line (lore: the-wall.md).
	var haze := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(900, 60)
	haze.mesh = plane
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.95, 1.0, 0.06)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	haze.material_override = m
	haze.position = Vector3(0, 30, WALL_Z)
	add_child(haze)
	# Border Woods: green canopy and flowers, so the arrival is a gift.
	var canopy := SphereMesh.new()
	canopy.radius = 3.0
	canopy.height = 5.0
	canopy.material = _mat(Color(0.36, 0.62, 0.30))
	var flower := SphereMesh.new()
	flower.radius = 0.12
	flower.height = 0.2
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.8, 0.9)
	fm.emission_energy_multiplier = 0.25
	flower.material = fm
	_scatter(canopy, 260, Vector2(-300, 300), Vector2(WALL_Z - 290, WALL_Z - 15), 6.0, false)
	_scatter(flower, 2400, Vector2(-200, 200), Vector2(WALL_Z - 200, WALL_Z - 4), 0.1, true)


func _scatter(mesh: Mesh, count: int, xr: Vector2, zr: Vector2, y: float, colored: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colored
	mm.mesh = mesh
	mm.instance_count = count
	var petals := [Color(1.0, 0.55, 0.70), Color(1.0, 0.95, 0.80), Color(0.80, 0.60, 1.0), Color(1.0, 0.80, 0.35)]
	for i in count:
		var p := Vector3(rng.randf_range(xr.x, xr.y), y, rng.randf_range(zr.x, zr.y))
		if absf(p.x) < 4.0:
			p.x += 8.0
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		if colored:
			mm.set_instance_color(i, petals[i % petals.size()])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)


func _entry(space: Node3D, size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var area := Area3D.new()
	area.name = "Entry"
	area.collision_mask = 1 << 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	area.add_child(shape)
	space.add_child(area)


func _build_spaces() -> void:
	var tally := FoodTally.new()
	tally.name = "FoodTally"
	tally.position = Vector3(-3.7, 2.4, -1.0)
	add_child(tally)

	var wolf := WolfKill.new()
	wolf.name = "WolfKill"
	wolf.position = CLEARING + Vector3(0, 0, 18)
	_entry(wolf, Vector3(30, 6, 12), Vector3(0, 3, 0))
	add_child(wolf)

	var skinning := WolfSkinning.new()
	skinning.name = "WolfSkinning"
	skinning.position = CLEARING
	add_child(skinning)

	var sale := PeltSale.new()
	sale.name = "PeltSale"
	sale.position = STALL
	add_child(sale)

	var beast := BeastDoor.new()
	beast.name = "BeastDoor"
	var door := Marker3D.new()
	door.name = "Door"
	door.position = Vector3(0, 0, 3.6)
	beast.add_child(door)
	_entry(beast, Vector3(7.4, 3, 5.6), Vector3(0, 1.5, 0))
	add_child(beast)

	var ride := RideNorth.new()
	ride.name = "RideNorth"
	var path := Path3D.new()
	path.name = "RidePath"
	path.curve = Curve3D.new()
	for p: Vector3 in [Vector3(0, 0, 6), Vector3(0, 0, -60), Vector3(-30, 0, -200), Vector3(0, 0, WALL_Z + 20),
			Vector3(0, 0, WALL_Z - 40), Vector3(10, 0, WALL_Z - 70)]:
		path.curve.add_point(p)
	ride.add_child(path)
	var seam := Marker3D.new()
	seam.name = "Seam"
	seam.position = Vector3(0, 0, WALL_Z)
	ride.add_child(seam)
	add_child(ride)

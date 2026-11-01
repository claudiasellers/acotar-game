## How each manor room is dressed beyond its props (experience bar §2.6,
## "princess château"): Rococo boiserie with gilt mouldings in the state rooms,
## ceilings painted as open skies in the grand ones, and one hero object per
## room lit hardest by a warm spot from the ceiling. Service rooms, cellars and
## the attic keep plain plaster so the state rooms read as the theatre of light.
class_name ManorRoomLook
extends RefCounted

const BOISERIE := preload("res://world/spring_court/manor_estate/house/boiserie.gdshader")
const SKY := preload("res://world/spring_court/manor_estate/house/sky_ceiling.gdshader")
const MARBLE := preload("res://world/spring_court/manor_estate/house/marble_floor.gdshader")

## State rooms that are working spaces and keep plain walls anyway.
const PLAIN := [&"map_stairwell", &"armory", &"conservatory", &"flower_room", &"lantern_lookout"]

## Grand rooms whose ceilings are painted as an open sky.
const SKY_ROOMS := [&"entrance_hall", &"garden_saloon", &"ballroom", &"drawing_room", &"music_room",
		&"gallery", &"morning_room", &"shrine", &"upper_hall", &"portrait_gallery", &"dressing_room",
		&"rose_parlour", &"wisteria_salon", &"rose_bower", &"garden_loggia"]

## Rooms where Act II plays at eye level under a lowered camera: a painted sky
## there reads as the roof missing, so they get a coffered ceiling instead,
## pearl beams with a gilt fillet over a blush field.
const COFFERED := [&"dining_hall", &"feyre_bedroom", &"feyre_bath"]
const COFFER_PITCH := 2.4
const BEAM_WIDTH := 0.26
const BEAM_DEPTH := 0.24
const FILLET_WIDTH := 0.07

## room id -> the one prop the room is about (its first placement is lit).
const HERO := {
	# ground floor
	&"entrance_hall": &"clock_grandfather", &"garden_saloon": &"birdcage_gilt", &"library": &"reading_lectern",
	&"tamlin_study": &"desk_large", &"hidden_nook": &"armchair", &"map_room": &"map_table", &"armory": &"armor_stand",
	&"drawing_room": &"pianoforte", &"music_room": &"lute_on_stand", &"morning_room": &"birdcage_gilt",
	&"gallery": &"statue_stag", &"dining_hall": &"table_dining_long", &"butlers_pantry": &"dresser_crockery",
	&"china_room": &"cabinet_curio", &"ballroom": &"harp_gilt", &"shrine": &"altar_marble",
	&"conservatory": &"fountain_small", &"flower_room": &"table_work", &"card_room": &"table_round",
	&"powder_room": &"vanity_mirror",
	# first floor
	&"upper_hall": &"clock_grandfather", &"garden_loggia": &"birdcage_gilt", &"front_reading_nook": &"reading_lectern",
	&"feyre_morning_room": &"desk_writing", &"feyre_bedroom": &"chaise_longue", &"dressing_room": &"vanity_table",
	&"jewel_closet": &"mask_display", &"feyre_bath": &"mirror_gilt", &"painting_room": &"easel",
	&"tamlin_bedchamber": &"bed_canopy", &"tamlin_bath": &"bath_sunken", &"portrait_gallery": &"statue_maiden",
	&"guest_suite_periwinkle": &"bed_canopy", &"lucien_cabinet": &"desk_writing", &"lucien_chambers": &"bed_canopy",
	&"guest_suite_lilac": &"bed_canopy", &"sewing_room": &"spinning_wheel", &"rose_parlour": &"harp_gilt",
	&"west_wing_hall": &"clock_grandfather", &"old_nursery": &"rocking_horse", &"pressed_flower_study": &"desk_writing",
	&"guest_suite_wisteria": &"bed_canopy", &"wisteria_salon": &"harp_gilt",
	# attic and towers
	&"attic_trunk_room": &"cheval_mirror", &"attic_painting_loft": &"easel", &"attic_costume_store": &"mask_display",
	&"attic_herb_loft": &"drying_rack_herbs", &"attic_playroom": &"dollhouse", &"attic_weaving_loft": &"loom_upright",
	&"attic_west_gable": &"mirror_gilt", &"attic_schoolroom": &"globe_stand", &"observatory": &"telescope_brass",
	&"rose_bower": &"rose_arbor", &"lantern_lookout": &"map_wall", &"moon_tower": &"harp_gilt",
	# service wing
	&"svc_kitchen": &"table_kitchen", &"svc_servants_hall": &"table_dining_long", &"svc_stillroom": &"alembic",
	&"svc_housekeeper": &"desk_writing", &"svc_alis_room": &"cradle_chest", &"svc_sewing_room": &"mannequin_gown",
}

const HERO_COLOR := Color(1.0, 0.86, 0.66)
const HERO_ENERGY := 3.2

static var _walls: Dictionary = {}
static var _marble: ShaderMaterial
static var _skies: Dictionary = {}
static var _coffer_mats: Dictionary = {}


## True for the rooms that get boiserie: the ground, first and tower floors of
## the main house, except service rooms, stair halls and the PLAIN list.
static func is_state_room(room: ManorRoomDef) -> bool:
	if room.level < 0 or room.level == 2 or String(room.id).begins_with("svc_"):
		return false
	if room.kind == &"exterior" or room.kind == &"stair_hall":
		return false
	return not PLAIN.has(room.id)


static func has_sky(room: ManorRoomDef) -> bool:
	return SKY_ROOMS.has(room.id)


## The wall material: boiserie for state rooms (one per colour), else plaster.
static func wall_material(room: ManorRoomDef) -> Material:
	if not is_state_room(room):
		return EstateKit.mat(room.wall_color, 0.9)
	var key := room.wall_color.to_html()
	if _walls.has(key):
		return _walls[key]
	var m := ShaderMaterial.new()
	m.shader = BOISERIE
	m.resource_name = "boiserie_" + key
	m.set_shader_parameter(&"wall_color", room.wall_color.lerp(EstateKit.PEARL, 0.25))
	m.set_shader_parameter(&"frame_color", EstateKit.PEARL)
	m.set_shader_parameter(&"floor0", ManorHouseBuilder.floor_y(0))
	m.set_shader_parameter(&"storey", ManorSitePlan.HOUSE_STOREY)
	m.set_shader_parameter(&"wall_height", ManorHouseBuilder.storey_height(0) - ManorHouseBuilder.SLAB - 0.02)
	_walls[key] = m
	return m


## The floor material: state rooms with marble floors get the lozenge damier
## (one shared material), everything else keeps `plain`.
static func floor_material(room: ManorRoomDef, plain: Material) -> Material:
	if room.floor_kind != &"marble" or not is_state_room(room):
		return plain
	if _marble == null:
		_marble = ShaderMaterial.new()
		_marble.shader = MARBLE
		_marble.resource_name = "marble_damier"
	return _marble


## The ceiling material: a painted sky over this room's rect, else `plain`.
static func ceiling_material(room: ManorRoomDef, plain: Material) -> Material:
	if is_coffered(room):
		return _coffer_mat(&"field", room.wall_color.lerp(EstateKit.BLUSH, 0.3).lerp(EstateKit.PEARL, 0.45), 0.85, 0.0)
	if not has_sky(room):
		return plain
	if _skies.has(room.id):
		return _skies[room.id]
	var m := ShaderMaterial.new()
	m.shader = SKY
	m.resource_name = "sky_" + String(room.id)
	m.set_shader_parameter(&"room_rect", Vector4(room.rect.position.x, room.rect.position.y, room.rect.size.x, room.rect.size.y))
	m.set_shader_parameter(&"field", EstateKit.PEARL)
	_skies[room.id] = m
	return m


static func is_coffered(room: ManorRoomDef) -> bool:
	return COFFERED.has(room.id)


## Coffering under a coffered room's ceiling: a perimeter cornice and a grid of
## beams about COFFER_PITCH apart, each with a gilt fillet along its underside.
## One mesh (two surfaces) per room, no collision. Returns it, or null.
static func add_coffers(node: Node3D, room: ManorRoomDef, origin: Vector3, ceiling: float) -> MeshInstance3D:
	if not is_coffered(room):
		return null
	var size := room.rect.size
	var y := origin.y + ceiling - BEAM_DEPTH * 0.5
	var beams := SurfaceTool.new()
	var gilt := SurfaceTool.new()
	beams.begin(Mesh.PRIMITIVE_TRIANGLES)
	gilt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines_x := _grid_lines(size.x)
	var lines_z := _grid_lines(size.y)
	for x in lines_x:
		var w := BEAM_WIDTH * (1.4 if x == 0.0 or x == size.x else 1.0)
		var cx := clampf(x, w * 0.5, size.x - w * 0.5)
		_beam(beams, gilt, Vector3(origin.x + cx, y, origin.z + size.y * 0.5), Vector3(w, BEAM_DEPTH, size.y))
	for z in lines_z:
		var w := BEAM_WIDTH * (1.4 if z == 0.0 or z == size.y else 1.0)
		var cz := clampf(z, w * 0.5, size.y - w * 0.5)
		_beam(beams, gilt, Vector3(origin.x + size.x * 0.5, y, origin.z + cz), Vector3(size.x, BEAM_DEPTH, w))
	var mesh := beams.commit()
	mesh = gilt.commit(mesh)
	mesh.surface_set_material(0, _coffer_mat(&"beam", EstateKit.PEARL, 0.6, 0.0))
	mesh.surface_set_material(1, _coffer_mat(&"gilt", EstateKit.GOLD, 0.35, 0.6))
	var mi := MeshInstance3D.new()
	mi.name = "Coffers"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	return mi


## Wall-to-wall line positions (0 and `span` included) about COFFER_PITCH apart.
static func _grid_lines(span: float) -> Array[float]:
	var n := maxi(1, roundi(span / COFFER_PITCH))
	var out: Array[float] = []
	for i in n + 1:
		out.append(span * float(i) / float(n))
	return out


static func _beam(beams: SurfaceTool, gilt: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	beams.append_from(box, 0, Transform3D(Basis(), center))
	var strip := BoxMesh.new()
	var along_x := size.x > size.z
	strip.size = Vector3(size.x if along_x else FILLET_WIDTH, 0.03, FILLET_WIDTH if along_x else size.z)
	gilt.append_from(strip, 0, Transform3D(Basis(), center - Vector3(0.0, size.y * 0.5 + 0.005, 0.0)))


## Coffer materials glow a little of their own colour: ambient from below is the
## lawn green (see sky_ceiling.gdshader), which would muddy a plain ceiling.
static func _coffer_mat(kind: StringName, color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var key := "%s|%s" % [kind, color.to_html()]
	if _coffer_mats.has(key):
		return _coffer_mats[key]
	var m := StandardMaterial3D.new()
	m.resource_name = "coffer_" + String(kind)
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.22 if kind != &"gilt" else 0.35
	_coffer_mats[key] = m
	return m


## The placement HERO names for this room (its first one), or null.
static func hero_of(room: ManorRoomDef) -> ManorPropPlacement:
	var id: StringName = HERO.get(room.id, &"")
	if id == &"":
		return null
	for p in room.props:
		if p.prop_id == id:
			return p
	return null


## A warm spot from the ceiling onto the room's hero, the brightest thing in the
## room (light hierarchy). Returns the light, or null if the room has no hero.
static func add_hero_light(node: Node3D, room: ManorRoomDef, origin: Vector3, ceiling: float) -> SpotLight3D:
	var hero := hero_of(room)
	if hero == null:
		return null
	var size := PropLib.size_of(hero.prop_id) * hero.scale
	var target := origin + hero.position + Vector3(0.0, size.y * 0.5, 0.0)
	var from := Vector3(target.x, origin.y + ceiling - 0.25, target.z)
	# Lean the spot in from the room's middle so the hero is lit from the front.
	var centre := Vector3(origin.x + room.rect.size.x * 0.5, from.y, origin.z + room.rect.size.y * 0.5)
	from += (centre - from).limit_length(1.2)
	var light := SpotLight3D.new()
	light.name = "HeroLight"
	light.light_color = HERO_COLOR
	light.light_energy = HERO_ENERGY
	light.shadow_enabled = false
	light.spot_range = from.distance_to(target) + 3.0
	var reach := maxf(size.x, maxf(size.y, size.z)) * 0.7 + 0.4
	light.spot_angle = clampf(rad_to_deg(atan2(reach, from.distance_to(target))), 14.0, 40.0)
	light.spot_angle_attenuation = 0.6
	light.distance_fade_enabled = true
	light.distance_fade_begin = 35.0
	light.distance_fade_length = 10.0
	light.add_to_group(&"manor_hero_light")
	var dir := (target - from).normalized()
	light.transform = Transform3D(Basis.looking_at(dir, Vector3.FORWARD if absf(dir.y) > 0.98 else Vector3.UP), from)
	node.add_child(light)
	return light

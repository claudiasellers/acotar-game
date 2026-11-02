## The manor's paintings (L39), contract: docs/contracts/manor_art.md.
## No painting hangs twice anywhere in the house; every work is sourced and
## tied to the story; the ch7 still life hangs in the entrance hall; the
## Keeper's dim-room works stay in dim rooms; canvases never glow.
extends GutTest

var cat: ManorArtCatalog
var all: ManorHouseIndex
var chosen: Dictionary


func before_all() -> void:
	cat = ManorArtCatalog.load_default()
	all = ManorHouseIndex.new(ManorHouseBuilder.load_layouts())
	chosen = ManorArtHanger.assign(all, cat)


func test_catalogue_is_unique_sourced_and_canon_tagged() -> void:
	assert_not_null(cat)
	assert_gte(cat.works.size(), 200, "at least 200 works")
	var ids := {}
	var titles := {}
	var cells := {}
	for w in cat.works:
		assert_false(ids.has(w.id), "id %s is unique" % w.id)
		assert_false(titles.has(w.title), "title %s is unique" % w.title)
		ids[w.id] = true
		titles[w.title] = true
		assert_has(["C", "C?", "X"], w.canon, "%s has a canon tag" % w.id)
		assert_gt(w.story_ref.length(), 20, "%s says what in the story it shows" % w.id)
		assert_gt(w.source.length(), 0, "%s records its source" % w.id)
		assert_gt(w.licence.length(), 0, "%s records its licence" % w.id)
		assert_false(w.themes.is_empty(), "%s says where it hangs" % w.id)
		assert_true(ManorArtCanvas.UNIT.has(w.shape()), "%s has a known shape" % w.id)
		if w.reserve:
			continue
		assert_true(ResourceLoader.exists(w.sheet), "%s's sheet %s exists" % [w.id, w.sheet])
		assert_true(w.layer >= 0 and w.layer < 16, "%s is on a layer of the array" % w.id)
		assert_true(w.uv.position.x > 0.0 and w.uv.position.y > 0.0 and w.uv.end.x < 1.0 and w.uv.end.y < 1.0,
				"%s's cell is inside its layer" % w.id)
		var cell := "%s|%d|%s" % [w.sheet, w.layer, w.uv]
		assert_false(cells.has(cell), "%s has its own canvas" % w.id)
		cells[cell] = true


func test_no_painting_hangs_twice_in_the_house() -> void:
	var slots := ManorArtHanger.slots(all)
	assert_gt(slots.size(), 100, "the house has its art slots")
	assert_eq(ManorArtHanger.last_duplicates.size(), 0, "enough works for every slot: %s" % ", ".join(ManorArtHanger.last_duplicates))
	var seen := {}
	for s: Dictionary in slots:
		assert_true(chosen.has(s.key), "slot %s is filled" % s.key)
		if not chosen.has(s.key):
			continue
		var w: ManorArtWork = chosen[s.key]
		assert_false(seen.has(w.id), "%s hangs once (again at %s, first at %s)" % [w.id, s.key, seen.get(w.id, "")])
		seen[w.id] = s.key
	gut.p("%d slots, %d different paintings hung, %d in the catalogue" % [slots.size(), seen.size(), cat.works.size()])


func test_the_ch7_still_life_hangs_in_the_hall_by_the_stair() -> void:
	var where := ""
	for k: String in chosen:
		if (chosen[k] as ManorArtWork).id == &"still_green_glass_vase":
			where = k
	assert_true(where.begins_with("upper_hall@") or where.begins_with("entrance_hall@"),
			"the green glass vase hangs in the hall by the stair (at %s)" % where)


func test_pinned_works_hang_in_their_rooms() -> void:
	var rooms := {}
	for s: Dictionary in ManorArtHanger.slots(all):
		rooms[String((s.room as ManorRoomDef).id)] = true
	for w in cat.works:
		if w.pin == &"" or w.reserve:
			continue
		var where := ""
		for k: String in chosen:
			if chosen[k] == w:
				where = k
		var first := ""
		for alt in String(w.pin).split("|", false):
			if rooms.has(alt.get_slice("@", 0)):
				first = alt.get_slice("@", 0)
				break
		if first != "":
			assert_true(where.begins_with(first + "@"), "%s hangs in %s (at %s)" % [w.id, first, where])


func test_held_back_works_never_hang() -> void:
	var hangable := 0
	for w in cat.works:
		if not w.reserve:
			hangable += 1
	for k: String in chosen:
		assert_false((chosen[k] as ManorArtWork).reserve, "%s is held back but hangs at %s" % [(chosen[k] as ManorArtWork).id, k])
	gut.p("%d works can hang, %d held back" % [hangable, cat.works.size() - hangable])


func test_the_gallery_hangs_pastorals_portraits_and_still_lifes() -> void:
	var genres := {}
	for k: String in chosen:
		if k.begins_with("gallery@"):
			genres[(chosen[k] as ManorArtWork).genre] = true
	for g: StringName in [&"landscape", &"portrait", &"still"]:
		assert_true(genres.has(g), "the gallery has %s (ch19)" % g)


func test_the_high_lords_kin_stay_in_dim_rooms() -> void:
	for k: String in chosen:
		var w: ManorArtWork = chosen[k]
		if not (w.id in [&"high_lord_father", &"elder_brothers", &"youngest_son"]):
			continue
		var room_id := k.get_slice("@", 0)
		var level := int(k.get_slice("@", 1).get_slice("#", 0))
		var themes := cat.themes_for(StringName(room_id), level)
		var ok := false
		for t in w.themes:
			ok = ok or themes.has(t)
		assert_true(ok, "%s hangs only in a dim side room, not %s" % [w.id, room_id])


func test_every_frame_model_exists() -> void:
	for shape: StringName in ManorArtHanger.SHAPE_STYLES:
		for style: StringName in ManorArtHanger.SHAPE_STYLES[shape]:
			var path := "%s%s_%s.glb" % [ManorArtHanger.FRAME_DIR, style, shape]
			assert_true(ResourceLoader.exists(path), path)
	var styles := {}
	for shape: StringName in ManorArtHanger.SHAPE_STYLES:
		for style: StringName in ManorArtHanger.SHAPE_STYLES[shape]:
			styles[style] = true
	assert_gte(styles.size(), 8, "at least 8 frame styles")


func test_canvases_never_glow_and_stay_under_the_albedo_cap() -> void:
	var code := ManorArtHanger.CANVAS_SHADER.code
	assert_false(code.contains("EMISSION"), "no emission before the glamour lifts")
	assert_true(code.contains("min(c, vec3(0.694))"), "whites capped at 0.85 sRGB (L18-4)")
	var tex := load(cat.works[0].sheet if not cat.works[0].reserve else cat.works[1].sheet) as TextureLayered
	assert_true(tex != null and tex.get_layered_type() == TextureLayered.LAYERED_TYPE_2D_ARRAY, "the paintings are one texture array")
	var m := ManorArtHanger.canvas_material(cat.works[0].sheet if not cat.works[0].reserve else cat.works[1].sheet) as ShaderMaterial
	assert_eq(m.get_shader_parameter(&"sheet"), tex, "the canvas material samples it")


func test_built_house_hangs_framed_canvases_on_few_draws() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var house := ManorHouseBuilder.build(root)
	var hung := {}
	for n in house.find_children("*", "Node3D", true, false):
		if n.has_meta(&"art_id") and n.get_node_or_null("Look") != null:
			var id: StringName = n.get_meta(&"art_id")
			assert_false(hung.has(id), "%s is hung once" % id)
			hung[id] = true
	assert_eq(hung.size(), ManorArtHanger.slots(all).size(), "every slot has a painting")
	var canvas_draws := 0
	var worst := 0
	for room in house.get_children():
		var props := room.get_node_or_null("Props")
		if props == null:
			continue
		var n := 0
		for mi: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
			var m := mi.mesh.surface_get_material(0) as ShaderMaterial
			if m != null and m.shader == ManorArtHanger.CANVAS_SHADER:
				n += 1
		canvas_draws += n
		worst = maxi(worst, n)
	gut.p("canvas draws: %d in the house, at most %d in one room" % [canvas_draws, worst])
	assert_lte(canvas_draws, 60, "the paintings add at most 60 draws to the house")
	assert_lte(worst, 1, "a room draws all its canvases in one call")


func test_frames_hang_on_the_wall_face_not_inside_it() -> void:
	# a slot placed a little into a room's own wall (ManorHouseBuilder.WALL)
	# once hid its canvas in the plaster (audit A5, F1)
	var root := Node3D.new()
	add_child_autofree(root)
	var house := ManorHouseBuilder.build(root)
	var checked := 0
	for s: Dictionary in ManorArtHanger.slots(all):
		var room: ManorRoomDef = s.room
		var p: ManorPropPlacement = s.placement
		var prop := ManorArtHanger._slot_prop(house, room, s.room_index, p)
		if prop == null:
			continue
		var look := prop.get_node("Look") as Node3D
		# the frame's back, in room-local metres
		var back := prop.transform * (look.position + Vector3(0, 0, 0.024 * _long(look, prop)))
		var local := back - Vector3(room.rect.position.x, ManorHouseBuilder.floor_y(room.level), room.rect.position.y)
		var w := ManorHouseBuilder.WALL - 0.005
		var inside := local.x >= w and local.z >= w and local.x <= room.rect.size.x - w and local.z <= room.rect.size.y - w
		assert_true(inside, "%s hangs in front of the wall (back at %s, room %s)" % [s.key, local, room.rect.size])
		checked += 1
	assert_eq(checked, ManorArtHanger.slots(all).size(), "every slot checked")


## The frame's scale: the long side of the canvas, kept on the Look as meta.
func _long(look: Node3D, _prop: Node3D) -> float:
	return float(look.get_meta(&"art_long", 0.0))

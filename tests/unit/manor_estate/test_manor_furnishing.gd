## L38-1, the interior designer's pass on the Act I rooms: every refurnished
## room meets the furnishing bar (ManorFurnishMetrics), the window rules the
## furnisher and the curtains use match the builder's, ceilings ignore the
## lawn-green ambient, and the story's little things sit where the book puts them.
extends GutTest

static var _ctx: ManorFurnishContext
static var _upper: ManorHouseLayout


func before_all() -> void:
	if _ctx != null:
		return
	var ground := load(ManorLayoutDSL.OUT_DIR + "ground.tres") as ManorHouseLayout
	_ctx = ManorFurnishContext.new(ground)
	_upper = load(ManorLayoutDSL.OUT_DIR + "upper.tres") as ManorHouseLayout


func _room(id: StringName, level: int) -> ManorRoomDef:
	for r in _ctx.index.interior_rooms():
		if r.id == id and r.level == level:
			return r
	return null


func test_refurnished_rooms_meet_the_bar() -> void:
	var bad := []
	var seen := 0
	for r in _ctx.index.interior_rooms():
		if not ManorFurnishMetrics.REFURNISHED.has(r.id):
			continue
		seen += 1
		var m := ManorFurnishMetrics.measure(r, _ctx, _ctx.index.stations)
		var why := []
		if not m.ok_coverage:
			why.append("coverage %.1f%% < %.1f%%" % [m.coverage * 100.0, m.want_coverage * 100.0])
		if not m.ok_details:
			why.append("details %d < %d" % [m.details, m.need_details])
		if not m.repeats.is_empty():
			why.append("repeats %s" % [m.repeats])
		if m.blocked_doors > 0:
			why.append("doors blocked by %s" % [m.blockers])
		if m.unreachable_doors > 0:
			why.append("%d doors unreachable" % m.unreachable_doors)
		if not m.story_hits.is_empty():
			why.append("story %s" % [m.story_hits])
		if not m.ok_open:
			why.append("open floor %.1f m round %s" % [m.open, m.open_at])
		if not m.passage and m.bare_cells > 0:
			why.append("bare cells %s" % [m.bare_list])
		if not why.is_empty():
			bad.append("%s L%d: %s" % [r.id, r.level, "; ".join(why)])
	assert_gt(seen, 16, "the refurnished rooms are in the layouts")
	assert_eq(bad.size(), 0, "\n".join(bad))


func test_window_rules_match_the_builder() -> void:
	assert_eq(ManorWindows.SPACING, ManorHouseBuilder.WINDOW_SPACING)
	assert_eq(ManorWindows.WIDTH, ManorHouseBuilder.WINDOW_WIDTH)
	assert_eq(ManorWindows.SILL, ManorHouseBuilder.SILL)
	assert_eq(ManorWindows.DOOR_TOLERANCE, ManorHouseBuilder.DOOR_TOLERANCE)
	assert_eq(ManorFurnisher.WALL_FACE, ManorHouseBuilder.WALL)


func test_ceilings_ignore_the_green_ambient() -> void:
	var code: String = ManorRoomFinish.PLASTER_SHADER.code
	assert_true(code.contains("ambient_light_disabled"), "plaster ignores ambient")
	var plain := 0
	for r in _ctx.index.interior_rooms():
		if ManorRoomLook.is_coffered(r) or ManorRoomLook.has_sky(r):
			continue
		plain += 1
		var m := ManorRoomLook.ceiling_material(r) as ShaderMaterial
		assert_not_null(m, "%s: plaster ceiling" % r.id)
		if m != null:
			assert_eq(m.shader, ManorRoomFinish.PLASTER_SHADER, "%s: plaster ceiling" % r.id)
			var c: Color = m.get_shader_parameter(&"color")
			assert_true(maxf(c.r, maxf(c.g, c.b)) <= 0.85 + 1e-4, "%s: ceiling albedo under the glare cap" % r.id)
	assert_gt(plain, 0)
	assert_true(ManorRoomFinish.gilt().disable_ambient_light)
	assert_true(ManorRoomFinish.timber().disable_ambient_light)


## [C] Ivory and cream with pale green and gold.
func test_feyre_bedroom_is_pale_green() -> void:
	var bed := _room(&"feyre_bedroom", 1)
	assert_not_null(bed)
	var c := bed.wall_color
	assert_true(c.g > c.r and c.g > c.b, "green leads: %s" % c)
	assert_gt(c.s, 0.03, "not grey")
	assert_gt(c.get_luminance(), 0.7, "pale")


## "Tucked under the window-seat cushion in Feyre's bedroom."
func test_pressed_violet_is_under_a_window_seat_cushion() -> void:
	var bed := _room(&"feyre_bedroom", 1)
	var violet: ManorSecretDef = null
	for s in _upper.secrets:
		if s.secret_id == &"pressed_violet":
			violet = s
	assert_not_null(violet)
	if violet == null or bed == null:
		return
	var local := Vector2(violet.position.x - bed.rect.position.x, violet.position.z - bed.rect.position.y)
	var on_seat := false
	var under_cushion := false
	for p in bed.props:
		var sz := PropLib.size_of(p.prop_id) * p.scale
		var near := absf(p.position.x - local.x) <= sz.x * 0.5 and absf(p.position.z - local.y) <= maxf(sz.z, 0.5) * 0.5 + 0.1
		if p.prop_id == &"window_seat" and near:
			on_seat = absf(violet.position.y - ManorDecorDecks.top_of(&"window_seat") * p.scale) < 0.1
		if p.prop_id == &"cushion_pile" and near:
			under_cushion = true
	assert_true(on_seat, "on a window seat's top")
	assert_true(under_cushion, "by its cushion")


## The mural's wall and the Calanmai painting's place stay bare of tall pieces.
func test_story_walls_stay_clear() -> void:
	var lib := _room(&"library", 0)
	var tam := _room(&"tamlin_bedchamber", 1)
	for p in lib.props:
		var sz := PropLib.size_of(p.prop_id) * p.scale
		if p.position.x > lib.rect.size.x - 1.0 and p.position.y < 0.3 and sz.y > 0.9:
			var t0 := p.position.z - sz.x * 0.5
			var t1 := p.position.z + sz.x * 0.5
			assert_false(t1 > ManorFurnishAct1.MURAL_T - ManorFurnishAct1.MURAL_HALF \
					and t0 < ManorFurnishAct1.MURAL_T + ManorFurnishAct1.MURAL_HALF,
					"library: %s stands under the mural" % p.prop_id)
	for p in tam.props:
		var sz := PropLib.size_of(p.prop_id) * p.scale
		if p.position.x < 1.0 and absf(p.position.z - ManorFurnishAct1.TAMLIN_PAINTING_T) < 1.0 + sz.x * 0.5:
			assert_lt(p.position.y + sz.y, 1.45, "tamlin_bedchamber: %s rises into the painting's place" % p.prop_id)


## L39 hangs frames up to 2.3 m wide: nothing else hung on a slot's wall
## within ManorFurnisher.ART_CLEAR of its centre (sconces, mirrors, shelves).
func test_painting_slots_have_their_wall() -> void:
	var bad := []
	for r in _ctx.index.interior_rooms():
		if not ManorFurnishMetrics.REFURNISHED.has(r.id):
			continue
		var w := r.rect.size.x
		var d := r.rect.size.y
		for a in r.props:
			if not ManorFurnisher.ART_CLEAR.has(a.prop_id):
				continue
			var side := _wall_of(a.position, w, d)
			if side == "":
				continue
			var ta := a.position.x if side in ["n", "s"] else a.position.z
			for p in r.props:
				if p == a or p.position.y < 0.3 or _wall_of(p.position, w, d) != side:
					continue
				if PropLib.entry(p.prop_id)[3] and p.position.y < 1.2:
					continue        # a thing on a sideboard under the picture
				var tp := p.position.x if side in ["n", "s"] else p.position.z
				var half := PropLib.size_of(p.prop_id).x * p.scale * 0.5
				if not ManorFurnisher.ART_CLEAR.has(p.prop_id) and absf(tp - ta) < ManorFurnisher.ART_CLEAR[a.prop_id] + half - 0.05 \
						and not ManorDecorDecks.DETAIL.values().any(func(l: Array) -> bool: return l.has(p.prop_id)):
					bad.append("%s: %s at %s %.1f on %s at %.1f" % [r.id, p.prop_id, side, tp, a.prop_id, ta])
	assert_eq(bad.size(), 0, "\n".join(bad))


func _wall_of(p: Vector3, w: float, d: float) -> String:
	if p.z < 0.5:
		return "n"
	if p.z > d - 0.5:
		return "s"
	if p.x < 0.5:
		return "w"
	if p.x > w - 0.5:
		return "e"
	return ""

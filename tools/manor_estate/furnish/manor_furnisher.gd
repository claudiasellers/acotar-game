## Furnishes one manor room the way an interior designer would: pieces belong
## to a wall or to a grouping round a focal point, every surface is dressed,
## and nothing small repeats inside the room (ManorDecorDecks).
##
## Coordinates are room-local, like ManorLayoutDSL.prop(): x along the rect's
## width, z along its depth, from the rect's min corner. Walls are "n" (z = 0),
## "s" (z = depth), "w" (x = 0) and "e" (x = width); `t` is the distance along
## a wall from the corner nearest the origin, `d` the distance out from the
## wall's inner face.
##
## Groups use a frame anchored on a wall point: local -Z points into the room
## and a piece at local yaw 0 has its back to that wall, facing the room.
class_name ManorFurnisher
extends RefCounted

const WALL_FACE := 0.25          # inner wall face from the rect edge (ManorHouseBuilder.WALL)
const DOOR_APRON := 1.2          # floor kept clear in front of every door
const OPENING_PAD := 0.3         # wall kept clear either side of a door or window
const SIDES := ["n", "s", "w", "e"]
## Wall kept clear either side of a painting slot's centre, by slot (L39's frames).
const ART_CLEAR := {&"painting_large": 1.3, &"painting_medium": 0.8, &"painting_small": 0.5, &"portrait_masked": 0.8}

var dsl: ManorLayoutDSL
var room: ManorRoomDef
var ctx: ManorFurnishContext
var rng := RandomNumberGenerator.new()
var _decks: Dictionary = {}        # style key -> remaining ids (shuffled)
var _used: Dictionary = {}         # decor id -> true
var _claimed: Dictionary = {}      # side -> Array of [t0, t1, height] (floor pieces)
var _hung: Dictionary = {}         # side -> Array of [t0, t1] (wall-hung pieces)
var _feet: Array = []              # [Rect2 world, id] of collide floor pieces
var surfaces: Array[ManorPropPlacement] = []
var misses: Array[String] = []     # pieces asked for that didn't fit
var why := ""                      # what the last fits() refusal hit


func _init(layout_dsl: ManorLayoutDSL, r: ManorRoomDef, context: ManorFurnishContext) -> void:
	dsl = layout_dsl
	room = r
	ctx = context
	rng.seed = hash(String(r.id))
	for side in SIDES:
		_claimed[side] = []
		_hung[side] = []
	# Start from an empty room: the refurnish owns every placement.
	room.props.clear()
	# Stations (hearths, the bed, the easel...) stand where the story put them.
	for st in ctx.index.stations:
		if st.level == r.level and r.rect.has_point(Vector2(st.position.x, st.position.z)):
			var probe := ManorPropPlacement.new()
			probe.prop_id = st.prop_id
			probe.position = Vector3(st.position.x - r.rect.position.x, 0.0, st.position.z - r.rect.position.y)
			probe.yaw_deg = st.yaw_deg
			_feet.append([footprint(probe), st.prop_id])
			_claim_against_wall(probe)


# --- geometry ------------------------------------------------------------------

func width() -> float:
	return room.rect.size.x


func depth() -> float:
	return room.rect.size.y


func wall_len(side: String) -> float:
	return width() if side == "n" or side == "s" else depth()


## Yaw for a piece backed onto `side`, facing the room (catalogue fronts face -Z).
static func wall_yaw(side: String) -> float:
	return {"n": 180.0, "s": 0.0, "w": -90.0, "e": 90.0}[side]


## Room-local point `d` metres out from `side`'s inner face, `t` along it.
func wall_point(side: String, t: float, d: float) -> Vector2:
	var off := WALL_FACE + d
	match side:
		"n":
			return Vector2(t, off)
		"s":
			return Vector2(t, depth() - off)
		"w":
			return Vector2(off, t)
	return Vector2(width() - off, t)


func to_world(local: Vector2) -> Vector2:
	return room.rect.position + local


## Doors and windows on a wall as [t0, t1, kind] (kind: &"door" or &"window"),
## the windows worked out exactly as ManorHouseBuilder._build_walls cuts them.
func openings(side: String) -> Array:
	return ctx.openings(room, side)


## Free stretches of a wall at least `min_len` long, clear of openings (padded)
## and of what is already along it: every floor piece when `low` (placing on the
## floor), else only tall floor pieces and other hung pieces (hanging on the wall).
func free_spans(side: String, min_len: float = 0.6, low: bool = true) -> Array:
	var blocks: Array = []
	var drapes := maxf(OPENING_PAD, ManorRoomFinish.drape_reach(room) + 0.05)
	for o in openings(side):
		var pad := drapes if o[2] == &"window" else OPENING_PAD
		blocks.append([o[0] - pad, o[1] + pad])
	for c in _claimed[side]:
		if low or c[2] > 1.3:
			blocks.append(c)
	if not low:
		blocks.append_array(_hung[side])
	blocks.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array = []
	var cursor := 0.35
	var end := wall_len(side) - 0.35
	for b in blocks:
		if b[0] - cursor >= min_len:
			out.append([cursor, minf(b[0], end)])
		cursor = maxf(cursor, b[1])
	if end - cursor >= min_len:
		out.append([cursor, end])
	return out.filter(func(s: Array) -> bool: return s[1] - s[0] >= min_len)


## Claims the wall stretch behind a piece standing within 0.4 m of a wall.
func _claim_against_wall(p: ManorPropPlacement) -> void:
	var f := footprint(p).grow(-0.01)
	var lo := f.position - room.rect.position
	var hi := lo + f.size
	var h := PropLib.size_of(p.prop_id).y * p.scale
	if lo.y < WALL_FACE + 0.4:
		claim("n", lo.x, hi.x, h)
	if hi.y > depth() - WALL_FACE - 0.4:
		claim("s", lo.x, hi.x, h)
	if lo.x < WALL_FACE + 0.4:
		claim("w", lo.y, hi.y, h)
	if hi.x > width() - WALL_FACE - 0.4:
		claim("e", lo.y, hi.y, h)


func claim(side: String, t0: float, t1: float, h: float = 9.0) -> void:
	_claimed[side].append([t0, t1, h])


func span_free(side: String, t0: float, t1: float) -> bool:
	for s in free_spans(side, 0.01):
		if t0 >= s[0] - 0.01 and t1 <= s[1] + 0.01:
			return true
	return false


## Windows on a wall (for window seats, desks and curtains-aware layouts).
func windows(side: String) -> Array:
	return openings(side).filter(func(o: Array) -> bool: return o[2] == &"window")


func doors(side: String) -> Array:
	return openings(side).filter(func(o: Array) -> bool: return o[2] == &"door")


# --- placing -----------------------------------------------------------------------

## Keeps a stretch of wall free of anything hung (a mural, a story painting's place).
func reserve(side: String, t0: float, t1: float) -> void:
	_hung[side].append([t0, t1])


## `id` centred under every window of `side` where it fits; returns those placed.
func under_windows(side: String, id: StringName, d: float = 0.0, s: float = 1.0) -> Array[ManorPropPlacement]:
	var out: Array[ManorPropPlacement] = []
	for w in windows(side):
		var t: float = (w[0] + w[1]) * 0.5
		var p := fit_wall(side, t, id, d, s, 0.0, false)
		if p != null:
			out.append(p)
	return out


## wall(), but only where the piece fits (else null, and the stretch stays free).
func fit_wall(side: String, t: float, id: StringName, d: float = 0.0, s: float = 1.0, turn: float = 0.0,
		check_span: bool = true) -> ManorPropPlacement:
	var size := PropLib.size_of(id) * s
	var reach := size.x if absf(turn) > 45.0 else size.z
	var c := wall_point(side, t, d + reach * 0.5 + 0.02)
	var along := size.z if absf(turn) > 45.0 else size.x
	if check_span and not span_free(side, t - along * 0.5, t + along * 0.5):
		misses.append("%s %s@%.1f (wall taken or drapes)" % [id, side, t])
		return null
	var probe := ManorPropPlacement.new()
	probe.prop_id = id
	probe.position = Vector3(c.x, 0.0, c.y)
	probe.yaw_deg = wall_yaw(side) + turn
	probe.scale = s
	if not fits(probe):
		misses.append("%s %s@%.1f (%s)" % [id, side, t, why])
		return null
	return wall(side, t, id, d, 0.0, s, turn)


## try_put() that remembers what didn't fit, for the generator's log.
func at(id: StringName, x: float, z: float, yaw: float = 0.0, s: float = 1.0) -> ManorPropPlacement:
	var p := try_put(id, x, z, yaw, s)
	if p == null:
		misses.append("%s (%.1f, %.1f) (%s)" % [id, x, z, why])
	return p


## A small thing set by hand at (x, y, z), unless the room already has one.
func put_on(id: StringName, x: float, z: float, yaw: float, y: float) -> ManorPropPlacement:
	if _used.has(id):
		return null
	_used[id] = true
	return dsl.prop(room, id, x, z, yaw, y)


## Places a piece at room-local (x, z). Floor pieces that collide are recorded
## for the overlap, apron and keep-clear checks. Surfaces are remembered for dress().
func put(id: StringName, x: float, z: float, yaw: float = 0.0, y: float = 0.0, s: float = 1.0) -> ManorPropPlacement:
	var p := dsl.prop(room, id, x, z, yaw, y, s)
	if ManorDecorDecks.is_decor(id):
		_used[id] = true
	if y < 0.3 and PropLib.entry(id)[3]:
		_feet.append([footprint(p), id])
	if ManorDecorDecks.SURFACE.has(id) and y < 0.3:
		surfaces.append(p)
	return p


## Like put(), but refuses (returns null) where the piece would block a door
## apron, a story zone, a stair, another piece, or leave the room.
func try_put(id: StringName, x: float, z: float, yaw: float = 0.0, s: float = 1.0) -> ManorPropPlacement:
	var probe := ManorPropPlacement.new()
	probe.prop_id = id
	probe.position = Vector3(x, 0.0, z)
	probe.yaw_deg = yaw
	probe.scale = s
	if not fits(probe):
		return null
	return put(id, x, z, yaw, 0.0, s)


## World-space footprint (axis-aligned bound of the turned box).
func footprint(p: ManorPropPlacement) -> Rect2:
	var size := PropLib.size_of(p.prop_id) * p.scale
	var turned := absf(fposmod(p.yaw_deg, 180.0) - 90.0) < 45.0
	var ext := Vector2(size.z, size.x) if turned else Vector2(size.x, size.z)
	var c := to_world(Vector2(p.position.x, p.position.z))
	return Rect2(c - ext * 0.5, ext)


func fits(p: ManorPropPlacement) -> bool:
	why = ""
	var f := footprint(p)
	var inner := room.rect.grow(-WALL_FACE + 0.02)
	if not inner.encloses(f):
		why = "outside"
		return false
	if not PropLib.entry(p.prop_id)[3]:
		return true
	for a in ctx.door_aprons(room):
		if (a as Rect2).intersects(f):
			why = "door"
			return false
	var z := ManorKeepClear.hits(ctx.keep_clear, room.level, f)
	if not z.is_empty():
		why = String(z.get("why", "story"))
		return false
	if ctx.in_stair(room.level, f):
		why = "stair"
		return false
	for other in _feet:
		if (other[0] as Rect2).grow(-0.02).intersects(f):
			why = String(other[1])
			return false
	return true


## A piece backed onto a wall at `t`. Claims that stretch of wall.
func wall(side: String, t: float, id: StringName, d: float = 0.0, y: float = 0.0, s: float = 1.0,
		turn: float = 0.0) -> ManorPropPlacement:
	var size := PropLib.size_of(id) * s
	var reach := size.x if absf(turn) > 45.0 else size.z
	var along := size.z if absf(turn) > 45.0 else size.x
	var c := wall_point(side, t, d + reach * 0.5 + 0.02)
	if y < 0.3 or PropLib.entry(id)[3]:
		claim(side, t - along * 0.5, t + along * 0.5, y + size.y)
	return put(id, c.x, c.y, wall_yaw(side) + turn, y, s)


## Wall-hung piece (mirror, clock, tapestry, painting slot) centred `y` up.
func hang(side: String, t: float, id: StringName, y: float, s: float = 1.0) -> ManorPropPlacement:
	var size := PropLib.size_of(id) * s
	var c := wall_point(side, t, size.z * 0.5 + 0.01)
	if id != &"candle_sconce":
		_hung[side].append([t - size.x * 0.5 - 0.15, t + size.x * 0.5 + 0.15])
	if ManorDecorDecks.is_decor(id):
		_used[id] = true
	return dsl.prop(room, id, c.x, c.y, wall_yaw(side), y - size.y * 0.5, s)


## A grouping in a wall frame: origin `t` along `side`, items [id, lx, lz, lyaw, y, s]
## where local -Z goes into the room. Items that would block something are dropped
## when `careful`, so a group shrinks rather than blocking a door.
func group(side: String, t: float, items: Array, careful: bool = true) -> Array[ManorPropPlacement]:
	var origin := wall_point(side, t, 0.0)
	return group_at(origin, wall_yaw(side), items, careful)


func group_at(origin: Vector2, yaw: float, items: Array, careful: bool = true) -> Array[ManorPropPlacement]:
	var out: Array[ManorPropPlacement] = []
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	for it: Array in items:
		var id: StringName = it[0]
		var local := Vector3(it[1], 0.0, it[2])
		var w := b * local
		var lyaw: float = it[3] if it.size() > 3 else 0.0
		var y: float = it[4] if it.size() > 4 else 0.0
		var s: float = it[5] if it.size() > 5 else 1.0
		var p: ManorPropPlacement
		if careful and y < 0.3 and PropLib.entry(id)[3]:
			p = try_put(id, origin.x + w.x, origin.y + w.z, yaw + lyaw, s)
		else:
			p = put(id, origin.x + w.x, origin.y + w.z, yaw + lyaw, y, s)
		if p != null:
			out.append(p)
	return out


## A conversation group round room-local (x, z): `back` (a sofa or settee) on
## the group's far side facing the middle, a pair of `chair` either side facing
## in, a low table between them. `yaw` turns the group: at 0 the sofa sits at
## +z looking towards -z. Pieces that would block something are left out (and
## logged). Returns the tables placed, for dressing.
func seating(x: float, z: float, yaw: float, back: StringName, chair: StringName,
		table: StringName = &"table_tea", reach: float = 1.35) -> Array[ManorPropPlacement]:
	var b := Basis(Vector3.UP, deg_to_rad(yaw))
	var depth_back := PropLib.size_of(back).z
	var out: Array[ManorPropPlacement] = []
	var items := [[back, 0.0, 0.55 + depth_back * 0.5, 0.0], [table, 0.0, 0.0, 0.0],
			[chair, -reach, 0.0, -90.0], [chair, reach, 0.0, 90.0]]
	for it: Array in items:
		var w := b * Vector3(it[1], 0.0, it[2])
		var p := at(it[0], x + w.x, z + w.z, yaw + it[3])
		if p != null and it[0] == table:
			out.append(p)
	return out


## Pieces in a row along a wall's free spans, each `gap` apart; returns the count.
func line_wall(side: String, ids: Array, gap: float = 0.25, from: float = -1.0, to: float = -1.0) -> int:
	var placed := 0
	var queue := ids.duplicate()
	for span in free_spans(side, 0.6):
		var t: float = maxf(span[0], from) if from >= 0.0 else span[0]
		var end: float = minf(span[1], to) if to >= 0.0 else span[1]
		while not queue.is_empty():
			var id: StringName = queue[0]
			var w := PropLib.size_of(id).x
			if t + w > end:
				break
			var mid := t + w * 0.5
			var probe_d := PropLib.size_of(id).z * 0.5 + 0.02
			var c := wall_point(side, mid, probe_d)
			var probe := ManorPropPlacement.new()
			probe.prop_id = id
			probe.position = Vector3(c.x, 0.0, c.y)
			probe.yaw_deg = wall_yaw(side)
			if fits(probe):
				wall(side, mid, id)
				placed += 1
				queue.pop_front()
			t += w + gap
		if queue.is_empty():
			break
	return placed


# --- dressing ----------------------------------------------------------------------

func _deck(table: Dictionary, style: StringName) -> Array:
	var key := "%s/%s" % [table.hash(), style]
	if not _decks.has(key):
		var d: Array = (table.get(style, []) as Array).duplicate()
		for i in range(d.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = d[i]
			d[i] = d[j]
			d[j] = tmp
		_decks[key] = d
	return _decks[key]


## Next unused id from a deck that passes `ok`, or &"".
func deal(table: Dictionary, style: StringName, ok: Callable = Callable()) -> StringName:
	var d := _deck(table, style)
	for i in d.size():
		var id: StringName = d[i]
		if _used.has(id):
			continue
		if ok.is_valid() and not ok.call(id):
			continue
		d.remove_at(i)
		_used[id] = true
		return id
	return &""


## Sets small things from `style` along a surface's top, spread across its width.
func dress(surface: ManorPropPlacement, style: StringName, count: int = -1) -> int:
	var spec: Array = ManorDecorDecks.SURFACE.get(surface.prop_id, [])
	if spec.is_empty():
		return 0
	var hw: float = spec[0] * surface.scale
	var hd: float = spec[1] * surface.scale
	var n: int = spec[2] if count < 0 else count
	var top := ManorDecorDecks.top_of(surface.prop_id) * surface.scale
	var b := Basis(Vector3.UP, deg_to_rad(surface.yaw_deg))
	var chosen: Array[StringName] = []
	var room_left := hw * 2.0
	for i in n:
		var id := deal(ManorDecorDecks.DETAIL, style, func(x: StringName) -> bool:
			var sz := PropLib.size_of(x)
			return sz.x <= room_left + 0.01 and sz.z <= hd * 2.0 + 0.02 and sz.x <= hw * 2.0)
		if id == &"":
			break
		chosen.append(id)
		room_left -= PropLib.size_of(id).x + 0.06
	return _lay(surface, chosen, hw, hd, top, b)


## Sets these exact things (story pieces, chosen by hand) along a surface's top.
func set_on(surface: ManorPropPlacement, ids: Array) -> int:
	if surface == null:
		return 0
	var spec: Array = ManorDecorDecks.SURFACE.get(surface.prop_id, [0.3, 0.2, 2])
	var chosen: Array[StringName] = []
	for id: StringName in ids:
		if _used.has(id):
			continue        # already in this room: never twice
		chosen.append(id)
		if ManorDecorDecks.is_decor(id):
			_used[id] = true
	surface.set_meta(&"dressed", true)
	return _lay(surface, chosen, spec[0] * surface.scale, spec[1] * surface.scale,
			ManorDecorDecks.top_of(surface.prop_id) * surface.scale, Basis(Vector3.UP, deg_to_rad(surface.yaw_deg)))


func _lay(surface: ManorPropPlacement, chosen: Array[StringName], hw: float, hd: float, top: float, b: Basis) -> int:
	if chosen.is_empty():
		return 0
	var total := 0.0
	for id in chosen:
		total += PropLib.size_of(id).x
	var gap := (hw * 2.0 - total) / float(chosen.size() + 1)
	var x := -hw + gap
	for i in chosen.size():
		var id := chosen[i]
		var sz := PropLib.size_of(id)
		var lz := clampf(rng.randf_range(-0.3, 0.3) * (hd * 2.0 - sz.z), -hd + sz.z * 0.5, hd - sz.z * 0.5)
		var local := b * Vector3(x + sz.x * 0.5, 0.0, lz)
		var yaw := surface.yaw_deg + rng.randf_range(-18.0, 18.0)
		dsl.prop(room, id, surface.position.x + local.x, surface.position.z + local.z, yaw, top + 0.005)
		x += sz.x + gap
	return chosen.size()


## Garniture on each grand hearth's mantel shelf (the model's shelf is at 0.88
## of its height, with its own candelabras at 0.38 of its width either side of a
## centre vase): one small thing from `style` in each gap between them. The small
## hearth's shelf is too short for more than its own pieces.
func mantel(style: StringName) -> int:
	var n := 0
	for st in ctx.index.stations:
		if st.level != room.level or st.prop_id != &"fireplace_grand":
			continue
		if not room.rect.has_point(Vector2(st.position.x, st.position.z)):
			continue
		var sz := PropLib.size_of(st.prop_id)
		var b := Basis(Vector3.UP, deg_to_rad(st.yaw_deg))
		for u in [-0.19, 0.19]:
			var id := deal(ManorDecorDecks.DETAIL, style, func(x: StringName) -> bool:
				var s := PropLib.size_of(x)
				return s.x <= 0.3 and s.z <= sz.z * 0.5 and s.y <= 0.45)
			if id == &"":
				return n
			var off := b * Vector3(u * sz.x, 0.0, 0.0)
			dsl.prop(room, id, st.position.x - room.rect.position.x + off.x, st.position.z - room.rect.position.y + off.z,
					st.yaw_deg, sz.y * 0.88 + 0.005)
			n += 1
	return n


## Dresses every surface placed so far that hasn't been dressed yet.
func dress_all(style: StringName, extra: int = 0) -> int:
	var n := 0
	for s in surfaces:
		if not s.has_meta(&"dressed"):
			s.set_meta(&"dressed", true)
			var spec: Array = ManorDecorDecks.SURFACE.get(s.prop_id, [0, 0, 0])
			n += dress(s, style, spec[2] + extra)
	return n


## A floor accent from `style` at (x, z) if it fits; returns it or null.
func accent(style: StringName, x: float, z: float, yaw: float = 0.0) -> ManorPropPlacement:
	var d := _deck(ManorDecorDecks.FLOOR, style)
	for i in d.size():
		var id: StringName = d[i]
		if _used.has(id):
			continue
		var p := try_put(id, x, z, yaw)
		if p != null:
			d.remove_at(i)
			return p
	return null


## Floor accents into the room's four corners (each tried, skipped if blocked).
func accent_corners(style: StringName, inset: float = 0.75) -> int:
	var n := 0
	for c in [Vector2(inset, inset), Vector2(width() - inset, inset), Vector2(inset, depth() - inset),
			Vector2(width() - inset, depth() - inset)]:
		if accent(style, c.x, c.y) != null:
			n += 1
	return n


## A wall piece from `style` centred on the widest span of `side` clear of
## openings, other hung pieces and tall furniture.
func wall_accent(side: String, style: StringName, y: float = 1.7) -> ManorPropPlacement:
	var spans := free_spans(side, 1.0, false)
	if spans.is_empty():
		return null
	spans.sort_custom(func(a: Array, b: Array) -> bool: return a[1] - a[0] > b[1] - b[0])
	var span: Array = spans[0]
	var id := deal(ManorDecorDecks.WALL, style, func(x: StringName) -> bool:
		return PropLib.size_of(x).x <= span[1] - span[0])
	if id == &"":
		return null
	var t: float = (span[0] + span[1]) * 0.5
	return hang(side, t, id, y)


## Sconces either side of every free span longer than `spacing`.
func sconces(spacing: float = 4.5, y: float = 1.95) -> void:
	for side in SIDES:
		for span in free_spans(side, 1.0, false):
			var n := int((span[1] - span[0]) / spacing)
			for i in n:
				var t: float = span[0] + (i + 0.5) * (span[1] - span[0]) / n
				hang(side, t, &"candle_sconce", y)


## Hanging light at a room-local point, under the ceiling.
func light(id: StringName, x: float, z: float, drop: float = 0.05) -> ManorPropPlacement:
	var y := ManorFurnishContext.ceiling_of(room) - PropLib.size_of(id).y - drop
	return dsl.prop(room, id, x, z, 0.0, y)


## A painting slot (L39 fills it) centred `y` up the wall; scale varies the size.
func art(side: String, t: float, id: StringName = &"painting_medium", y: float = 1.75, s: float = 1.0) -> ManorPropPlacement:
	var p := hang(side, t, id, y, s)
	# L39 hangs frames up to 2.3 m wide in a large slot (docs/contracts/manor_art.md):
	# keep sconces and wall pieces this far either side of the slot's centre
	var clear: float = ART_CLEAR.get(id, 0.5)
	_hung[side].append([t - clear, t + clear])
	return p

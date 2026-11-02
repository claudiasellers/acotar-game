## Hangs the manor's paintings (L39). The layouts place frames as wall slots
## (painting_large, painting_medium, painting_small, portrait_masked; their
## positions are the refurnish lane's). After the house is built, and before
## its props merge, each slot's stand-in is replaced by a Blender frame with
## a plaque and a canvas from ManorArtCatalog.
##
## No work hangs twice anywhere in the house: assign() hands out works once
## each, best fit first, and tests/unit/manor_art/test_manor_art.gd keeps it
## that way. Pinned works go to their rooms first (the ch7 green-glass still
## life in the entrance hall). Deterministic: the same layouts hang the same
## pictures every time, so the merged-room cache stays valid.
class_name ManorArtHanger
extends RefCounted

const FRAME_DIR := "res://world/spring_court/manor_estate/art/frames/"
const CANVAS_SHADER := preload("res://world/spring_court/manor_estate/art/manor_canvas.gdshader")

## Slot prop id -> slot class.
const SLOT_CLASSES := {
	&"painting_large": &"large", &"painting_medium": &"medium",
	&"painting_small": &"small", &"portrait_masked": &"portrait",
}

## The largest canvas (metres) a slot class holds; major works get the big box.
const BOX := {
	&"large": Vector2(1.6, 1.25), &"large_major": Vector2(2.3, 1.62),
	&"medium": Vector2(1.25, 1.1), &"medium_major": Vector2(1.4, 1.2),
	&"small": Vector2(0.62, 0.62), &"small_major": Vector2(0.7, 0.62),
	&"portrait": Vector2(1.05, 1.4), &"portrait_major": Vector2(1.3, 1.95),
}

## Works whose themes are only these hang only in rooms that share one: the
## Keeper's ruling that Tamlin's father and brothers stay in dim side rooms.
const RESTRICTED := [&"store", &"store_secret", &"portrait_dim"]

## Frame styles that exist for each shape (tools/blender/manor_frames.py).
const SHAPE_STYLES := {
	&"land": [&"gilt_baroque", &"gilt_simple", &"walnut_gold", &"silver_leaf", &"ebony_dark", &"crocus_spring", &"pearl_roses"],
	&"port": [&"gilt_baroque", &"gilt_simple", &"walnut_gold", &"silver_leaf", &"ebony_dark", &"crocus_spring", &"pearl_roses", &"mask_crest"],
	&"square": [&"gilt_baroque", &"gilt_simple", &"walnut_gold", &"silver_leaf", &"ebony_dark", &"crocus_spring", &"pearl_roses"],
	&"full": [&"gilt_baroque", &"gilt_simple", &"pearl_roses", &"mask_crest"],
	&"round": [&"tondo_garland", &"crocus_spring"],
	&"oval_p": [&"oval_ribbon", &"oval_pearl", &"mask_crest", &"pearl_roses"],
	&"oval_l": [&"oval_ribbon", &"oval_pearl"],
	&"arch_p": [&"rococo_arch"],
}

## Frame styles a room theme favours.
const THEME_STYLES := {
	&"store": [&"ebony_dark", &"gilt_simple", &"walnut_gold"],
	&"store_secret": [&"ebony_dark", &"gilt_simple"],
	&"portrait_dim": [&"ebony_dark", &"gilt_simple"],
	&"library": [&"walnut_gold", &"gilt_simple", &"ebony_dark"],
	&"study": [&"walnut_gold", &"ebony_dark", &"gilt_simple"],
	&"map": [&"walnut_gold", &"gilt_simple"],
	&"mask": [&"mask_crest", &"gilt_baroque"],
	&"portrait": [&"mask_crest", &"gilt_baroque", &"gilt_simple", &"silver_leaf"],
	&"portrait_full": [&"gilt_baroque", &"mask_crest"],
	&"bedroom": [&"pearl_roses", &"silver_leaf", &"crocus_spring"],
	&"nursery": [&"crocus_spring", &"pearl_roses"],
	&"service": [&"crocus_spring", &"walnut_gold", &"silver_leaf"],
	&"alis": [&"walnut_gold"],
	&"stillroom": [&"crocus_spring", &"walnut_gold"],
	&"kitchen": [&"walnut_gold", &"crocus_spring"],
	&"night": [&"silver_leaf", &"ebony_dark"],
}
const DEFAULT_STYLES := [&"gilt_baroque", &"gilt_simple", &"silver_leaf", &"pearl_roses", &"crocus_spring", &"walnut_gold"]

## Slots that had to reuse a work on the last assign() (the test wants none).
static var last_duplicates: PackedStringArray = PackedStringArray()
static var _materials: Dictionary = {}
## The most of a room's slots one genre takes while other works can fill them.
const GENRE_SHARE := 0.4
const GENRE_SHARE_CLASS := 0.5


## Every art slot of the house in build order:
## [{key, room, room_index, placement, cls, order}].
static func slots(all: ManorHouseIndex) -> Array:
	var out: Array = []
	for ri in all.rooms.size():
		var room: ManorRoomDef = all.rooms[ri]
		var order := 0
		for p in room.props:
			if SLOT_CLASSES.has(p.prop_id):
				out.append({key = "%s@%d#%d" % [room.id, room.level, order], room = room, room_index = ri,
						placement = p, cls = SLOT_CLASSES[p.prop_id], order = order})
				order += 1
	return out


## Slot key -> ManorArtWork for every slot, each work at most once.
static func assign(all: ManorHouseIndex, cat: ManorArtCatalog) -> Dictionary:
	var ss := slots(all)
	var out: Dictionary = {}
	var used: Dictionary = {}
	var themes: Array = []
	for s: Dictionary in ss:
		var room: ManorRoomDef = s.room
		themes.append(cat.themes_for(room.id, room.level))
	# pinned works first, in their own rooms
	for w in cat.works:
		if w.pin == &"" or w.reserve:
			continue
		var best := _pinned_slot(w, ss, themes, out)
		if best >= 0:
			out[ss[best].key] = w
			used[w.id] = true
	# then every (slot, work) pair, best score first
	var keys := PackedInt64Array()
	for i in ss.size():
		var s: Dictionary = ss[i]
		if out.has(s.key):
			continue
		for j in cat.works.size():
			var w: ManorArtWork = cat.works[j]
			if w.reserve or used.has(w.id) or not _fits(w, s.cls) or not _allowed(w, themes[i]):
				continue
			var score := _theme_rank(w, themes[i]) * 10 + _class_fit(w, s.cls, themes[i])
			keys.append(score * 1000000 + i * 1000 + j)
	keys.sort()
	# no genre takes more than GENRE_SHARE of a room, or GENRE_SHARE_CLASS of
	# its slots of one size, while other works can fill them;
	# pairs over the share wait for a second pass
	var room_n: Dictionary = {}
	var room_genre: Dictionary = {}
	for s: Dictionary in ss:
		for rk: String in ["%d" % s.room_index, "%d|%s" % [s.room_index, s.cls]]:
			room_n[rk] = int(room_n.get(rk, 0)) + 1
	for key: String in out:
		var s0: Dictionary = _slot_by_key(ss, key)
		for g0: String in ["%d|%s" % [s0.room_index, (out[key] as ManorArtWork).genre],
				"%d|%s|%s" % [s0.room_index, s0.cls, (out[key] as ManorArtWork).genre]]:
			room_genre[g0] = int(room_genre.get(g0, 0)) + 1
	# portrait slots first: only portraits fit them, so they must not run short
	for tier in 2:
		var waiting := PackedInt64Array()
		for k in keys:
			var i := int(k / 1000) % 1000
			var j := int(k % 1000)
			var s: Dictionary = ss[i]
			if (s.cls == &"portrait") != (tier == 0):
				continue
			var w: ManorArtWork = cat.works[j]
			if out.has(s.key) or used.has(w.id):
				continue
			var g := "%d|%s" % [s.room_index, w.genre]
			var gc := "%d|%s|%s" % [s.room_index, s.cls, w.genre]
			if tier == 1 and (int(room_genre.get(g, 0)) >= maxi(2, ceili(int(room_n["%d" % s.room_index]) * GENRE_SHARE)) \
					or int(room_genre.get(gc, 0)) >= maxi(2, ceili(int(room_n["%d|%s" % [s.room_index, s.cls]]) * GENRE_SHARE_CLASS))):
				waiting.append(k)
				continue
			out[s.key] = w
			used[w.id] = true
			room_genre[g] = int(room_genre.get(g, 0)) + 1
			room_genre[gc] = int(room_genre.get(gc, 0)) + 1
		for k in waiting:
			var s: Dictionary = ss[int(k / 1000) % 1000]
			var w: ManorArtWork = cat.works[int(k % 1000)]
			if not out.has(s.key) and not used.has(w.id):
				out[s.key] = w
				used[w.id] = true
	_interleave(ss, out)
	# more slots than works: reuse, never in the same room (reported, and failed by the test)
	last_duplicates = PackedStringArray()
	for i in ss.size():
		var s: Dictionary = ss[i]
		if out.has(s.key):
			continue
		var room_works: Array = []
		for t: Dictionary in ss:
			if t.room_index == s.room_index and out.has(t.key):
				room_works.append(out[t.key])
		for w in cat.works:
			if not w.reserve and _fits(w, s.cls) and _allowed(w, themes[i]) and not room_works.has(w):
				out[s.key] = w
				last_duplicates.append(s.key)
				break
	return out


static func _slot_by_key(ss: Array, key: String) -> Dictionary:
	for s: Dictionary in ss:
		if s.key == key:
			return s
	return {}


## Along each wall run of one slot class in a room, no two neighbours share a
## genre where the room's mix allows it: the works are dealt out round-robin,
## the biggest genre first. Pinned works keep their slots.
static func _interleave(ss: Array, out: Dictionary) -> void:
	var runs: Dictionary = {}
	for s: Dictionary in ss:
		if not out.has(s.key) or (out[s.key] as ManorArtWork).pin != &"":
			continue
		var rk := "%d|%s" % [s.room_index, s.cls]
		if not runs.has(rk):
			runs[rk] = []
		runs[rk].append(s)
	for rk: String in runs:
		var run: Array = runs[rk]
		if run.size() < 3:
			continue
		var by_genre: Dictionary = {}
		for s: Dictionary in run:
			var w: ManorArtWork = out[s.key]
			if not by_genre.has(w.genre):
				by_genre[w.genre] = []
			by_genre[w.genre].append(w)
		if by_genre.size() < 2:
			continue
		var groups: Array = by_genre.values()
		groups.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size() or (a.size() == b.size() and String(a[0].genre) < String(b[0].genre)))
		# deal into even slots, then odd ones, biggest genre first
		var dealt: Array = []
		for gr: Array in groups:
			dealt.append_array(gr)
		var order: Array = []
		for i in range(0, run.size(), 2):
			order.append(i)
		for i in range(1, run.size(), 2):
			order.append(i)
		for n in run.size():
			out[run[order[n]].key] = dealt[n]


## How far behind a slot (along the prop's back, +Z) the room's inner wall
## face is, in metres, 1 cm proud of it. Each room builds its own walls
## ManorHouseBuilder.WALL thick inside its rect, so a slot placed a little
## into that thickness still hangs on the face. `fallback` when no wall is
## within half a metre of it (a free-standing or odd-shaped spot).
static func _wall_behind(room: ManorRoomDef, p: ManorPropPlacement, fallback: float) -> float:
	var back := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(p.yaw_deg))
	var t := INF
	var lo := Vector2(ManorHouseBuilder.WALL, ManorHouseBuilder.WALL)
	var hi := room.rect.size - lo
	for axis in 2:
		var d := back.x if axis == 0 else back.z
		var at := p.position.x if axis == 0 else p.position.z
		if absf(d) < 0.7:
			continue
		var face := (hi[axis] if d > 0.0 else lo[axis])
		t = minf(t, (face - at) / d)
	if t == INF or absf(t - fallback) > 0.5:
		return fallback
	return t - 0.01


## The slot a pinned work takes: the first alternative room that has a free,
## fitting slot; with "@x,z", the one nearest that room-local point.
static func _pinned_slot(w: ManorArtWork, ss: Array, themes: Array, out: Dictionary) -> int:
	for alt in String(w.pin).split("|", false):
		var room_id := alt.get_slice("@", 0)
		var near := Vector2.INF
		if alt.contains("@"):
			var xz := alt.get_slice("@", 1).split(",")
			near = Vector2(float(xz[0]), float(xz[1]))
		var best := -1
		var best_fit := INF
		for i in ss.size():
			var s: Dictionary = ss[i]
			if String((s.room as ManorRoomDef).id) != room_id or out.has(s.key) or not _fits(w, s.cls):
				continue
			var p: ManorPropPlacement = s.placement
			var f: float
			if near != Vector2.INF:
				f = Vector2(p.position.x, p.position.z).distance_to(near)
			else:
				f = _class_fit(w, s.cls, themes[i]) + (20 if s.cls == &"small" else 0)
			if f < best_fit:
				best_fit = f
				best = i
		if best >= 0:
			return best
	return -1


static func _fits(w: ManorArtWork, cls: StringName) -> bool:
	if cls == &"portrait":
		return w.genre == &"portrait" and w.fmt in [&"port", &"oval_p", &"arch_p"]
	if cls == &"small":
		return not w.major
	return true


static func _allowed(w: ManorArtWork, room_themes: PackedStringArray) -> bool:
	for t in w.themes:
		if not RESTRICTED.has(StringName(t)):
			return true
	for t in w.themes:
		if room_themes.has(t):
			return true
	return false


## 0 when the room's first theme is the work's, 1 for its second...; 10 if none.
static func _theme_rank(w: ManorArtWork, room_themes: PackedStringArray) -> int:
	for r in room_themes.size():
		if w.themes.has(room_themes[r]):
			return r
	return 10


## How well a work's size suits a slot class (0 best).
static func _class_fit(w: ManorArtWork, cls: StringName, room_themes: PackedStringArray) -> int:
	match cls:
		&"large":
			if w.major:
				return 0
			return 4 if w.fmt in [&"land", &"oval_l"] else 6
		&"medium":
			return 9 if w.major else 0
		&"small":
			return 0 if w.fmt in [&"square", &"round", &"oval_p", &"oval_l", &"arch_p"] or w.genre in [&"plate", &"botanical"] else 3
		&"portrait":
			if w.major:
				return 0 if room_themes.has("portrait_full") else 7
			return 0
	return 5


## The canvas size in metres for a work in a slot class.
static func canvas_size(w: ManorArtWork, cls: StringName) -> Vector2:
	var box: Vector2 = BOX[StringName(String(cls) + "_major")] if w.major else BOX[cls]
	var a := w.aspect()
	var size := Vector2(box.x, box.x / a)
	if size.y > box.y:
		size = Vector2(box.y * a, box.y)
	return size


## The frame style for a work hanging in a room (varied, deterministic).
static func frame_style(w: ManorArtWork, room_themes: PackedStringArray) -> StringName:
	var shape := w.shape()
	var avail: Array = SHAPE_STYLES.get(shape, SHAPE_STYLES[&"land"])
	var pool: Array = []
	for t in room_themes:
		for st: StringName in THEME_STYLES.get(StringName(t), []):
			if avail.has(st) and not pool.has(st):
				pool.append(st)
		if pool.size() >= 2:
			break
	if pool.is_empty():
		for st: StringName in DEFAULT_STYLES:
			if avail.has(st):
				pool.append(st)
	if pool.is_empty():
		pool = avail
	return pool[absi(String(w.id).hash()) % pool.size()]


## The one canvas material: every painting is a layer of the same array, so
## a room's canvases merge into a single draw.
static func canvas_material(sheet: String) -> Material:
	if not _materials.has(sheet):
		var m := ShaderMaterial.new()
		m.shader = CANVAS_SHADER
		var tex := load(sheet) as TextureLayered
		m.set_shader_parameter(&"sheet", tex)
		if tex != null:
			m.set_shader_parameter(&"sheet_px", Vector2(tex.get_width(), tex.get_height()))
		m.resource_name = "canvas_" + sheet.get_file().get_basename()
		_materials[sheet] = m
	return _materials[sheet]


## Replaces every art slot's stand-in under `house` (built from `all`) with a
## framed painting. Returns the number hung.
static func hang(house: Node3D, all: ManorHouseIndex) -> int:
	var hung: Array[int] = [0]
	hang_paced(house, all, null, hung)
	return hung[0]


## hang() across frames with a `pace`: await it. Counts into `hung`.
static func hang_paced(house: Node3D, all: ManorHouseIndex, pace: BuildPace, hung: Array[int] = [0]) -> void:
	var cat := ManorArtCatalog.load_default()
	if cat == null or cat.works.is_empty():
		push_warning("ManorArtHanger: no catalogue at %s" % ManorArtCatalog.PATH)
		return
	var chosen := assign(all, cat)
	if not last_duplicates.is_empty():
		push_warning("ManorArtHanger: more art slots than paintings; reused at %s" % ", ".join(last_duplicates))
	for s: Dictionary in slots(all):
		if pace:
			await pace.tick()
		var room: ManorRoomDef = s.room
		var prop := _slot_prop(house, room, s.room_index, s.placement)
		if prop == null or not chosen.has(s.key):
			continue
		_dress(prop, chosen[s.key], s, cat.themes_for(room.id, room.level))
		hung[0] += 1


## The prop for a placement. The builder adds rooms first, in order, so room
## i is child i; a room id used on two levels gets an engine-made name there,
## so the index is tried first and the name only as a fallback.
static func _slot_prop(house: Node3D, room: ManorRoomDef, index: int, p: ManorPropPlacement) -> Node3D:
	var node := house.get_child(index) as Node3D if index < house.get_child_count() else null
	var prop := _slot_node(node, room, p) if node != null else null
	if prop == null:
		node = house.get_node_or_null(NodePath(String(room.id))) as Node3D
		prop = _slot_node(node, room, p) if node != null else null
	return prop


## The prop built for a placement: the child with a "Look" at its position.
static func _slot_node(room_node: Node3D, room: ManorRoomDef, p: ManorPropPlacement) -> Node3D:
	var at := Vector3(room.rect.position.x, ManorHouseBuilder.floor_y(room.level), room.rect.position.y) + p.position
	for c in room_node.get_children():
		var n := c as Node3D
		if n != null and n.get_node_or_null("Look") != null and n.position.distance_to(at) < 0.001:
			return n
	return null


static func _dress(prop: Node3D, w: ManorArtWork, s: Dictionary, room_themes: PackedStringArray) -> void:
	var p: ManorPropPlacement = s.placement
	var room: ManorRoomDef = s.room
	var cls: StringName = s.cls
	var stand_in := PropLib.size_of(p.prop_id)
	var size := canvas_size(w, cls)
	var long := maxf(size.x, size.y)
	# keep the whole frame, crest to plaque, between floor and ceiling
	var sc := p.scale
	var room_h := ManorHouseBuilder.ceiling_of(room)
	var above := 0.17 * long   # moulding and crest
	var below := 0.24 * long   # moulding and plaque
	var span := size.y + above + below
	var room_for := (room_h - 0.4) / sc
	if span > room_for:
		var k := room_for / span
		size *= k
		long *= k
		above *= k
		below *= k
	var cy := stand_in.y * 0.5
	var lo := (0.25 - p.position.y) / sc + size.y * 0.5 + below
	var hi := (room_h - 0.12 - p.position.y) / sc - size.y * 0.5 - above
	cy = clampf(cy, lo, maxf(lo, hi))
	var old := prop.get_node("Look")
	prop.remove_child(old)
	old.free()
	var look := Node3D.new()
	look.name = "Look"
	# the frame's back board sits on the wall: the room's own wall behind the
	# slot when it is near, else the back of the stand-in
	look.position = Vector3(0.0, cy, _wall_behind(room, p, stand_in.z * 0.5 * sc) / sc - 0.024 * long)
	look.set_meta(&"art_id", w.id)
	look.set_meta(&"art_long", long)
	prop.add_child(look)
	prop.set_meta(&"art_id", w.id)
	var style := frame_style(w, room_themes)
	var fname := "%s_%s" % [style, w.shape()]
	var frame := PropModels.pair(FRAME_DIR + fname + ".glb", fname)
	if not frame.is_empty():
		var fm := MeshInstance3D.new()
		fm.name = "Frame"
		fm.mesh = frame[0]
		fm.scale = Vector3.ONE * long
		look.add_child(fm)
	var canvas := MeshInstance3D.new()
	canvas.name = "Canvas"
	canvas.mesh = ManorArtCanvas.mesh(w.shape(), size, w.uv, w.layer, canvas_material(w.sheet))
	canvas.position.z = -0.002 * long
	look.add_child(canvas)

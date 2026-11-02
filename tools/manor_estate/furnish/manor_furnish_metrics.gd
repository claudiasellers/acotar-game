## The refurnish's numbers for one room, read from the saved layouts:
## floor coverage, small details, repeats, bare 4x4 m patches, blocked door
## aprons, door-to-door walkability and story keep-clear hits. Used by
## tools/manor_estate/furnish_report.gd and the contract test.
class_name ManorFurnishMetrics
extends RefCounted

## Rooms the refurnish has done, by hand-in. The contract test holds these to
## the bar; the others are reported only.
const REFURNISHED := [
	# L38-1: the rooms Feyre walks through in Act I
	&"entrance_hall", &"dining_hall", &"library", &"tamlin_study", &"gallery", &"east_corridor",
	&"west_corridor", &"upper_hall", &"feyre_bedroom", &"feyre_bath", &"painting_room",
	&"svc_kitchen", &"svc_infirmary", &"svc_passage_0", &"svc_alis_room", &"svc_servants_hall",
	&"tamlin_bedchamber",
]

## Floor coverage wanted: 15% in rooms up to 100 m2, easing to 8% at 250 m2
## and over (a state room needs its circulation space; the bare-cell rule
## keeps a big room from being empty in patches). Passages 5%.
const COVERAGE_ROOM := 0.15
const COVERAGE_BIG := 0.08
const SMALL_AREA := 100.0
const BIG_AREA := 250.0
const COVERAGE_PASSAGE := 0.05
## One small detail per 8 m2 in rooms; one per 12 m2 in passages, where the
## painting slots count (a gallery's details are its pictures).
const DETAIL_AREA := 8.0
const DETAIL_AREA_PASSAGE := 12.0
## Rooms the book describes as nearly empty: [coverage, details, why].
const CANON_SPARSE := {
	&"painting_room": [0.03, 20, "ch19 [C]: an empty room with a table full of canvases, clear bright light"],
}
## Floor taken by a table or sink a scene builds at its stage mark (m2).
const BUILT_AREA := 1.0
## A piece of furniture may come in a matched pair; decor never repeats.
const PAIR := 2
const CELL := 4.0
const AGENT := 0.4
const GRID := 0.25

## Pieces that don't count as furniture footprint (they sit flat or hang).
const FLAT := [&"rug_large", &"rug_round", &"rug_runner", &"picnic_blanket", &"bath_sunken"]


static func is_passage(room: ManorRoomDef) -> bool:
	return room.kind == &"corridor" or room.kind == &"stair_hall" or String(room.id).contains("corridor") \
			or String(room.id).contains("passage") or String(room.id).contains("stair") or room.id == &"upper_hall" \
			or room.id == &"gallery" or room.id == &"entrance_hall"


static func want_coverage(room: ManorRoomDef) -> float:
	if CANON_SPARSE.has(room.id):
		return CANON_SPARSE[room.id][0]
	if is_passage(room):
		return COVERAGE_PASSAGE
	var area := room.rect.size.x * room.rect.size.y
	var t := clampf((area - SMALL_AREA) / (BIG_AREA - SMALL_AREA), 0.0, 1.0)
	return lerpf(COVERAGE_ROOM, COVERAGE_BIG, t)


static func footprint(room: ManorRoomDef, p: ManorPropPlacement) -> Rect2:
	var size := PropLib.size_of(p.prop_id) * p.scale
	var turned := absf(fposmod(p.yaw_deg, 180.0) - 90.0) < 45.0
	var ext := Vector2(size.z, size.x) if turned else Vector2(size.x, size.z)
	var c := room.rect.position + Vector2(p.position.x, p.position.z)
	return Rect2(c - ext * 0.5, ext)


static func is_floor_piece(p: ManorPropPlacement) -> bool:
	return p.position.y < 0.3 and PropLib.entry(p.prop_id)[3] and not FLAT.has(p.prop_id)


static func measure(room: ManorRoomDef, ctx: ManorFurnishContext, stations: Array = []) -> Dictionary:
	var area := room.rect.size.x * room.rect.size.y
	var foot := 0.0
	var details := 0
	var counts := {}
	var floor_rects: Array = []
	var floor_ids: Array = []
	var any_rects: Array = []
	for p in room.props:
		counts[p.prop_id] = counts.get(p.prop_id, 0) + 1
		var f := footprint(room, p)
		if is_floor_piece(p):
			foot += f.get_area()
			floor_rects.append(f)
			floor_ids.append(p.prop_id)
		if p.position.y < 0.3:
			any_rects.append(f)
		var sz := PropLib.size_of(p.prop_id)
		var lighting: bool = PropLib.entry(p.prop_id)[0] == &"lighting" and sz.y > 0.6
		if not lighting and not String(p.prop_id).begins_with("painting") and p.prop_id != &"portrait_masked" \
				and (p.position.y >= 0.3 or not PropLib.entry(p.prop_id)[3]) and max(sz.x, sz.z) < 1.2:
			details += 1
	for s in stations:
		if s.level == room.level and room.rect.has_point(Vector2(s.position.x, s.position.z)):
			var sz := PropLib.size_of(s.prop_id)
			var f := Rect2(Vector2(s.position.x, s.position.z) - Vector2(sz.x, sz.z) * 0.5, Vector2(sz.x, sz.z))
			foot += f.get_area()
			floor_rects.append(f)
			any_rects.append(f)
	# the stairs that rise from this floor stand on it like furniture
	for st in ctx.index.stairs:
		if st.level_from == room.level and st.rect.intersects(room.rect):
			var sr: Rect2 = st.rect.intersection(room.rect)
			foot += sr.get_area()
			any_rects.append(sr)
	var repeats: Array = []
	for id in counts:
		var allowed := 1 if ManorDecorDecks.is_small_decor(id) else PAIR
		if counts[id] > allowed and not ManorDecorDecks.MAY_REPEAT.has(id):
			repeats.append("%s x%d" % [id, counts[id]])
	# bare 4x4 m cells (cells at least 2 m on each side)
	var bare := 0
	var bare_list: Array = []
	var nx := maxi(1, roundi(room.rect.size.x / CELL))
	var nz := maxi(1, roundi(room.rect.size.y / CELL))
	var cw := room.rect.size.x / nx
	var cd := room.rect.size.y / nz
	for i in nx:
		for j in nz:
			var cell := Rect2(room.rect.position + Vector2(i * cw, j * cd), Vector2(cw, cd))
			var hit := false
			for r in any_rects:
				if (r as Rect2).intersects(cell):
					hit = true
					break
			if not hit:
				bare += 1
				bare_list.append(cell.get_center() - room.rect.position)
	# door aprons
	var aprons := ctx.door_aprons(room)
	var blocked_doors := 0
	var blockers: Array = []
	for a in aprons:
		for i in floor_rects.size():
			if (a as Rect2).intersects(floor_rects[i]):
				blocked_doors += 1
				blockers.append(floor_ids[i])
				break
	# keep-clear
	var story_hits: Array = []
	for p in room.props:
		if is_floor_piece(p):
			var z := ManorKeepClear.hits(ctx.keep_clear, room.level, footprint(room, p))
			if not z.is_empty():
				story_hits.append("%s near %s" % [p.prop_id, z.get("why", "?")])
	var unreachable := _unreachable_doors(room, floor_rects, aprons)
	# a table or sink a story scene builds at its mark stands on this floor too
	for z: Dictionary in ctx.keep_clear:
		if z.level == room.level and z.get("built", false) and room.rect.has_point(z.a):
			foot += BUILT_AREA
	var passage := is_passage(room)
	# coverage is of the floor that may be furnished: not the story's floor or the door aprons
	var usable := area * (1.0 - _kept_fraction(room, ctx))
	var coverage := foot / maxf(usable, 1.0)
	var art := 0
	for id in [&"painting_large", &"painting_medium", &"painting_small", &"portrait_masked"]:
		art += counts.get(id, 0)
	if passage:
		details += art
	var need_details := clampi(int(area / (DETAIL_AREA_PASSAGE if passage else DETAIL_AREA)), 6, 45)
	if CANON_SPARSE.has(room.id):
		need_details = mini(need_details, CANON_SPARSE[room.id][1])
	return {
		"id": room.id, "area": area, "coverage": coverage, "details": details, "need_details": need_details,
		"repeats": repeats, "bare_cells": bare, "bare_list": bare_list, "cells": nx * nz, "blocked_doors": blocked_doors, "blockers": blockers,
		"story_hits": story_hits, "unreachable_doors": unreachable, "passage": passage,
		"art_slots": art, "want_coverage": want_coverage(room),
		"ok_coverage": coverage >= want_coverage(room),
		"ok_details": details >= need_details,
	}


## Share of the room's floor inside a story keep-clear zone or a door apron
## (sampled on a 0.5 m grid).
static func _kept_fraction(room: ManorRoomDef, ctx: ManorFurnishContext) -> float:
	var aprons := ctx.door_aprons(room)
	var n := 0
	var kept := 0
	var y := room.rect.position.y + 0.25
	while y < room.rect.end.y:
		var x := room.rect.position.x + 0.25
		while x < room.rect.end.x:
			var p := Vector2(x, y)
			n += 1
			var hit := false
			for a in aprons:
				if (a as Rect2).has_point(p):
					hit = true
					break
			if not hit:
				for z: Dictionary in ctx.keep_clear:
					if z.level == room.level and ManorKeepClear.distance(z, p) < z.r:
						hit = true
						break
			kept += 1 if hit else 0
			x += 0.5
		y += 0.5
	return float(kept) / maxf(n, 1)


## Doors whose aprons can't reach the first door's apron on a 0.25 m grid with
## a 0.4 m-radius walker (furniture inflated by the radius, walls by the face).
static func _unreachable_doors(room: ManorRoomDef, floor_rects: Array, aprons: Array) -> int:
	if aprons.size() < 2:
		return 0
	var r := room.rect.grow(-(ManorFurnisher.WALL_FACE + AGENT))
	var nx := int(r.size.x / GRID)
	var nz := int(r.size.y / GRID)
	if nx <= 0 or nz <= 0:
		return 0
	var blocked := PackedByteArray()
	blocked.resize(nx * nz)
	for i in nx:
		for j in nz:
			var c := r.position + Vector2((i + 0.5) * GRID, (j + 0.5) * GRID)
			for f in floor_rects:
				if (f as Rect2).grow(AGENT).has_point(c):
					blocked[j * nx + i] = 1
					break
	var cells_of := func(a: Rect2) -> Array:
		var out: Array = []
		var ar := a.grow(0.3)
		for i in nx:
			for j in nz:
				var c := r.position + Vector2((i + 0.5) * GRID, (j + 0.5) * GRID)
				if ar.has_point(c) and blocked[j * nx + i] == 0:
					out.append(j * nx + i)
		return out
	var start: Array = cells_of.call(aprons[0])
	var seen := PackedByteArray()
	seen.resize(nx * nz)
	var queue: Array = start.duplicate()
	for s in start:
		seen[s] = 1
	while not queue.is_empty():
		var k: int = queue.pop_back()
		var i := k % nx
		var j := k / nx
		for dlt in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = i + dlt.x
			var nj: int = j + dlt.y
			if ni < 0 or nj < 0 or ni >= nx or nj >= nz:
				continue
			var nk: int = nj * nx + ni
			if seen[nk] == 0 and blocked[nk] == 0:
				seen[nk] = 1
				queue.append(nk)
	var bad := 0
	for a_i in range(1, aprons.size()):
		var reached := false
		for c in cells_of.call(aprons[a_i]):
			if seen[c] == 1:
				reached = true
				break
		if not reached:
			bad += 1
	return bad

## Dresses the stable block's outer walls in the manor's own façade (L56): the
## user saw its long blank side from the west parterre as "a random building",
## a plain cream box under a flat blue roof. Now its garden faces carry the L42
## alabaster ashlar, plinth, pilasters, crowning cornice and an arched window
## to every stall, whose panes glow warm at dusk like the house's, with climbing
## roses on the pilasters. The yard faces keep their stall doors.
## [X] invented: the stables' architecture (the book only has Feyre ride out).
##
## Reuses the façade kit (tools/blender/manor_facade.py) as one MultiMesh per
## piece, so the whole block costs six draw calls more than the bare walls.
class_name ManorStablesDress
extends RefCounted

## Window: arched opening, bottom and top above the yard floor.
const WIN_W := 1.4
const WIN_BOTTOM := 1.5
const WIN_TOP := 4.1
## Window spacing on the long sides (one per stall).
const BAY := ManorStables.STALL_W
const PIECES: Array[StringName] = [&"facade_plinth", &"facade_cornice", &"facade_pilaster",
	&"facade_surround_arch", &"facade_climber_rose"]


## The outer (non-yard) wall runs: {a, b, out}, a and b on the wall's centre line.
static func runs() -> Array:
	var w := ManorStables.WEST
	var e := ManorStables.EAST
	var n := ManorStables.NORTH
	return [
		{"a": Vector2(w.position.x, w.end.y), "b": Vector2(w.position.x, n.position.y), "out": Vector2(-1, 0)},
		{"a": Vector2(w.position.x, w.end.y), "b": Vector2(w.end.x, w.end.y), "out": Vector2(0, 1)},
		{"a": Vector2(e.end.x, n.position.y), "b": Vector2(e.end.x, e.end.y), "out": Vector2(1, 0)},
		{"a": Vector2(e.position.x, e.end.y), "b": Vector2(e.end.x, e.end.y), "out": Vector2(0, 1)},
		{"a": Vector2(n.position.x, n.position.y), "b": Vector2(n.end.x, n.position.y), "out": Vector2(0, -1)},
	]


## Window centres along each run (metres from a), one per bay, clear of the corners.
static func windows_on(run: Dictionary) -> Array[float]:
	var length := (run.a as Vector2).distance_to(run.b)
	var out: Array[float] = []
	var n := maxi(1, floori((length - 1.0) / BAY))
	var step := length / n
	for i in n:
		out.append((i + 0.5) * step)
	return out


## Piece id -> Array[Transform3D], plus &"panes" -> [[Transform3D, seed, level], ...].
static func placements(y: float) -> Dictionary:
	var plan := {}
	for id in PIECES:
		plan[id] = []
	plan[&"panes"] = []
	var face_off := 0.45 * 0.5
	for run: Dictionary in runs():
		var a: Vector2 = run.a
		var dir: Vector2 = ((run.b as Vector2) - a).normalized()
		var out: Vector2 = run.out
		var length := a.distance_to(run.b)
		var face := func(along: float, proud: float = 0.0) -> Vector2:
			return a + dir * along + out * (face_off + proud)
		var tiles := maxi(1, ceili(length / ManorFacade.TILE))
		var step := length / tiles
		for i in tiles:
			var p: Vector2 = face.call((i + 0.5) * step)
			plan[&"facade_plinth"].append(Transform3D(_basis(out, step / ManorFacade.TILE * 1.001), Vector3(p.x, y - 0.05, p.y)))
			plan[&"facade_cornice"].append(Transform3D(_basis(out, step / ManorFacade.TILE * 1.001), Vector3(p.x, y + ManorStables.WALL_H - 0.9, p.y)))
		var wins := windows_on(run)
		var sx := WIN_W / 1.5
		var sy := (WIN_TOP - WIN_BOTTOM) / ManorFacade.KIT_WIN_H
		for along in wins:
			var p: Vector2 = face.call(along)
			plan[&"facade_surround_arch"].append(Transform3D(_basis(out, sx, sy), Vector3(p.x, y + WIN_BOTTOM, p.y)))
			var q: Vector2 = face.call(along, 0.03)
			var pane := Transform3D(_basis(out, WIN_W, WIN_TOP - WIN_BOTTOM), Vector3(q.x, y + (WIN_BOTTOM + WIN_TOP) * 0.5, q.y))
			plan[&"panes"].append([pane, fposmod(q.x * 0.37 + q.y * 0.61, 1.0), 0.0])
		# Pilasters at both ends and between windows; roses climb every other one.
		var spots: Array[float] = [0.55, length - 0.55]
		for i in range(1, wins.size()):
			spots.append((wins[i - 1] + wins[i]) * 0.5)
		var k := 0
		for s in spots:
			var p: Vector2 = face.call(s)
			var h := ManorStables.WALL_H - 0.9
			plan[&"facade_pilaster"].append(Transform3D(_basis(out, 1.0, h / ManorFacade.KIT_STOREY), Vector3(p.x, y, p.y)))
			if k % 2 == 1:
				var r: Vector2 = face.call(s, 0.12)
				plan[&"facade_climber_rose"].append(Transform3D(_basis(out, 1.25, (h + 0.2) / 4.4), Vector3(r.x, y - 0.2, r.y)))
			k += 1
	return plan


static func _basis(out: Vector2, sx: float = 1.0, sy: float = 1.0) -> Basis:
	return Basis(Vector3(out.y, 0.0, -out.x) * sx, Vector3.UP * sy, Vector3(out.x, 0.0, out.y))


## Adds the "Facade" node under the stables root.
static func dress(parent: Node3D, y: float) -> Node3D:
	var plan := placements(y)
	var root := Node3D.new()
	root.name = "Facade"
	parent.add_child(root)
	for id: StringName in PIECES:
		var xforms: Array = plan[id]
		var meshes := PropModels.pair(ManorFacade.MODEL_DIR + String(id) + ".glb", String(id))
		if meshes.is_empty() or xforms.is_empty():
			continue
		root.add_child(ManorFacade._multimesh(String(id), meshes[0], xforms))
	root.add_child(ManorFacade._pane_multimesh(plan[&"panes"], ManorFacade.window_material(), "stable_panes"))
	return root

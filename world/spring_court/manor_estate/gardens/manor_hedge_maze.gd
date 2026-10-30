## The hedge maze: a seeded perfect maze (depth-first backtracker, then a few
## loops knocked through) on a 28 x 28 grid of 3 m cells filling HEDGE_MAZE.
## Hedge walls are 2.6 m tall and solid. The entrance is on the east side; the
## centre court (4 x 4 cells) holds a dew pool (forage ing_rose_maze_dew), a
## statue, gold roses and benches. Dead ends hide dew and keepsakes.
class_name ManorHedgeMaze
extends RefCounted

const N := 28
const CELL := 3.0
const WALL_H := 2.6
const WALL_T := 0.8
const SEED := "manor_hedge_maze_v1"
const COURT_MIN := 12
const COURT_MAX := 15        # inclusive
const ENTRANCE_ROW := 14     # opening in the east wall
const LOOP_FRACTION := 0.04

static var _grid: Dictionary = {}


## {"h": PackedByteArray((N+1)*N) walls on z-lines, "v": PackedByteArray(N*(N+1)) walls on x-lines}
## h[r * N + c] = wall on the north edge of cell (r, c) (r = 0..N);
## v[r * (N + 1) + c] = wall on the west edge of cell (r, c) (c = 0..N).
static func grid() -> Dictionary:
	if not _grid.is_empty():
		return _grid
	var h := PackedByteArray()
	h.resize((N + 1) * N)
	h.fill(1)
	var v := PackedByteArray()
	v.resize(N * (N + 1))
	v.fill(1)
	var rng := EstateKit.rng(SEED)
	var visited := PackedByteArray()
	visited.resize(N * N)
	var stack: Array[Vector2i] = [Vector2i(ENTRANCE_ROW, N - 1)]
	visited[ENTRANCE_ROW * N + N - 1] = 1
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nb: Vector2i = cur + d
			if nb.x >= 0 and nb.x < N and nb.y >= 0 and nb.y < N and visited[nb.x * N + nb.y] == 0:
				options.append(nb)
		if options.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		_open(h, v, cur, nxt)
		visited[nxt.x * N + nxt.y] = 1
		stack.append(nxt)
	# a few loops so the maze is fun rather than a single corridor
	for i in int(N * N * LOOP_FRACTION):
		var r := rng.randi_range(1, N - 2)
		var c := rng.randi_range(1, N - 2)
		if rng.randf() < 0.5:
			h[r * N + c] = 0
		else:
			v[r * (N + 1) + c] = 0
	# centre court: no inner walls
	for r in range(COURT_MIN, COURT_MAX + 1):
		for c in range(COURT_MIN, COURT_MAX + 1):
			if r > COURT_MIN:
				h[r * N + c] = 0
			if c > COURT_MIN:
				v[r * (N + 1) + c] = 0
	# entrance through the east wall
	v[ENTRANCE_ROW * (N + 1) + N] = 0
	_grid = {"h": h, "v": v}
	return _grid


static func _open(h: PackedByteArray, v: PackedByteArray, a: Vector2i, b: Vector2i) -> void:
	if a.x == b.x:
		v[a.x * (N + 1) + maxi(a.y, b.y)] = 0
	else:
		h[maxi(a.x, b.x) * N + a.y] = 0


## True if you can step from cell a to its neighbour b.
static func passable(a: Vector2i, b: Vector2i) -> bool:
	var g := grid()
	if b.x < 0 or b.x >= N or b.y < 0 or b.y >= N:
		return false
	if a.x == b.x:
		return g["v"][a.x * (N + 1) + maxi(a.y, b.y)] == 0
	return g["h"][maxi(a.x, b.x) * N + a.y] == 0


static func entrance_cell() -> Vector2i:
	return Vector2i(ENTRANCE_ROW, N - 1)


static func court_center_cell() -> Vector2i:
	return Vector2i(COURT_MIN + 1, COURT_MIN + 1)


static func is_court(cell: Vector2i) -> bool:
	return cell.x >= COURT_MIN and cell.x <= COURT_MAX and cell.y >= COURT_MIN and cell.y <= COURT_MAX


## BFS path length in cells from a to b (-1 = unreachable).
static func path_length(a: Vector2i, b: Vector2i) -> int:
	var dist := {a: 0}
	var queue: Array[Vector2i] = [a]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == b:
			return dist[cur]
		for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nb: Vector2i = cur + d
			if not dist.has(nb) and passable(cur, nb):
				dist[nb] = dist[cur] + 1
				queue.append(nb)
	return -1


## World x/z of a cell centre (row = z index from the north edge, col = x index from the west).
static func cell_center(cell: Vector2i) -> Vector2:
	var m := ManorSitePlan.HEDGE_MAZE
	return Vector2(m.position.x + (cell.y + 0.5) * CELL, m.position.y + (cell.x + 0.5) * CELL)


static func court_center() -> Vector2:
	var m := ManorSitePlan.HEDGE_MAZE
	var mid := (COURT_MIN + COURT_MAX + 1) * 0.5 * CELL
	return Vector2(m.position.x + mid, m.position.y + mid)


static func dead_ends() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in N:
		for c in N:
			var cell := Vector2i(r, c)
			if is_court(cell):
				continue
			var exits := 0
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if passable(cell, cell + d):
					exits += 1
			if exits == 1 and cell != entrance_cell():
				out.append(cell)
	return out


static func plant(sb: ManorScatter) -> void:
	var rng := EstateKit.rng("hedge_maze_plant")
	var ends := dead_ends()
	var keepsakes := [&"col_lost_ribbon", &"col_glass_marble", &"col_garden_key", &"col_lost_ribbon", &"col_glass_marble"]
	for i in ends.size():
		var p := cell_center(ends[i])
		match i % 5:
			0, 2:
				sb.put(&"ing_rose_maze_dew", p.x, p.y, rng.randf() * TAU)
			1:
				sb.put(&"ing_rose_red" if i % 2 == 0 else &"ing_rose_white", p.x, p.y, rng.randf() * TAU)
			3:
				sb.put(&"ing_moss", p.x, p.y, rng.randf() * TAU)
			4:
				sb.put(keepsakes[(i / 5) % keepsakes.size()], p.x, p.y, rng.randf() * TAU)
	# honeysuckle and climbing roses against the hedges here and there
	for r in N:
		for c in N:
			var cell := Vector2i(r, c)
			if is_court(cell) or rng.randf() > 0.12:
				continue
			var p := cell_center(cell)
			var off := Vector2(rng.randf_range(-0.9, 0.9), -1.0 if not passable(cell, cell + Vector2i(-1, 0)) else 1.0)
			sb.put(&"ing_honeysuckle" if rng.randf() < 0.6 else &"deco_rose_climbing", p.x + off.x, p.y + off.y, rng.randf() * TAU, 0.7)
	# court: the dew pool ringed with gold roses
	var cc := court_center()
	for i in 14:
		var a := TAU * i / 14.0
		sb.put(&"ing_rose_maze_dew", cc.x + cos(a) * 3.1, cc.y + sin(a) * 3.1, a)
	for i in 16:
		var a := TAU * i / 16.0 + 0.2
		sb.put(&"ing_rose_gold", cc.x + cos(a) * 5.0, cc.y + sin(a) * 5.0, a, 0.9)


static func build(parent: Node3D) -> void:
	var b := GroundsBatch.new(parent, "HedgeMaze")
	b.root.set_meta(&"grid_size", N)
	var g := grid()
	var m := ManorSitePlan.HEDGE_MAZE
	var y := ManorGrounds.ground(m.get_center().x, m.get_center().y)
	var hedge := ManorGrounds.hedge()
	var cap := EstateKit.mat(Color(0.38, 0.74, 0.42), 0.9, 0.0, "maze_cap")
	# merged runs along each z-line
	for r in N + 1:
		var c := 0
		while c < N:
			if g["h"][r * N + c] == 0:
				c += 1
				continue
			var start := c
			while c < N and g["h"][r * N + c] == 1:
				c += 1
			var x0 := m.position.x + start * CELL - WALL_T * 0.5
			var x1 := m.position.x + c * CELL + WALL_T * 0.5
			var z := m.position.y + r * CELL
			b.box(Vector3((x0 + x1) * 0.5, y + WALL_H * 0.5 - 0.2, z), Vector3(x1 - x0, WALL_H + 0.4, WALL_T), hedge)
			b.box(Vector3((x0 + x1) * 0.5, y + WALL_H + 0.1, z), Vector3(x1 - x0 - 0.2, 0.2, WALL_T + 0.1), cap, false)
	for c in N + 1:
		var r := 0
		while r < N:
			if g["v"][r * (N + 1) + c] == 0:
				r += 1
				continue
			var start := r
			while r < N and g["v"][r * (N + 1) + c] == 1:
				r += 1
			var z0 := m.position.y + start * CELL + WALL_T * 0.5
			var z1 := m.position.y + r * CELL - WALL_T * 0.5
			var x := m.position.x + c * CELL
			if z1 > z0:
				b.box(Vector3(x, y + WALL_H * 0.5 - 0.2, (z0 + z1) * 0.5), Vector3(WALL_T, WALL_H + 0.4, z1 - z0), hedge)
	# gravel floor
	b.box(Vector3(m.get_center().x, y + 0.02, m.get_center().y), Vector3(m.size.x, 0.04, m.size.y), ManorGrounds.gravel(), false)
	# entrance arch: two stone piers and a gilt crest
	var ex := m.end.x
	var ez := m.position.y + (ENTRANCE_ROW + 0.5) * CELL
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(ex + 0.4, y + 1.7, ez + side * 1.9), Vector3(1.0, 3.4, 1.0), ManorGrounds.stone())
		b.sphere(Vector3(ex + 0.4, y + 3.75, ez + side * 1.9), 0.35, ManorGrounds.gold())
	b.torus(Vector3(ex + 0.4, y + 3.4, ez), 1.7, 1.85, ManorGrounds.iron_gold(), Basis(Vector3.FORWARD, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5))
	b.drape_path(PackedVector2Array([Vector2(-92.0, -104.0), Vector2(-140.0, -160.0), Vector2(ex + 1.0, ez)]), 3.0, ManorGrounds.gravel())
	# centre court: dew pool, statue, benches, lamps
	var cc := court_center()
	var base := Vector3(cc.x, y, cc.y)
	b.cylinder(base, 2.6, 0.5, ManorGrounds.marble(), true, 20)
	b.disc(base + Vector3.UP * 0.48, Vector2.ONE * 2.3, ManorGrounds.water(), 24)
	b.torus(base + Vector3.UP * 0.5, 2.45, 2.65, ManorGrounds.gold())
	b.prop(&"statue_maiden", base + Vector3(0, 0, -4.6), 0.0)
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		b.prop(&"garden_bench", base + Vector3(cos(a), 0, sin(a)) * 4.6, -a - PI * 0.5)
	for i in 4:
		var a := TAU * i / 4.0
		ManorGrounds.lamp(b, cc.x + cos(a) * 5.4, cc.y + sin(a) * 5.4)
	b.flush()
	var dew := Marker3D.new()
	dew.name = "MazeDewPool"
	dew.position = base
	b.root.add_child(dew)

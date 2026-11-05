## Top-down shaded relief of the Spring Court from WorldHeight, with water,
## paths, gates and the court's named sites, for looking at the terrain without
## a GPU. Writes user:// or the path given after --:
##   tools/mq/godot.sh -s tools/court/court_relief.gd -- out.png [step_m] [x0 z0 x1 z1]
extends SceneTree

var _step := 4.0
var _rect := Rect2(-2048.0, -2048.0, 4096.0, 3600.0)
var _w := 0
var _h := 0
var _heights := PackedFloat32Array()


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://court_relief.png"
	if args.size() > 1:
		_step = float(args[1])
	if args.size() > 5:
		_rect = Rect2(float(args[2]), float(args[3]), float(args[4]) - float(args[2]), float(args[5]) - float(args[3]))
	WorldHeight.warm_up()
	CourtHeight.prewarm()
	_w = int(_rect.size.x / _step)
	_h = int(_rect.size.y / _step)
	_heights.resize(_w * _h)
	var id := WorkerThreadPool.add_group_task(_row, _h, -1, true, "relief")
	WorkerThreadPool.wait_for_group_task_completion(id)
	var img := Image.create(_w, _h, false, Image.FORMAT_RGB8)
	var sun := Vector3(-0.55, 0.75, -0.4).normalized()
	var lakes := CourtHeight.lakes()
	for row in _h:
		for col in _w:
			var x := _rect.position.x + col * _step
			var z := _rect.position.y + row * _step
			var hh := _heights[row * _w + col]
			var hx := _heights[row * _w + mini(col + 1, _w - 1)] - hh
			var hz := _heights[mini(row + 1, _h - 1) * _w + col] - hh
			var n := Vector3(-hx, _step, -hz).normalized()
			var shade := clampf(n.dot(sun), 0.0, 1.0)
			var c := _elev_color(hh)
			var slope := rad_to_deg(acos(n.y))
			if slope > 42.0:
				c = c.lerp(Color(0.45, 0.4, 0.38), 0.7)
			c = c * (0.35 + 0.85 * shade)
			# Water.
			var water := -INF
			if MacroHeight.distance_to_river(x, z) < 8.0:
				water = CourtHeight.river_level_at(x, z)
			for l in lakes:
				if Vector2(x, z).distance_to(l["center"]) < float(l["radius"]):
					water = maxf(water, float(l["level"]))
			if CourtHeight.distance_to_brook(x, z) < 1.0:
				water = hh + 0.2
			if water > hh:
				c = Color(0.35, 0.62, 0.9).lerp(Color(0.1, 0.25, 0.6), clampf((water - hh) / 12.0, 0.0, 1.0))
			# Contours every 10 m.
			if fmod(hh + 1000.0, 10.0) < 10.0 * 0.06 * _step / 4.0 * 2.0 and slope < 42.0:
				c = c.darkened(0.18)
			# Foreign ground dimmed.
			if CourtHeight.own_weight(x, z) <= 0.0:
				c = c.lerp(Color(0.5, 0.5, 0.5), 0.35)
			img.set_pixel(col, row, c)
	# Paths.
	for p in CourtHeight.paths():
		var pts: PackedVector2Array = p["points"]
		for q in pts:
			_dot(img, q, Color(0.95, 0.85, 0.55), 1)
	for id_s: StringName in CourtHeight.SITES:
		var s: Array = CourtHeight.SITES[id_s]
		var col := Color(1, 0.2, 0.6) if s[3] == &"landmark" else (Color(1, 1, 0.2) if s[3] == &"anchor" else Color(0.2, 1, 1))
		_dot(img, Vector2(s[0], s[1]), col, 3)
	for g: Array in CourtHeight.GATES:
		_dot(img, Vector2(g[2], g[3]), Color(1, 0, 0), 4)
	img.save_png(out)
	print("wrote ", out, " ", _w, "x", _h)
	quit()


func _row(row: int) -> void:
	var z := _rect.position.y + row * _step
	for col in _w:
		_heights[row * _w + col] = WorldHeight.height_at(_rect.position.x + col * _step, z)


func _dot(img: Image, p: Vector2, c: Color, r: int) -> void:
	var cx := int((p.x - _rect.position.x) / _step)
	var cz := int((p.y - _rect.position.y) / _step)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := cx + dx
			var z := cz + dz
			if x >= 0 and z >= 0 and x < _w and z < _h:
				img.set_pixel(x, z, c)


func _elev_color(h: float) -> Color:
	var stops := [[-10.0, Color(0.3, 0.45, 0.35)], [10.0, Color(0.45, 0.68, 0.38)], [35.0, Color(0.55, 0.78, 0.42)],
		[60.0, Color(0.75, 0.8, 0.45)], [100.0, Color(0.78, 0.66, 0.42)], [160.0, Color(0.7, 0.55, 0.45)], [260.0, Color(0.95, 0.93, 0.9)]]
	for i in stops.size() - 1:
		if h <= stops[i + 1][0]:
			return (stops[i][1] as Color).lerp(stops[i + 1][1], clampf((h - stops[i][0]) / (stops[i + 1][0] - stops[i][0]), 0.0, 1.0))
	return stops[-1][1]

## The bow's aim and feel as numbers (and frames on the Mac), on the test hill
## with real input actions. The numbers are the bow's done-when list
## (docs/tuning.md "Bow feel"):
##   A  crosshair on a target at 10, 20, 30 and 40 m, full draw: how far from
##      the point under the crosshair the arrow lands (want under 0.15 m)
##   B  crosshair on the middle of a hare (side on, 20 m), a wolf (head on,
##      20 m) and a deer (side on, 30 m), as boxes their size: hits of 20
##      (want 19 or more)
##   C  how far the point under the crosshair moves between the press and the
##      full draw (want under 0.1 m) and how far the crosshair moves on screen
##      (want under 4 px)
##   D  a 0.05 s click: when the arrow leaves, how fast, and where it lands
##   E  the real hare at 20 m and deer at 25 m, unaware: hits of 10 (want 9 or more)
##   F  two arrows as fast as the bow allows
##   Cloud: tools/mq/godot.sh res://tools/playtest/bow_feel_probe.tscn
##   Mac:   shot bowfeel res://tools/playtest/bow_feel_probe.tscn -- --out={out}
## `-- --stages=AB` runs only those. With a window it also writes
## {out}/<stage>_##.jpg.
extends Node

const HILL := preload("res://world/shared/test_hill/test_hill.tscn")
const HillScript := preload("res://world/shared/test_hill/test_hill.gd")
const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
## Across, high, deep (m): Creature's own box for each (body_length x 0.85).
const BOXES := {"hare side on": [Vector3(0.43, 0.32, 0.18), 20.0],
	"wolf head on": [Vector3(0.35, 0.8, 1.27), 20.0],
	"deer side on": [Vector3(1.36, 1.0, 0.42), 30.0]}
const PREY := [["res://creatures/prey/hare.tscn", 20.0], ["res://creatures/prey/deer.tscn", 25.0]]

var feyre: Feyre
var bow: BowController
var cam: FeyreCamera
var out_dir := ""
var stages := "ABCDEF"
var _arrow: Arrow = null
var _landed := Vector3.INF
var _struck: Node = null
var _target: Node3D = null
var _label := ""
var _frame := 0
var _ticks := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--stages="):
			stages = arg.trim_prefix("--stages=")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	var hill := HILL.instantiate()
	add_child(hill)
	feyre = hill.feyre
	bow = feyre.bow_controller
	cam = feyre.camera_control
	Gameplay.inventory.carry_quiver(Inventory.FULL_QUIVER)
	feyre.arrow_fired.connect(_on_fired)
	get_tree().physics_frame.connect(func() -> void: _ticks += 1)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _label == "" or out_dir == "" or DisplayServer.get_name() == "headless":
		return
	_frame += 1
	if _frame % 3 == 0 and _frame < 600:
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_jpg("%s/%s_%03d.jpg" % [out_dir, _label, _frame / 3], 0.9)


func _on_fired(arrow: Arrow) -> void:
	_arrow = arrow
	_landed = Vector3.INF
	_struck = null
	arrow.hit.connect(func(body: Node, at: Vector3) -> void:
		_landed = arrow.get_meta(&"impact", at)
		_struck = body)


func _run() -> void:
	await _wait(1.0)
	# The hill's own props would stop arrows short of the targets.
	for node in get_tree().root.find_children("*", "StaticBody3D", true, false):
		if node.name != "Ground" and not feyre.is_ancestor_of(node):
			node.queue_free()
	await _wait(0.1)
	var ahead := -cam.camera.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	if "A" in stages:
		for metres: float in [10.0, 20.0, 30.0, 40.0]:
			var at := await _box(metres, Vector3(3.0, 3.0, 0.5), ahead)
			var shot := await _shoot(at, 1.0, "A%d" % int(metres))
			print("A %2d m: lands %.2f m from the point under the crosshair (%s)" % [int(metres), shot.off,
				"hit" if shot.hit else "MISSED the wall"])
	if "B" in stages:
		for kind: String in BOXES:
			var hits := 0
			var worst := 0.0
			for i in 20:
				var at := await _box(BOXES[kind][1], BOXES[kind][0], ahead)
				# A different length of hold each time.
				var shot := await _shoot(at, 0.5 + 0.05 * i, "B_%s" % kind.replace(" ", "_") if i == 0 else "")
				hits += int(shot.hit)
				worst = maxf(worst, shot.off)
			print("B %s at %d m: %d/20 hits, worst %.2f m from the crosshair's point" % [kind, int(BOXES[kind][1]), hits, worst])
	if "C" in stages:
		await _press_and_draw(ahead)
	if "D" in stages:
		var at := await _box(20.0, BOXES["deer side on"][0], ahead)
		Input.action_press(&"aim")
		await _aim_at(at, 20)
		Input.action_release(&"aim")
		await _wait(2.5)
		await _aim_at(at, 10)
		var shot := await _shoot(at, 0.05, "D", false)
		print("D 0.05 s click: arrow %s after %d ms at %.1f m/s (bow %.1f), lands %.2f m from the crosshair's point, %s" % [
			"loosed" if _arrow else "NONE", shot.ms, shot.speed, bow.bow.max_speed, shot.off, "hit" if shot.hit else "MISS"])
	if "E" in stages:
		for spec: Array in PREY:
			var hits := 0
			for i in 10:
				var creature := (load(spec[0]) as PackedScene).instantiate() as Creature
				add_child(creature)
				var at: Vector3 = feyre.global_position + ahead * float(spec[1])
				at.y = HillScript.height_at(at.x, at.z)
				creature.global_position = at
				creature.rotation.y = atan2(ahead.x, ahead.z) + PI * 0.5
				_set_target(creature)
				await _wait(0.5)
				var middle := creature.global_position + Vector3.UP * creature.data.body_height * 0.5
				var shot := await _shoot(middle, 1.0, "E_%s" % String(spec[0]).get_file().get_basename() if i == 0 else "")
				hits += int(shot.hit)
				await _wait(0.2)
			print("E %s at %d m, unaware: %d/10 hits" % [String(spec[0]).get_file().get_basename(), int(spec[1]), hits])
		_set_target(null)
	if "F" in stages:
		await _wait(2.5)
		_label = "F"
		_frame = 0
		var began := _ms()
		for i in 2:
			_arrow = null
			Input.action_press(&"fire")
			await _wait(0.05)
			Input.action_release(&"fire")
			while _arrow == null and _ms() - began < 4000:
				await get_tree().physics_frame
		print("F two clicks, two arrows in %d ms" % (_ms() - began))
		_label = ""
	get_tree().quit()


## C: the bow comes up on the press with the mouse still.
func _press_and_draw(ahead: Vector3) -> void:
	var at := await _box(35.0, Vector3(4.0, 4.0, 0.5), ahead)
	Input.action_press(&"aim")
	await _aim_at(at, 20)
	Input.action_release(&"aim")
	await _wait(2.5)
	await _aim_at(at, 10)
	await _wait(0.3)
	_label = "C"
	_frame = 0
	var on := feyre.aim_point()
	var lens := cam.camera.global_position
	Input.action_press(&"fire")
	var point_moved := 0.0
	var px_moved := 0.0
	var first := Vector2.INF
	for i in 60:
		await get_tree().physics_frame
		point_moved = maxf(point_moved, feyre.aim_point().distance_to(on))
		if bow.reticle.visible:
			if first == Vector2.INF:
				first = bow.reticle.at
			px_moved = maxf(px_moved, bow.reticle.at.distance_to(first))
	print("C press to full draw at 35 m: the point under the crosshair moved %.3f m at most, the crosshair %.1f px, the lens %.2f m" % [
		point_moved, px_moved, cam.camera.global_position.distance_to(lens)])
	Input.action_release(&"fire")
	_label = ""
	await _wait(2.5)


## One arrow: fire is pressed, the crosshair is put on `at` (unless `aim` is
## false: it is there already), fire is let go after `held` seconds.
## {"hit": struck the target, "off": metres from the point under the
## crosshair at release to where it landed, "ms": press to arrow, "speed"}.
func _shoot(at: Vector3, held: float, label: String = "", aim: bool = true) -> Dictionary:
	Gameplay.inventory.add(&"arrow_wood", 1)
	_arrow = null
	_landed = Vector3.INF
	_label = label
	_frame = 0
	var pressed := _ms()
	Input.action_press(&"fire")
	var ticks := maxi(roundi(held * Engine.physics_ticks_per_second), 1)
	if aim:
		await _aim_at(at, mini(ticks, 10))
		ticks -= mini(ticks, 10)
	for i in ticks:
		await get_tree().physics_frame
	Input.action_release(&"fire")
	var on := feyre.aim_point()
	while _arrow == null and _ms() - pressed < 3000:
		await get_tree().physics_frame
		on = feyre.aim_point()
	var took := _ms() - pressed
	var speed := float(_arrow.get_meta(&"speed", 0.0)) if _arrow else 0.0
	var waited := 0
	while _landed == Vector3.INF and waited < 300:
		await get_tree().physics_frame
		waited += 1
	_label = ""
	var result := {"hit": _struck != null and _struck == _target, "ms": took, "speed": speed,
		"off": _landed.distance_to(on) if _landed != Vector3.INF else -1.0}
	# Let the bow come down, so the next press raises it again.
	await _wait(bow.tuning.stay_up_s + 0.4)
	return result


## A box `metres` ahead of her on the ground, facing her. Returns its middle.
func _box(metres: float, across_high_deep: Vector3, ahead: Vector3) -> Vector3:
	var p := feyre.global_position + ahead * metres
	p.y = HillScript.height_at(p.x, p.z)
	var body := StaticBody3D.new()
	body.collision_layer = Arrow.MASK_TARGETS
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = across_high_deep
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var look := BoxMesh.new()
	look.size = across_high_deep
	mesh.mesh = look
	body.add_child(mesh)
	add_child(body)
	body.global_position = p + Vector3.UP * across_high_deep.y * 0.5
	body.look_at(feyre.global_position + Vector3.UP * across_high_deep.y * 0.5, Vector3.UP)
	_set_target(body)
	await get_tree().physics_frame
	return body.global_position


func _set_target(node: Node3D) -> void:
	if _target != null and is_instance_valid(_target):
		_target.queue_free()
	_target = node


## Turns the camera, as a mouse would, until the middle of the screen is on `p`.
func _aim_at(p: Vector3, ticks: int) -> void:
	for i in ticks:
		var lens := cam.camera
		var want := (p - lens.global_position).normalized()
		var have := -lens.global_basis.z
		var yaw := wrapf(atan2(-want.x, -want.z) - atan2(-have.x, -have.z), -PI, PI)
		var pitch := asin(clampf(want.y, -1.0, 1.0)) - asin(clampf(have.y, -1.0, 1.0))
		cam._rotate(yaw * 0.7, pitch * 0.7)
		await get_tree().physics_frame


## Game seconds, counted in physics ticks, so the numbers are the same on a
## slow machine.
func _wait(seconds: float) -> void:
	for i in maxi(roundi(seconds * Engine.physics_ticks_per_second), 1):
		await get_tree().physics_frame


func _ms() -> int:
	return _ticks * 1000 / Engine.physics_ticks_per_second

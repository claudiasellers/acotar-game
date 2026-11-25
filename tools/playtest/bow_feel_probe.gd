## The bow's feel as numbers and frames, on the test hill with real input
## actions: a quick tap, a half draw and a full draw from the hip, a full draw
## with the aim held, and a second arrow straight after. For each: how long
## from the press to the arrow, how fast it leaves, how far it lands, how wide
## the sway is, and how long the bow stays up afterwards.
##   Cloud: tools/mq/godot.sh res://tools/playtest/bow_feel_probe.tscn
##   Mac:   shot bowfeel res://tools/playtest/bow_feel_probe.tscn -- --out={out}
## Prints one line per shot; with a window it also writes {out}/<shot>_##.jpg.
extends Node

const HILL := preload("res://world/shared/test_hill/test_hill.tscn")
const TEST_SET := preload("res://data/phases/m0_test_phases.tres")
## label, aim held, seconds the string is held
const SHOTS := [["tap", false, 0.08], ["half", false, 0.15], ["hip_full", false, 0.6],
	["aimed_full", true, 0.6]]

var feyre: Feyre
var bow: BowController
var out_dir := ""
var _last: Arrow = null
var _label := ""
var _frame := 0
var _ticks := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	PhaseManager.start(TEST_SET)
	StoryControl.release()
	var hill := HILL.instantiate()
	add_child(hill)
	feyre = hill.feyre
	bow = feyre.bow_controller
	Gameplay.inventory.carry_quiver(Inventory.FULL_QUIVER)
	Gameplay.inventory.add(&"arrow_wood", 20)
	feyre.arrow_fired.connect(func(a: Arrow) -> void: _last = a)
	get_tree().physics_frame.connect(_on_tick)
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _label == "" or out_dir == "" or DisplayServer.get_name() == "headless":
		return
	_frame += 1
	if _frame % 3 == 0:
		var img := get_viewport().get_texture().get_image()
		if img:
			img.save_jpg("%s/%s_%02d.jpg" % [out_dir, _label, _frame / 3], 0.9)


func _run() -> void:
	await _wait(1.0)
	for shot: Array in SHOTS:
		await _shoot(shot[0], shot[1], shot[2])
		await _wait(2.5)
	# Two arrows as fast as the bow allows, from the hip.
	_label = "follow_up"
	_frame = 0
	var began := _ms()
	for i in 2:
		_last = null
		Input.action_press(&"fire")
		while bow.draw_amount < 1.0:
			await get_tree().physics_frame
		Input.action_release(&"fire")
		while _last == null:
			await get_tree().physics_frame
	print("follow_up: two full arrows in %d ms" % (_ms() - began))
	_label = ""
	get_tree().quit()


func _shoot(label: String, aim: bool, held: float) -> void:
	_label = label
	_frame = 0
	_last = null
	if aim:
		Input.action_press(&"aim")
		await _wait(0.5)
	var pressed := _ms()
	Input.action_press(&"fire")
	await _wait(held)
	var draw := bow.draw_amount
	var lands: Dictionary = bow.predict_impact()
	var raised := bow.visual.raised
	var sway := bow.sway_degrees()
	var ring := bow.reticle.visible
	var fov := feyre.camera.fov
	Input.action_release(&"fire")
	while _last == null and _ms() - pressed < 3000:
		await get_tree().physics_frame
	var took := _ms() - pressed
	Input.action_release(&"aim")
	var down := _ms()
	while bow.is_up() and _ms() - down < 5000:
		await get_tree().physics_frame
	print("%s: arrow %s after %d ms, draw %.2f, speed %.1f m/s, lands %.1f m away, sway %.2f deg, bow pose %.2f at release, reticle %s, bow up %d ms after, fov %.1f" % [
		label, "loosed" if _last else "NONE", took, draw,
		float(_last.get_meta(&"speed", 0.0)) if _last else 0.0,
		feyre.global_position.distance_to(lands.point) if not lands.is_empty() else -1.0,
		sway, raised, "shown" if ring else "hidden", _ms() - down, fov])
	_label = ""


## Game seconds, counted in physics ticks, so the numbers are the same on a
## slow machine.
func _wait(seconds: float) -> void:
	for i in maxi(roundi(seconds * Engine.physics_ticks_per_second), 1):
		await get_tree().physics_frame


func _on_tick() -> void:
	_ticks += 1


func _ms() -> int:
	return _ticks * 1000 / Engine.physics_ticks_per_second

## Proof shots for L34-6: the steaming bath and its "E   step in" card, from the
## real game through Feyre's own camera. Run with --from=manor
## --stop-after=act2_bath: just before the bot presses E at the tub it looks at
## the water and saves
##   {out}/bath_1_card.png   on arrival at the tub: steam and the card
##   {out}/bath_2_go_on.png  after Alis's "Go on" nudge
## then presses E as the playthrough does. Headless it only logs.
extends "res://tools/playtest/act1_playtest.gd"

var _shot_done: bool = false


func _press(action: StringName) -> void:
	if action == &"interact" and not _shot_done:
		var welcome := _find_named(&"AlisWelcome") as AlisWelcome
		if welcome and welcome.running and welcome.current_beat_label() == "until she steps in":
			_shot_done = true
			var look := welcome.mark(&"bath") + Vector3.UP * 0.4
			await _hold_look(look, 2.5)
			_save("bath_1_card.png", welcome)
			await _hold_look(look, AlisWelcome.GO_ON_AFTER + 2.5)
			_save("bath_2_go_on.png", welcome)
	await super._press(action)


func _hold_look(point: Vector3, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_turn_camera_to(point)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _save(file: String, welcome: AlisWelcome) -> void:
	var card := welcome.get_node_or_null(^"PressCard") as PressCard
	_note("%s: card '%s', steam %s" % [file, card.text() if card else "", welcome.steam != null])
	if DisplayServer.get_name() == "headless":
		return
	var dir := out_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png(dir.path_join(file))

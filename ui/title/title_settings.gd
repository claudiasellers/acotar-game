## The pause menu's settings, opened from the title screen. Same panel and
## the same GameSettings / InputSettings, without the in-game actions
## (Wriggle free, Return Home, Save & Title, Save & Quit): there is no game
## to save from the title. Resume becomes Back; Esc also goes back.
class_name TitleSettings
extends SettingsPanel

signal closed


func _ready() -> void:
	super._ready()
	var col := _resume.get_parent().get_parent() as VBoxContainer
	var heading := col.get_child(0) as Label
	if heading != null:
		heading.text = "Settings"
	var actions := _resume.get_parent()
	for c in actions.get_children():
		if c != _resume:
			c.queue_free()
	# The "stuck?" row sits just above the actions.
	var stuck := col.get_child(actions.get_index() - 1)
	if stuck is HBoxContainer:
		stuck.queue_free()
	_resume.text = "Back"


func open() -> void:
	super.open()
	# Keep the Wall drifting behind the panel.
	get_tree().paused = false


func close() -> void:
	_menu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		close()
		get_viewport().set_input_as_handled()

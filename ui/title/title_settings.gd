## The pause menu's settings, opened from the title screen. Same panel and
## the same GameSettings / InputSettings, without the in-game actions
## (Wriggle free, Return Home, Save & Title, Save & Quit): there is no game
## to save from the title. Resume becomes Back; Esc also goes back.
class_name TitleSettings
extends SettingsPanel

signal closed


func _init() -> void:
	# The Wall keeps drifting behind the panel, and Esc on the bare title
	# opens nothing.
	_screen_flags = ScreenStack.Flag.MOUSE
	_opens_on_pause = false


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


func close() -> void:
	_menu.visible = false
	ScreenStack.pop(self)
	closed.emit()

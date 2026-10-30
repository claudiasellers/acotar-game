## M0 debug overlay: phase, flags, quiver, stamina, time, and a crosshair.
## Replaced by the real (mostly diegetic) UI later.
##
## The debug text is off by default and toggled with F3 (action
## "toggle_debug_hud"). The crosshair still shows while aiming.
extends CanvasLayer

var debug_visible: bool = false

var _info: Label
var _crosshair: Label
var _deed: Label
var _deed_timer: float = 0.0


func _ready() -> void:
	_info = Label.new()
	_info.position = Vector2(24, 20)
	_info.add_theme_font_size_override(&"font_size", 18)
	_info.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.7))
	_info.visible = debug_visible
	add_child(_info)
	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.add_theme_font_size_override(&"font_size", 28)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_crosshair)
	_deed = Label.new()
	_deed.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_deed.position.y = 80
	_deed.add_theme_font_size_override(&"font_size", 22)
	add_child(_deed)
	EventBus.phase_changed.connect(func(_p: StringName, current: StringName) -> void:
		_show("Phase: %s" % current))
	EventBus.deed_performed.connect(func(flag: String) -> void: _show("Deed: %s" % flag))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug_hud"):
		debug_visible = not debug_visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_info.visible = debug_visible
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	var phase := PhaseManager.current()
	var lines := PackedStringArray([
		"Phase: %s" % (phase.display_name if phase else "-"),
		"Day %d  %02d:%02d" % [Clock.day, int(Clock.hour()), int(fmod(Clock.hour(), 1.0) * 60.0)],
	])
	if feyre:
		lines.append("Arrows: %d   Stamina: %d" % [feyre.quiver, roundi(feyre.stamina)])
		lines.append("Draw: %d%%" % roundi(feyre.draw_amount * 100.0))
		if feyre.body_state:
			lines.append("Hunger %d%%  Cold %d%%  Coin %d  Sketches %d  Journal %d  Family food %.1f d" % [
				roundi(feyre.body_state.hunger * 100.0), roundi(feyre.body_state.cold * 100.0),
				Gameplay.inventory.coin, Gameplay.sketchbook.count(), Gameplay.journal.count(),
				Gameplay.food_tally.days_of_food])
		_crosshair.visible = feyre.is_aiming or feyre.is_drawing
	lines.append("Flags: %s" % ", ".join(PackedStringArray(WorldState.all_flags().keys())))
	lines.append("WASD move, Shift sprint, Space jump/climb, hold LMB draw, RMB aim, E interact, Q arrow type, R craft arrow")
	_info.text = "\n".join(lines)
	_deed_timer -= delta
	_deed.visible = debug_visible and _deed_timer > 0.0


func _show(text: String) -> void:
	_deed.text = text
	_deed_timer = 3.0

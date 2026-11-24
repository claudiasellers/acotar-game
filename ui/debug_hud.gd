## The dev overlay: phase, flags, quiver, stamina and time, and a line when a
## phase turns or a deed is done. Off by default; F3 (action
## "toggle_debug_hud") toggles it. It sits in HudLayout's WORLD zone, so it
## hides under a film or an open screen like the rest of the HUD.
extends Node

var debug_visible: bool = false

var _info: Label
var _deed: Label
var _deed_timer: float = 0.0


func _ready() -> void:
	var overlay := Control.new()
	overlay.name = "Debug"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	HudLayout.of(get_tree()).place(overlay, HudLayout.Zone.WORLD, self)
	_info = Label.new()
	_info.position = Vector2(24, 20)
	_info.add_theme_font_size_override(&"font_size", 18)
	_info.add_theme_color_override(&"font_color", JournalTheme.color(&"paper"))
	_info.add_theme_color_override(&"font_shadow_color", Color(JournalTheme.color(&"ink"), 0.7))
	_info.visible = debug_visible
	overlay.add_child(_info)
	_deed = Label.new()
	_deed.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_deed.position.y = 80
	_deed.add_theme_font_size_override(&"font_size", 22)
	_deed.add_theme_color_override(&"font_color", JournalTheme.color(&"paper"))
	overlay.add_child(_deed)
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
	lines.append("Flags: %s" % ", ".join(PackedStringArray(WorldState.all_flags().keys())))
	lines.append("%s move, Shift sprint, Space jump/climb, hold RMB aim + LMB shoot, E interact, Q arrow type, F craft arrow, R recenter camera" \
			% InputSettings.SCHEME_NAMES[InputSettings.scheme])
	_info.text = "\n".join(lines)
	_deed_timer -= delta
	_deed.visible = debug_visible and _deed_timer > 0.0


func _show(text: String) -> void:
	_deed.text = text
	_deed_timer = 3.0

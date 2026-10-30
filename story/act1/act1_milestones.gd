## Act I's milestone layer: the player always knows when they're close, when
## something is starting and what to do once it has.
##   - Getting warmer: the edges of the screen draw in, softly, as Feyre nears
##     the wolf clearing (the forest going quiet before ch1's kill), gone once
##     the scene starts. (Her landmark thoughts carry the rest of the route.)
##   - Starting / done: a chapter-style card at the top of the screen, a title
##     and one plain line on what to do now, with the keys as they're bound.
## Each card shows once per play: they hang on scene starts and on deeds being
## raised, which only happen once.
class_name Act1Milestones
extends CanvasLayer

const FONT_PATH := "res://ui/title/fonts/EBGaramond-Medium.ttf"
const HOLD := 6.0
const FADE := 0.6
## The vignette starts this far from the clearing and is fullest at the Entry.
const HUSH_FROM := 120.0
const HUSH_TO := 35.0
const HUSH_MAX := 0.55
## Actions other systems add in code once they're up (bow_controller.gd).
const DEFAULT_KEYS := {&"cycle_arrow": "Q"}

## Cards: trigger -> [title, what to do]. A trigger is a scene id (on start)
## or a flag (when raised). {key:action} in the line becomes that action's key.
const CARDS := {
	&"scene:wolf_kill": ["The Wolf in the Snow", ""],
	&"fact.wolf_spotted": ["", "Ash arrow first, into his side.   {key:cycle_arrow} nock  ·  {key:aim} aim  ·  {key:fire} loose"],
	&"wolf_killed": ["He's Down", "Skin him for the pelt.  {key:interact}"],
	&"fact.wolf_skinned": ["A Pelt Worth Selling", "Take it to the fur stall in the village, down the road past the cottage."],
	&"pelt_sold": ["Coin for the Winter", "Go home and sleep the day away in the ironwood bed.  {key:interact}"],
	&"scene:beast_door": ["The Beast at the Door", ""],
	&"window:beast_door": ["", "Throw the knife {key:interact}  ·  the bracelets {key:fire}  ·  or stand still"],
	&"beast_claim_accepted": ["A Life for a Life", "You go with him. Ride, and look."],
	&"wall_crossed": ["Prythian", "Spring, on the other side of the wall."],
	&"scene_end:ride_north": ["The Spring Court", "Explore the grounds. The great house is waiting."],
}

var shown: Dictionary = {}
var queue: Array = []
var hush: float = 0.0

var _card: PanelContainer
var _title: Label
var _line: RichTextLabel
var _vignette: TextureRect
var _left: float = 0.0
var _tween: Tween
var _quiet_for: float = 1.0
var _window_open: bool = false


func _ready() -> void:
	layer = 14
	name = "Act1Milestones"
	_build()
	EventBus.scene_space_started.connect(func(id: StringName) -> void: trigger(StringName("scene:%s" % id)))
	EventBus.scene_space_finished.connect(func(id: StringName) -> void: trigger(StringName("scene_end:%s" % id)))
	EventBus.flag_changed.connect(func(flag: String, value: Variant) -> void:
		if value:
			trigger(StringName(flag)))


## Queues a card for `id` once. Ignored in the first second (a loaded save
## replaying its flags) and for ids with no card.
func trigger(id: StringName) -> bool:
	if _quiet_for > 0.0 or shown.has(id) or not CARDS.has(id):
		return false
	shown[id] = true
	queue.append(id)
	return true


func _process(delta: float) -> void:
	_quiet_for = maxf(_quiet_for - delta, 0.0)
	_watch_beast_window()
	_update_hush(delta)
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0:
			_fade_out()
	elif not queue.is_empty() and not (_tween and _tween.is_running()):
		show_card(queue.pop_front())


func show_card(id: StringName) -> void:
	var spec: Array = CARDS[id]
	_title.text = spec[0]
	_title.visible = spec[0] != ""
	var line := expand(spec[1])
	_line.text = "[center]%s[/center]" % line
	_line.visible = line != "" and GuideSettings.get_mode() != GuideSettings.Mode.OFF
	if not _title.visible and not _line.visible:
		return
	_left = HOLD + 0.03 * line.length()
	if _tween and _tween.is_valid():
		_tween.kill()
	_card.modulate.a = 0.0
	_card.visible = true
	_tween = create_tween()
	_tween.tween_property(_card, ^"modulate:a", 1.0, FADE)


## Replaces {key:action} with the action's current key in a chip.
static func expand(text: String) -> String:
	var out := text
	var at := out.find("{key:")
	while at >= 0:
		var close := out.find("}", at)
		var action := StringName(out.substr(at + 5, close - at - 5))
		out = out.substr(0, at) + "[color=#f6d98c]%s[/color]" % key_name(action) + out.substr(close + 1)
		at = out.find("{key:")
	return out


## The first keyboard or mouse binding of an action, as players read it.
static func key_name(action: StringName) -> String:
	if not InputMap.has_action(action):
		return DEFAULT_KEYS.get(action, "?")
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var k := event as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "Left mouse"
				MOUSE_BUTTON_RIGHT:
					return "Right mouse"
	return "?"


func _fade_out() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_card, ^"modulate:a", 0.0, FADE)
	_tween.tween_callback(func() -> void: _card.visible = false)


## The decision window has no flag of its own: watch the door's beat.
func _watch_beast_window() -> void:
	var open := false
	for door in get_tree().get_nodes_in_group(BeastDoor.GROUP):
		if (door as BeastDoor).running and (door as BeastDoor).current_beat_label().begins_with("decision"):
			open = true
	if open and not _window_open:
		trigger(&"window:beast_door")
	_window_open = open


## How far the edges draw in: 0 away from the clearing, HUSH_MAX at its Entry.
static func hush_at(distance: float) -> float:
	return HUSH_MAX * clampf((HUSH_FROM - distance) / (HUSH_FROM - HUSH_TO), 0.0, 1.0)


func _update_hush(delta: float) -> void:
	var target := 0.0
	var feyre := get_tree().get_first_node_in_group(&"player") as Node3D
	if feyre and not WorldState.has_flag("fact.wolf_spotted") and not WorldState.has_flag("wolf_killed"):
		var c := HumanRealmLayout.DOE_CLEARING
		target = hush_at(Vector2(feyre.global_position.x, feyre.global_position.z).distance_to(c))
	hush = move_toward(hush, target, delta * 0.5)
	_vignette.modulate.a = hush
	_vignette.visible = hush > 0.005


func _build() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.06, 0.1, 0.0))
	gradient.set_color(1, Color(0.05, 0.06, 0.1, 1.0))
	gradient.set_offset(0, 0.35)
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.visible = false
	add_child(_vignette)

	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null
	var top := Control.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_card = PanelContainer.new()
	_card.position = Vector2(-450, 48)
	_card.custom_minimum_size = Vector2(900, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A soft dusk wash behind the words so they read on snow and bright sky.
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(0.09, 0.06, 0.13, 0.5)
	wash.set_corner_radius_all(22)
	wash.shadow_color = Color(0.09, 0.06, 0.13, 0.35)
	wash.shadow_size = 24
	wash.content_margin_top = 14
	wash.content_margin_bottom = 16
	wash.content_margin_left = 28
	wash.content_margin_right = 28
	_card.add_theme_stylebox_override(&"panel", wash)
	_card.visible = false
	top.add_child(_card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	_card.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 44)
	_title.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.9))
	_title.add_theme_color_override(&"font_shadow_color", Color(0.1, 0.06, 0.12, 0.8))
	_title.add_theme_constant_override(&"shadow_offset_y", 2)
	_title.add_theme_constant_override(&"shadow_outline_size", 6)
	if font:
		_title.add_theme_font_override(&"font", font)
	box.add_child(_title)
	var rule := ColorRect.new()
	rule.color = Color(UiStyle.BORDER, 0.85)
	rule.custom_minimum_size = Vector2(220, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(rule)
	_line = RichTextLabel.new()
	_line.bbcode_enabled = true
	_line.fit_content = true
	_line.scroll_active = false
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.add_theme_font_size_override(&"normal_font_size", 24)
	_line.add_theme_font_size_override(&"bold_font_size", 24)
	_line.add_theme_color_override(&"default_color", Color(0.98, 0.95, 0.9))
	_line.add_theme_color_override(&"font_shadow_color", Color(0.1, 0.06, 0.12, 0.85))
	_line.add_theme_constant_override(&"shadow_offset_y", 2)
	_line.add_theme_constant_override(&"shadow_outline_size", 5)
	if font:
		_line.add_theme_font_override(&"normal_font", font)
		_line.add_theme_font_override(&"bold_font", font)
	box.add_child(_line)

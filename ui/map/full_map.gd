## The full map: Feyre's sketchbook page of everywhere she has been. Opens
## with M (pad RB) or from the pause menu, pauses the game, and pans and
## zooms. Shows the uncovered land, the places she has found (named), the
## landmarks she has seen and where she stands, nothing else (R2).
class_name FullMap
extends CanvasLayer

const SHADER := preload("res://ui/map/map_view.gdshader")
## Width of the view in metres: closest, furthest, and on opening.
const ZOOM_MIN := 360.0
const ZOOM_MAX := 4600.0
const ZOOM_OPEN := 1500.0
const PAN_SPEED := 0.9  # view widths per second
const LANDMARK_NAMES_BELOW := 1700.0
## Pixels: a click this close to the pin lifts it; a press that moves further is a drag.
const PIN_HIT := 22.0
const CLICK_SLOP := 6.0

var hud: WorldMapHud
var view_center: Vector2 = Vector2.ZERO
var view_width: float = ZOOM_OPEN

var _root: Control
var _card: PanelContainer
var _map: ColorRect
var _overlay: Control
var _stats: Label
var _dragging: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _dragged: float = 0.0
## A pad was used last: show the reticle at the centre and pin there.
var _pad: bool = false
var _t: float = 0.0
var _hover_id: String = ""


func _init(owner_hud: WorldMapHud) -> void:
	hud = owner_hud
	name = "FullMap"


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func map_rect() -> ColorRect:
	return _map


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view_center = hud.player_xz
	view_width = ZOOM_OPEN
	_stats.text = hud.stats_line()
	Juice.bounce_control(_card, 0.03)


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(MapSettings.ACTION_OPEN) or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"camera_recenter"):
		view_center = hud.player_xz
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad = true
		# Pad: A drops the pin under the reticle (or lifts it if it is there); X lifts it.
		if event.is_action_pressed(&"jump"):
			toggle_pin_at(view_center, _map.size * 0.5)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"interact"):
			hud.clear_pin()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouse:
		_pad = false


## A click or press on the map: on the pin lifts it, anywhere else drops it.
func toggle_pin_at(world: Vector2, point: Vector2) -> void:
	if hud.pin.active and to_map_point(hud.pin.xz).distance_to(point) < PIN_HIT:
		hud.clear_pin()
	else:
		hud.set_pin(world)
		Juice.bounce_control(_card, 0.015)


func _process(delta: float) -> void:
	if not is_open():
		return
	_t += delta
	var pan := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if pan != Vector2.ZERO:
		view_center += pan * view_width * PAN_SPEED * delta
	var zoom := Input.get_action_strength(&"aim") - Input.get_action_strength(&"fire")
	if Input.is_key_pressed(KEY_EQUAL) or Input.is_key_pressed(KEY_KP_ADD):
		zoom -= 1.0
	if Input.is_key_pressed(KEY_MINUS) or Input.is_key_pressed(KEY_KP_SUBTRACT):
		zoom += 1.0
	if absf(zoom) > 0.05:
		view_width = clampf(view_width * exp(zoom * delta * 1.6), ZOOM_MIN, ZOOM_MAX)
	_clamp_view()
	var mat := _map.material as ShaderMaterial
	var map_size := WorldMap.MAP_RECT.size
	var view_height := view_width * _map.size.y / maxf(_map.size.x, 1.0)
	mat.set_shader_parameter(&"view_center", MapArt.world_to_uv(view_center.x, view_center.y))
	mat.set_shader_parameter(&"view_size", Vector2(view_width / map_size.x, view_height / map_size.y))
	_overlay.queue_redraw()


func _clamp_view() -> void:
	var rect := WorldMap.MAP_RECT
	view_center.x = clampf(view_center.x, rect.position.x, rect.end.x)
	view_center.y = clampf(view_center.y, rect.position.y, rect.end.y)


## World XZ to a point on the map control.
func to_map_point(xz: Vector2) -> Vector2:
	var scale := _map.size.x / view_width
	return _map.size * 0.5 + (xz - view_center) * scale


func to_world(point: Vector2) -> Vector2:
	return view_center + (point - _map.size * 0.5) * (view_width / _map.size.x)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
			if mb.pressed:
				_press_at = mb.position
				_dragged = 0.0
			elif _dragged < CLICK_SLOP:
				# A click, not a drag: left sets or lifts the pin, right lifts it.
				if mb.button_index == MOUSE_BUTTON_LEFT:
					toggle_pin_at(to_world(mb.position), mb.position)
				elif mb.button_index == MOUSE_BUTTON_RIGHT:
					hud.clear_pin()
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			# Zoom about the cursor.
			var before := to_world(mb.position)
			var f := 0.85 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.85
			view_width = clampf(view_width * f, ZOOM_MIN, ZOOM_MAX)
			view_center += before - to_world(mb.position)
			_clamp_view()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			_dragged = maxf(_dragged, mm.position.distance_to(_press_at))
			view_center -= mm.relative * (view_width / _map.size.x)
			_clamp_view()
		_hover_id = _landmark_near(mm.position)


func _landmark_near(point: Vector2) -> String:
	for id: String in hud.seen_landmarks:
		var lm: Dictionary = hud.seen_landmarks[id]
		if to_map_point(Vector2(lm.x, lm.z)).distance_to(point) < 16.0:
			return id
	return ""


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = PauseStyle.theme()
	add_child(_root)
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.42, 0.24, 0.42, 0.5)
	_root.add_child(veil)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 90)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_root.add_child(margin)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override(&"panel", PauseStyle.card_box())
	margin.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 18)
	col.add_child(head)
	var title := PauseStyle.title("Feyre's Map", 40)
	head.add_child(title)
	_stats = PauseStyle.note("")
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_stats)

	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(1.0, 0.97, 0.93)
	frame_box.border_color = PauseStyle.GOLD
	frame_box.set_border_width_all(3)
	frame_box.set_corner_radius_all(18)
	frame_box.set_content_margin_all(3)
	frame.add_theme_stylebox_override(&"panel", frame_box)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	col.add_child(frame)

	_map = ColorRect.new()
	_map.name = "Map"
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_map.material = mat
	frame.add_child(_map)
	_overlay = Control.new()
	_overlay.name = "Marks"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_overlay.draw.connect(_draw_marks)
	_overlay.gui_input.connect(_on_map_input)
	frame.add_child(_overlay)

	var foot := PauseStyle.note("Drag to look around  ·  Scroll to zoom  ·  Click to set or lift your pin  ·  R finds Feyre  ·  M closes")
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(foot)


func _draw_marks() -> void:
	var ci := _overlay
	var font := PauseStyle.DISPLAY_FONT
	var body := PauseStyle.body_font(700)
	# Names of the places she has found.
	for place: MapPlace in hud.found_places():
		var p := to_map_point(place.label_at)
		var fs := clampi(int(26.0 * 1500.0 / view_width), 14, 34)
		var w := font.get_string_size(place.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_string_outline(font, p - Vector2(w * 0.5, 0), place.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(1.0, 0.97, 0.99, 0.9))
		ci.draw_string(font, p - Vector2(w * 0.5, 0), place.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PauseStyle.PLUM)
	# Landmarks she has seen, named when close enough to read.
	for id: String in hud.seen_landmarks:
		var lm: Dictionary = hud.seen_landmarks[id]
		var p := to_map_point(Vector2(lm.x, lm.z))
		if not Rect2(Vector2.ZERO, _map.size).grow(20).has_point(p):
			continue
		var hover := id == _hover_id
		MapMarks.draw_landmark(ci, p, StringName(lm.kind), 13.0 if hover else 10.0, 0.6 if hover else 0.0)
		if hover or view_width < LANDMARK_NAMES_BELOW:
			var label := String(lm.label)
			var w := body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var at := p + Vector2(-w * 0.5, 30)
			ci.draw_string_outline(body, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Color(1.0, 0.97, 0.99, 0.95))
			ci.draw_string(body, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PauseStyle.PLUM_SOFT)
	if hud.pin.active:
		MapMarks.draw_pin(ci, to_map_point(hud.pin.xz), 16.0, _t)
	MapMarks.draw_feyre(ci, to_map_point(hud.player_xz), hud.player_angle, 13.0, _t)
	if _pad:
		_draw_reticle(ci, _map.size * 0.5)
	_draw_compass(ci, Vector2(_map.size.x - 64, 64))


## The pad's cursor: a small gold ring with four petals.
func _draw_reticle(ci: CanvasItem, at: Vector2) -> void:
	var colours := MapMarks.pin_colours()
	ci.draw_arc(at, 11.0, 0.0, TAU, 32, colours.line, 2.0, true)
	for i in 4:
		var d := Vector2(sin(TAU * i / 4.0), -cos(TAU * i / 4.0))
		ci.draw_line(at + d * 14.0, at + d * 22.0, colours.line, 2.5, true)
	ci.draw_circle(at, 2.5, colours.accent)


func _draw_compass(ci: CanvasItem, at: Vector2) -> void:
	ci.draw_circle(at, 34, Color(1.0, 0.97, 0.99, 0.85))
	ci.draw_arc(at, 34, 0, TAU, 48, PauseStyle.GOLD, 2.0, true)
	for i in 4:
		var a := TAU * i / 4.0
		var d := Vector2(sin(a), -cos(a))
		var s := Vector2(-d.y, d.x)
		var tip := at + d * 28.0
		ci.draw_colored_polygon(PackedVector2Array([tip, at + s * 6.0, at - s * 6.0]),
			PauseStyle.ROSE if i == 0 else PauseStyle.LILAC)
	ci.draw_circle(at, 4, PauseStyle.GOLD)
	var font := PauseStyle.DISPLAY_FONT
	ci.draw_string(font, at + Vector2(-6, -40), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, PauseStyle.PLUM)

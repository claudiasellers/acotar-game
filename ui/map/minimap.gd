## The round minimap (HudLayout's MINIMAP zone, upper right): a pearl-and-gold
## medallion, the partner of the guide's medallion in the upper left (same
## gold ring, same key pill under it). North is up; Feyre's arrow turns as she
## does. Shows what she has uncovered, the landmarks she has seen, and her.
class_name Minimap
extends Control

const DIAMETER := 232.0
const RING := 9.0
## Metres from the centre to the rim.
const VIEW_RADIUS := 170.0
const SHADER := preload("res://ui/map/map_view.gdshader")
const ManorSketch := preload("res://ui/map/manor_sketch.gd")
## Inside the manor: metres from the centre to the rim of her house plan.
const MANOR_RADIUS := 28.0

var hud: WorldMapHud
var map_rect: ColorRect
var _overlay: Control
## Her house plan on a paper disc, shown instead of the land while she is inside.
var _manor_disc: Control
var _manor_plan: Control
var _pill: Label
var _sparkles: CPUParticles2D
var _t: float = 0.0
var _glow: Dictionary = {}


func _init(owner_hud: WorldMapHud) -> void:
	hud = owner_hud
	name = "Minimap"
	if is_instance_valid(owner_hud):
		owner_hud.tree_exiting.connect(_drop_hud, CONNECT_ONE_SHOT)


## The hud is leaving (region change, save load): stop reading it.
func _drop_hud() -> void:
	hud = null


func _hud_alive() -> bool:
	return is_instance_valid(hud)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(DIAMETER, DIAMETER)
	size = custom_minimum_size
	pivot_offset = size * 0.5

	map_rect = ColorRect.new()
	map_rect.name = "Map"
	map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_rect.position = Vector2(RING, RING)
	map_rect.size = size - Vector2(RING, RING) * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"round_mask", true)
	map_rect.material = mat
	add_child(map_rect)

	_manor_disc = Control.new()
	_manor_disc.name = "ManorDisc"
	_manor_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_manor_disc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_manor_disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_manor_disc.visible = false
	_manor_disc.draw.connect(func() -> void:
		_manor_disc.draw_circle(size * 0.5, DIAMETER * 0.5 - RING + 0.5, ManorSketch.PAPER))
	add_child(_manor_disc)
	_manor_plan = Control.new()
	_manor_plan.name = "ManorPlan"
	_manor_plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_manor_plan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_manor_plan.draw.connect(_draw_manor)
	_manor_disc.add_child(_manor_plan)

	_overlay = Control.new()
	_overlay.name = "Marks"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_marks)
	_overlay.gui_input.connect(_on_click)
	add_child(_overlay)

	_sparkles = CPUParticles2D.new()
	_sparkles.emitting = false
	_sparkles.one_shot = true
	_sparkles.amount = 40
	_sparkles.lifetime = 1.1
	_sparkles.explosiveness = 0.9
	_sparkles.position = size * 0.5
	_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_sparkles.emission_ring_radius = DIAMETER * 0.5
	_sparkles.emission_ring_inner_radius = DIAMETER * 0.46
	_sparkles.direction = Vector2(0, -1)
	_sparkles.spread = 180.0
	_sparkles.initial_velocity_min = 20.0
	_sparkles.initial_velocity_max = 70.0
	_sparkles.gravity = Vector2(0, 30)
	_sparkles.scale_amount_min = 2.0
	_sparkles.scale_amount_max = 4.5
	_sparkles.texture = JournalTheme.soft_dot(16)
	var ramp := Gradient.new()
	ramp.set_color(0, JournalTheme.color(&"glow"))
	ramp.set_color(1, Color(JournalTheme.wash(0), 0.0))
	_sparkles.color_ramp = ramp
	add_child(_sparkles)

	_pill = BookKit.label("M   map", &"SatchelCount")
	_pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_pill)
	_pill.reset_size()
	_pill.position = Vector2((DIAMETER - _pill.size.x) * 0.5, DIAMETER - 6.0)


func _process(delta: float) -> void:
	_t += delta
	if not visible or not _hud_alive():
		return
	var mat := map_rect.material as ShaderMaterial
	var map_size := WorldMap.MAP_RECT.size
	var inner := (DIAMETER - RING * 2.0) / DIAMETER
	mat.set_shader_parameter(&"view_center", MapArt.world_to_uv(hud.player_xz.x, hud.player_xz.y))
	mat.set_shader_parameter(&"view_size", Vector2(VIEW_RADIUS * 2.0 * inner / map_size.x, VIEW_RADIUS * 2.0 * inner / map_size.y))
	for id: String in _glow.keys():
		_glow[id] = maxf(0.0, float(_glow[id]) - delta * 0.35)
		if _glow[id] <= 0.0:
			_glow.erase(id)
	var in_house := in_manor()
	_manor_disc.visible = in_house
	map_rect.visible = not in_house
	if in_house:
		_manor_plan.queue_redraw()
	_overlay.queue_redraw()


func in_manor() -> bool:
	return _hud_alive() and hud.manor != null and hud.manor.inside


## Her plan of the floor she is on, centred on her.
func _draw_manor() -> void:
	if not _hud_alive() or hud.manor == null:
		return
	var plan := hud.manor
	var c := size * 0.5
	var ppm := (DIAMETER * 0.5 - RING) / MANOR_RADIUS
	ManorSketch.draw_plan(_manor_plan, plan, plan.level, func(xz: Vector2) -> Vector2: return c + (xz - plan.at) * ppm, ppm)


## World XZ to a point on this control (may fall outside the disc).
func to_local_point(xz: Vector2) -> Vector2:
	var scale := (DIAMETER * 0.5) / VIEW_RADIUS
	if not _hud_alive():
		return size * 0.5
	return size * 0.5 + (xz - hud.player_xz) * scale


## A found landmark or place: its mark glows, sparkles round the rim and a
## bounce. (Its name is a notice: WorldMapHud sends it to the notice queue.)
func celebrate(landmark_id: String = "") -> void:
	if not landmark_id.is_empty():
		_glow[landmark_id] = 1.0
	sparkle()


## Sparkles round the rim and a bounce (a find, or arriving at her pin).
func sparkle() -> void:
	if visible:
		_sparkles.amount = 12 if GameSettings.reduced_effects else 40
		_sparkles.restart()
		Juice.bounce_control(self, 0.03 if GameSettings.reduced_effects else 0.07)


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hud.open_full_map()
		accept_event()


func _draw_marks() -> void:
	if not _hud_alive():
		return
	var ci := _overlay
	var c := size * 0.5
	var r := DIAMETER * 0.5
	# Gold ring with a pearl bevel, like the guide's medallion.
	ci.draw_arc(c, r - RING * 0.5, 0.0, TAU, 96, JournalTheme.color(&"line"), RING, true)
	ci.draw_arc(c, r - RING - 1.0, 0.0, TAU, 96, Color(JournalTheme.color(&"paper"), 0.9), 2.0, true)
	ci.draw_arc(c, r - 1.5, 0.0, TAU, 96, JournalTheme.color(&"glow"), 1.5, true)
	# Little pearls round the ring, and a fleur at north.
	for i in 12:
		var a := TAU * i / 12.0
		var p := c + Vector2(sin(a), -cos(a)) * (r - RING * 0.5)
		ci.draw_circle(p, 2.6 if i % 3 else 3.4, JournalTheme.color(&"paper"))
	var n := c + Vector2(0, -r + RING * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([n + Vector2(0, -15), n + Vector2(9, 2), n + Vector2(0, -2), n + Vector2(-9, 2)]), JournalTheme.color(&"accent"))
	ci.draw_polyline(PackedVector2Array([n + Vector2(0, -15), n + Vector2(9, 2), n + Vector2(0, -2), n + Vector2(-9, 2), n + Vector2(0, -15)]), JournalTheme.color(&"line"), 1.5, true)

	# Landmarks she has seen, inside the disc.
	var inner := r - RING - 10.0
	var in_house := in_manor()
	for id: String in ([] if in_house else hud.seen_landmarks.keys()):
		var lm: Dictionary = hud.seen_landmarks[id]
		var p := to_local_point(Vector2(lm.x, lm.z))
		if p.distance_to(c) <= inner:
			MapMarks.draw_landmark(ci, p, StringName(lm.kind), 9.0, float(_glow.get(id, 0.0)))
	if not in_house:
		WhorlMapMarks.draw_all(ci, hud.reveal, to_local_point, func(p: Vector2) -> bool: return p.distance_to(c) <= inner, 9.0, _t)
	_draw_pin(ci, c, inner, in_house)
	MapMarks.draw_feyre(ci, c, hud.manor.angle if in_house else hud.player_angle, 10.0, _t)


## Her pin: on the map when it is near, else riding the rim, leaning the way to go.
## Indoors the plan is at another scale: the pin always rides the rim.
func _draw_pin(ci: CanvasItem, c: Vector2, inner: float, rim_only: bool = false) -> void:
	if not hud.pin.active:
		return
	var p := to_local_point(hud.pin.xz)
	if p.distance_to(c) <= inner and not rim_only:
		MapMarks.draw_pin(ci, p, 11.0, _t)
		return
	var bearing := hud.pin.bearing_from(hud.player_xz)
	var dir := Vector2(sin(bearing), -cos(bearing))
	# The tip sits on the ring, the head outside it, pointing the way.
	MapMarks.draw_pin(ci, c + dir * (DIAMETER * 0.5 - RING * 0.5), 11.0, _t, bearing)

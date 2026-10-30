## The satchel page: her satchel tipped out onto her spread cloak, beside the
## map as one menu. Her things lie in a loose flat-lay (sized by weight, each
## at its own fixed tilt); the one in focus lifts and a paper tag on twine
## swings in, in its own column. Pockets are flaps along the top edge, and the map is the
## last flap.
##
## Keys: I / Tab / Esc close, Q / R (pad LB / RB) flip pockets and run on to
## the map, M opens the map, E / Enter (pad A) uses, 1–4 (pad X) pins.
## Silent by the user's call (T022). Look: theme variations from SatchelTheme
## only; no colours or fonts here.
class_name SatchelMenu
extends CanvasLayer

signal opened
signal closed

const MARGIN := Vector2(96, 64)
const CELL := 156.0
## Icon size by weight class (TINY..HEAVY); dishes use MEDIUM.
const SIZES: Array[float] = [60.0, 72.0, 88.0, 112.0, 124.0]
const TILT_DEG := 4.0
const JITTER := 10.0
const HERO_SCALE := 1.25
const HERO_LIFT := 10.0
const REST_ALPHA := 0.8
## Lazy tween: each frame (at 60 fps) a value moves this share of the way to its target.
const EASE := 0.3
const OPEN_STAGGER := 0.02
const TAG_GAP := 72.0
const TAG_WIDTH := 360.0
## The tag keeps its own column on the right; things lie to the left of it.
const TAG_COLUMN := TAG_WIDTH + TAG_GAP * 2.0

var bar: QuickBar
var pocket: StringName = SatchelEntries.ALL
var selected_id: StringName = &""

var _root: Control
var _cloth: PanelContainer
var _flaps: HBoxContainer
var _pocket_buttons: Dictionary = {}
var _map_flap: Button
var _purse: Label
var _lay: Control
var _empty: Label
var _shadow: TextureRect
var _items: Array[Dictionary] = []
var _tag: PanelContainer
var _tag_name: Label
var _tag_line: Label
var _tag_meta: Label
var _use_button: Button
var _pin_buttons: Array[Button] = []
var _twine: Line2D
var _tag_angle: float = 0.0
var _tag_spin: float = 0.0
var _load_glyph: SatchelGlyph
var _load_label: Label
var _prompts: HBoxContainer
var _lay_slide: float = 0.0
var _new_ids: Dictionary = {}
var _tag_y: float = -1.0


func _init(quick_bar: QuickBar = null) -> void:
	bar = quick_bar if quick_bar else QuickBar.current()
	name = "SatchelMenu"


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	bar.changed.connect(_watch_new)
	_watch_new()


## Opens the satchel in whichever scene has one (for the map's own tab).
static func open_from(tree: SceneTree) -> void:
	var found := tree.root.find_children("*", "SatchelMenu", true, false)
	if found.size() > 0:
		(found[0] as SatchelMenu).open()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_apply_theme()
	_root.visible = true
	for n in get_tree().root.find_children("*", "PanelContainer", true, false):
		if n is ControlsHint:
			(n as ControlsHint).hide_now()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh(true)
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	_new_ids.clear()
	_tag_y = -1.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func set_pocket(p: StringName) -> void:
	if p == pocket:
		return
	var step := signf(SatchelEntries.POCKETS.find(p) - SatchelEntries.POCKETS.find(pocket))
	pocket = p
	_lay_slide = 40.0 * step
	_refresh(true)


## Next / previous pocket; past the last one is the map.
func flip(step: int) -> void:
	var i := SatchelEntries.POCKETS.find(pocket) + step
	if i >= SatchelEntries.POCKETS.size():
		_to_map()
	elif i >= 0:
		set_pocket(SatchelEntries.POCKETS[i])


func select(id: StringName) -> void:
	if id == selected_id:
		return
	selected_id = id
	_tag_angle = deg_to_rad(9.0)
	_tag_spin = 0.0
	_show_detail()
	_build_prompts()


func use_selected() -> bool:
	if selected_id == &"" or not SatchelUse.can_pin(selected_id):
		return false
	var ok := SatchelUse.use(bar.inventory, selected_id, get_tree().get_first_node_in_group(&"player"))
	if ok:
		_refresh(false)
	return ok


func pin_selected(slot: int) -> bool:
	if not bar.pin(slot, selected_id):
		return false
	Juice.bounce_control(_pin_buttons[slot], 0.2)
	_show_detail()
	return true


# --- input -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel") \
			or event.is_action_pressed(SatchelHud.ACTION_OPEN):
		close()
	elif event.is_action_pressed(MapSettings.ACTION_OPEN):
		_to_map()
	elif _pad(event, JOY_BUTTON_LEFT_SHOULDER) or _key(event, [KEY_Q]):
		flip(-1)
	elif _pad(event, JOY_BUTTON_RIGHT_SHOULDER) or _key(event, [KEY_R]):
		flip(1)
	elif _pad(event, JOY_BUTTON_X):
		pin_selected(bar.next_slot_for(selected_id))
	elif _key(event, [KEY_E, KEY_ENTER, KEY_KP_ENTER]):
		use_selected()
	else:
		for i in QuickBar.SLOTS:
			if event.is_action_pressed(SatchelHud.slot_action(i)):
				pin_selected(i)
				get_viewport().set_input_as_handled()
				return
		return
	get_viewport().set_input_as_handled()


func _pad(event: InputEvent, button: JoyButton) -> bool:
	return event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == button


func _key(event: InputEvent, keys: Array) -> bool:
	return event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode in keys


func _to_map() -> void:
	var huds := get_tree().root.find_children("*", "WorldMapHud", true, false)
	if huds.is_empty():
		return
	close()
	(huds[0] as WorldMapHud).full_map.open()


func _watch_new() -> void:
	if not bar.inventory.item_added.is_connected(_on_item_added):
		bar.inventory.item_added.connect(_on_item_added)


func _on_item_added(id: StringName, _n: int, _c: StringName) -> void:
	_new_ids[id] = true


# --- build -------------------------------------------------------------------

## Act I and the Spring Court wear different themes (SatchelTheme).
func _apply_theme() -> void:
	_root.theme = SatchelTheme.theme()
	_twine.default_color = SatchelTheme.color(&"line")
	_shadow.texture = _shadow_texture()
	_load_glyph.queue_redraw()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = SatchelTheme.theme()
	add_child(_root)
	# The cloak's cloth fills the screen: no card, no box.
	_cloth = PanelContainer.new()
	_cloth.theme_type_variation = &"SatchelCard"
	_cloth.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cloth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_cloth)
	_root.add_child(_vignette())

	_flaps = HBoxContainer.new()
	_flaps.position = MARGIN
	_flaps.add_theme_constant_override(&"separation", 8)
	_root.add_child(_flaps)
	for p: StringName in SatchelEntries.POCKETS:
		var b := _button(SatchelEntries.POCKET_NAMES[p], &"SatchelTab")
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_pocket.bind(p))
		_flaps.add_child(b)
		_pocket_buttons[p] = b
	_map_flap = _button("Map", &"SatchelTab")
	_map_flap.focus_mode = Control.FOCUS_NONE
	_map_flap.pressed.connect(_to_map)
	_flaps.add_child(_map_flap)

	_purse = _label("", &"SatchelSmall")
	_purse.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_purse.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_purse.offset_right = -MARGIN.x
	_purse.offset_top = MARGIN.y + 8
	_root.add_child(_purse)

	_lay = Control.new()
	_lay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lay.offset_left = MARGIN.x
	_lay.offset_right = -(MARGIN.x + TAG_COLUMN)
	_lay.offset_top = MARGIN.y + 88
	_lay.offset_bottom = -(MARGIN.y + 72)
	_lay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_lay)
	_shadow = TextureRect.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lay.add_child(_shadow)
	_empty = _label("Nothing in this pocket yet.", &"SatchelBody")
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_lay.add_child(_empty)

	_twine = Line2D.new()
	_twine.width = 2.0
	_twine.default_color = SatchelTheme.color(&"line")
	_twine.antialiased = true
	_root.add_child(_twine)
	_build_tag()
	_build_footer()


func _build_tag() -> void:
	_tag = PanelContainer.new()
	_tag.theme_type_variation = &"SatchelDetail"
	_tag.custom_minimum_size = Vector2(TAG_WIDTH, 0)
	_root.add_child(_tag)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	_tag.add_child(col)
	_tag_name = _label("", &"SatchelHeading")
	_tag_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_tag_name)
	_tag_line = _label("", &"SatchelBody")
	_tag_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_tag_line)
	_tag_meta = _label("", &"SatchelSmall")
	_tag_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_tag_meta)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	col.add_child(row)
	_use_button = _button("Use", &"SatchelTab")
	_use_button.focus_mode = Control.FOCUS_NONE
	_use_button.pressed.connect(use_selected)
	row.add_child(_use_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	for i in QuickBar.SLOTS:
		var b := _button(str(i + 1), &"SatchelTab")
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(36, 36)
		b.tooltip_text = "Pin to quick bar slot %d" % (i + 1)
		b.pressed.connect(pin_selected.bind(i))
		row.add_child(b)
		_pin_buttons.append(b)


func _build_footer() -> void:
	var load_row := HBoxContainer.new()
	load_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	load_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	load_row.offset_left = MARGIN.x
	load_row.offset_bottom = -MARGIN.y
	load_row.add_theme_constant_override(&"separation", 10)
	_root.add_child(load_row)
	_load_glyph = SatchelGlyph.new()
	_load_glyph.custom_minimum_size = Vector2(52, 46)
	load_row.add_child(_load_glyph)
	_load_label = _label("", &"SatchelSmall")
	_load_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	load_row.add_child(_load_label)

	_prompts = HBoxContainer.new()
	_prompts.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_prompts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompts.offset_right = -MARGIN.x
	_prompts.offset_bottom = -MARGIN.y
	_prompts.add_theme_constant_override(&"separation", 22)
	_root.add_child(_prompts)


func _button(text: String, variation: StringName) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	return b


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# --- the flat-lay ------------------------------------------------------------

## Lays the current pocket out. `settle` replays the drop-in.
func _refresh(settle: bool = false) -> void:
	var inv := bar.inventory
	for p: StringName in _pocket_buttons:
		(_pocket_buttons[p] as Button).set_pressed_no_signal(p == pocket)
	var entries := SatchelEntries.list(inv, pocket)
	var old := {}
	for it in _items:
		old[it.id] = it
	var fresh: Array[Dictionary] = []
	var layout := _layout(entries)
	for i in entries.size():
		var e := entries[i]
		var it: Dictionary = old.get(e.id, {})
		old.erase(e.id)
		if it.is_empty() or settle:
			if not it.is_empty():
				(it.node as Node).queue_free()
			it = _make_item(e)
		it.home = layout[i]
		it.entry = e
		_update_count(it, e)
		if settle:
			(it.node as Control).modulate.a = 0.0
			it.at = it.home + Vector2(_lay_slide, -14.0)
			it.rot = it.tilt + deg_to_rad(2.0)
			it.delay = OPEN_STAGGER * i
		fresh.append(it)
	for id in old:
		(old[id].node as Node).queue_free()
	_items = fresh
	_empty.visible = entries.is_empty()
	if not entries.any(func(e: Dictionary) -> bool: return e.id == selected_id):
		selected_id = entries[0].id if entries.size() > 0 else &""
	_show_detail()
	_purse.text = "%d coppers" % inv.coin
	var cap := float(Inventory.CAPACITY[Inventory.SATCHEL])
	_load_glyph.fill = clampf(inv.used(Inventory.SATCHEL) / cap, 0.0, 1.0)
	_load_glyph.queue_redraw()
	_load_label.text = "%s / %d" % [_units(inv.used(Inventory.SATCHEL)), int(cap)]
	if inv.speed_multiplier() < 1.0:
		_load_label.text += "   heavy, she walks slower"
	_build_prompts()
	_focus_selected.call_deferred()


## Loose rows centred in the lay area, each item nudged and tilted by a seed
## from its id so it rests in the same place every time.
func _layout(entries: Array[Dictionary]) -> Array[Vector2]:
	var area := _lay.size.max(Vector2(CELL, CELL))
	var n := entries.size()
	# A block about as wide as the area is, not one long row.
	var max_cols := maxi(1, int(area.x / CELL))
	var cols := clampi(ceili(sqrt(n * area.x / area.y)), 1, max_cols)
	var rows := ceili(float(n) / cols)
	var top := maxf(0.0, (area.y - rows * CELL) * 0.42)
	var out: Array[Vector2] = []
	for i in n:
		var r := _seeded(entries[i].id)
		var row := i / cols
		var in_row := mini(cols, n - row * cols)
		var left := (area.x - in_row * CELL) * 0.5
		# Alternate rows sit half a step over, like things tipped out, not shelved.
		var stagger := CELL * 0.18 * (1.0 if row % 2 else -1.0)
		var cell := Vector2(left + (i % cols + 0.5) * CELL + stagger, top + (row + 0.5) * CELL)
		out.append(cell + Vector2(r.x, r.y) * JITTER)
	return out


func _seeded(id: StringName) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(id))
	return Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))


func _size_for(e: Dictionary) -> float:
	var item := e.get("item") as ItemData
	return SIZES[item.weight_class] if item else SIZES[2]


func _make_item(e: Dictionary) -> Dictionary:
	var px := _size_for(e)
	var b := Button.new()
	b.flat = true
	for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(px, px)
	b.size = Vector2(px, px)
	b.pivot_offset = Vector2(px, px) * 0.5
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = e.name
	b.add_child(SatchelIcon.make(e, px))
	var count := _label("", &"SatchelCount")
	count.position = Vector2(px * 0.62, px * 0.72)
	b.add_child(count)
	var pin := _label("", &"QuickBarKey")
	pin.position = Vector2(-2, px * 0.70)
	b.add_child(pin)
	_lay.add_child(b)
	var it := {"id": e.id, "node": b, "px": px, "count": count, "pin": pin, "entry": e,
		"tilt": deg_to_rad(_seeded(e.id).z * TILT_DEG), "at": Vector2.ZERO, "rot": 0.0, "scale": 1.0,
		"delay": 0.0, "home": Vector2.ZERO}
	b.focus_entered.connect(select.bind(e.id))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		if selected_id == e.id:
			use_selected())
	return it


func _update_count(it: Dictionary, e: Dictionary) -> void:
	(it.count as Label).text = str(e.count) if int(e.count) > 1 else ""
	var at := bar.slot_of(e.id)
	(it.pin as Label).text = "◦%d" % (at + 1) if at >= 0 else ("new" if _new_ids.has(e.id) else "")


func _process(delta: float) -> void:
	if not is_open():
		return
	var k := 1.0 - pow(1.0 - EASE, delta * 60.0)
	_lay_slide = lerpf(_lay_slide, 0.0, k)
	var hero: Dictionary = {}
	for it in _items:
		var node := it.node as Control
		if it.delay > 0.0:
			it.delay -= delta
			continue
		var is_hero: bool = it.id == selected_id
		var target_at: Vector2 = it.home + (Vector2(0, -HERO_LIFT) if is_hero else Vector2.ZERO)
		it.at = (it.at as Vector2).lerp(target_at, k)
		it.rot = lerpf(it.rot, it.tilt, k)
		it.scale = lerpf(it.scale, HERO_SCALE if is_hero else 1.0, k)
		node.position = it.at - Vector2(it.px, it.px) * 0.5
		node.rotation = it.rot
		node.scale = Vector2.ONE * it.scale
		node.modulate.a = lerpf(node.modulate.a, 1.0 if is_hero else REST_ALPHA, k)
		if is_hero:
			hero = it
	_place_tag(hero, delta, k)


## The tag hangs beside the hero on a sagging length of twine and swings in
## like a pendulum (damped spring).
func _place_tag(hero: Dictionary, delta: float, k: float) -> void:
	_tag.visible = not hero.is_empty()
	_twine.visible = _tag.visible
	_shadow.visible = _tag.visible
	if hero.is_empty():
		return
	var px: float = hero.px * HERO_SCALE
	var centre: Vector2 = _lay.position + hero.at
	_shadow.size = Vector2(px * 1.1, px * 0.45)
	_shadow.position = hero.at + Vector2(-px * 0.55, px * 0.42 + HERO_LIFT)
	# The tag keeps its column and only drifts up or down to sit level with
	# the hero, so the eye always finds it in the same place.
	var x := _root.size.x - MARGIN.x - TAG_WIDTH
	var y := clampf(centre.y - 40.0, _lay.position.y, maxf(_lay.position.y, _root.size.y - MARGIN.y - 96 - _tag.size.y))
	_tag_y = y if _tag_y < 0.0 else lerpf(_tag_y, y, k)
	_tag.position = Vector2(x, _tag_y)
	_tag.pivot_offset = Vector2(24.0, 0.0)
	_tag_spin += (-90.0 * _tag_angle - 9.0 * _tag_spin) * delta
	_tag_angle += _tag_spin * delta
	_tag.rotation = _tag_angle
	# A loose loop of twine through the tag's hole, trailing off the top edge.
	var tie := _tag.position + Vector2(24.0, 18.0).rotated(_tag_angle)
	var pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0 * TAU
		pts.append(tie + Vector2(sin(t) * 9.0 - 6.0 * t / TAU, -16.0 + cos(t) * -16.0).rotated(_tag_angle))
	pts.append(tie + Vector2(-26.0, -44.0).rotated(_tag_angle * 0.5))
	pts.append(tie + Vector2(-40.0, -52.0).rotated(_tag_angle * 0.3))
	_twine.points = pts


func _show_detail() -> void:
	var e := SatchelEntries.find(bar.inventory, selected_id) if selected_id != &"" else {}
	if e.is_empty():
		return
	var item := e.item as ItemData
	_tag_name.text = e.name
	_tag_line.text = e.description
	var meta: Array[String] = [String(SatchelEntries.POCKET_NAMES.get(e.pocket, "")).to_upper()]
	if int(e.count) > 1:
		meta.append("%d CARRIED" % e.count)
	if item and item.base_price > 0:
		meta.append("MARKET %d COPPERS" % item.base_price)
	_tag_meta.text = "   ".join(meta)
	var verb := SatchelUse.verb(selected_id)
	_use_button.visible = verb != ""
	_use_button.text = verb
	for i in _pin_buttons.size():
		_pin_buttons[i].visible = SatchelUse.can_pin(selected_id)
		_pin_buttons[i].set_pressed_no_signal(bar.entry(i) == selected_id)
	for it in _items:
		_update_count(it, it.entry)


## Button glyphs, not a sentence: pad or keys, whichever was used last.
func _build_prompts() -> void:
	for c in _prompts.get_children():
		c.queue_free()
	var pad := SatchelHud.pad_active
	var pairs: Array = []
	var verb := SatchelUse.verb(selected_id) if selected_id != &"" else ""
	if verb != "":
		pairs.append(["A" if pad else "E", verb])
		pairs.append(["X" if pad else "1–4", "Pin"])
	pairs.append(["LB RB" if pad else "Q R", "Pocket"])
	pairs.append(["B" if pad else "Esc", "Back"])
	for p in pairs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		var glyph := PanelContainer.new()
		glyph.theme_type_variation = &"QuickBarSlot"
		var key := _label(p[0], &"QuickBarKey")
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.add_child(key)
		row.add_child(glyph)
		var word := _label(p[1], &"SatchelSmall")
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(word)
		_prompts.add_child(row)


func _focus_selected() -> void:
	for it in _items:
		if it.id == selected_id:
			(it.node as Control).grab_focus()
			return


## Edges of the cloak fall into shade, so the eye settles in the middle.
func _vignette() -> TextureRect:
	var g := Gradient.new()
	var ink := SatchelTheme.color(&"ink")
	g.set_offset(0, 0.55)
	g.set_color(0, Color(ink, 0.0))
	g.set_color(1, Color(ink, 0.16))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 1.0)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _shadow_texture() -> GradientTexture2D:
	var g := Gradient.new()
	var ink := SatchelTheme.color(&"ink")
	g.set_color(0, Color(ink, 0.28))
	g.set_color(1, Color(ink, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _units(v: float) -> String:
	return str(snappedf(v, 0.25)).trim_suffix(".0")

## Feyre's easel (L30): the canvas in the middle, her paints and six mixing
## wells on the left, brushes and the finish on the right. Pick a paint and
## paint, or pick a paint and tap a well to mix it in. Right-click a well to
## wipe it. Pauses the game while open (UiStyle.modal).
##   StudioUi.open(feyre, easel)   # interactor, station_id "easel"
class_name StudioUi
extends RefCounted

const DISPLAY_SCALE := 0.78
const SWATCH := 34
const WELL := 56

static var _open: CanvasLayer = null
static var _session: StudioSession = null


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


static func session() -> StudioSession:
	return _session if is_open() else null


static func open(feyre: Node3D, easel: Node3D) -> void:
	if is_open() or feyre == null:
		return
	var tree := feyre.get_tree()
	if not StudioDeeds.easel_open():
		FindCard.note(tree, "A dust sheet over the easel, and over the empty canvases.")
		return
	var s := StudioSession.new(Gameplay.inventory, easel, feyre)
	_session = s
	var parts := UiStyle.modal("StudioUI", 1560.0)
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	_open = layer
	s.layer = layer

	var head := HBoxContainer.new()
	box.add_child(head)
	var title_label := UiStyle.label("The easel", 28)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	var found := UiStyle.label("", 18)
	# One line: a wrapping label in a row gets no width and stacks its letters.
	found.autowrap_mode = TextServer.AUTOWRAP_OFF
	found.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(found)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	box.add_child(row)

	# --- Left: paints and wells -------------------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	row.add_child(left)
	left.add_child(UiStyle.label("Paints", 20))
	var paints := GridContainer.new()
	paints.columns = 6
	left.add_child(paints)
	var paint_name := UiStyle.label("", 15)
	left.add_child(paint_name)
	left.add_child(UiStyle.label("Palette", 20))
	var wells := GridContainer.new()
	wells.columns = 3
	wells.add_theme_constant_override(&"h_separation", 12)
	wells.add_theme_constant_override(&"v_separation", 12)
	left.add_child(wells)
	left.add_child(UiStyle.label("Tap a well to mix the paint in. Right-click to wipe it.", 13))

	# --- Centre: the canvas ------------------------------------------------
	var frame := PanelContainer.new()
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = Color(0.93, 0.78, 0.45)
	frame_box.set_corner_radius_all(6)
	frame_box.set_content_margin_all(8)
	frame_box.shadow_color = Color(0.5, 0.3, 0.4, 0.3)
	frame_box.shadow_size = 10
	frame.add_theme_stylebox_override(&"panel", frame_box)
	row.add_child(frame)
	var tex := TextureRect.new()
	tex.name = "Canvas"
	tex.custom_minimum_size = Vector2(StudioCanvas.WIDTH, StudioCanvas.HEIGHT) * DISPLAY_SCALE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.texture = ImageTexture.create_from_image(s.canvas.image)
	tex.mouse_filter = Control.MOUSE_FILTER_STOP
	tex.mouse_default_cursor_shape = Control.CURSOR_CROSS
	frame.add_child(tex)
	s.canvas_rect = tex

	# --- Right: brushes, sizes, finish -------------------------------------
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(230, 0)
	right.add_theme_constant_override(&"separation", 8)
	row.add_child(right)
	right.add_child(UiStyle.label("Brushes", 20))
	var brush_group := ButtonGroup.new()
	var brushes := StudioCanvas.brushes()
	for i in brushes.size():
		var b := UiStyle.button(brushes[i].display_name, true)
		b.button_group = brush_group
		b.button_pressed = i == 0
		b.pressed.connect(func() -> void: s.canvas.brush = brushes[i])
		right.add_child(b)
	right.add_child(UiStyle.label("Size", 20))
	var sizes := HBoxContainer.new()
	var size_group := ButtonGroup.new()
	for i in StudioCanvas.SIZES.size():
		var b := UiStyle.button(["S", "M", "L", "XL"][i], true)
		b.button_group = size_group
		b.button_pressed = i == s.canvas.size_index
		b.pressed.connect(func() -> void: s.canvas.size_index = i)
		sizes.add_child(b)
	right.add_child(sizes)
	var undo := UiStyle.button("Undo")
	undo.pressed.connect(func() -> void:
		if s.canvas.undo():
			s.dirty = true)
	right.add_child(undo)
	var title := LineEdit.new()
	title.placeholder_text = "Title (or leave it)"
	right.add_child(title)
	var status := UiStyle.label("", 15)
	right.add_child(status)
	var finish := UiStyle.button("Finish and set it aside")
	right.add_child(finish)
	var leave := UiStyle.button("Leave it for now")
	right.add_child(leave)

	# --- Behaviour ----------------------------------------------------------
	var refresh := func() -> void:
		found.text = "Colours found %d / %d" % [StudioPalette.found_names().size(), StudioPalette.book_size()]
		for c in paints.get_children():
			c.queue_free()
		for p: Dictionary in s.supply.paints():
			var sw := _swatch(p.color, SWATCH, s.selected == p.id)
			var left_n: int = p.left
			sw.tooltip_text = "%s%s" % [p.name, "" if left_n < 0 else " (%d)" % left_n]
			if left_n == 0:
				sw.modulate.a = 0.35
			var pid: StringName = p.id
			sw.pressed.connect(func() -> void:
				s.select_paint(pid)
				paint_name.text = String(p.name)
				Juice.bounce_control(sw, 0.15)
				s.refresh_needed = true)
			paints.add_child(sw)
		for c in wells.get_children():
			c.queue_free()
		for i in StudioPalette.WELLS:
			var w: Dictionary = s.palette.wells[i]
			var empty := int(w.amount) <= 0
			var well := _swatch(Color(0.97, 0.95, 0.93) if empty else w.color, WELL, s.selected_well == i, empty)
			well.tooltip_text = "Empty" if empty else "%d strokes" % int(w.amount)
			well.gui_input.connect(func(e: InputEvent) -> void:
				if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
					s.palette.wipe(i)
					s.refresh_needed = true)
			well.pressed.connect(func() -> void:
				var mixed := s.tap_well(i)
				if mixed:
					StudioFx.burst(well, well.size * 0.5, &"pickup", s.palette.wells[i].color, well, 12)
				else:
					Juice.bounce_control(well, 0.12)
				s.refresh_needed = true)
			wells.add_child(well)
	s.refresh = refresh
	refresh.call()

	s.palette.colour_found.connect(func(colour_name: String, color: Color) -> void:
		status.text = "A new colour: %s" % colour_name
		StudioFx.burst(found, found.size * 0.5, &"unlock", color, found, 40)
		s.refresh_needed = true)

	tex.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var why := s.start_stroke(event.position / DISPLAY_SCALE)
				if why != "":
					status.text = why
				elif s.opened_gallery:
					s.opened_gallery = false
					StudioFx.burst(tex, event.position, &"unlock", Color(1, 0.9, 0.7), null, 36)
			else:
				s.end_stroke()
		elif event is InputEventMouseMotion and s.canvas.painting:
			s.canvas.drag(event.position / DISPLAY_SCALE))

	finish.pressed.connect(func() -> void:
		if s.canvas.strokes == 0:
			status.text = "Nothing on it yet."
			Juice.bounce_control(finish, 0.12)
			return
		finish.disabled = true
		leave.disabled = true
		var done: Image = s.canvas.image.duplicate()
		s.finish(title.text)
		# Hold the finished canvas on screen a moment while it sparkles.
		(tex.texture as ImageTexture).update(done)
		StudioFx.burst(frame, frame.size * 0.5, &"outfit", Color(1, 0.85, 0.95), frame, 70)
		status.text = "Finished."
		await tree.create_timer(0.8, true).timeout
		close())
	leave.pressed.connect(func() -> void: close())

	tree.process_frame.connect(s.tick)
	tree.root.add_child(layer)
	tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	StudioFx.chime(layer, &"pickup", 0.8)


static func close() -> void:
	var s := _session
	if s:
		s.close()
		var tree := s.layer.get_tree() if s.layer and s.layer.is_inside_tree() else null
		if tree:
			if tree.process_frame.is_connected(s.tick):
				tree.process_frame.disconnect(s.tick)
			tree.paused = false
	if is_open():
		_open.queue_free()
	_open = null
	_session = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## A round paint blob (a button) in `color`.
static func _swatch(color: Color, size: int, selected: bool, empty: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(size, size) * 0.5
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(size)
		box.border_color = UiStyle.BORDER if selected else (Color(0.85, 0.75, 0.8) if empty else Color(1, 1, 1, 0.9))
		box.set_border_width_all(4 if selected else 2)
		box.shadow_color = Color(0.5, 0.3, 0.4, 0.25)
		box.shadow_size = 4 if state == "hover" else 2
		b.add_theme_stylebox_override(state, box)
	return b

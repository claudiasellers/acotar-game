## Feyre's easel (L30): the canvas in the middle, her paints and six mixing
## wells on the left, brushes and the finish on the right. Pick a paint and
## paint, or pick a paint and tap a well to mix it in. Right-click a well to
## wipe it. A loose page of her journal (LoosePage) on ScreenStack, which
## pauses the game while it is open.
##   StudioUi.open(feyre, easel)   # interactor, station_id "easel"
class_name StudioUi
extends RefCounted

## The paints, the canvas and the brushes side by side, with the paper's edge.
const WIDTH := 1440.0
## The pink wash: paint.
const WASH := 0
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
	var layer := CanvasLayer.new()
	layer.name = "StudioUI"
	var page := LoosePage.lay(layer, WIDTH, WASH, 10)
	var box := page.column
	_open = layer
	s.layer = layer

	var head := page.head()
	head[0].text = "The easel"
	var found := head[1]

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	box.add_child(row)

	# --- Left: paints and wells -------------------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	row.add_child(left)
	left.add_child(BookKit.label("Paints", &"PageSection"))
	var paints := GridContainer.new()
	paints.columns = 6
	left.add_child(paints)
	var paint_name := BookKit.label("", &"SatchelSmall")
	left.add_child(paint_name)
	left.add_child(BookKit.label("Palette", &"PageSection"))
	var wells := GridContainer.new()
	wells.columns = 3
	wells.add_theme_constant_override(&"h_separation", 12)
	wells.add_theme_constant_override(&"v_separation", 12)
	left.add_child(wells)
	left.add_child(BookKit.label("Tap a well to mix the paint in. Right-click to wipe it.", &"SatchelSmall", true))

	# --- Centre: the canvas ------------------------------------------------
	var frame := PanelContainer.new()
	var frame_box := StyleBoxFlat.new()
	frame_box.bg_color = JournalTheme.color(&"line")
	frame_box.set_corner_radius_all(6)
	frame_box.set_content_margin_all(8)
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
	right.add_child(BookKit.label("Brushes", &"PageSection"))
	var brush_group := ButtonGroup.new()
	var brushes := StudioCanvas.brushes()
	for i in brushes.size():
		var b := _choice(brushes[i].display_name)
		b.button_group = brush_group
		b.button_pressed = i == 0
		b.pressed.connect(func() -> void: s.canvas.brush = brushes[i])
		right.add_child(b)
	right.add_child(BookKit.label("Size", &"PageSection"))
	var sizes := HBoxContainer.new()
	var size_group := ButtonGroup.new()
	for i in StudioCanvas.SIZES.size():
		var b := _choice(["S", "M", "L", "XL"][i])
		b.button_group = size_group
		b.button_pressed = i == s.canvas.size_index
		b.pressed.connect(func() -> void: s.canvas.size_index = i)
		sizes.add_child(b)
	right.add_child(sizes)
	var undo := LoosePage.button("Undo")
	undo.pressed.connect(func() -> void:
		if s.canvas.undo():
			s.dirty = true)
	right.add_child(undo)
	var title := LineEdit.new()
	title.placeholder_text = "Title (or leave it)"
	right.add_child(title)
	var status := BookKit.label("", &"SatchelSmall", true)
	right.add_child(status)
	var finish := LoosePage.button("Finish and set it aside")
	right.add_child(finish)
	var leave := LoosePage.button("Leave it for now")
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
			var well := _swatch(JournalTheme.color(&"paper_deep") if empty else w.color, WELL, s.selected_well == i, empty)
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
					StudioFx.burst(tex, event.position, &"unlock", JournalTheme.color(&"glow"), null, 36)
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
		StudioFx.burst(frame, frame.size * 0.5, &"outfit", JournalTheme.wash(0), frame, 70)
		status.text = "Finished."
		await tree.create_timer(0.8, true).timeout
		close())
	leave.pressed.connect(func() -> void: close())

	tree.process_frame.connect(s.tick)
	tree.root.add_child(layer)
	ScreenStack.push(layer, ScreenStack.Flag.PAUSES | ScreenStack.Flag.MOUSE, StudioUi.close)
	StudioFx.chime(layer, &"pickup", 0.8)


static func close() -> void:
	var s := _session
	if s:
		s.close()
		var tree := s.layer.get_tree() if s.layer and s.layer.is_inside_tree() else null
		if tree:
			if tree.process_frame.is_connected(s.tick):
				tree.process_frame.disconnect(s.tick)
	if is_open():
		ScreenStack.pop(_open)
		_open.queue_free()
	_open = null
	_session = null


## One of a set of choices (a brush, a size): stays pressed.
static func _choice(text: String) -> Button:
	var b := LoosePage.button(text)
	b.toggle_mode = true
	return b


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
		box.border_color = JournalTheme.color(&"accent") if selected else JournalTheme.color(&"line" if empty else &"paper")
		box.set_border_width_all(4 if selected else 2)
		b.add_theme_stylebox_override(state, box)
	return b

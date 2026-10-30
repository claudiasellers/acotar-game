## The easel: paint with owned pigments, then finish to hang it.
## Functional UI; pauses the game while open.
extends RefCounted

static var _open: CanvasLayer = null


static func open(feyre: Feyre, easel: Node3D) -> void:
	if _open and is_instance_valid(_open):
		return
	var canvas := PaintingCanvas.new(Gameplay.inventory)
	var parts := UiStyle.modal("PaintingUI", 1000.0)
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	_open = layer
	box.add_child(UiStyle.label("The easel", 26))
	var state := {"pigment": &"", "size": 1, "last": Vector2.INF}

	var row := HBoxContainer.new()
	box.add_child(row)
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(PaintingCanvas.WIDTH, PaintingCanvas.HEIGHT)
	tex.texture = ImageTexture.create_from_image(canvas.image)
	tex.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(tex)
	var side := VBoxContainer.new()
	row.add_child(side)
	var status := UiStyle.label("")
	var palette := GridContainer.new()
	palette.columns = 2
	side.add_child(UiStyle.label("Paints", 18))
	side.add_child(palette)
	var refresh := func() -> void:
		for c in palette.get_children():
			c.queue_free()
		var pal := canvas.palette()
		if pal.is_empty():
			status.text = "No paints. Infuse woad, madder, chalk or other pigments at a fire."
		for id: StringName in pal:
			var item := ItemCatalog.get_item(id)
			var b := UiStyle.button("%s (%d)" % [item.display_name, int(pal[id])])
			var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
			img.fill(item.color)
			b.icon = ImageTexture.create_from_image(img)
			b.pressed.connect(func() -> void: state.pigment = id)
			palette.add_child(b)
	refresh.call()
	side.add_child(UiStyle.label("Brush", 18))
	var sizes := HBoxContainer.new()
	for i in PaintingCanvas.BRUSH_SIZES.size():
		var b := UiStyle.button(["Fine", "Medium", "Broad"][i])
		b.pressed.connect(func() -> void: state.size = i)
		sizes.add_child(b)
	side.add_child(sizes)
	var title := LineEdit.new()
	title.placeholder_text = "Title"
	side.add_child(title)
	side.add_child(status)

	tex.gui_input.connect(func(event: InputEvent) -> void:
		var pos: Vector2 = Vector2.INF
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			state.last = event.position if event.pressed else Vector2.INF
			pos = event.position
		elif event is InputEventMouseMotion and state.last != Vector2.INF:
			pos = event.position
		if pos == Vector2.INF or state.pigment == &"":
			return
		var from: Vector2 = state.last if state.last != Vector2.INF else pos
		if canvas.stroke(from, pos, state.pigment, state.size):
			(tex.texture as ImageTexture).update(canvas.image)
		else:
			refresh.call()
		state.last = pos)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var finish := UiStyle.button("Finish and hang it")
	finish.pressed.connect(func() -> void:
		if canvas.strokes == 0:
			status.text = "Paint something first."
			return
		var record := Gameplay.gallery.finish(canvas, title.text, feyre.get_tree())
		close(feyre)
		PaintingObject.hang(record, feyre.get_parent(), easel))
	buttons.add_child(finish)
	var leave := UiStyle.button("Leave it")
	leave.pressed.connect(func() -> void: close(feyre))
	buttons.add_child(leave)
	feyre.get_tree().root.add_child(layer)
	feyre.get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func close(feyre: Feyre) -> void:
	if _open and is_instance_valid(_open):
		_open.queue_free()
	_open = null
	feyre.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

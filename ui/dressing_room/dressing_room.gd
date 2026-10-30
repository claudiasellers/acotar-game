## The dressing room (manor): try on outfits, hair and makeup in front of the
## vanity mirror. Opened from the "wardrobe" (outfits + hair) and
## "dressing_mirror" (makeup + hair) stations. Every change gets the outfit
## sparkle and chime.
extends RefCounted

## Wardrobe sources that are simply hanging in the dressing room.
const ROOM_SOURCES: Array[StringName] = [&"manor_wardrobe", &"alis", &"stables", &"painting_room"]

static var _open: CanvasLayer = null
static var _vanity: Camera3D = null


static func open(feyre: Feyre, station_id: StringName) -> void:
	if _open and is_instance_valid(_open):
		return
	_stock_room()
	var parts := UiStyle.modal("DressingRoom", 980.0)
	var layer: CanvasLayer = parts[0]
	var box: VBoxContainer = parts[1]
	_open = layer
	var mirror := station_id == &"dressing_mirror"
	box.add_child(UiStyle.label("The vanity" if mirror else "The dressing room", 28))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 460)
	box.add_child(tabs)
	if not mirror:
		tabs.add_child(_outfits(feyre))
	tabs.add_child(_hair(feyre))
	tabs.add_child(_makeup(feyre))
	var close := UiStyle.button("Done")
	close.pressed.connect(func() -> void: close_room(feyre))
	box.add_child(close)
	feyre.get_tree().root.add_child(layer)
	_enter_vanity(feyre)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	feyre.get_tree().paused = true


static func close_room(feyre: Feyre) -> void:
	if _open and is_instance_valid(_open):
		_open.queue_free()
	_open = null
	if _vanity and is_instance_valid(_vanity):
		_vanity.queue_free()
	_vanity = null
	if feyre.camera:
		feyre.camera.current = true
	feyre.get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Grants every piece hanging in the room (sources above) the first time.
static func _stock_room() -> void:
	for p in WardrobeCatalog.all_pieces():
		if ROOM_SOURCES.has(p.source):
			Gameplay.wardrobe.grant(p.id)


static func _outfits(feyre: Feyre) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Outfits"
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id in Gameplay.wardrobe.owned_pieces():
		var p := WardrobeCatalog.piece(id)
		if p == null:
			continue
		var b := UiStyle.button(p.display_name)
		b.icon = _swatch(p.color)
		b.tooltip_text = "%s\n%s" % [", ".join(PackedStringArray(p.slots)), p.description]
		b.pressed.connect(func() -> void:
			Gameplay.wardrobe.equip(id)
			Juice.burst(feyre, &"outfit"))
		grid.add_child(b)
	return scroll


static func _hair(feyre: Feyre) -> Control:
	var grid := GridContainer.new()
	grid.name = "Hair"
	grid.columns = 3
	for h in WardrobeCatalog.all_hair():
		var b := UiStyle.button(h.display_name)
		b.pressed.connect(func() -> void:
			Gameplay.wardrobe.set_hair(h.id)
			Juice.burst(feyre, &"outfit"))
		grid.add_child(b)
	return grid


static func _makeup(feyre: Feyre) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Makeup"
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	for channel in MakeupData.CHANNELS:
		col.add_child(UiStyle.label(String(channel).replace("_", " ").capitalize(), 18))
		var row := HFlowContainer.new()
		col.add_child(row)
		var none := UiStyle.button("None")
		none.pressed.connect(func() -> void: Gameplay.wardrobe.clear_makeup(channel))
		row.add_child(none)
		for m in WardrobeCatalog.all_makeup():
			if m.channel != channel:
				continue
			var b := UiStyle.button(m.display_name)
			b.icon = _swatch(m.color)
			b.pressed.connect(func() -> void:
				Gameplay.wardrobe.apply_makeup(m.id)
				Juice.burst(feyre, &"outfit"))
			row.add_child(b)
	return scroll


## The vanity mirror view: a camera in front of Feyre, framing face and dress.
static func _enter_vanity(feyre: Feyre) -> void:
	_vanity = Camera3D.new()
	_vanity.name = "VanityCamera"
	_vanity.fov = 40.0
	_vanity.process_mode = Node.PROCESS_MODE_ALWAYS
	feyre.get_parent().add_child(_vanity)
	var front := -feyre.model.global_basis.z
	var eye := feyre.global_position + Vector3.UP * 1.25 + front * 2.3
	_vanity.look_at_from_position(eye, feyre.global_position + Vector3.UP * 1.05)
	_vanity.current = true


static func _swatch(color: Color) -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

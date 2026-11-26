## Tending the white mare (docs/contracts/mare_bond.md; the screen is the UI
## lane's, on the open tin since the owner picked it, 2026-11-26): T (her own
## key) beside her and the camera draws round to her side, the side Feyre is
## not standing on, with the mare in the middle of the picture. Her paint tin
## opens along the foot of the screen (OpenTin) and everything above it is
## hers: stroke her coat with the brush (hold the mouse, or A and the stick)
## and it comes up gleaming, with sparkles and a soft rising chime where the
## brush passes. In the tin: her coat and her bond as the same meters the
## Bonds page draws, then two groups of pans, Care (brush and treats, her own
## page) and Dress her (one pan per MareTack slot), and under them what the
## chosen pan holds, in wells. Treats are the satchel's own pictures; a
## dress-up piece shows its colours as enamel swatches and what making it
## takes as pictures. Her page stands up on the tin's lid. Every change
## sparkles, chimes and makes her toss her head (R3). The world keeps
## turning; Feyre stands by her. Esc, T, E or Done to leave.
class_name MareTendingView
extends Control

signal closed

const CAMERA_OUT := 5.6
const CAMERA_AHEAD := 0.2
const CAMERA_UP := 1.55
## How high on her the camera aims (m): low, so she stands in the upper part
## of the frame and her hooves clear the tin.
const CAMERA_AIM := 0.6
## Pad brushing: stick travel per second while A is held, in screen widths.
const PAD_BRUSH := 1.6
## The pans that are not a dress-up slot: brush and treats, and her page
## (MarePage: what Feyre knows of her, what to try, what she remembers).
const CARE := &"care"
const HER := &"her"
const TAB_NAMES := {CARE: "Brush and treats", HER: "Her"}
## The tin's left compartment (her meters at their one size, with the
## longest word a coat has), and the lid her page stands on.
const LEFT_WIDTH := 470.0
const LID_WIDTH := 372.0
## The row under the pans: how tall, and how wide a piece's well is (six fit).
const BODY_HEIGHT := 150.0
const WELL_WIDTH := 208.0
const WELL_GAP := 10
## How far a group's name sits into the room its pans keep for standing proud.
const GROUP_TUCK := -12
## A colour swatch on a piece, and a making's picture.
const SWATCH := 30.0
const NEED_ICON := 18.0
## A piece of several colours: each bead, and how far the next laps over it.
const BEAD := 22.0
const BEAD_LAP := -9
## How to brush, by the device she last used.
const BRUSH_MOUSE := "I hold the mouse on her and stroke to brush her coat."
const BRUSH_PAD := "I hold A and move the stick over her to brush her coat."
## The brush under the pointer, and the chime as it strokes: how often, how
## quiet, and how far its pitch climbs as her coat comes up.
const BRUSH_SIZE := 64.0
const CHIME_GAP := 0.42
const CHIME_DB := -20.0
const CHIME_PITCH := Vector2(0.9, 1.5)

var mare: MareMount
var feyre: Node3D
var inventory: Inventory
var camera: Camera3D
var tin: OpenTin
var _prev_camera: Camera3D
var _tab: StringName = CARE
var _tabs: Dictionary = {}  # tab id -> OpenTin.Pan
var _body: HBoxContainer
var _meters: VBoxContainer
var _coat: HBoxContainer
var _brushing: bool = false
var _brush_at: Vector2 = Vector2.ZERO
var _sparkles: CPUParticles2D
var _chime: AudioStreamPlayer
var _since_stroke: float = 99.0
var _since_chime: float = 99.0
var _last_applied: float = -1.0


## Opens the screen over `parent` for `mare`. Feyre stands still while it's open.
static func open(parent: Node, p_mare: MareMount, p_feyre: Node3D, p_inventory: Inventory) -> MareTendingView:
	var layer := CanvasLayer.new()
	layer.name = "MareTending"
	parent.add_child(layer)
	var v := MareTendingView.new()
	v.mare = p_mare
	v.feyre = p_feyre
	v.inventory = p_inventory
	layer.add_child(v)
	return v


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame_camera()
	if feyre:
		feyre.set_physics_process(false)
		if feyre is CharacterBody3D:
			(feyre as CharacterBody3D).velocity = Vector3.ZERO
	# The mare keeps moving under the brush, so the game is not paused.
	ScreenStack.push(self, ScreenStack.Flag.MOUSE)
	var layer := get_parent() as CanvasLayer
	if layer:
		layer.layer = ScreenStack.layer_of(self)
	_build()
	_sparkles = _make_sparkles()
	add_child(_sparkles)
	_chime = AudioStreamPlayer.new()
	_chime.stream = Juice.chime(&"pickup")
	_chime.volume_db = CHIME_DB
	add_child(_chime)
	_show(_tab)
	tin.settle()


## Esc or B while the tending screen is the top screen.
func screen_cancel() -> void:
	close()


## The chosen pan takes the focus, so a pad starts on it.
func screen_focus() -> void:
	if _tabs.has(_tab):
		(_tabs[_tab] as Button).grab_focus()


func close() -> void:
	ScreenStack.pop(self)
	if camera and is_instance_valid(camera):
		camera.current = false
		camera.queue_free()
	if _prev_camera and is_instance_valid(_prev_camera):
		_prev_camera.current = true
	if feyre and is_instance_valid(feyre):
		feyre.set_physics_process(true)
	closed.emit()
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.queue_free()
	else:
		queue_free()


# ------------------------------------------------------------------ camera

## From her side, the one Feyre is not on, so Feyre never stands between the
## camera and the mare; she stands in the middle, above the tin.
func _frame_camera() -> void:
	if mare == null:
		return
	_prev_camera = get_viewport().get_camera_3d()
	camera = Camera3D.new()
	camera.name = "MareTendingCamera"
	camera.fov = 42.0
	mare.get_parent().add_child(camera)
	var side := -mare.global_basis.x
	if feyre and (feyre.global_position - mare.global_position).dot(side) > 0.0:
		side = -side
	var fwd := -mare.global_basis.z
	var at := mare.global_position + fwd * CAMERA_AHEAD + Vector3.UP * CAMERA_AIM
	camera.look_at_from_position(at + side * CAMERA_OUT + Vector3.UP * (CAMERA_UP - CAMERA_AIM), at)
	camera.current = true


# ------------------------------------------------------------------ layout

func _build() -> void:
	tin = OpenTin.lay(self)
	var left := tin.compartment(LEFT_WIDTH)
	OpenTin.head(left, "Tending her")
	_meters = VBoxContainer.new()
	_meters.add_theme_constant_override(&"separation", 6)
	left.add_child(_meters)
	left.add_child(BookKit.spring())
	var done := OpenTin.hint_button(KeyPrompt.key(&"interact_alt"), "Done")
	done.name = "Done"
	done.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	done.pressed.connect(close)
	left.add_child(done)
	var main := tin.compartment(0.0, 4)
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override(&"separation", 0)
	main.add_child(groups)
	groups.add_child(_pan_group("Care", [CARE, HER]))
	groups.add_child(OpenTin.rule())
	groups.add_child(_pan_group("Dress her", MareTack.SLOTS))
	_body = HBoxContainer.new()
	_body.name = "Body"
	_body.custom_minimum_size.y = BODY_HEIGHT
	_body.add_theme_constant_override(&"separation", WELL_GAP)
	main.add_child(_body)


static func tab_name(tab: StringName) -> String:
	return String(TAB_NAMES.get(tab, MareTack.SLOT_NAMES.get(tab, "")))


## A group of pans under its name.
func _pan_group(title: String, ids: Array) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.add_theme_constant_override(&"separation", GROUP_TUCK)
	group.add_child(OpenTin.section(title))
	var pans := HBoxContainer.new()
	pans.add_theme_constant_override(&"separation", 0)
	group.add_child(pans)
	for id: StringName in ids:
		var pan := OpenTin.pan(BookKit.picture(Icons.texture(Icons.TEND, id), Vector2.ZERO), tab_name(id))
		pan.name = String(id)
		pan.wash = _tabs.size()
		pan.pressed.connect(_show.bind(id))
		_tabs[id] = pan
		pans.add_child(pan)
	return group


func _show(tab: StringName) -> void:
	_tab = tab
	for id: StringName in _tabs:
		(_tabs[id] as OpenTin.Pan).choose(id == tab)
	tin.name_pan(_tabs[tab])
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_refresh_meters()
	if tab == HER:
		_build_page()
		return
	tin.drop_lid()
	if tab == CARE:
		_build_care()
	else:
		_build_slot(tab)


## The pan `by` places along from the chosen one (LB and RB on a pad).
func step(by: int) -> void:
	var ids := _tabs.keys()
	var to: StringName = ids[posmod(ids.find(_tab) + by, ids.size())]
	_show(to)
	(_tabs[to] as Button).grab_focus()


## Her coat and her bond, as the meters the Bonds page draws.
func _refresh_meters() -> void:
	for c in _meters.get_children():
		_meters.remove_child(c)
		c.queue_free()
	_coat = MeterRow.on_tin(MeterRow.make(Icons.texture(Icons.TEND, CARE), "Coat", &"SatchelMeter", MareCare.shine(), 1.0, _coat_word()))
	_coat.name = "Coat"
	_meters.add_child(_coat)
	for m in BondBook.measures(BondBook.get_bond(BondBook.MARE)):
		if m.id == BondBook.CLOSENESS:
			_meters.add_child(MeterRow.on_tin(MeterRow.of_measure(m)))


func _coat_word() -> String:
	var s := MareCare.shine()
	return "Gleaming" if s >= 1.0 else ("Dull" if s < 0.05 else "Coming up lovely")


func _refresh_shine() -> void:
	if _coat:
		(_coat.get_node("Meter") as ProgressBar).value = MareCare.shine()
		(_coat.get_node("Word") as Label).text = _coat_word()


func _build_care() -> void:
	var brushing := OpenTin.well()
	brushing.name = "Brushing"
	brushing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	brushing.add_child(col)
	var heading := BookKit.label("Brushing", &"PageSection")
	heading.uppercase = true
	col.add_child(heading)
	col.add_child(BookKit.label(BRUSH_PAD if SatchelHud.pad_active else BRUSH_MOUSE, &"ThoughtText", true))
	_body.add_child(brushing)
	var treats := VBoxContainer.new()
	treats.add_theme_constant_override(&"separation", 6)
	_body.add_child(treats)
	var have := MareCare.treats_in(inventory)
	if MareCare.full():
		treats.add_child(OpenTin.words("She has had her fill today. She noses my hand anyway."))
	elif have.is_empty():
		treats.add_child(OpenTin.words("Nothing sweet in the satchel. These are what she likes:"))
	else:
		treats.add_child(OpenTin.section("Treats"))
	var pans := HBoxContainer.new()
	pans.name = "Treats"
	pans.add_theme_constant_override(&"separation", 6)
	treats.add_child(pans)
	for row: Array in have:
		var pan := _treat(row[0], int(row[1]))
		pan.disabled = MareCare.full() and row[0] != MareCare.HONEYPLUM
		pan.pressed.connect(_feed.bind(row[0], pan))
		pans.add_child(pan)
	if have.is_empty() and not MareCare.full():
		for id in MareCare.TREATS:
			if Icons.has(Icons.ITEMS, Icons.item_key(id)):
				var wished := _treat(id, 0)
				wished.wished = true
				pans.add_child(wished)
	if MareBond.done(&"balked") and not MareBond.balmed():
		_body.add_child(_card_balm())


## A treat: the satchel's picture of it in a small pan, how many, and its name.
func _treat(id: StringName, count: int) -> OpenTin.Pan:
	var pan := OpenTin.pan(Icons.item(SatchelEntries.item_entry(inventory, id, &""), OpenTin.Pan.ICON_SMALL),
			MareTack._item_name(id), true)
	pan.name = String(id)
	pan.wash = MareCare.TREATS.find(id)
	if count > 0:
		pan.count("×%d" % count)
	return pan


## The sweetbalm: masks the smell of the blight so she'll carry Feyre in (MareBond).
func _card_balm() -> Control:
	var card := OpenTin.well()
	card.name = "Balm"
	card.custom_minimum_size.x = WELL_WIDTH * 1.5
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	card.add_child(col)
	col.add_child(BookKit.label("Sweetbalm", &"SatchelBody", true))
	col.add_child(BookKit.label("Rubbed on her muzzle, so the grey ground smells of nothing.", &"SatchelSmall", true))
	for id in MareBond.BALM_NEEDS:
		col.add_child(_need(String(id), MareTack._item_name(id), inventory.count(id) if inventory else 0, 1))
	var b := _press("Make it and put it on")
	b.disabled = not MareBond.can_make_balm(inventory)
	b.pressed.connect(func() -> void:
		if MareBond.put_balm(inventory):
			Juice.burst(mare, &"craft")
			if mare:
				mare.nicker()
			_show(_tab))
	col.add_child(BookKit.spring())
	col.add_child(b)
	return card


## Her page, in Feyre's hand (MarePage), on the tin's lid.
func _build_page() -> void:
	var page := tin.lid(LID_WIDTH)
	page.add_child(BookKit.section("What I know of her"))
	page.add_child(BookKit.label(MarePage.now_line(), &"SatchelBody", true))
	var after := MarePage.after_line()
	if after != "":
		page.add_child(BookKit.section("What I mean to try"))
		page.add_child(BookKit.label(after, &"SatchelBody", true))
		for h in MarePage.hints_shown():
			page.add_child(BookKit.label(h, &"SatchelSmall", true))
		var think := _press("Think on it")
		think.disabled = not MarePage.can_think()
		think.pressed.connect(func() -> void:
			MarePage.think()
			_show(_tab))
		page.add_child(think)
	var kept := MarePage.memories()
	if not kept.is_empty():
		page.add_child(BookKit.section("Remembered"))
		for m in kept:
			page.add_child(BookKit.label(m, &"SatchelSmall", true))


## A slot's pieces, one well each in a row; more than fit scroll sideways.
func _build_slot(slot: StringName) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_body.add_child(scroll)
	var wells := HBoxContainer.new()
	wells.name = "Pieces"
	wells.add_theme_constant_override(&"separation", WELL_GAP)
	scroll.add_child(wells)
	var now := MareTack.worn_in(slot)
	if slot == &"tack" and MareBond.can_ride_bareback():
		wells.add_child(_card_saddle())
	if slot in MareTack.OPTIONAL:
		wells.add_child(_card_none(slot, now == null))
	for p in MareTack.in_slot(slot):
		wells.add_child(_card(p, now != null and now.id == p.id))


## A bead of enamel in `color` with the gold rim the icons have.
static func swatch(color: Color, px: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := BookKit.picture(Icons.texture(Icons.TEND, &"swatch_fill"), Vector2(px, px))
	fill.modulate = color
	holder.add_child(fill)
	holder.add_child(BookKit.picture(Icons.texture(Icons.TEND, &"swatch_rim"), Vector2(px, px)))
	return holder


## One thing a making takes: its picture (an item) or the slot's own (a kind
## of bloom or cord), its name, and how many she has of how many it needs. A
## making she is short of is written in the danger ink.
func _need(key: String, label: String, have: int, need: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 4)
	var id := StringName(key)
	if not key.begins_with("tag:") and Icons.has(Icons.ITEMS, Icons.item_key(id)):
		line.add_child(BookKit.picture(Icons.texture(Icons.ITEMS, Icons.item_key(id)), Vector2(NEED_ICON, NEED_ICON)))
	else:
		line.add_child(BookKit.picture(Icons.texture(Icons.TEND, &"brow"), Vector2(NEED_ICON, NEED_ICON)))
	var said := BookKit.label("%s %d/%d" % [label, mini(have, need), need], &"SatchelLack" if have < need else &"SatchelSmall", true)
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(said)
	return line


## A well for one thing in a slot, and the column to write in it.
func _well(chosen: bool = false) -> Array:
	var card := OpenTin.well(chosen)
	card.custom_minimum_size.x = WELL_WIDTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	card.add_child(col)
	return [card, col]


## The one thing a well does, at its foot.
func _press(text: String) -> Button:
	var b := OpenTin.button(text)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


func _card(p: MareDecor, wearing: bool) -> Control:
	var made := _well(wearing)
	var card := made[0] as PanelContainer
	var col := made[1] as VBoxContainer
	card.name = String(p.id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	col.add_child(row)
	if p.colors.is_empty():
		row.add_child(BookKit.picture(Icons.texture(Icons.TEND, p.slot), Vector2(SWATCH, SWATCH)))
	elif p.colors.size() == 1:
		row.add_child(swatch(p.colors[0], SWATCH))
	else:
		# Several colours are strung like beads, so the name keeps its room.
		var beads := HBoxContainer.new()
		beads.add_theme_constant_override(&"separation", BEAD_LAP)
		beads.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for c in p.colors:
			beads.add_child(swatch(c, BEAD))
		row.add_child(beads)
	var name := BookKit.label(p.display_name, &"SatchelBody", true)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	if p.blurb != "":
		col.add_child(BookKit.label(p.blurb, &"SatchelSmall", true))
	if wearing:
		var worn := BookKit.ribbon("on her")
		worn.name = "OnHer"
		worn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(BookKit.spring())
		col.add_child(worn)
		col.add_child(BookKit.label("She's wearing it", &"SatchelWhere", true))
		return card
	var b: Button
	if MareTack.owned(p.id):
		b = _press("Put it on her")
		b.pressed.connect(_wear.bind(p))
	else:
		var needs := MareTack.needs(p, inventory)
		var keys := p.inputs.keys()
		for i in needs.size():
			col.add_child(_need(String(keys[i]), String(needs[i][0]), int(needs[i][1]), int(needs[i][2])))
		b = _press("Make it")
		b.disabled = not MareTack.can_make(p, inventory)
		b.pressed.connect(_make.bind(p))
	col.add_child(BookKit.spring())
	col.add_child(b)
	return card


## Once she trusts Feyre (MareBond), the saddle can come off: bareback (L47-8, canon ch 20).
func _card_saddle() -> Control:
	var made := _well()
	var col := made[1] as VBoxContainer
	(made[0] as Control).name = "Saddle"
	var on := MareTack.saddled()
	col.add_child(BookKit.label("Saddle", &"SatchelBody", true))
	col.add_child(BookKit.label("She'll carry me without it now." if on else "Just her back and my knees.", &"SatchelSmall", true))
	var b := _press("Ride bareback" if on else "Saddle her")
	b.pressed.connect(func() -> void:
		MareTack.set_saddled(not MareTack.saddled())
		_apply(true)
		_show(_tab))
	col.add_child(BookKit.spring())
	col.add_child(b)
	return made[0]


func _card_none(slot: StringName, bare: bool) -> Control:
	var made := _well()
	var col := made[1] as VBoxContainer
	(made[0] as Control).name = "Nothing"
	col.add_child(BookKit.label("Nothing", &"SatchelBody", true))
	var b := _press("Bare" if bare else "Take it off")
	b.disabled = bare
	b.pressed.connect(func() -> void:
		MareTack.take_off(slot)
		_apply(true)
		_show(_tab))
	col.add_child(BookKit.spring())
	col.add_child(b)
	return made[0]


# ------------------------------------------------------------------ deeds

func _wear(p: MareDecor) -> void:
	if MareTack.wear(p):
		_apply(true)
		_show(_tab)


func _make(p: MareDecor) -> void:
	if MareTack.make(p, inventory):
		MareTack.wear(p)
		_apply(true)
		Juice.burst(mare, &"craft")
		_show(_tab)


func _feed(id: StringName, button: Button) -> void:
	if not MareCare.feed(id, inventory):
		return
	Juice.burst(mare, &"pickup")
	if mare and mare.horse and mare.horse.animator:
		mare.horse.animator.nibble()
	if mare:
		mare.nicker()
	if button:
		Juice.bounce_control(button)
	_show(_tab)


## Re-lays her look; `celebrate` adds the dress-up sparkle, chime and a toss of her head.
func _apply(celebrate: bool) -> void:
	if mare and mare.horse:
		MareSaddle.set_saddled(mare.horse, MareTack.saddled())
		MareLook.apply(mare.horse, MareTack.outfit(), MareCare.shine())
		_last_applied = MareCare.shine()
		if celebrate:
			Juice.burst(mare, &"outfit")
			Juice.bounce(mare.horse.model, 0.06)
			mare.nicker()


# ------------------------------------------------------------------ brushing

## Everything the tin, its lid and its slip leave clear is hers to brush.
func _over_mare(at: Vector2) -> bool:
	return not tin.covers(at)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_brushing = (event as InputEventMouseButton).pressed and _over_mare((event as InputEventMouseButton).position)
		_brush_at = (event as InputEventMouseButton).position
		accept_event()
	elif event is InputEventMouseMotion:
		_brush_at = (event as InputEventMouseMotion).position
		if _brushing and _over_mare(_brush_at):
			_stroke((event as InputEventMouseMotion).relative.length() / maxf(size.x, 1.0))
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact_alt") or event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		close()
		return
	if MenuTab.pad_pressed(event, JOY_BUTTON_LEFT_SHOULDER) or MenuTab.pad_pressed(event, JOY_BUTTON_RIGHT_SHOULDER):
		get_viewport().set_input_as_handled()
		step(-1 if (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
		return
	# Nothing else reaches the game while she's being tended; ScreenStack
	# still hears Esc.
	if ScreenStack.answers(event):
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_since_stroke += delta
	_since_chime += delta
	if _sparkles and _sparkles.emitting and _since_stroke > 0.15:
		_sparkles.emitting = false
	# Pad: hold A and move the stick to brush.
	var stick := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if Input.is_joy_button_pressed(0, JOY_BUTTON_A) and stick.length() > 0.2:
		if _brush_at == Vector2.ZERO:
			_brush_at = Vector2(size.x * 0.5, tin.clear_height() * 0.5)
		_brush_at += stick * delta * size.x * 0.4
		_brush_at.x = clampf(_brush_at.x, 40.0, size.x - 40.0)
		_brush_at.y = clampf(_brush_at.y, 60.0, tin.clear_height() - 40.0)
		_stroke(stick.length() * PAD_BRUSH * delta)
		queue_redraw()


func _stroke(amount: float) -> void:
	if amount <= 0.0:
		return
	var before := MareCare.shine()
	var now := MareCare.brush(amount)
	_since_stroke = 0.0
	if _sparkles:
		_sparkles.position = _brush_at
		_sparkles.emitting = true
	if _chime and _since_chime >= CHIME_GAP and before < 1.0:
		_since_chime = 0.0
		_chime.pitch_scale = lerpf(CHIME_PITCH.x, CHIME_PITCH.y, now)
		_chime.play()
	if absf(now - _last_applied) > 0.04 or (now >= 1.0 and before < 1.0):
		_apply(false)
	if now >= 1.0 and before < 1.0:
		Juice.burst(mare, &"unlock")
		if mare:
			mare.nicker()
	_refresh_shine()


func _draw() -> void:
	if not _over_mare(_brush_at) or _brush_at == Vector2.ZERO:
		return
	# The brush, held by its back above the pointer.
	draw_texture_rect(Icons.texture(Icons.TEND, CARE), Rect2(_brush_at + Vector2(-BRUSH_SIZE * 0.5, -BRUSH_SIZE * 0.8), Vector2(BRUSH_SIZE, BRUSH_SIZE)), false)


func _make_sparkles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 24
	p.lifetime = 0.7
	p.one_shot = false
	p.emitting = false
	p.explosiveness = 0.0
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 60)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	var g := Gradient.new()
	g.colors = PackedColorArray([JournalTheme.color(&"glow"), Color(JournalTheme.wash(0), 0.0)])
	p.color_ramp = g
	return p

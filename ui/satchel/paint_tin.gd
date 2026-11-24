## The quick strap, as her paint tin: a dark tin with the book at its left end
## and four round pans, one per quick slot. A pan is a disc of paper with a
## dab of wash under the thing in it, its key on a chip at the top left and
## how many are left on a chip at the bottom right. A pan hops when it is
## used, stands proud with a gold ring while LB is held, and names what is in
## it for a moment after it is used or pinned. Colours from JournalTheme.
class_name PaintTin
extends Control

const TIN := Vector2(468, 84)
## Room above the tin for a pan's name, with the pan standing proud.
const NAME_ROOM := 38.0
const CORNER := 16.0
const BOOK := Vector2(46, 56)
const BOOK_AT := Vector2(18, 14)
const PAN_START := 136.0
const PAN_STEP := 86.0
const NAME_SECONDS := 2.2

var pans: Array[Pan] = []
## The book at the tin's left end: pickups fly into it.
var book: Control
var book_key: Label

var _name: Label
var _name_left: float = 0.0
var _name_pan: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = TIN + Vector2(0, NAME_ROOM)
	size = custom_minimum_size
	book = Book.new()
	book.position = BOOK_AT + Vector2(0, NAME_ROOM)
	add_child(book)
	book_key = BookKit.slot_badge()
	book_key.position = Vector2(-10, -10)
	book.add_child(book_key)
	for i in QuickBar.SLOTS:
		var pan := Pan.new()
		pan.position = Vector2(PAN_START + PAN_STEP * i - Pan.RADIUS, NAME_ROOM + TIN.y * 0.5 - Pan.RADIUS)
		add_child(pan)
		pans.append(pan)
	_name = BookKit.label("", &"TinName")
	_name.modulate.a = 0.0
	add_child(_name)


## Puts `icon` (or nothing) in pan `i`, with its key and how many are left.
func fill(i: int, icon: Control, count: int, key: String, wash_index: int) -> void:
	pans[i].fill(icon, count, key, wash_index)


## Names what is in pan `i` above it, for a moment.
func name_pan(i: int, text: String) -> void:
	_name.text = text.to_upper()
	_name.reset_size()
	_name_pan = i
	_name_left = NAME_SECONDS if text != "" else 0.0


func _process(delta: float) -> void:
	_name_left = maxf(_name_left - delta, 0.0)
	_name.modulate.a = move_toward(_name.modulate.a, 1.0 if _name_left > 0.0 else 0.0, delta * 5.0)
	if _name_pan >= 0:
		var pan := pans[_name_pan]
		_name.position = name_at(pan)


## Where the name sits: centred over its pan, clear of its rim, and never
## outside the tin's own rect.
func name_at(pan: Pan) -> Vector2:
	var x := clampf(pan.position.x + Pan.RADIUS - _name.size.x * 0.5, 0.0, maxf(size.x - _name.size.x, 0.0))
	return Vector2(x, maxf(pan.position.y - Pan.PROUD - _name.size.y - 4.0, 0.0))


func _draw() -> void:
	var ink := JournalTheme.color(&"ink")
	var line := JournalTheme.color(&"line")
	var box := StyleBoxFlat.new()
	box.bg_color = ink
	box.border_color = line
	box.set_border_width_all(2)
	box.border_width_bottom = 5
	box.set_corner_radius_all(int(CORNER))
	box.anti_aliasing = true
	draw_style_box(box, Rect2(Vector2(0, NAME_ROOM), TIN))
	# The lip of the tin, and the rule between the book and the pans.
	draw_line(Vector2(CORNER, NAME_ROOM + 5), Vector2(TIN.x - CORNER, NAME_ROOM + 5), Color(line, 0.35), 1.0, true)
	var rule_x := BOOK_AT.x + BOOK.x + 14.0
	draw_line(Vector2(rule_x, NAME_ROOM + 16), Vector2(rule_x, NAME_ROOM + TIN.y - 18), Color(line, 0.6), 1.5, true)
	# Her mark, stamped small into the far end.
	WhorlInk.ink_whorl(self, Vector2(TIN.x - 22, NAME_ROOM + 22), 7.0, Color(JournalTheme.color(&"glow"), 0.8), 1.5)


## The book: a closed journal, paper edge and leather spine, with her whorl.
class Book extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = PaintTin.BOOK
		pivot_offset = size * 0.5

	func _draw() -> void:
		var cover := StyleBoxFlat.new()
		cover.bg_color = JournalTheme.color(&"leather")
		cover.border_color = JournalTheme.color(&"line")
		cover.set_border_width_all(2)
		cover.set_corner_radius_all(6)
		cover.anti_aliasing = true
		draw_style_box(cover, Rect2(Vector2.ZERO, size))
		# Pages along the fore edge, and the spine's band.
		draw_rect(Rect2(size.x - 7, 5, 4, size.y - 10), JournalTheme.color(&"paper"))
		draw_line(Vector2(9, 3), Vector2(9, size.y - 3), Color(JournalTheme.color(&"line"), 0.8), 1.5, true)
		WhorlInk.ink_whorl(self, Vector2(size.x * 0.5 + 2, size.y * 0.5), 10.0, JournalTheme.color(&"glow"), 2.0)


## One pan of the tin.
class Pan extends Control:
	const RADIUS := 32.0
	const ICON_PX := 44.0
	## How far a pan stands proud while LB is held.
	const PROUD := 9.0
	## Spring stiffness and damping for the hop.
	const K := 140.0
	const DAMP := 12.0

	## Lit while the pad chord (LB) is held.
	var lit: bool = false:
		set(v):
			lit = v
			queue_redraw()
	var count: int = 0

	var _wash: int = 0
	var _filled: bool = false
	var _icon: Control
	var _key: Label
	var _count: Label
	var _hop: float = 0.0
	var _speed: float = 0.0
	var _proud: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2.ONE * RADIUS * 2.0
		pivot_offset = size * 0.5
		_key = BookKit.slot_badge()
		_key.name = "Key"
		_key.position = Vector2(-8, -8)
		add_child(_key)
		_count = BookKit.count_badge()
		_count.name = "Count"
		add_child(_count)

	func fill(icon: Control, n: int, key: String, wash_index: int) -> void:
		if _icon:
			_icon.queue_free()
		_icon = icon
		_filled = icon != null
		count = n
		_wash = wash_index
		_key.text = key
		_count.visible = _filled
		_count.text = str(n)
		_count.reset_size()
		_count.position = size - _count.size + Vector2(6, 4)
		if icon:
			icon.position = size * 0.5 - Vector2.ONE * ICON_PX * 0.5
			icon.modulate.a = 1.0 if n > 0 else 0.35
			add_child(icon)
			move_child(icon, 0)
		queue_redraw()

	## Sets it hopping; `amount` is in pixels per second, up.
	func kick(amount: float) -> void:
		_speed -= amount

	## How far above its seat it is now (negative is up).
	func rise() -> float:
		return _hop - _proud

	func _process(delta: float) -> void:
		_speed += (-K * _hop - DAMP * _speed) * delta
		_hop += _speed * delta
		_proud = move_toward(_proud, PROUD if lit else 0.0, delta * 60.0)
		var seat := PaintTin.NAME_ROOM + PaintTin.TIN.y * 0.5 - RADIUS
		position.y = seat + rise()

	func _draw() -> void:
		var paper := JournalTheme.color(&"paper")
		var line := JournalTheme.color(&"line")
		var glow := JournalTheme.color(&"glow")
		var c := size * 0.5
		if lit:
			draw_circle(c, RADIUS + 4.0, Color(glow, 0.9), true, -1.0, true)
		draw_circle(c, RADIUS, line, true, -1.0, true)
		draw_circle(c, RADIUS - 2.5, paper if _filled else Color(paper, 0.55), true, -1.0, true)
		if _filled:
			draw_circle(c, RADIUS - 8.0, Color(JournalTheme.wash(_wash), 0.75), true, -1.0, true)

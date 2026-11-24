## The small parts every page of the book is written with: a label, a chip, a
## section heading over its rule, a key cap with its word, the night-sky
## stroke. Looks come from JournalTheme variations only.
class_name BookKit
extends RefCounted


static func label(text: String, variation: StringName, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## The page's name, top of the left sheet.
static func title(text: String) -> Label:
	var l := label(text, &"MenuTitle")
	l.uppercase = true
	return l


## A small heading in brass capitals over a hairline: "FORAGE POUCH".
static func section(text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	var l := label(text, &"PageSection")
	l.name = "Heading"
	l.uppercase = true
	box.add_child(l)
	box.add_child(HSeparator.new())
	return box


## A pill that stays pressed: a pocket, a category, a choice.
static func chip(text: String, toggle: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"SatchelTab"
	b.toggle_mode = toggle
	b.focus_mode = Control.FOCUS_NONE
	return b


## A key cap and what it does: [Esc] Back.
static func key_hint(key: String, word: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.add_child(key_cap(key))
	var l := label(word, &"SatchelSmall")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


static func key_cap(key: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.theme_type_variation = &"SatchelKey"
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(key, &"SatchelKeyLabel")
	l.name = "Key"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


## How many of a thing: "×3" on a round paper chip.
static func count_badge(text: String = "") -> Label:
	return _badge(text, JournalTheme.COUNT_BADGE)


## Which pan of the tin a thing is in, or the key that opens something: a
## small ink key cap.
static func slot_badge(text: String = "") -> Label:
	return _badge(text, JournalTheme.SLOT_BADGE)


## She has not looked at this yet: a gold ribbon that says NEW.
static func new_badge() -> Label:
	var badge := _badge("new", JournalTheme.NEW_BADGE)
	badge.uppercase = true
	return badge


static func _badge(text: String, variation: StringName) -> Label:
	var badge := label(text, variation)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return badge


## The stroke of night sky with its whorls of stars, her own mark, `width` wide.
static func sky(width: float) -> TextureRect:
	return picture(load(BookLayout.SKY), Vector2(width, width * 280.0 / 1222.0))


## A soft blot of watercolour, `px` across, in the nth wash.
static func wash(px: float, i: int) -> TextureRect:
	var r := picture(load(BookLayout.WASH), Vector2(px, px))
	r.modulate = JournalTheme.wash(i)
	return r


static func picture(texture: Texture2D, size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = size
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Fills what is left of a column, pushing the rest to the foot of the sheet.
static func spring() -> Control:
	var c := gap(0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## The first key bound to an action, as its label ("I", "M").
static func key_word(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			return OS.get_keycode_string(code)
	return ""

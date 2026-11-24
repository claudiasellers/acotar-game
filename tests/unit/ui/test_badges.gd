## A thing in her book can wear three badges, and no two look alike (owner,
## 2026-11-24: "new" and the pan number were the same pill): how many is a
## round paper chip, which pan is a small ink key cap, new is a gold ribbon.
extends GutTest


func _box(theme: Theme, v: StringName) -> StyleBoxFlat:
	return theme.get_stylebox(&"normal", v) as StyleBoxFlat


func test_each_badge_has_its_own_fill_and_shape_and_reads_on_it() -> void:
	for act: JournalTheme.Act in JournalTheme.Act.values():
		var theme := JournalTheme.build(act)
		var fills := {}
		var corners := {}
		for v: StringName in JournalTheme.BADGES:
			var box := _box(theme, v)
			assert_not_null(box, "%s has a sheet" % v)
			fills[box.bg_color.to_html()] = v
			corners[box.corner_radius_top_left] = v
			assert_gte(JournalTheme.contrast(theme.get_color(&"font_color", v), box.bg_color), 4.5,
					"act %d: %s reads on its own fill" % [act, v])
			assert_gte(theme.get_font_size(&"font_size", v), 14, "%s is readable" % v)
		assert_eq(fills.size(), 3, "act %d: three fills" % act)
		assert_eq(corners.size(), 3, "act %d: three shapes" % act)
		var c := JournalTheme.colors(act)
		assert_eq(_box(theme, JournalTheme.COUNT_BADGE).bg_color, c[&"paper"])
		assert_eq(_box(theme, JournalTheme.SLOT_BADGE).bg_color, c[&"ink"], "a key cap, like every key")
		assert_eq(_box(theme, JournalTheme.NEW_BADGE).bg_color, c[&"glow"], "gold")


func test_the_kit_makes_each_badge() -> void:
	assert_eq(BookKit.count_badge("×3").theme_type_variation, JournalTheme.COUNT_BADGE)
	assert_eq(BookKit.slot_badge("3").theme_type_variation, JournalTheme.SLOT_BADGE)
	var fresh := BookKit.new_badge()
	assert_eq(fresh.theme_type_variation, JournalTheme.NEW_BADGE)
	assert_eq(fresh.text, "new")
	assert_true(fresh.uppercase)
	for b: Label in [BookKit.count_badge(), BookKit.slot_badge(), fresh]:
		b.free()


## In the satchel a thing wears its pan's key or the ribbon, never both, and
## its count is its own chip.
func test_a_satchel_slot_wears_the_key_or_the_ribbon() -> void:
	var src := FileAccess.get_file_as_string("res://ui/satchel/satchel_menu.gd")
	assert_string_contains(src, "BookKit.count_badge()")
	assert_string_contains(src, "BookKit.slot_badge()")
	assert_string_contains(src, "BookKit.new_badge()")
	assert_string_contains(src, "at < 0 and _new_ids.has(e.id)")


## Nothing writes "new" on any other chip.
func test_new_is_only_ever_the_ribbon() -> void:
	var other := RegEx.create_from_string("label\\(\\s*\"[Nn]ew\"")
	for path in _scripts("res://ui"):
		if path == "res://ui/menu/book_kit.gd":
			continue
		assert_null(other.search(FileAccess.get_file_as_string(path)), "%s writes its own new tag" % path)


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out

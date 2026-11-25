## The one look, kept (docs/contracts/ui-theme.md): no UI script carries a
## colour or a typeface of its own. A colour is a JournalTheme token (with its
## own alpha if it likes), type is a theme variation or JournalTheme.font().
## The only scripts let off are the ones that paint a picture, each named
## here with why.
extends GutTest

const UI := "res://ui"
const THEME_DIR := "res://ui/theme"
## UI pieces that live beside what they serve, outside ui/.
const UI_ELSEWHERE: Array[String] = [
	"res://systems/interaction/press_card.gd",
	"res://systems/bow/quiver_card.gd",
	"res://story/act1/key_prompts.gd",
	"res://story/film/film_skip.gd",
	"res://story/film/opening/film_title_card.gd",
]
const PICTURES := {
	"res://ui/map/map_art.gd": "paints the map's sheet",
	"res://ui/map/map_marks.gd": "the map's painted marks, in the sheet's own paints",
	"res://ui/map/manor_sketch.gd": "her charcoal plan of the manor",
	"res://ui/collection_book/item_icon.gd": "draws an item's picture",
	"res://ui/title/title_backdrop.gd": "a 3D scene: the Wall at dusk",
	"res://ui/satchel/satchel_model.gd": "reads a 3D model's own vertex colours",
}
## A colour written out (numbers, a hex string, a named colour that is not
## the neutral white or clear a modulate starts from), a font file, or a font
## set by hand on one Control.
const OWN_LOOK := "Color\\(\\s*[-0-9.\"]|Color8\\(|Color\\.html\\(|Color\\.(?!WHITE\\b|TRANSPARENT\\b)[A-Z][A-Z_]+\\b|\\.(ttf|otf|woff2?)\"|add_theme_font_override\\("


func test_no_ui_script_carries_a_colour_or_a_typeface_of_its_own() -> void:
	var own := RegEx.create_from_string(OWN_LOOK)
	var files: Array[String] = []
	_scripts(UI, files)
	files.append_array(UI_ELSEWHERE)
	assert_gt(files.size(), 60, "the search really walks ui/")
	var hits: Array[String] = []
	for path in files:
		if PICTURES.has(path):
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		assert_gt(lines.size(), 1, "%s exists" % path)
		for i in lines.size():
			var line := lines[i].strip_edges()
			if not line.begins_with("#") and own.search(line):
				hits.append("%s:%d: %s" % [path, i + 1, line])
	assert_eq(hits, [] as Array[String], ("a colour or font outside JournalTheme (docs/contracts/ui-theme.md). Fix: "
			+ "use a token, JournalTheme.color(&\"ink\") or Color(JournalTheme.color(&\"ink\"), 0.4) for your own "
			+ "alpha; add a new token to JournalTheme if none fits; set type with theme_type_variation or "
			+ "JournalTheme.font(). A script that paints a picture can be listed in PICTURES here, with why."))


func test_every_picture_let_off_is_still_there() -> void:
	for path: String in PICTURES:
		assert_true(FileAccess.file_exists(path), "%s (%s) is gone: take it off the list" % [path, PICTURES[path]])


func test_the_search_knows_a_colour_from_a_token() -> void:
	var own := RegEx.create_from_string(OWN_LOOK)
	for bad in ["Color(1.0, 0.9, 0.8)", "Color( 0, 0, 0, 0.7)", "Color(\"#aabbcc\")", "Color.BLACK", "Color.DARK_RED",
			"Color8(255, 0, 0)", "Color.html(\"fff\")", "preload(\"res://a/b.ttf\")", "l.add_theme_font_override(&\"font\", f)"]:
		assert_not_null(own.search(bad), bad)
	for fine in ["Color(JournalTheme.color(&\"ink\"), 0.5)", "Color(tint, 0.38 * reveal)", "Color.WHITE", "Color.TRANSPARENT",
			"Color.from_hsv(tint.h, tint.s, tint.v)", "JournalTheme.font(\"hand\")", "var colors := PackedColorArray()"]:
		assert_null(own.search(fine), fine)


func _scripts(dir: String, into: Array[String]) -> void:
	if dir == THEME_DIR:
		return
	for sub in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(sub), into)
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			into.append(dir.path_join(file))

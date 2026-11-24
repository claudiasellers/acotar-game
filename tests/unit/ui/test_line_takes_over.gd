## No line is seen through another (docs/contracts/ui-frame.md, "Line voices"):
## a page and the middle share the centre of the screen, and Dread stands alone.
extends GutTest

const V := LinePresenter.Voice
## The most of a line that may still show when another takes its room.
const GONE := 0.05

var lines: LinePresenter


func before_each() -> void:
	lines = LinePresenter.of(get_tree())
	lines.clear()
	get_tree().paused = false
	await _settle()


func after_each() -> void:
	lines.clear()


func _settle() -> void:
	await get_tree().create_timer(LinePresenter.FADE + 0.1).timeout


func test_read_then_whisper_then_dread_never_overlap() -> void:
	lines.say(V.READ, "A tag on the hasp", "For whoever puts an arrow in all three butts.")
	await _settle()
	assert_almost_eq(lines.stand_of(V.READ).modulate.a, 1.0, 0.01, "the page is up")
	lines.say(V.WHISPER, "", "Please. Look at me. I will be gentle.")
	assert_lte(lines.stand_of(V.READ).modulate.a, GONE, "the page is gone as the whisper starts")
	assert_eq(lines.stand_of(V.READ).showing, "")
	await _settle()
	assert_almost_eq(lines.stand_of(V.WHISPER).modulate.a, 1.0, 0.01, "the whisper is up")
	lines.say(V.DREAD, "", "Stay with the High Lord, human.")
	assert_lte(lines.stand_of(V.WHISPER).modulate.a, GONE, "the whisper is gone as the flood starts")
	assert_lte(lines.stand_of(V.READ).modulate.a, GONE)
	assert_eq(lines.stand_of(V.WHISPER).showing, "")
	await _settle()
	assert_lte(lines.stand_of(V.WHISPER).modulate.a, GONE, "and it stays gone")
	assert_almost_eq(lines.stand_of(V.DREAD).modulate.a, 1.0, 0.01)


func test_a_page_taken_up_ends_a_whisper() -> void:
	lines.say(V.WHISPER, "", "Look at me.")
	await _settle()
	lines.say(V.READ, "A note", "Gone to the village.")
	assert_lte(lines.stand_of(V.WHISPER).modulate.a, GONE)


func test_dread_takes_the_page_and_the_lane_is_its_own() -> void:
	lines.say(V.READ, "A note", "Gone to the village.")
	lines.say(V.SAID, "Lucien", "Keep to the path.")
	await _settle()
	lines.say(V.DREAD, "", "Do not go looking for answers.")
	assert_lte(lines.stand_of(V.READ).modulate.a, GONE)
	assert_eq(lines.showing, "Do not go looking for answers.", "the lane holds the new line only")
	assert_eq(lines.voice, V.DREAD)


func test_a_whisper_and_a_spoken_line_stand_together() -> void:
	lines.say(V.SAID, "Lucien", "Don't look at it.")
	await _settle()
	lines.say(V.WHISPER, "", "Look at me.")
	assert_almost_eq(lines.stand_of(V.SAID).modulate.a, 1.0, 0.01, "Lucien is still talking")
	assert_eq(lines.showing, "Don't look at it.")


func test_the_flood_is_black_behind_the_words() -> void:
	var box := lines.stand_of(V.DREAD).get_theme_stylebox(&"panel", &"LineFlood") as StyleBoxTexture
	var img := box.texture.get_image()
	var foot := img.get_pixel(0, img.get_height() - 1)
	# The fade is the top margin, above the sheet; the words sit under it.
	var words := img.get_pixel(0, int(box.get_texture_margin(SIDE_TOP)) + 1)
	assert_gte(words.a, 0.9, "the flood where the words begin")
	assert_gte(foot.a, 0.9)
	# Bone on the flood over white, the worst ground there is.
	var behind := Color.WHITE.lerp(Color(words, 1.0), words.a)
	assert_gte(JournalTheme.contrast(JournalTheme.color(&"bone"), behind), 4.5, "bone on the flood")

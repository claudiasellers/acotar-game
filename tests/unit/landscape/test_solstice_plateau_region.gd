extends GutTest
## F41: the P6 solstice plateau (solstice_dance_floor, world -150, -1060) is
## the Solstice Meadow's, not the Blighted Reaches'. The blight's streaming
## circle (r 1254) and its L-shaped bounding box both swallow the plateau, so
## the region, the grade, the music bed and the ambient lines each have to
## use the macro-map's rectangles.

const PLATEAU := Vector3(-150, 40, -1060)
const CONTENT := "res://data/regions/spring_court/content/%s.tres"

var _grades: Array[Node] = []


func after_each() -> void:
	WorldStreamer.configure([], null)
	for g in _grades:
		g.free()
	_grades.clear()


func test_macro_map_owns_the_plateau_for_the_meadow() -> void:
	assert_eq(CourtMap.region_at(PLATEAU.x, PLATEAU.z), &"solstice_meadow")
	# The dance ring, the musicians' bower and the long tables too.
	for p: Vector2 in [Vector2(-150, -1080), Vector2(-100, -1135), Vector2(-60, -1040)]:
		assert_eq(CourtMap.region_at(p.x, p.y), &"solstice_meadow", str(p))


func test_streamer_puts_the_plateau_in_the_meadow() -> void:
	var regions := DialogueDirector.load_regions()
	var parent := Node3D.new()
	add_child_autofree(parent)
	WorldStreamer.configure(regions, parent)
	var here := WorldStreamer.region_at(PLATEAU)
	assert_not_null(here)
	assert_eq(here.id, &"solstice_meadow", "not the blight's deeper circle")
	# The reaches themselves still read as the reaches.
	assert_eq(WorldStreamer.region_at(Vector3(300, 0, -1595)).id, &"blighted_reaches")
	# Outside the court (the woods, the manor) the circles still decide.
	assert_eq(WorldStreamer.region_at(Vector3(0, 0, 900)).id, &"border_woods")


func test_music_bed_and_ambient_lines_pick_the_meadow() -> void:
	var parent := Node3D.new()
	add_child_autofree(parent)
	WorldStreamer.configure(DialogueDirector.load_regions(), parent)
	var sound := SoundDirector.new()
	add_child_autofree(sound)
	assert_eq(sound.space_at(PLATEAU), &"solstice_meadow")
	var talk := DialogueDirector.new()
	talk.auto_tick = false
	talk.books_dir = ""
	add_child_autofree(talk)
	assert_eq(talk.region_for(PLATEAU), &"solstice_meadow")


func test_blight_grade_stays_out_of_the_plateau() -> void:
	var blight := _grade_for(&"blighted_reaches")
	var meadow := _grade_for(&"solstice_meadow")
	assert_true(blight.bounds.has_point(Vector2(PLATEAU.x, PLATEAU.z)),
		"the L's bounding box does cover the plateau (why rects are needed)")
	assert_false(blight.contains(PLATEAU), "no blight grade on the dance floor")
	assert_true(meadow.contains(PLATEAU))
	assert_ne(meadow.grade, blight.grade)
	assert_true(blight.contains(Vector3(300, 0, -1595)), "the reaches keep their grade")
	# The hill of the rite sits inside the blight's box too.
	assert_false(blight.contains(Vector3(556, 0, -856)))


func _grade_for(id: StringName) -> RegionGrade:
	var region := CourtRegion.new()
	region.content = load(CONTENT % id) as CourtRegionContent
	region._build_grade()
	_grades.append(region)
	return region.get_node(^"RegionGrade") as RegionGrade

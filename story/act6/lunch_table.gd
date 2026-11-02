## Ch26 [C]: a letter from Winter (the blight has killed twenty-four of their
## younglings), then lunch: she is already at the table with Tamlin and
## Lucien when Rhysand comes. The deed is sitting down to lunch at her place
## (E at her chair): it writes fact.lunch_sat_down, and L33's film "The Night
## Court" (the rhysand_visit moment) takes over at once, hiding at the
## curtains included. Hangs on manor_dining_table, the day after the Solstice.
class_name LunchTable
extends Act6Space

const NOON := 12.0 / 24.0


func _init() -> void:
	space_id = &"lunch_table"
	require_flags = PackedStringArray(["solstice_danced"])
	done_flags = PackedStringArray(["fact.lunch_sat_down"])
	day_only = true
	arrive_radius = 9.0


func _ready() -> void:
	super._ready()
	arrive_offset = Vector3(0.0, 0.0, -5.0)


func can_start() -> bool:
	return super.can_start() and day_after("fact.solstice_sunrise_watched")


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			if Clock.time_of_day < NOON - 0.02 or Clock.time_of_day > NOON + 0.1:
				TimeShift.advance_to(NOON)
			cast(&"tamlin", &"tamlin_chair", &"table")
			cast(&"lucien", &"lucien_chair", &"table")
			EventBus.face_requested.emit(&"tamlin", &"grim", 0.6, 12.0)
			StoryControl.release(), "lunch is laid"),
		say(&"tamlin_letter"),
		say(&"lucien_blight"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"chair_prompt"), "her place"),
		press_near(func() -> Vector3: return mark(&"feyre_chair"), 2.4, "E: sit down to lunch"),
		Beats.run(func(_s: SceneSpace) -> void:
			place_feyre(mark(&"feyre_chair"))
			StoryControl.set_mode(StoryControl.Mode.LOOK)
			StoryControl.set_focus(actor(&"tamlin"))
			stamp("fact.lunch_sat_down"), "she sits"),
	]

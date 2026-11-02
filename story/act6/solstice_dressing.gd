## Ch25 [C] (Keeper): the morning of the Summer Solstice the garden is decked
## in ribbons and streamers; Alis: "Summer Solstice. The main celebration
## used to be at the Summer Court... You're going." In the late afternoon Alis
## yanks her upstairs and dresses her: a cornflower-blue chiffon gown, hair
## unbound, a garland of pink, white and blue wildflowers. The deed is the
## dress-up itself (E at the gown Alis holds out: outfit sparkle), then they
## walk through the garden into the fields to the plateau as the sun goes
## down (a fade). Hangs on feyre_bedroom_window. Fact: fact.solstice_dressed.
class_name SolsticeDressing
extends Act6Space

const GOWN := &"outfit_solstice_blue_gown"
const HAIR := &"hair_loose_with_flowers"
## Late afternoon, then the sun's last descent on the plateau.
const AFTERNOON := 17.0 / 24.0
const DUSK := 19.6 / 24.0


func _init() -> void:
	space_id = &"solstice_dressing"
	require_flags = PackedStringArray(["fountain_head_found"])
	done_flags = PackedStringArray(["fact.solstice_dressed"])
	day_only = true
	arrive_radius = 7.0


func _ready() -> void:
	super._ready()
	arrive_offset = Vector3(2.5, 0.0, 11.0)


## A day or more after the head (the Solstice comes while Tamlin rides the border).
func can_start() -> bool:
	return super.can_start() and day_after("fact.fountain_head_seen")


func _build_beats() -> Array:
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"alis", &"alis_tray", &"bed_side")
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(actor(&"alis")), "Alis with news"),
		say(&"ribbons_thought"),
		say(&"alis_solstice"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(null), "free"),
	] + fade_time(AFTERNOON, _gown_out, "the afternoon") + [
		say(&"alis_upstairs"),
		Beats.run(func(_s: SceneSpace) -> void: aside(&"gown_prompt"), "the gown"),
		press_near(func() -> Vector3: return mark(&"gown"), 2.6, "E: the blue gown"),
		Beats.run(_dress, "dressed"),
		say(&"garland_thought"),
		say(&"alis_go_on"),
		Beats.run(func(_s: SceneSpace) -> void: stamp("fact.solstice_dressed"), "ready"),
		say(&"lucien_cauldron"),
	] + fade_time(DUSK, _to_plateau, "through the fields") + [
		say(&"plateau_thought"),
	]


func _gown_out() -> void:
	var alis := actor(&"alis")
	if alis:
		alis.global_position = mark(&"alis_gown")
		alis.look_at(Vector3(mark(&"bed_side").x, alis.global_position.y, mark(&"bed_side").z), Vector3.UP)
	place_feyre(mark(&"bed_side"))


## The gown and the garland, with the outfit sparkle; both stay in her wardrobe.
func _dress(_s: SceneSpace) -> void:
	var w := Gameplay.wardrobe
	w.grant(GOWN)
	w.equip(GOWN)
	w.set_hair(HAIR)
	EventBus.story_item_granted.emit(GOWN, 1)
	EventBus.story_item_granted.emit(HAIR, 1)
	var p := player()
	if p and is_inside_tree():
		Juice.burst(p, &"outfit")


func _to_plateau() -> void:
	dismiss(&"alis")
	go_to(&"solstice_meadow", &"solstice_dance_floor", stage.mark(&"plateau_arrive") if stage else Vector3.ZERO)

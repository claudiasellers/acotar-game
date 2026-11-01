## Alis's welcome, ch6 (Keeper, [C]): Alis (brass bird mask) bathes her and
## cuts her hair; Feyre sits in a white dressing gown. She refuses the velvet
## turquoise dress Alis lays out; her old shirt and pants fell apart in the
## wash, so Alis comes back with trousers and a tunic that fit: a white shirt
## and a dark blue tunic with scratchy gold thread on the lapels. Then dinner.
##
## Hangs on feyre_bedroom_window (Act2Spaces.EXTRA). Starts when she is in her
## room after the arrival. Play: walk to the bath and press E; the tunic goes
## on with the outfit sparkle. Fact: fact.alis_bathed (FirstDinner's gate).
class_name AlisWelcome
extends Act2Space

## Dinner hour (ch7 dinner is in the evening).
const DINNER_HOUR := 20.0 / 24.0
## The closest pieces in the wardrobe to the white shirt and dark blue tunic.
const TUNIC := &"spring_tunic_sky"
const TROUSERS := &"spring_trousers_cream"
const ROOM_RADIUS := 6.0

var bathed: bool = false


func _init() -> void:
	space_id = &"alis_welcome"
	require_flags = PackedStringArray(["fact.manor_arrived"])
	done_flags = PackedStringArray(["fact.alis_bathed"])
	arrive_radius = ROOM_RADIUS


func _ready() -> void:
	super._ready()
	if stage:
		arrive_offset = stage.mark(&"feyre_start")


func _build_beats() -> Array:
	bathed = false
	var presses_at := [0]
	return [
		Beats.run(func(_s: SceneSpace) -> void:
			cast(&"alis", &"alis_spot", &"feyre_start")
			StoryControl.set_mode(StoryControl.Mode.WALK, PackedStringArray(["interact"]))
			StoryControl.set_focus(actor(&"alis")), "Alis waits"),
		say(&"alis_bath_drawn"),
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.set_focus(null), "free to look"),
		reach(&"bath", 2.2),
		Beats.run(func(_s: SceneSpace) -> void:
			presses_at[0] = presses()
			aside(&"bath_prompt"), "at the bath"),
		Beats.until(func() -> bool: return presses() > presses_at[0], "until she steps in"),
	] + fade_time(DINNER_HOUR - 1.0 / 24.0, _bathe, "the bath") + [
		say(&"bath_thought"),
		Beats.run(func(_s: SceneSpace) -> void:
			StoryControl.set_focus(actor(&"alis")), "Alis and the dress"),
		say(&"alis_dress"),
		say(&"feyre_no_dress"),
		say(&"alis_tunic"),
		Beats.run(_dress, "the tunic"),
		say(&"tunic_thought"),
		Beats.raise("fact.alis_bathed"),
		say(&"alis_dinner"),
	] + fade_time(DINNER_HOUR, _down_to_dinner, "down to dinner") + [
		Beats.run(func(_s: SceneSpace) -> void: StoryControl.release(), "dinner"),
	]


func _bathe() -> void:
	bathed = true
	place_feyre(mark(&"after_bath"))
	var alis := actor(&"alis")
	if alis:
		alis.global_position = mark(&"alis_spot")


## Trousers and a tunic, with the outfit sparkle (R3: every change gets it).
func _dress(_s: SceneSpace) -> void:
	var wardrobe := Gameplay.wardrobe
	for piece in [TUNIC, TROUSERS]:
		wardrobe.grant(piece)
		wardrobe.equip(piece)
	var p := player()
	if p and is_inside_tree():
		Juice.burst(p, &"outfit")


func _down_to_dinner() -> void:
	dismiss(&"alis")
	var dining := find_anchor(&"manor_dining_table")
	if dining:
		# Just inside the dining room door, where the dinner scene begins.
		place_feyre(dining.global_position)

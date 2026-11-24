## The in-play screen: every HUD piece sits in a HudLayout zone, the zones
## show by UiMode, and celebrations wait out dread and staged moments.
## Contract: docs/contracts/ui-frame.md.
extends GutTest

## Every script that puts something on the in-play screen.
const PIECES: Array[String] = [
	"res://ui/hud/vitals/vitals_hud.gd", "res://ui/hud/vitals/grab_prompt.gd",
	"res://ui/hud/vitals/edge_fx.gd", "res://ui/hud/vitals/status_row.gd",
	"res://ui/hud/vitals/health_bar.gd", "res://ui/hud/vitals/stamina_bow.gd",
	"res://ui/satchel/satchel_hud.gd", "res://ui/satchel/quick_strap.gd",
	"res://ui/map/world_map_hud.gd", "res://ui/map/minimap.gd", "res://ui/map/pin_marker.gd",
	"res://systems/bow/quiver_card.gd", "res://ui/aim_reticle.gd",
	"res://systems/interaction/press_card.gd", "res://systems/interaction/forage_focus.gd",
	"res://story/act1/key_prompts.gd", "res://story/act1/act1_milestones.gd",
	"res://ui/chemistry/brew_prompt.gd", "res://ui/market/market_prompt.gd",
	"res://ui/collection_book/find_card.gd", "res://ui/guide/guide_journal.gd",
	"res://ui/pause_menu/controls_hint.gd",
]

## The scripts that make those pieces and hand them to HudLayout.
const KEEPERS: Array[String] = [
	"res://ui/hud/vitals/vitals_hud.gd", "res://ui/satchel/satchel_hud.gd", "res://ui/map/world_map_hud.gd",
	"res://systems/bow/quiver_card.gd", "res://systems/bow/bow_controller.gd",
	"res://systems/interaction/press_card.gd", "res://story/act1/key_prompts.gd",
	"res://story/act1/act1_milestones.gd", "res://ui/chemistry/brew_prompt.gd",
	"res://ui/market/market_prompt.gd", "res://ui/collection_book/find_card.gd",
	"res://ui/guide/guide_journal.gd", "res://ui/settings_panel.gd",
]

var hud: HudLayout


func before_each() -> void:
	hud = HudLayout.of(get_tree())
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	FindCard.clear(get_tree())


func after_each() -> void:
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	FindCard.clear(get_tree())


func _cards_on_screen() -> int:
	return get_tree().get_nodes_in_group(FindCard.GROUP).size()


func test_one_layout_on_the_hud_layer() -> void:
	assert_not_null(hud)
	assert_eq(hud.layer, UiLayers.HUD)
	assert_eq((hud.zone(HudLayout.Zone.EDGE).get_parent() as CanvasLayer).layer, UiLayers.EDGE,
			"the edges draw under everything")
	for which: HudLayout.Zone in HudLayout.Zone.values():
		assert_not_null(hud.zone(which), "zone %s" % HudLayout.Zone.keys()[which])
		assert_true(HudLayout.SHOWS.has(which), "zone %s has a row in the table" % HudLayout.Zone.keys()[which])


func test_mode_follows_what_the_game_knows() -> void:
	assert_eq(UiMode.current(get_tree()), UiMode.Mode.PLAY)
	StoryControl.set_mode(StoryControl.Mode.WALK)
	assert_eq(UiMode.current(get_tree()), UiMode.Mode.STAGED)
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	assert_eq(UiMode.current(get_tree()), UiMode.Mode.STAGED)
	StoryControl.set_mode(StoryControl.Mode.NONE)
	assert_eq(UiMode.current(get_tree()), UiMode.Mode.HELD)
	var screen := Control.new()
	add_child_autofree(screen)
	ScreenStack.push(screen, 0)
	assert_eq(UiMode.current(get_tree()), UiMode.Mode.SCREEN, "an open screen wins over the story")
	ScreenStack.pop(screen)
	assert_eq(UiMode.current(get_tree()), UiMode.Mode.HELD)


func test_zones_show_by_mode() -> void:
	await wait_process_frames(2)
	for which: HudLayout.Zone in HudLayout.Zone.values():
		assert_true(hud.zone(which).visible, "%s shows in play" % HudLayout.Zone.keys()[which])
	StoryControl.set_mode(StoryControl.Mode.WALK)
	await wait_process_frames(2)
	assert_false(hud.zone(HudLayout.Zone.STRAP).visible, "no strap in a staged moment")
	assert_false(hud.zone(HudLayout.Zone.VITALS).visible)
	assert_false(hud.zone(HudLayout.Zone.MINIMAP).visible)
	assert_false(hud.zone(HudLayout.Zone.THOUGHT).visible)
	assert_true(hud.zone(HudLayout.Zone.PROMPT).visible, "a scene can still say what E does")
	assert_true(hud.zone(HudLayout.Zone.NOTICE).visible, "chapter cards show over a scene")
	StoryControl.set_mode(StoryControl.Mode.NONE)
	await wait_process_frames(2)
	assert_false(hud.zone(HudLayout.Zone.PROMPT).visible, "no key does anything while she is held")
	var screen := Control.new()
	add_child_autofree(screen)
	ScreenStack.push(screen)
	await wait_process_frames(2)
	for which: HudLayout.Zone in HudLayout.Zone.values():
		if which != HudLayout.Zone.EDGE:
			assert_false(hud.zone(which).visible, "%s hides under a screen" % HudLayout.Zone.keys()[which])
	assert_true(hud.zone(HudLayout.Zone.EDGE).visible, "the edges stay")
	ScreenStack.pop(screen)


func test_a_placed_piece_sits_in_its_zone_and_goes_with_its_keeper() -> void:
	var keeper := Node.new()
	add_child(keeper)
	var piece := Control.new()
	piece.custom_minimum_size = Vector2(120, 40)
	hud.place(piece, HudLayout.Zone.VITALS, keeper)
	await wait_process_frames(2)
	assert_eq(piece.get_parent(), hud.zone(HudLayout.Zone.VITALS))
	var view := get_viewport().get_visible_rect().size
	assert_almost_eq(piece.global_position.x, 56.0, 1.0, "bottom left")
	assert_almost_eq(piece.global_position.y + piece.size.y, view.y - 70.0, 1.0)
	var full := Control.new()
	hud.place(full, HudLayout.Zone.WORLD, keeper)
	await wait_process_frames(2)
	assert_almost_eq(full.size.x, view.x, 1.0, "a WORLD piece gets the whole screen")
	keeper.free()
	await wait_process_frames(2)
	assert_false(is_instance_valid(piece), "freed with its keeper")
	assert_false(is_instance_valid(full))


func test_the_status_row_stops_short_of_the_line_lane() -> void:
	var row := VitalsStatusRow.new()
	add_child_autofree(row)
	var left := HudLayout.CORNERS[HudLayout.Zone.VITALS][1].x + VitalsHud.STATUS_AT.x as float
	for i in VitalsStatusRow.MAX_SHOWN + 1:
		assert_lte(left + row._slot(i).x + VitalsStatusRow.RADIUS, HudLayout.LANE_LEFT, "chip %d" % i)


func test_dread_holds_a_card_and_calm_lets_it_show() -> void:
	EventBus.mood_requested.emit(&"dread", 0.6, 2.0)
	assert_true(hud.dread())
	assert_true(UiMode.quiet(get_tree()))
	FindCard.show_find(get_tree(), &"fact.suriel_home", &"truths")
	await wait_seconds(1.2)
	assert_eq(_cards_on_screen(), 0, "no card while the Suriel is frightening")
	assert_eq(FindCard.pending(), 1, "the card is queued, not dropped")
	EventBus.mood_requested.emit(&"calm", 0.0, 2.0)
	assert_false(UiMode.quiet(get_tree()))
	await wait_seconds(FindCard.RECHECK + 0.2)
	assert_eq(_cards_on_screen(), 1, "the card shows once the dread clears")
	assert_eq(get_tree().get_first_node_in_group(FindCard.GROUP).get_parent(), hud.zone(HudLayout.Zone.NOTICE))


func test_a_staged_moment_holds_cards() -> void:
	StoryControl.set_mode(StoryControl.Mode.LOOK)
	FindCard.note(get_tree(), "Something true.")
	await wait_seconds(0.8)
	assert_eq(_cards_on_screen(), 0)
	StoryControl.set_mode(StoryControl.Mode.FULL)
	await wait_seconds(FindCard.RECHECK + 0.2)
	assert_eq(_cards_on_screen(), 1)


func test_a_held_queue_shows_one_card_at_a_time() -> void:
	EventBus.mood_requested.emit(&"dread", 1.0, 0.5)
	FindCard.note(get_tree(), "one")
	FindCard.note(get_tree(), "two")
	await wait_seconds(1.1)
	EventBus.mood_requested.emit(&"calm", 0.0, 1.0)
	await wait_seconds(FindCard.RECHECK + 0.2)
	assert_eq(_cards_on_screen(), 1, "never two cards stacked after the hold")
	assert_eq(FindCard.pending(), 2)


func test_calm_play_shows_a_card_at_once() -> void:
	FindCard.note(get_tree(), "A rabbit. Something, at least.")
	await wait_frames(2)
	assert_eq(_cards_on_screen(), 1)


## The frame owns each piece's layer, its place on screen and its mode: no
## piece makes a layer, anchors itself to the screen or reads the story's mode
## or the pause to decide whether to show.
func test_no_piece_does_the_frames_job() -> void:
	var banned := RegEx.new()
	banned.compile("CanvasLayer|^\\s*set_anchors_preset\\(|^\\s*set_anchors_and_offsets_preset\\(|StoryControl\\.mode|\\.paused\\b|\\blayer\\s*=")
	for path in PIECES:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		assert_gt(lines.size(), 1, "%s exists" % path)
		for i in lines.size():
			var line := lines[i]
			if line.strip_edges().begins_with("#"):
				continue
			var hit := banned.search(line)
			assert_null(hit, "%s:%d does the frame's job: %s" % [path, i + 1, line.strip_edges()])


func test_every_keeper_hands_its_piece_to_the_layout() -> void:
	for path in KEEPERS:
		assert_true(FileAccess.get_file_as_string(path).contains("HudLayout.of("), "%s places its piece" % path)

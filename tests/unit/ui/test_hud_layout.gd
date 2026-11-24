## The in-play screen: every HUD piece sits in a HudLayout zone, the zones
## show by UiMode. (What waits out dread is in test_pickup_log.gd.)
## Contract: docs/contracts/ui-frame.md.
extends GutTest

## Every script that puts something on the in-play screen.
const PIECES: Array[String] = [
	"res://ui/hud/vitals/vitals_hud.gd", "res://ui/hud/vitals/grab_prompt.gd",
	"res://ui/hud/vitals/edge_fx.gd", "res://ui/hud/vitals/status_row.gd",
	"res://ui/hud/vitals/health_bar.gd", "res://ui/hud/vitals/stamina_bow.gd",
	"res://ui/satchel/satchel_hud.gd", "res://ui/satchel/paint_tin.gd",
	"res://ui/map/world_map_hud.gd", "res://ui/map/minimap.gd", "res://ui/map/pin_marker.gd",
	"res://systems/bow/quiver_card.gd", "res://ui/aim_reticle.gd",
	"res://ui/hud/key_prompt.gd",
	"res://systems/interaction/press_card.gd", "res://systems/interaction/forage_focus.gd",
	"res://story/act1/key_prompts.gd", "res://story/act1/act1_milestones.gd",
	"res://ui/chemistry/brew_prompt.gd", "res://ui/market/market_prompt.gd",
	"res://ui/hud/chapter_heading.gd", "res://ui/hud/pickup_log.gd", "res://ui/guide/guide_journal.gd",
	"res://ui/hud/controls_hint.gd", "res://ui/debug_hud.gd",
]

## The scripts that make those pieces and hand them to HudLayout.
const KEEPERS: Array[String] = [
	"res://ui/hud/vitals/vitals_hud.gd", "res://ui/satchel/satchel_hud.gd", "res://ui/map/world_map_hud.gd",
	"res://systems/bow/quiver_card.gd", "res://systems/bow/bow_controller.gd",
	"res://ui/hud/key_prompt.gd", "res://story/act1/act1_milestones.gd",
	"res://ui/hud/chapter_heading.gd", "res://ui/hud/pickup_log.gd",
	"res://ui/guide/guide_journal.gd", "res://ui/menu/settings_tab.gd", "res://ui/debug_hud.gd",
]

## Pixels between the controls slip and the strap's box, at the least.
const CLEAR_OF_STRAP := 24.0

var hud: HudLayout


func before_each() -> void:
	hud = HudLayout.of(get_tree())
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	ChapterHeading.clear(get_tree())


func after_each() -> void:
	StoryControl.set_mode(StoryControl.Mode.FULL)
	EventBus.mood_requested.emit(&"calm", 0.0, 0.0)
	ChapterHeading.clear(get_tree())


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


## The controls slip sits beside the strap, never under it, at every text size.
func test_the_controls_slip_keeps_clear_of_the_strap() -> void:
	var keeper := Node.new()
	add_child_autofree(keeper)
	var slip := ControlsHint.new()
	hud.place(slip, HudLayout.Zone.CONTROLS, keeper)
	var strap := Control.new()
	strap.custom_minimum_size = SatchelHud.bar_size()
	hud.place(strap, HudLayout.Zone.STRAP, keeper)
	var was := get_tree().root.content_scale_factor
	for scale: float in GameSettings.TEXT_SCALES:
		get_tree().root.content_scale_factor = scale
		slip.show_for(20.0)
		await wait_process_frames(4)
		var a := slip.get_global_rect()
		var b := strap.get_global_rect()
		var apart := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), maxf(a.position.y - b.end.y, b.position.y - a.end.y))
		assert_gte(apart, CLEAR_OF_STRAP, "text scale %.2f: slip %s, strap %s" % [scale, a, b])
		assert_true(get_viewport().get_visible_rect().encloses(a), "and on the screen at %.2f" % scale)
	get_tree().root.content_scale_factor = was


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


## Every CanvasLayer number comes from UiLayers: no script in the game writes
## a bare number into `layer`.
func test_no_script_writes_a_bare_layer_number() -> void:
	var bare := RegEx.new()
	bare.compile("\\blayer\\s*=\\s*-?\\d")
	var hits: Array[String] = []
	_scan("res://", bare, hits)
	assert_eq(hits, [] as Array[String], "bare layer numbers")


func _scan(dir: String, bare: RegEx, hits: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if dir == "res://" and sub in ["addons", "tests", "tools", ".godot", ".git", ".lanes"]:
			continue
		_scan(dir.path_join(sub), bare, hits)
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd") or dir.path_join(file) == "res://ui/frame/ui_layers.gd":
			continue
		var lines := FileAccess.get_file_as_string(dir.path_join(file)).split("\n")
		for i in lines.size():
			if bare.search(lines[i]) and not lines[i].contains("collision_layer"):
				hits.append("%s:%d" % [dir.path_join(file), i + 1])

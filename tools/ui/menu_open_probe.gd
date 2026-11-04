## Times opening each menu page, first open and again, on a stocked satchel
## with Feyre stood on a plain floor. Prints one line per open: the open()
## call, and the slowest of the next frames (the hitch the player sees).
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . \
##     res://tools/ui/menu_open_probe.tscn
## With `-- shots <dir>` it saves one frame of each page in SHOT_PAGES instead.
## (A scene, not a -s script, so the autoloads exist.)
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const STOCK := {
	&"ing_bilberry": 6, &"ing_chanterelle": 3, &"ing_moonflower": 1, &"ing_primrose": 4,
	&"ing_rose_hip": 5, &"ing_hazelnut": 8, &"ing_lavender": 2, &"ing_foxglove": 1,
	&"ing_honey": 1, &"ing_watermint": 3, &"ing_wild_strawberry": 7, &"ing_elderflower": 2,
	&"col_odd_stone": 1, &"col_river_glass": 2, &"col_blue_jay_feather": 1,
	&"col_painted_pebble": 1, &"col_robin_egg_shell": 1, &"arrow_wood": 12, &"ing_crow_feather": 3,
}
const FRAMES_AFTER := 12
const OPENS := 3
const WARM_FRAMES := 120
const SHOT_PAGES: Array[StringName] = [&"collection", &"map", &"satchel", &"wardrobe", &"sketchbook"]

var feyre: Feyre


func _ready() -> void:
	get_tree().create_timer(300.0, true).timeout.connect(func() -> void:
		push_error("menu_open_probe: timed out")
		get_tree().quit(1))
	_go.call_deferred()


func _go() -> void:
	var floor := CSGBox3D.new()
	floor.size = Vector3(40, 1, 40)
	floor.position.y = -0.5
	floor.use_collision = true
	add_child(floor)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	feyre = (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(feyre)
	for id: StringName in STOCK:
		Gameplay.inventory.add(id, STOCK[id])
	_setup()
	# Long enough for the shell's warm-up to finish, as behind the loading veil.
	for i in WARM_FRAMES:
		await get_tree().process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shots":
		await _shots(args[1])
	else:
		for page in _pages():
			for n in OPENS:
				await _time(page, n)
	print("menu_open_probe: done")
	get_tree().quit()


## Override point for the scene under test: what to add before timing.
func _setup() -> void:
	add_child(SettingsPanel.new())
	add_child(StoryJournal.new())
	add_child(WorldMapHud.new())
	add_child(SatchelHud.new())


func _pages() -> Array[StringName]:
	return [&"none", &"satchel", &"wardrobe", &"collection", &"sketchbook", &"map"]


## &"none" times plain frames, the baseline the hitch is read against.
func _open(page: StringName) -> void:
	if page != &"none":
		MenuShell.open_tab(get_tree(), page)


func _close() -> void:
	MenuShell.close_all(get_tree())


func _time(page: StringName, n: int) -> void:
	var t0 := Time.get_ticks_usec()
	_open(page)
	var call_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var frames: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in FRAMES_AFTER:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	# The page's own cost per frame (the last frames) against the worst early one.
	var settled: Array[float] = frames.slice(FRAMES_AFTER - 3)
	settled.sort()
	var steady := settled[1]
	var worst: float = frames.max()
	print("menu_open_probe: %-10s open#%d  call %6.1f ms  worst %6.1f ms  steady %6.1f ms  hitch %6.1f ms" \
			% [page, n + 1, call_ms, worst, steady, maxf(0.0, worst - steady)])
	_close()
	for i in 4:
		await get_tree().process_frame


func _shots(dir: String) -> void:
	for page in SHOT_PAGES:
		_open(page)
		for i in 90:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check_overlap(page)
		var path := dir.path_join("menu_shell_%s.png" % page)
		get_viewport().get_texture().get_image().save_png(path)
		print("menu_open_probe: shot ", path)
		_close()
		for i in 4:
			await get_tree().process_frame


## Prints how far the tab strip reaches into the page's own panels and titles
## (0 = clear): every visible Control of the page smaller than the screen.
func _check_overlap(page: StringName) -> void:
	var shell := MenuShell.of(get_tree())
	var strip := shell.get_node(^"ShellRoot/TabStrip") as Control
	var strip_rect := strip.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	var worst := 0.0
	var who := ""
	for c in shell.current.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or not (ctl is PanelContainer or ctl is Label):
			continue
		var r := ctl.get_global_rect()
		if r.size.y >= screen.y - 1.0 or r.size.x <= 0.0:
			continue
		var hit := r.intersection(strip_rect)
		if hit.size.y > worst:
			worst = hit.size.y
			who = String(ctl.get_path()).get_file()
	print("menu_open_probe: %-10s strip overlap %.0f px %s (screen %s)" % [page, worst, who, screen])

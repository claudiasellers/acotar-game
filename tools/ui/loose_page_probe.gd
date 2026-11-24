## Saves one frame of each loose page (the stations she opens with E): the
## stillroom, a stall, the whorl stones' card and the easel, on a stocked
## satchel with Feyre stood on a plain floor.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --audio-driver Dummy --path . \
##     res://tools/ui/loose_page_probe.tscn -- <dir> [phase]
## (A scene, not a -s script, so the autoloads exist.)
extends Node

const FEYRE := "res://characters/feyre/feyre.tscn"
const STOCK := {
	&"ing_bilberry": 6, &"ing_chanterelle": 3, &"ing_snowdrop": 2, &"ing_primrose": 4,
	&"ing_rose_hip": 5, &"ing_hazelnut": 8, &"ing_lavender": 2, &"ing_hide": 2,
	&"ing_honey": 1, &"ing_watermint": 3, &"ing_wild_strawberry": 7, &"ing_elderflower": 2,
}
const SETTLE_FRAMES := 20


func _ready() -> void:
	get_tree().create_timer(240.0, true).timeout.connect(func() -> void:
		push_error("loose_page_probe: timed out")
		get_tree().quit(1))
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() >= 1 else "user://loose_pages"
	if args.size() >= 2:
		PhaseManager.current_phase = StringName(args[1])
		JournalTheme.apply()
	DirAccess.make_dir_recursive_absolute(dir)
	var floor := CSGBox3D.new()
	floor.size = Vector3(40, 1, 40)
	floor.position.y = -0.5
	floor.use_collision = true
	add_child(floor)
	add_child(DirectionalLight3D.new())
	var feyre := (load(FEYRE) as PackedScene).instantiate() as Feyre
	add_child(feyre)
	for id: StringName in STOCK:
		Gameplay.inventory.add(id, STOCK[id])
	for i in 30:
		await get_tree().process_frame

	var hearth := CookingStation.new()
	hearth.station = load("res://data/stations/stillroom.tres")
	add_child(hearth)
	var brew := BrewMenu.open_for(feyre, hearth)
	brew.toggle(&"ing_snowdrop")
	await _save(dir, "brew")
	brew.close()

	var market := load("res://data/market/market.tres") as MarketSet
	for buyer: MarketBuyer in market.buyers():
		if not buyer.offers(Gameplay.inventory).is_empty():
			var stall := MarketMenu.open_for(get_tree(), buyer)
			await _save(dir, "market")
			stall.close()
			break

	var stones := WhorlStones.defs()
	if stones.size() >= 2:
		var card := WhorlTravelCard.open(get_tree(), stones[0], stones.slice(1, 5))
		await _save(dir, "whorl_card")
		card.close()

	WorldState.set_flag("starlight_pool_found")
	var easel := Node3D.new()
	add_child(easel)
	StudioUi.open(feyre, easel)
	if StudioUi.is_open():
		await _save(dir, "easel")
		StudioUi.close()
	print("loose_page_probe: done")
	get_tree().quit()


func _save(dir: String, label: String) -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/loose_%s.png" % [dir, label])
	print("loose_page_probe: saved ", label)

## In-world shot of brew tells on Feyre (lane L62-2): a glow draught (bright
## motes, cool rime) and a hearth-warm tea (warmth haze), framed at 3/4 from
## the front. Needs a GPU (the Mac: Feyre crashes cloud lavapipe, F46):
##   godot res://tools/chemistry/brew_tells_shot.tscn -- [out.png]
extends Node

const GREYBOX := "res://story/act1/greybox/act1_greybox.tscn"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://brew_tells.png"
	Gameplay.reset()
	var scene := (load(GREYBOX) as PackedScene).instantiate()
	get_tree().root.add_child(scene)
	for i in 60:
		await get_tree().process_frame
	var feyre := get_tree().get_first_node_in_group(&"player") as Feyre
	if feyre == null:
		push_error("brew_tells_shot: no Feyre")
		get_tree().quit(1)
		return
	var still := load("res://data/stations/stillroom.tres") as StationData
	var hearth := load("res://data/stations/hearth.tres") as StationData
	feyre.body_state.eat(Chemistry.combine(_items([&"ing_glowcap", &"ing_moss"]), still, &"distill"))
	feyre.body_state.eat(Chemistry.combine(_items([&"ing_chaga", &"ing_blackberry"]), hearth, &"infuse"))
	var tells := BrewTells.ensure(feyre)
	var cam := Camera3D.new()
	feyre.add_child(cam)
	var model := feyre.model
	var left := model.global_basis.x
	var fwd := -model.global_basis.z
	cam.global_position = feyre.global_position + Vector3.UP * 1.25 + left * 1.3 + fwd * 1.9
	cam.look_at(feyre.global_position + Vector3.UP * 1.1)
	cam.fov = 45.0
	cam.current = true
	for i in 150:
		await get_tree().process_frame
	print("brew_tells_shot: showing ", tells.showing())
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()


func _items(ids: Array) -> Array[IngredientData]:
	var out: Array[IngredientData] = []
	for id in ids:
		out.append(ItemCatalog.get_item(id) as IngredientData)
	return out

## Standalone hunt on the M0 test hill: a doe herd with Andras stalking it,
## hares, ground birds and a wolf pack. The first arrow Feyre looses is her one
## ash arrow. E skins the nearest carcass. Not part of the story flow.
extends Node3D

const HILL := preload("res://world/shared/test_hill/test_hill.tscn")
const HILL_SCRIPT := preload("res://world/shared/test_hill/test_hill.gd")
const DEER := preload("res://creatures/prey/deer.tscn")
const HARE := preload("res://creatures/prey/hare.tscn")
const BIRD := preload("res://creatures/prey/bird.tscn")
const WOLF := preload("res://creatures/wolves/wolf.tscn")
const GREAT_WOLF := preload("res://creatures/wolves/great_wolf.tscn")

const DEMO_WIND := preload("res://creatures/demo/demo_wind.gd")

var hill: Node3D
var andras: GreatWolf
var doe: Prey
var pack: WolfPack
var ash_arrows: int = 1

var _label: Label
var _note_timer: float = 0.0


func _ready() -> void:
	hill = HILL.instantiate()
	add_child(hill)
	add_child(TrackLayer.new())
	if get_tree().get_first_node_in_group(&"wind_source") == null:
		var wind := DEMO_WIND.new()
		wind.name = "DemoWind"
		add_child(wind)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for i in 3:
		var deer := _place(DEER, Vector2(38.0 + i * 3.0, 30.0 - i * 4.0)) as Prey
		if i == 0:
			doe = deer
			doe.name = "Doe"
			doe.add_to_group(&"doe")
	for i in 4:
		_place(HARE, Vector2(rng.randf_range(-30.0, 10.0), rng.randf_range(20.0, 55.0)))
	for i in 6:
		_place(BIRD, Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(40.0, 52.0)))
	pack = WolfPack.new()
	pack.name = "WolfPack"
	add_child(pack)
	pack.global_position = Vector3(-60.0, HILL_SCRIPT.height_at(-60.0, -55.0), -55.0)
	for i in 4:
		var wolf := _place(WOLF, Vector2(-60.0 + i * 2.5, -55.0 + (i % 2) * 2.0)) as Wolf
		pack.register(wolf)
		wolf.pack = pack
	andras = GREAT_WOLF.instantiate() as GreatWolf
	andras.name = "Andras"
	andras.kill_flag = "wolf_killed"
	_put(andras, Vector2(70.0, 10.0))
	var feyre := hill.get(&"feyre") as Node3D
	if feyre and feyre.has_signal(&"arrow_fired"):
		feyre.connect(&"arrow_fired", _on_arrow_fired)
	_build_label()


func _place(scene: PackedScene, xz: Vector2) -> Node3D:
	var node := scene.instantiate() as Node3D
	_put(node, xz)
	return node


func _put(node: Node3D, xz: Vector2) -> void:
	node.position = Vector3(xz.x, HILL_SCRIPT.height_at(xz.x, xz.y) + 0.3, xz.y)
	add_child(node)


## Her one ash arrow, carried since the market (canon: she has only one).
func _on_arrow_fired(arrow: Node3D) -> void:
	if ash_arrows <= 0:
		return
	ash_arrows -= 1
	arrow.set(&"arrow_id", &"ash")
	arrow.set_meta(&"arrow_id", &"ash")
	for child in arrow.get_children():
		if child is MeshInstance3D:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.86, 0.84, 0.78)
			(child as MeshInstance3D).material_override = mat
			break


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact"):
		var feyre := hill.get(&"feyre") as Node3D
		var carcass := Harvestable.nearest(get_tree(), feyre.global_position, 3.0) if feyre else null
		if carcass:
			var names := PackedStringArray()
			for item in carcass.harvest():
				names.append("%s x%d" % [item.item_id, item.qty])
			_note("Harvested: " + ", ".join(names))


func _process(delta: float) -> void:
	_note_timer -= delta
	if _note_timer <= 0.0:
		var andras_state: String = GreatWolf.State.keys()[andras.state] if is_instance_valid(andras) else "-"
		_label.text = "Ash arrows: %d (first shot)   Andras: %s   Pack: %s   E: skin carcass" % [
			ash_arrows, andras_state, WolfPack.Phase.keys()[pack.phase]]


func _note(text: String) -> void:
	_label.text = text
	_note_timer = 3.0


func _build_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_label.position = Vector2(24, 1020)
	_label.add_theme_font_size_override(&"font_size", 20)
	_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	layer.add_child(_label)


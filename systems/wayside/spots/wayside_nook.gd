## A hidden nook [X]: a hollow under an old oak, a gap behind a lilac, a
## ledge under a footbridge. What's in it shows as the item's own little
## model, glinting faintly; interact to take it. A cue nearby pulls her off
## the line without a marker (the Keeper's canon guides): a drooping lilac
## whose cones brush her cheek (ch 9), or a bunting singing (ch 7).
class_name WaysideNook
extends WaysideSpotNode

const LILAC := &"flora_tree_lilac_fae"
const BUNTING := "res://creatures/ambient/scenes/songbird_gold.tscn"

var station_id := &"wayside_nook"
var glints: Array[Node3D] = []


func build() -> void:
	add_to_group(&"station")
	var shell := String(spot.param("shell", ""))
	if shell != "":
		add_model(StringName(shell), Vector3(0.0, 0.0, -0.9), PI * 0.2, float(spot.param("shell_scale", 1.0)))
	match String(spot.param("cue", "")):
		"lilac":
			add_model(LILAC, Vector3(1.8, ground(spot.position.x + 1.8, spot.position.z + 0.6) - spot.position.y, 0.6), 0.7, 0.9)
		"bunting":
			var bird := load(BUNTING) as PackedScene
			if bird:
				var b: Node3D = bird.instantiate()
				b.position = Vector3(0.0, 2.6, 0.0)
				add_child(b)
	if found():
		return
	for i in spot.items.size():
		var id := StringName(spot.items[i])
		var g := add_model(id, Vector3(0.25 * i - 0.25 * (spot.items.size() - 1) * 0.5, 0.06, 0.0), randf() * TAU, 1.0)
		if g:
			glints.append(g)


func use(_user: Node) -> void:
	if found():
		FindCard.note(get_tree(), String(spot.param("empty", "Nothing else tucked away here.")))
		return
	complete()
	for g in glints:
		Juice.bounce(g)
		g.queue_free()
	glints.clear()


func _process(_delta: float) -> void:
	update_prompt()
	var t := Time.get_ticks_msec() * 0.002
	for i in glints.size():
		glints[i].rotation.y = t + i

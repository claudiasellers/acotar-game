## Lets the estate be played on its own before the gameplay lane's interact
## lands: E uses the nearest station or harvests the nearest keepsake/forage.
## Steps aside automatically when the player already has an interact system.
class_name ManorPreviewInteractor
extends Node

const REACH := 2.6

var player: Node3D
var satchel: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not event.is_action_pressed(&"interact"):
		return
	if player.has_method("interact_nearest"):
		return
	var best: Node3D = null
	var best_d := REACH
	for group in [ManorSitePlan.FORAGE_GROUP, ManorStation.GROUP]:
		for n in get_tree().get_nodes_in_group(group):
			var node := n as Node3D
			if node == null or not node.visible:
				continue
			var d := node.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = node
	if best == null:
		for field in get_tree().get_nodes_in_group(ManorSitePlan.FORAGE_FIELD_GROUP):
			var id: StringName = field.pick_nearest(player.global_position, REACH)
			if id != &"":
				_collect(id)
				return
		return
	if best.has_method("harvest"):
		_collect(best.harvest())
	elif best.has_method("use"):
		best.use(player)
		print("[manor] used station %s" % best.get("station_id"))


func _collect(id: StringName) -> void:
	if id == &"":
		return
	satchel[id] = int(satchel.get(id, 0)) + 1
	print("[manor] picked %s (%d)" % [id, satchel[id]])

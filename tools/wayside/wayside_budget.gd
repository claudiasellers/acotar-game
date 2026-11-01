## Wayside draw-call budget (L23): builds every spot once, counts its mesh
## surfaces (one draw call each, shadows not counted), then reports per
## region the worst total for spots live at once (within Wayside.SPAWN_RADIUS
## of any spot in that region).
##   godot --headless res://tools/wayside/wayside_budget.tscn
extends Node

const STREAMER := preload("res://core/streaming/world_streamer.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var w := Wayside.new()
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(w)
	await get_tree().process_frame
	var cost := {}
	for spot in w.spots():
		w._spawn(spot)
		await get_tree().process_frame
		var node: Node = w.live[spot.id]
		cost[spot.id] = _surfaces(node)
		w.live.erase(spot.id)
		node.free()
	var defs := STREAMER.find_region_defs("res://data/regions")
	var worst := {}
	for spot in w.spots():
		var here := Vector2(spot.position.x, spot.position.z)
		var total := 0
		for other in w.spots():
			if here.distance_to(Vector2(other.position.x, other.position.z)) <= Wayside.SPAWN_RADIUS:
				total += int(cost[other.id])
		var region := "none"
		var best := INF
		for def: RegionDef in defs:
			var d := def.edge_distance(spot.position)
			if d <= 0.0 and d < best:
				best = d
				region = String(def.id)
		if total > int(worst.get(region, [0, ""])[0]):
			worst[region] = [total, String(spot.id)]
	var max_spot := 0
	for id in cost:
		max_spot = maxi(max_spot, int(cost[id]))
	print("wayside draw calls: max per spot %d" % max_spot)
	for region in worst:
		print("  %-20s +%3d (worst near %s)" % [region, worst[region][0], worst[region][1]])
	get_tree().quit(0)


func _surfaces(n: Node) -> int:
	var c := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as Node3D).visible:
		c += (n as MeshInstance3D).mesh.get_surface_count()
	for ch in n.get_children():
		c += _surfaces(ch)
	return c

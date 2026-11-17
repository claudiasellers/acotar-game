## Second placement pass for the whorl stones, in the real streamed world:
## loads each pair's region, gathers everything tall standing near it (scatter
## trees and bushes from every MultiMesh, props and buildings from every mesh),
## and moves the pair to the nearest spot that is clear by CLEAR metres, still
## flat (place_whorl_stones' footprint slope) and still in its map place.
## Rewrites data/fast_travel/<id>.tres and prints a report. Run after
## place_whorl_stones.gd, with the levels built (tools/mq/levels.sh ensure):
##   tools/mq/godot.sh res://tools/fast_travel/clear_whorl_stones.tscn
extends Node

const PLACER := preload("res://tools/fast_travel/place_whorl_stones.gd")
const PLACES := "res://data/map/map_places.tres"
## Nothing taller than knee height this close to the pair's middle.
const CLEAR := 5.0
const TALL := 1.0
const SEARCH := 40.0
const NEAR := 60.0
const MAX_SLOPE := 8.0

var _places: MapPlaceSet


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_places = load(PLACES) as MapPlaceSet
	var world := load("res://world/shared/world/world.tscn").instantiate() as World
	get_tree().root.add_child(world)
	WorldStreamer.configure_from_tree("res://data/regions", world.regions)
	var bad := 0
	print("  %-16s %10s %6s %6s %5s  obstacles" % ["id", "at", "moved", "slope", "near"])
	for d in WhorlStones.defs():
		var at := Vector3(d.position.x, WorldHeight.height_at(d.position.x, d.position.y), d.position.y)
		WorldStreamer.update_for(at)
		var f := 0
		while not WorldStreamer.is_ready(d.region_id) and f < 6000:
			await get_tree().process_frame
			f += 1
		for i in 3000:
			await get_tree().process_frame
			if i > 60 and _all_built():
				break
		# Some regions build their scatter late: wait until the count holds.
		var obstacles := _obstacles(d.position)
		for k in 20:
			for i in 120:
				await get_tree().process_frame
			var again := _obstacles(d.position)
			if again.size() == obstacles.size() and (k >= 3 or obstacles.size() > 0):
				break
			obstacles = again
		if OS.get_cmdline_user_args().has("verbose"):
			print("    loaded %s, ready after %d frames" % [WorldStreamer.loaded_ids(), f])
		var best := d.position
		var best_score := INF
		var r := 0.0
		while r <= SEARCH and best_score == INF:
			var n := maxi(1, int(TAU * r / 1.0))
			for i in n:
				var p := d.position + Vector2.from_angle(TAU * i / n) * r
				var place := _places.place_at(p.x, p.y)
				if place == null or place.id != d.place_id:
					continue
				var slope := PLACER.footprint_slope(p, d.yaw_degrees)
				if slope > MAX_SLOPE or _nearest(obstacles, p) < CLEAR:
					continue
				var s := slope + r * 0.2
				if s < best_score:
					best_score = s
					best = p
			r += 1.0
		best = Vector2(snappedf(best.x, 0.5), snappedf(best.y, 0.5))
		var ok := best_score < INF
		if not ok:
			bad += 1
		print("  %-16s %10s %5.1fm %5.1f° %4.1fm  %d%s" % [d.id, "(%d,%d)" % [best.x, best.y], best.distance_to(d.position),
			PLACER.footprint_slope(best, d.yaw_degrees), _nearest(obstacles, best), obstacles.size(), "" if ok else "  <- FAIL"])
		if ok and best != d.position:
			d.position = best
			ResourceSaver.save(d, d.resource_path)
	print("whorl stones cleared: %d failing" % bad)
	get_tree().quit(1 if bad else 0)


func _all_built() -> bool:
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		if n is CourtRegion and not (n as CourtRegion).is_built:
			return false
	return true


## Distance from p to the edge of the nearest obstacle.
func _nearest(obstacles: Array[Vector3], p: Vector2) -> float:
	var best := INF
	for o in obstacles:
		best = minf(best, Vector2(o.x, o.y).distance_to(p) - o.z)
	return best


## Everything tall within NEAR metres, as Vector3(x, z, radius).
func _obstacles(c: Vector2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if n.find_parent("WhorlStone_*") != null:
			continue
		if n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			var ab := mm.mesh.get_aabb()
			for i in mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count:
				var t := mmi.global_transform * mm.get_instance_transform(i)
				var box := t * ab
				if box.size.y < TALL:
					continue
				var o := Vector2(t.origin.x, t.origin.z)
				if o.distance_to(c) < NEAR:
					out.append(Vector3(o.x, o.y, minf(maxf(box.size.x, box.size.z) * 0.25, 2.5)))
		elif n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			var box := mi.global_transform * mi.mesh.get_aabb()
			if box.size.y < TALL or box.size.x > 60.0 or box.size.z > 60.0:
				continue
			var mid := Vector2(box.get_center().x, box.get_center().z)
			if mid.distance_to(c) < NEAR:
				out.append(Vector3(mid.x, mid.y, maxf(box.size.x, box.size.z) * 0.5))
	return out

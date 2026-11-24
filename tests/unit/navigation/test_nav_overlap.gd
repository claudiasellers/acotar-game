## Contract: a baked navmesh never leaves three polygons on one edge (T129);
## the navigation server logs an edge error for that, which fails GUT runs.
extends GutTest


func _mesh(tris: Array) -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.vertices = PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(0.5, 0, -1), Vector3(0.5, 0, 3)])
	for t: Array in tris:
		nm.add_polygon(PackedInt32Array(t))
	return nm


func test_a_third_polygon_on_an_edge_is_dropped() -> void:
	var nm := _mesh([[0, 1, 2], [0, 1, 4], [0, 1, 5]])
	assert_eq(NavBaker.drop_overlapping_polygons(nm), 1, "one of three on edge 0-1 goes")
	assert_eq(nm.get_polygon_count(), 2)


func test_a_clean_mesh_is_untouched() -> void:
	var nm := _mesh([[0, 1, 2], [1, 3, 2]])
	assert_eq(NavBaker.drop_overlapping_polygons(nm), 0)
	assert_eq(nm.get_polygon_count(), 2)

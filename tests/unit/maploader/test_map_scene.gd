extends GdUnitTestSuite
## Covers the tree-free MapScene read API: markers, bounds, and the reserved
## setup hook. Spawn-point world transforms require the tree and live in
## tests/integration/maploader/.


func test_spawn_points_empty_without_container() -> void:
	var map := auto_free(MapScene.new()) as MapScene

	assert_array(map.get_spawn_points()).is_empty()


func test_marker_lookup_returns_named_node3d() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	var markers := auto_free(Node3D.new()) as Node3D
	markers.name = "Markers"
	map.add_child(markers)
	var red_base := auto_free(Marker3D.new()) as Marker3D
	red_base.name = "RedBase"
	markers.add_child(red_base)

	assert_object(map.get_marker(&"RedBase")).is_same(red_base)


func test_marker_lookup_returns_null_for_missing_name() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	var markers := auto_free(Node3D.new()) as Node3D
	markers.name = "Markers"
	map.add_child(markers)

	assert_object(map.get_marker(&"BlueBase")).is_null()


func test_marker_lookup_returns_null_without_markers_container() -> void:
	var map := auto_free(MapScene.new()) as MapScene

	assert_object(map.get_marker(&"RedBase")).is_null()


func test_marker_lookup_ignores_non_node3d_child() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	var markers := auto_free(Node3D.new()) as Node3D
	markers.name = "Markers"
	map.add_child(markers)
	var not_a_marker := auto_free(Node.new()) as Node
	not_a_marker.name = "RedBase"
	markers.add_child(not_a_marker)

	assert_object(map.get_marker(&"RedBase")).is_null()


func test_default_bounds_is_empty() -> void:
	var map := auto_free(MapScene.new()) as MapScene

	assert_bool(map.get_bounds() == AABB()).is_true()


func test_apply_setup_is_noop() -> void:
	var map := auto_free(MapScene.new()) as MapScene

	map.apply_setup({"difficulty": "hard"})
	map.apply_setup({})

	assert_bool(map.get_bounds() == AABB()).is_true()
	assert_object(map.get_marker(&"RedBase")).is_null()

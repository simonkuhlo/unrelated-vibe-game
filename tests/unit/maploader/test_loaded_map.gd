extends GdUnitTestSuite
## Covers the LoadedMap borrowed-handle API: manifest exposure, delegation, and
## tree-free validity checks. The freed-root lifecycle lives in
## tests/integration/maploader/.


class FixedBoundsMapScene:
	extends MapScene

	func get_bounds() -> AABB:
		return AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))


class SetupRecordingMapScene:
	extends MapScene

	var received_configs: Array[Dictionary] = []

	func apply_setup(config: Dictionary) -> void:
		received_configs.append(config)


func test_new_handle_is_invalid() -> void:
	var loaded := LoadedMap.new()

	assert_object(loaded.manifest).is_null()
	assert_object(loaded.root).is_null()
	assert_bool(loaded.is_valid()).is_false()


func test_exposes_manifest() -> void:
	var manifest := MapManifest.new()
	manifest.map_id = &"test_box"
	manifest.version = "1.0.0"
	var loaded := LoadedMap.new()

	loaded.manifest = manifest

	assert_object(loaded.manifest).is_same(manifest)


func test_delegates_marker_lookup() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	var markers := auto_free(Node3D.new()) as Node3D
	markers.name = "Markers"
	map.add_child(markers)
	var red_base := auto_free(Marker3D.new()) as Marker3D
	red_base.name = "RedBase"
	markers.add_child(red_base)
	var loaded := LoadedMap.new()
	loaded.root = map

	assert_object(loaded.get_marker(&"RedBase")).is_same(red_base)


func test_delegates_bounds() -> void:
	var map := auto_free(FixedBoundsMapScene.new()) as FixedBoundsMapScene
	var loaded := LoadedMap.new()
	loaded.root = map

	assert_bool(loaded.get_bounds() == map.get_bounds()).is_true()


func test_delegates_apply_setup() -> void:
	var map := auto_free(SetupRecordingMapScene.new()) as SetupRecordingMapScene
	var loaded := LoadedMap.new()
	loaded.root = map
	var config := {"difficulty": "hard"}

	loaded.apply_setup(config)

	assert_array(map.received_configs).has_size(1)
	assert_dict(map.received_configs[0]).is_equal(config)


func test_is_valid_with_live_root() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	var loaded := LoadedMap.new()
	loaded.root = map

	assert_bool(loaded.is_valid()).is_true()


func test_is_valid_is_false_after_root_is_cleared() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	var loaded := LoadedMap.new()
	loaded.root = map
	assert_bool(loaded.is_valid()).is_true()

	loaded.root = null

	assert_bool(loaded.is_valid()).is_false()

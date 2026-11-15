# Integration tests for MapLoader.
# Cover success, error precedence, signal timing, and state transitions.
@tool
extends GdUnitTestSuite

var _db: MapDB
var _host: Node3D
var _loader: MapLoader


func before_test() -> void:
	_db = MapDB.new()
	_host = Node3D.new()
	add_child(_host)
	_loader = MapLoader.new()
	_loader.map_db = _db
	_loader.map_host = _host
	add_child(_loader)


func after_test() -> void:
	# Ensure anything we added to the tree is gone.
	# Loader.unload() should handle the map root.
	if is_instance_valid(_loader):
		_loader.unload()
		_loader.free()
	if is_instance_valid(_host):
		_host.free()


func _make_valid_packed_scene() -> PackedScene:
	var scene := PackedScene.new()
	var map_scene := MapScene.new()
	var collection := MapMarkerCollection.new()
	collection.name = "Markers"
	map_scene.add_child(collection)
	collection.owner = map_scene
	map_scene.markers = collection
	
	# Add a dummy marker to avoid empty collection warning
	var marker := MapMarker.new()
	collection.add_child(marker)
	marker.owner = map_scene
	
	scene.pack(map_scene)
	map_scene.free()
	return scene


func _make_manifest(id: StringName, display_name: String = "Map") -> MapManifest:
	var manifest := MapManifest.new()
	manifest.id = id
	manifest.display_name = display_name
	manifest.scene = _make_valid_packed_scene()
	# Dummy thumbnail to avoid warning
	manifest.thumbnail = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGB8))
	return manifest


func test_load_success() -> void:
	var m := _make_manifest(&"test_map")
	_db.add_map(m)

	var signal_monitor := monitor_signals(_loader)
	var result := _loader.load_map(&"test_map")

	assert_bool(result.is_ok()).is_true()
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_not_null()
	assert_bool(_loader.is_loaded()).is_true()
	assert_object(_loader.get_loaded_map()).is_equal(result.map)
	assert_int(_host.get_child_count()).is_equal(1)
	assert_object(_host.get_child(0)).is_equal(result.map.get_root())
	assert_bool(result.map.get_root().transform == Transform3D.IDENTITY).is_true()

	# Signal timing: one terminal signal emitted synchronously
	await get_tree().process_frame
	assert_signal(signal_monitor).is_emitted("load_finished", [result])


func test_load_not_found() -> void:
	var signal_monitor := monitor_signals(_loader)
	var result := _loader.load_map(&"non_existent")

	assert_int(result.code).is_equal(MapLoadError.Code.NOT_FOUND)
	assert_bool(_loader.is_loaded()).is_false()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_signal(signal_monitor).is_emitted("load_finished", [result])


func test_load_db_invalid() -> void:
	_loader.map_db = null
	var result := _loader.load_map(&"any")
	assert_int(result.code).is_equal(MapLoadError.Code.DB_INVALID)


func test_load_host_invalid() -> void:
	var m := _make_manifest(&"test_map")
	_db.add_map(m)

	# Host null
	_loader.map_host = null
	var result := _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)

	# Host outside tree
	var orphan_host := Node3D.new()
	_loader.map_host = orphan_host
	result = _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)
	orphan_host.free()

	# Loader descendant of host
	_loader.map_host = _host
	remove_child(_loader)
	_host.add_child(_loader)
	result = _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)


func test_load_host_occupied() -> void:
	var m := _make_manifest(&"test_map")
	_db.add_map(m)
	var child := Node3D.new()
	_host.add_child(child)

	var result := _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_OCCUPIED)
	child.free()


func test_load_already_loaded() -> void:
	var m1 := _make_manifest(&"map1")
	var m2 := _make_manifest(&"map2")
	_db.add_map(m1)
	_db.add_map(m2)

	_loader.load_map(&"map1")
	var result := _loader.load_map(&"map2")

	assert_int(result.code).is_equal(MapLoadError.Code.ALREADY_LOADED)
	assert_object(_loader.get_loaded_map().manifest).is_equal(m1)


func test_load_validation_failure_manifest() -> void:
	var m := _make_manifest(&"invalid")
	m.display_name = "" # ERROR: display_name_missing
	_db.add_map(m)

	var result := _loader.load_map(&"invalid")
	assert_int(result.code).is_equal(MapLoadError.Code.INVALID_MANIFEST)
	assert_bool(MapValidationIssue.has_errors(result.issues)).is_true()


func test_load_validation_failure_scene_missing() -> void:
	var m := _make_manifest(&"no_scene")
	m.scene = null
	_db.add_map(m)

	var result := _loader.load_map(&"no_scene")
	assert_int(result.code).is_equal(MapLoadError.Code.SCENE_MISSING)


func test_load_validation_failure_invalid_scene() -> void:
	var m := _make_manifest(&"bad_root")
	var scene := PackedScene.new()
	var bad_root := Node3D.new()
	scene.pack(bad_root) # Not a MapScene
	bad_root.free()
	m.scene = scene
	_db.add_map(m)

	var result := _loader.load_map(&"bad_root")
	assert_int(result.code).is_equal(MapLoadError.Code.INVALID_SCENE)


func test_load_target_duplicate_blocking() -> void:
	var m1 := _make_manifest(&"dup")
	var m2 := _make_manifest(&"dup")
	_db.add_map(m1)
	_db.add_map(m2)

	var result := _loader.load_map(&"dup")
	assert_int(result.code).is_equal(MapLoadError.Code.INVALID_MANIFEST)
	var has_dup_issue := false
	for issue in result.issues:
		if issue.code == &"duplicate_map_id":
			has_dup_issue = true
			break
	assert_bool(has_dup_issue).is_true()


func test_load_multiple_maps() -> void:
	var target := _make_manifest(&"ok")
	var other := _make_manifest(&"other")
	_db.add_map(target)
	_db.add_map(other)

	var result := _loader.load_map(&"ok")
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(target)


func test_unload() -> void:
	_db.add_map(_make_manifest(&"test"))
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var signal_monitor := monitor_signals(_loader)

	_loader.unload()

	assert_bool(_loader.is_loaded()).is_false()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_bool(handle.is_valid()).is_false()
	assert_signal(signal_monitor).is_emitted("map_unloaded", [handle])

	# Idempotent
	_loader.unload()
	# The signal monitor already has one emission from the first unload.
	# We rely on no new signal being emitted.


func test_external_free_resets_loader_state() -> void:
	_db.add_map(_make_manifest(&"test"))
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var root := handle.get_root()

	root.free()

	assert_bool(_loader.is_loaded()).is_false()
	assert_object(_loader.get_loaded_map()).is_null()

	# Next load should proceed
	var result := _loader.load_map(&"test")
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)


func test_external_detach_resets_loader_state_but_does_not_free() -> void:
	_db.add_map(_make_manifest(&"test"))
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var root := handle.get_root()

	_host.remove_child(root)

	assert_bool(_loader.is_loaded()).is_false()

	# Loader should not free the detached root on next load or unload
	_loader.unload()
	assert_bool(is_instance_valid(root)).is_true()

	root.free()

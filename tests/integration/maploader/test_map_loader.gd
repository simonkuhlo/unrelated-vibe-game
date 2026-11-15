# Integration tests for MapLoader.
# Cover success, error precedence, signal timing, and state transitions.
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


## Counts `load_finished` emissions exactly. gdUnit's `is_emitted()` only
## asserts at-least-once, so synchronous "exactly once" needs a manual counter.
func _track_load_finished() -> Dictionary:
	var tracker := {"count": 0, "result": null}
	_loader.load_finished.connect(func(result: MapLoadResult) -> void:
		tracker["count"] += 1
		tracker["result"] = result
	)
	return tracker


func _track_map_unloaded() -> Dictionary:
	var tracker := {"count": 0, "map": null}
	_loader.map_unloaded.connect(func(map: LoadedMap) -> void:
		tracker["count"] += 1
		tracker["map"] = map
	)
	return tracker


## Loads a map that is expected to log one non-fatal warning and consumes that
## warning so it does not fail the suite. gdUnit reports `push_warning()` as a
## failure when `report/godot/push_error` is enabled.
func _load_expecting_warning(id: StringName) -> MapLoadResult:
	var captured: Array[MapLoadResult] = []
	await assert_error(func() -> MapLoadResult:
		var result := _loader.load_map(id)
		captured.append(result)
		return result
	).is_push_warning(GdUnitArgumentMatchers.any())
	return captured[0]


func test_load_success() -> void:
	var m := _make_manifest(&"test_map")
	_db.add_map(m)

	var tracker := _track_load_finished()
	var result := _loader.load_map(&"test_map")

	assert_bool(result.is_ok()).is_true()
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_not_null()
	assert_int(result.issues.size()).is_equal(0)
	assert_bool(_loader.is_loaded()).is_true()
	assert_object(_loader.get_loaded_map()).is_equal(result.map)
	assert_int(_host.get_child_count()).is_equal(1)
	assert_object(_host.get_child(0)).is_equal(result.map.get_root())
	assert_bool(result.map.get_root().transform == Transform3D.IDENTITY).is_true()

	# `load_finished` is emitted synchronously, exactly once, before returning.
	assert_int(tracker["count"]).is_equal(1)
	assert_object(tracker["result"]).is_equal(result)


func test_load_not_found() -> void:
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"non_existent")

	assert_int(result.code).is_equal(MapLoadError.Code.NOT_FOUND)
	assert_object(result.manifest).is_null()
	assert_object(result.map).is_null()
	assert_int(result.issues.size()).is_equal(0)
	assert_bool(_loader.is_loaded()).is_false()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_load_db_invalid() -> void:
	_loader.map_db = null
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"any")

	assert_int(result.code).is_equal(MapLoadError.Code.DB_INVALID)
	assert_object(result.manifest).is_null()
	assert_object(result.map).is_null()
	assert_int(result.issues.size()).is_equal(0)
	assert_int(_host.get_child_count()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_load_host_invalid() -> void:
	var m := _make_manifest(&"test_map")
	_db.add_map(m)

	# Host null
	_loader.map_host = null
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_null()
	assert_int(result.issues.size()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)

	# Host outside tree
	var orphan_host := Node3D.new()
	_loader.map_host = orphan_host
	tracker = _track_load_finished()
	result = _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)
	assert_int(tracker["count"]).is_equal(1)
	orphan_host.free()

	# Loader descendant of host
	_loader.map_host = _host
	remove_child(_loader)
	_host.add_child(_loader)
	tracker = _track_load_finished()
	result = _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)
	assert_int(tracker["count"]).is_equal(1)

	# Restore the loader's usual place so after_test cleans up normally.
	_host.remove_child(_loader)
	add_child(_loader)
	_loader.map_host = _host


func test_load_host_occupied() -> void:
	var m := _make_manifest(&"test_map")
	_db.add_map(m)
	var child := Node3D.new()
	_host.add_child(child)
	var tracker := _track_load_finished()

	var result := _loader.load_map(&"test_map")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_OCCUPIED)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_null()
	assert_int(result.issues.size()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)
	child.free()


func test_load_already_loaded() -> void:
	var m1 := _make_manifest(&"map1")
	var m2 := _make_manifest(&"map2")
	_db.add_map(m1)
	_db.add_map(m2)

	_loader.load_map(&"map1")
	var handle := _loader.get_loaded_map()
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"map2")

	assert_int(result.code).is_equal(MapLoadError.Code.ALREADY_LOADED)
	assert_object(result.manifest).is_equal(m2)
	assert_object(result.map).is_null()
	assert_int(result.issues.size()).is_equal(0)
	assert_object(_loader.get_loaded_map()).is_equal(handle)
	assert_object(_loader.get_loaded_map().manifest).is_equal(m1)
	assert_int(tracker["count"]).is_equal(1)


func test_load_validation_failure_manifest() -> void:
	var m := _make_manifest(&"invalid")
	m.display_name = "" # ERROR: display_name_missing
	_db.add_map(m)
	var tracker := _track_load_finished()

	var result := _loader.load_map(&"invalid")
	assert_int(result.code).is_equal(MapLoadError.Code.INVALID_MANIFEST)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_null()
	assert_bool(MapValidationIssue.has_errors(result.issues)).is_true()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_load_validation_failure_scene_missing() -> void:
	var m := _make_manifest(&"no_scene")
	m.scene = null
	_db.add_map(m)
	var tracker := _track_load_finished()

	var result := _loader.load_map(&"no_scene")
	assert_int(result.code).is_equal(MapLoadError.Code.SCENE_MISSING)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_null()
	assert_bool(MapValidationIssue.has_errors(result.issues)).is_true()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_load_validation_failure_invalid_scene() -> void:
	var m := _make_manifest(&"bad_root")
	var scene := PackedScene.new()
	var bad_root := Node3D.new()
	scene.pack(bad_root) # Not a MapScene
	bad_root.free()
	m.scene = scene
	_db.add_map(m)
	var tracker := _track_load_finished()

	var result := _loader.load_map(&"bad_root")
	assert_int(result.code).is_equal(MapLoadError.Code.INVALID_SCENE)
	assert_object(result.manifest).is_equal(m)
	assert_object(result.map).is_null()
	assert_bool(MapValidationIssue.has_errors(result.issues)).is_true()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_load_target_duplicate_blocking() -> void:
	var m1 := _make_manifest(&"dup")
	var m2 := _make_manifest(&"dup")
	_db.add_map(m1)
	_db.add_map(m2)
	var tracker := _track_load_finished()

	var result := _loader.load_map(&"dup")
	assert_int(result.code).is_equal(MapLoadError.Code.INVALID_MANIFEST)
	assert_int(result.issues.size()).is_equal(1)
	assert_that(result.issues[0].code).is_equal(&"duplicate_map_id")
	assert_that(result.issues[0].map_id).is_equal(&"dup")
	assert_object(result.issues[0].context).is_equal(_db)
	assert_int(_host.get_child_count()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_load_multiple_maps() -> void:
	var target := _make_manifest(&"ok")
	var other := _make_manifest(&"other")
	_db.add_map(target)
	_db.add_map(other)

	var result := _loader.load_map(&"ok")
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(target)
	assert_int(result.issues.size()).is_equal(0)


func test_unload() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var tracker := _track_map_unloaded()

	_loader.unload()

	assert_bool(_loader.is_loaded()).is_false()
	assert_object(_loader.get_loaded_map()).is_null()
	assert_int(_host.get_child_count()).is_equal(0)
	assert_bool(handle.is_valid()).is_false()
	assert_object(handle.root).is_null()
	assert_str(handle.id).is_equal(&"test")
	assert_object(handle.manifest).is_equal(m)
	assert_int(tracker["count"]).is_equal(1)
	assert_object(tracker["map"]).is_equal(handle)

	# Idempotent: a second unload emits nothing.
	_loader.unload()
	assert_int(tracker["count"]).is_equal(1)


func test_unload_when_nothing_loaded_emits_nothing() -> void:
	var tracker := _track_map_unloaded()
	_loader.unload()
	assert_int(tracker["count"]).is_equal(0)


func test_external_free_resets_loader_state() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var root := handle.get_root()

	root.free()

	assert_bool(_loader.is_loaded()).is_false()
	assert_object(_loader.get_loaded_map()).is_null()

	# The stale handle is pruned on the next load without an explicit unload.
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"test")
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(m)
	assert_int(tracker["count"]).is_equal(1)


func test_external_detach_resets_loader_state_but_does_not_free() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var root := handle.get_root()

	_host.remove_child(root)

	assert_bool(_loader.is_loaded()).is_false()

	# unload() must not free a detached root owned by external code.
	_loader.unload()
	assert_bool(is_instance_valid(root)).is_true()
	assert_object(root.get_parent()).is_null()

	# The loader ignores the detached root and can load again.
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"test")
	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(m)
	assert_int(tracker["count"]).is_equal(1)

	root.free()


func test_external_reparented_root_is_not_freed_by_unload() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var root := handle.get_root()
	var other_parent := Node3D.new()
	add_child(other_parent)
	_host.remove_child(root)
	other_parent.add_child(root)

	var tracker := _track_map_unloaded()
	_loader.unload()

	assert_bool(is_instance_valid(root)).is_true()
	assert_object(root.get_parent()).is_equal(other_parent)
	assert_bool(handle.is_valid()).is_false()
	assert_int(tracker["count"]).is_equal(1)
	other_parent.free()


func test_external_queue_free_resets_loader_state() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	var root := handle.get_root()

	root.queue_free()

	assert_bool(_loader.is_loaded()).is_false()
	assert_object(_loader.get_loaded_map()).is_null()
	assert_bool(handle.is_valid()).is_false()


func test_unload_after_external_invalidation_emits_nothing() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()
	handle.get_root().free()
	var tracker := _track_map_unloaded()

	_loader.unload()

	assert_int(tracker["count"]).is_equal(0)


func test_load_fails_while_loaded_leaves_active_untouched() -> void:
	var m1 := _make_manifest(&"map1")
	_db.add_map(m1)
	_loader.load_map(&"map1")
	var handle1 := _loader.get_loaded_map()
	var tracker := _track_load_finished()

	var result := _loader.load_map(&"non_existent")
	assert_int(result.code).is_equal(MapLoadError.Code.NOT_FOUND)
	assert_object(result.map).is_null()
	assert_int(tracker["count"]).is_equal(1)

	assert_bool(_loader.is_loaded()).is_true()
	assert_object(_loader.get_loaded_map()).is_equal(handle1)
	assert_int(_host.get_child_count()).is_equal(1)
	assert_object(_host.get_child(0)).is_equal(handle1.get_root())


func test_load_after_unload_succeeds() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	_loader.unload()

	var tracker := _track_load_finished()
	var result := _loader.load_map(&"test")

	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(m)
	assert_int(result.issues.size()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)
	assert_int(_host.get_child_count()).is_equal(1)
	assert_bool(_loader.is_loaded()).is_true()


func test_unrelated_broken_map_does_not_block_target() -> void:
	var target := _make_manifest(&"target")
	var broken := _make_manifest(&"broken")
	broken.display_name = "" # ERROR
	_db.add_map(target)
	_db.add_map(broken)

	var tracker := _track_load_finished()
	var result := await _load_expecting_warning(&"target")

	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(target)
	assert_int(result.issues.size()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_unrelated_duplicate_id_does_not_block_target() -> void:
	var target := _make_manifest(&"target")
	var dup1 := _make_manifest(&"dup")
	var dup2 := _make_manifest(&"dup")
	_db.add_map(target)
	_db.add_map(dup1)
	_db.add_map(dup2)

	var tracker := _track_load_finished()
	var result := await _load_expecting_warning(&"target")

	assert_int(result.code).is_equal(MapLoadError.Code.NONE)
	assert_object(result.manifest).is_equal(target)
	assert_int(result.issues.size()).is_equal(0)
	assert_int(tracker["count"]).is_equal(1)


func test_loaded_map_handle_post_unload() -> void:
	var m := _make_manifest(&"test")
	_db.add_map(m)
	_loader.load_map(&"test")
	var handle := _loader.get_loaded_map()

	_loader.unload()

	assert_bool(handle.is_valid()).is_false()
	assert_object(handle.get_root()).is_null()
	assert_object(handle.root).is_null()
	assert_str(handle.id).is_equal(&"test")
	assert_object(handle.manifest).is_equal(m)


func test_precedence_db_invalid_before_not_found() -> void:
	_loader.map_db = null
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"")

	assert_int(result.code).is_equal(MapLoadError.Code.DB_INVALID)
	assert_int(tracker["count"]).is_equal(1)


func test_precedence_not_found_before_host_invalid() -> void:
	_loader.map_host = null
	var tracker := _track_load_finished()
	var result := _loader.load_map(&"missing")

	assert_int(result.code).is_equal(MapLoadError.Code.NOT_FOUND)
	assert_object(result.manifest).is_null()
	assert_int(tracker["count"]).is_equal(1)


func test_precedence_host_invalid_before_already_loaded() -> void:
	var m1 := _make_manifest(&"map1")
	var m2 := _make_manifest(&"map2")
	_db.add_map(m1)
	_db.add_map(m2)
	_loader.load_map(&"map1")

	_loader.map_host = null
	var result := _loader.load_map(&"map2")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_INVALID)
	assert_object(result.manifest).is_equal(m2)

	_loader.map_host = _host


func test_precedence_already_loaded_before_host_occupied() -> void:
	var m1 := _make_manifest(&"map1")
	var m2 := _make_manifest(&"map2")
	_db.add_map(m1)
	_db.add_map(m2)
	_loader.load_map(&"map1")

	var extra := Node3D.new()
	_host.add_child(extra)
	var result := _loader.load_map(&"map2")
	assert_int(result.code).is_equal(MapLoadError.Code.ALREADY_LOADED)
	extra.free()


func test_precedence_host_occupied_before_validation() -> void:
	var m := _make_manifest(&"invalid")
	m.display_name = "" # Would be INVALID_MANIFEST if validation ran first.
	_db.add_map(m)
	var child := Node3D.new()
	_host.add_child(child)

	var result := _loader.load_map(&"invalid")
	assert_int(result.code).is_equal(MapLoadError.Code.HOST_OCCUPIED)
	child.free()

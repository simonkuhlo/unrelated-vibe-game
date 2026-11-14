extends GdUnitTestSuite


class IdFilter extends MapFilter:
	var allowed: StringName

	func _init(p_allowed: StringName) -> void:
		allowed = p_allowed

	func matches(manifest: MapManifest) -> bool:
		return manifest.id == allowed


func _make_valid_packed_scene() -> PackedScene:
	var scene := PackedScene.new()
	var map_scene := MapScene.new()
	var collection := MapMarkerCollection.new()
	collection.name = "Markers"
	map_scene.add_child(collection)
	collection.owner = map_scene
	var marker := MapMarker.new()
	collection.add_child(marker)
	marker.owner = map_scene
	map_scene.markers = collection
	scene.pack(map_scene)
	map_scene.free()
	return scene


func _make_manifest(id: StringName, display_name: String = "Map") -> MapManifest:
	var manifest := MapManifest.new()
	manifest.id = id
	manifest.display_name = display_name
	manifest.scene = _make_valid_packed_scene()
	return manifest


func test_map_db_operations() -> void:
	var db := MapDB.new()
	assert_bool(db.has_map(&"alpha")).is_false()
	assert_object(db.get_map(&"alpha")).is_null()

	var manifest := _make_manifest(&"alpha", "Alpha")
	db.add_map(manifest)
	assert_bool(db.has_map(&"alpha")).is_true()
	assert_object(db.get_map(&"alpha")).is_equal(manifest)
	assert_array(db.get_map_ids()).is_equal([&"alpha"])

	db.remove_map(&"alpha")
	assert_bool(db.has_map(&"alpha")).is_false()
	assert_object(db.get_map(&"alpha")).is_null()


func test_map_db_duplicate_validation() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"box", "Box 1"))
	db.add_map(_make_manifest(&"box", "Box 2"))

	var issues := db.validate()
	assert_bool(db.is_valid()).is_false()

	var has_duplicate_error := false
	for issue in issues:
		if issue.code == &"duplicate_map_id":
			has_duplicate_error = true
			break
	assert_bool(has_duplicate_error).is_true()


func test_map_db_validates_clean_content() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"alpha"))
	assert_bool(db.is_valid()).is_true()


func test_map_db_get_maps_returns_independent_copy() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"alpha"))

	var copy := db.get_maps()
	assert_int(copy.size()).is_equal(1)
	copy.clear()
	assert_int(db.maps.size()).is_equal(1)


func test_map_db_get_maps_filters_and_skips_null_entries() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"alpha"))
	db.add_map(_make_manifest(&"beta"))
	# Simulates a bad inspector row; direct mutation is intentional here.
	db.maps.append(null)

	var all_maps := db.get_maps()
	assert_int(all_maps.size()).is_equal(2)

	var default_filtered := db.get_maps(MapFilter.new())
	assert_int(default_filtered.size()).is_equal(2)

	var filtered := db.get_maps(IdFilter.new(&"beta"))
	assert_int(filtered.size()).is_equal(1)
	assert_object(filtered[0]).is_equal(db.get_map(&"beta"))


func test_map_db_get_map_ids_skips_null_and_empty_entries() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"alpha"))
	db.add_map(_make_manifest(&""))
	db.maps.append(null)

	assert_array(db.get_map_ids()).is_equal([&"alpha"])


func test_map_db_get_map_rejects_empty_id() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&""))

	assert_object(db.get_map(&"")).is_null()
	assert_bool(db.has_map(&"")).is_false()


func test_map_db_add_map_is_idempotent_for_the_same_manifest() -> void:
	var db := MapDB.new()
	var manifest := _make_manifest(&"alpha")

	db.add_map(manifest)
	db.add_map(manifest)

	assert_int(db.maps.size()).is_equal(1)


func test_map_db_remove_map_removes_all_matching_ids() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"box", "Box 1"))
	db.add_map(_make_manifest(&"box", "Box 2"))

	db.remove_map(&"box")

	assert_int(db.maps.size()).is_equal(0)


func test_map_db_validation_reports_null_rows() -> void:
	var db := MapDB.new()
	db.maps.append(null)

	var issues := db.validate()
	assert_int(issues.size()).is_equal(1)
	assert_int(issues[0].severity).is_equal(MapValidationIssue.Severity.ERROR)
	assert_that(issues[0].code).is_equal(&"manifest_null")


func test_map_db_validation_propagates_manifest_issues() -> void:
	var db := MapDB.new()
	var manifest := _make_manifest(&"alpha")
	manifest.scene = null
	db.add_map(manifest)

	var issues := db.validate()
	assert_bool(MapValidationIssue.has_errors(issues)).is_true()

	var has_scene_error := false
	for issue in issues:
		if issue.code == &"scene_missing":
			has_scene_error = true
			break
	assert_bool(has_scene_error).is_true()

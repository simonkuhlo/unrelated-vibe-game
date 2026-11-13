extends GdUnitTestSuite


class IdFilter extends MapFilter:
	var allowed: StringName

	func _init(p_allowed: StringName) -> void:
		allowed = p_allowed

	func matches(manifest: MapManifest) -> bool:
		return manifest.id == allowed


func _make_manifest(id: StringName, display_name: String = "Map") -> MapManifest:
	var manifest := MapManifest.new()
	manifest.id = id
	manifest.display_name = display_name
	manifest.scene = PackedScene.new()
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

	assert_bool(db.is_validated).is_false()
	var issues := db.validate()
	assert_bool(db.is_validated).is_true()
	assert_bool(db.is_valid()).is_false()

	var has_duplicate_error := false
	for issue in issues:
		if issue.code == &"duplicate_map_id":
			has_duplicate_error = true
			break
	assert_bool(has_duplicate_error).is_true()


func test_map_db_validation_state_tracks_mutations() -> void:
	var db := MapDB.new()
	db.validate()
	assert_bool(db.is_validated).is_true()

	db.add_map(_make_manifest(&"alpha"))
	assert_bool(db.is_validated).is_false()

	db.validate()
	db.remove_map(&"alpha")
	assert_bool(db.is_validated).is_false()

	db.validate()
	db.clear_db()
	assert_bool(db.is_validated).is_false()


func test_map_db_property_assignment_resets_validation() -> void:
	var db := MapDB.new()
	db.validate()
	assert_bool(db.is_validated).is_true()

	var replacement: Array[MapManifest] = [_make_manifest(&"alpha")]
	db.maps = replacement
	assert_bool(db.is_validated).is_false()


func test_map_db_validates_clean_content() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"alpha"))
	assert_bool(db.is_valid()).is_true()
	assert_bool(db.is_validated).is_true()


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

	var filtered := db.get_maps(IdFilter.new(&"beta"))
	assert_int(filtered.size()).is_equal(1)
	assert_object(filtered[0]).is_equal(db.get_map(&"beta"))


func test_map_db_get_map_ids_skips_null_and_empty_entries() -> void:
	var db := MapDB.new()
	db.add_map(_make_manifest(&"alpha"))
	db.add_map(_make_manifest(&""))
	db.maps.append(null)

	assert_array(db.get_map_ids()).is_equal([&"alpha"])

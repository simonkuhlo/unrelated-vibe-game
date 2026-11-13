extends GdUnitTestSuite

func test_map_db_operations() -> void:
	var db := MapDB.new()
	assert_bool(db.has_map(&"alpha")).is_false()
	assert_object(db.get_map(&"alpha")).is_null()
	
	var manifest := MapManifest.new()
	manifest.id = &"alpha"
	manifest.display_name = "Alpha"
	manifest.scene = PackedScene.new()
	
	db.add_map(manifest)
	assert_bool(db.has_map(&"alpha")).is_true()
	assert_object(db.get_map(&"alpha")).is_equal(manifest)
	assert_array(db.get_map_ids()).is_equal([&"alpha"])
	
	db.remove_map(&"alpha")
	assert_bool(db.has_map(&"alpha")).is_false()
	assert_object(db.get_map(&"alpha")).is_null()

func test_map_db_duplicate_validation() -> void:
	var db := MapDB.new()
	var m1 := MapManifest.new()
	m1.id = &"box"
	m1.display_name = "Box 1"
	m1.scene = PackedScene.new()
	
	var m2 := MapManifest.new()
	m2.id = &"box"
	m2.display_name = "Box 2"
	m2.scene = PackedScene.new()
	
	db.add_map(m1)
	db.add_map(m2)
	
	var issues := db.validate()
	assert_bool(db.is_validated).is_true()
	
	var has_duplicate_error := false
	for issue in issues:
		if issue.code == &"duplicate_map_id":
			has_duplicate_error = true
			break
	assert_bool(has_duplicate_error).is_true()

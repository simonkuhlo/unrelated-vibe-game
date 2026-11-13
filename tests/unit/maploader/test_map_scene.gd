extends GdUnitTestSuite

func test_map_scene_validation() -> void:
	var scene := auto_free(MapScene.new()) as MapScene
	
	# Missing marker_root should be an ERROR
	var issues := scene.validate()
	var has_missing_root := false
	for issue in issues:
		if issue.code == &"marker_root_missing":
			has_missing_root = true
			break
	assert_bool(has_missing_root).is_true()
	
	# Assign marker_root
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection
	scene.marker_root = collection
	scene.add_child(collection)
	
	var warnings := scene._get_configuration_warnings()
	assert_int(warnings.size()).is_equal(0)

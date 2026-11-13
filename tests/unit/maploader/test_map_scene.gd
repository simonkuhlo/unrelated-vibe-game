extends GdUnitTestSuite


func test_map_scene_reports_missing_markers_root() -> void:
	var scene := auto_free(MapScene.new()) as MapScene

	var issues := scene.validate()
	assert_bool(MapValidationIssue.has_errors(issues)).is_true()

	var found_missing_root := false
	for issue in issues:
		if issue.code == &"markers_missing":
			found_missing_root = true
			break
	assert_bool(found_missing_root).is_true()

	var warnings := scene._get_configuration_warnings()
	assert_int(warnings.size()).is_equal(1)
	assert_bool(warnings[0].contains("markers_missing")).is_true()


func test_map_scene_aggregates_marker_collection_warnings() -> void:
	var scene := auto_free(MapScene.new()) as MapScene
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection
	scene.markers = collection
	scene.add_child(collection)

	var issues := scene.validate()
	assert_int(issues.size()).is_equal(1)
	assert_that(issues[0].code).is_equal(&"marker_collection_empty")

	var warnings := scene._get_configuration_warnings()
	assert_int(warnings.size()).is_equal(1)
	assert_bool(warnings[0].contains("marker_collection_empty")).is_true()


func test_map_scene_with_markers_is_clean() -> void:
	var scene := auto_free(MapScene.new()) as MapScene
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection
	scene.markers = collection
	scene.add_child(collection)

	var marker := auto_free(MapMarker.new()) as MapMarker
	collection.add_child(marker)

	assert_array(scene.validate()).is_empty()
	assert_int(scene._get_configuration_warnings().size()).is_equal(0)

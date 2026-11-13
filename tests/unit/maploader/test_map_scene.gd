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
	collection.name = "Markers"
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
	collection.name = "Markers"
	scene.markers = collection
	scene.add_child(collection)

	var marker := auto_free(MapMarker.new()) as MapMarker
	collection.add_child(marker)

	assert_array(scene.validate()).is_empty()
	assert_int(scene._get_configuration_warnings().size()).is_equal(0)


func test_map_scene_requires_markers_to_be_a_direct_child() -> void:
	var scene := auto_free(MapScene.new()) as MapScene
	var other := auto_free(Node3D.new()) as Node3D
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection
	collection.name = "Markers"
	collection.add_child(auto_free(MapMarker.new()) as MapMarker)
	other.add_child(collection)
	scene.markers = collection
	scene.add_child(other)

	var issues := scene.validate()
	assert_int(issues.size()).is_equal(1)
	assert_int(issues[0].severity).is_equal(MapValidationIssue.Severity.ERROR)
	assert_that(issues[0].code).is_equal(&"markers_not_child")


func test_map_scene_warns_when_markers_node_is_not_named_markers() -> void:
	var scene := auto_free(MapScene.new()) as MapScene
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection
	collection.name = "SpawnMarkers"
	collection.add_child(auto_free(MapMarker.new()) as MapMarker)
	scene.markers = collection
	scene.add_child(collection)

	var issues := scene.validate()
	assert_int(issues.size()).is_equal(1)
	assert_int(issues[0].severity).is_equal(MapValidationIssue.Severity.WARNING)
	assert_that(issues[0].code).is_equal(&"markers_wrong_name")

	var warnings := scene._get_configuration_warnings()
	assert_int(warnings.size()).is_equal(1)
	assert_bool(warnings[0].contains("markers_wrong_name")).is_true()

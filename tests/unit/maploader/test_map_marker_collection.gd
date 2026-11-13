extends GdUnitTestSuite


class NamedMarkerFilter extends MapMarkerFilter:
	var target: StringName

	func _init(p_target: StringName) -> void:
		target = p_target

	func matches(marker: MapMarker) -> bool:
		return marker.name == target


func test_marker_collection_depth_first_order() -> void:
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection

	var m1 := auto_free(MapMarker.new()) as MapMarker
	m1.name = "Marker1"
	collection.add_child(m1)

	var parent_node := auto_free(Node3D.new()) as Node3D
	parent_node.name = "ParentNode"
	collection.add_child(parent_node)

	var m2 := auto_free(MapMarker.new()) as MapMarker
	m2.name = "Marker2"
	parent_node.add_child(m2)

	var markers := collection.get_markers()
	assert_int(markers.size()).is_equal(2)
	assert_object(markers[0]).is_equal(m1)
	assert_object(markers[1]).is_equal(m2)


func test_marker_collection_filters_markers() -> void:
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection

	var m1 := auto_free(MapMarker.new()) as MapMarker
	m1.name = "Marker1"
	collection.add_child(m1)

	var m2 := auto_free(MapMarker.new()) as MapMarker
	m2.name = "Marker2"
	collection.add_child(m2)

	var filtered := collection.get_markers(NamedMarkerFilter.new(&"Marker2"))
	assert_int(filtered.size()).is_equal(1)
	assert_object(filtered[0]).is_equal(m2)


func test_empty_marker_collection_is_a_warning() -> void:
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection

	var issues := collection.validate()
	assert_int(issues.size()).is_equal(1)
	assert_int(issues[0].severity).is_equal(MapValidationIssue.Severity.WARNING)
	assert_that(issues[0].code).is_equal(&"marker_collection_empty")

	var marker := auto_free(MapMarker.new()) as MapMarker
	collection.add_child(marker)
	assert_array(collection.validate()).is_empty()

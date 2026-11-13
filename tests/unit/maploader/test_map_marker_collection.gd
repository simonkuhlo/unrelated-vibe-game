extends GdUnitTestSuite

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

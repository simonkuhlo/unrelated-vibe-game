extends GdUnitTestSuite


func test_player_spawn_point_defaults_to_index_zero() -> void:
	var marker := auto_free(PlayerSpawnPoint.new()) as PlayerSpawnPoint

	assert_int(marker.player_index).is_equal(0)


func test_filter_matches_same_player_index() -> void:
	var marker := auto_free(PlayerSpawnPoint.new()) as PlayerSpawnPoint
	marker.player_index = 2
	var filter := PlayerSpawnFilter.new()
	filter.player_index = 2

	assert_bool(filter.matches(marker)).is_true()


func test_filter_rejects_different_player_index() -> void:
	var marker := auto_free(PlayerSpawnPoint.new()) as PlayerSpawnPoint
	marker.player_index = 1
	var filter := PlayerSpawnFilter.new()
	filter.player_index = 2

	assert_bool(filter.matches(marker)).is_false()


func test_filter_rejects_non_spawn_marker() -> void:
	var marker := auto_free(MapMarker.new()) as MapMarker
	var filter := PlayerSpawnFilter.new()

	assert_bool(filter.matches(marker)).is_false()


func test_marker_collection_filters_spawns_by_index() -> void:
	var collection := auto_free(MapMarkerCollection.new()) as MapMarkerCollection

	var spawn_zero := auto_free(PlayerSpawnPoint.new()) as PlayerSpawnPoint
	spawn_zero.player_index = 0
	collection.add_child(spawn_zero)

	var spawn_one := auto_free(PlayerSpawnPoint.new()) as PlayerSpawnPoint
	spawn_one.player_index = 1
	collection.add_child(spawn_one)

	var filter := PlayerSpawnFilter.new()
	filter.player_index = 1
	var markers := collection.get_markers(filter)

	assert_int(markers.size()).is_equal(1)
	assert_object(markers[0]).is_equal(spawn_one)

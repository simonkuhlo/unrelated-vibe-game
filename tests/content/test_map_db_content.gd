extends GdUnitTestSuite
## Guards the built-in map database content in game/maps/map_db.tres.

const MAP_DB_PATH := "res://game/maps/map_db.tres"


func test_map_db_content_resolves() -> void:
	var db := load(MAP_DB_PATH) as MapDB
	assert_that(db).override_failure_message("Failed to load MapDB from %s" % MAP_DB_PATH).is_not_null()
	if db == null:
		return

	var issues := db.validate()
	for issue in issues:
		if issue.severity == MapValidationIssue.Severity.ERROR:
			fail("MapDB validation error: %s" % issue.format_string())

	var ids := db.get_map_ids()
	assert_that(ids).is_not_empty()

	for id in ids:
		var manifest := db.get_map(id)
		assert_that(manifest).override_failure_message("Manifest for map id '%s' is null" % id).is_not_null()
		if manifest == null:
			continue

		assert_that(manifest.id).is_equal(id)
		assert_that(manifest.display_name).is_not_empty()
		assert_that(manifest.scene).override_failure_message("Map scene for '%s' is null or missing" % id).is_not_null()

		if manifest.scene != null:
			var instance := auto_free(manifest.scene.instantiate()) as Node
			assert_that(instance).override_failure_message("Failed to instantiate map scene for '%s'" % id).is_not_null()
			if instance is MapScene:
				assert_that((instance as MapScene).marker_root).override_failure_message("MapScene '%s' has no marker_root assigned" % id).is_not_null()

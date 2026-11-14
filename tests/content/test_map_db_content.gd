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

		var manifest_folder := manifest.resource_path.get_base_dir().get_file()
		assert_that(manifest_folder).is_equal(str(id))

		var scene_folder := manifest.scene.resource_path.get_base_dir()
		assert_that(scene_folder).is_equal(manifest.resource_path.get_base_dir())

		assert_that(manifest.scene).override_failure_message("Map scene for '%s' is null or missing" % id).is_not_null()

		if manifest.scene == null:
			continue

		var instance := auto_free(manifest.scene.instantiate()) as Node
		assert_that(instance).override_failure_message("Failed to instantiate map scene for '%s'" % id).is_not_null()
		if instance == null:
			continue

		assert_bool(instance is MapScene).override_failure_message("Map scene for '%s' must use MapScene as its root" % id).is_true()
		if not instance is MapScene:
			continue

		var map_scene := instance as MapScene
		assert_that(map_scene.markers).override_failure_message("MapScene '%s' has no markers root assigned" % id).is_not_null()

		for issue in map_scene.validate():
			if issue.severity == MapValidationIssue.Severity.ERROR:
				fail("MapScene validation error for '%s': %s" % [id, issue.format_string()])

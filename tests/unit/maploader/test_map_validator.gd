extends GdUnitTestSuite


func test_null_inputs_return_empty_issue_lists() -> void:
	assert_array(MapValidator.validate_db(null)).is_empty()
	assert_array(MapValidator.validate_manifest(null)).is_empty()
	assert_array(MapValidator.validate_scene(null)).is_empty()


func test_validate_db_forwards_to_the_database() -> void:
	var db := MapDB.new()
	var manifest := MapManifest.new()
	manifest.id = &"alpha"
	manifest.display_name = "Alpha"
	manifest.scene = PackedScene.new()
	manifest.thumbnail = PlaceholderTexture2D.new()
	db.add_map(manifest)

	assert_array(MapValidator.validate_db(db)).is_empty()
	assert_bool(db.is_validated).is_true()


func test_validate_manifest_returns_issues() -> void:
	var manifest := MapManifest.new()
	manifest.display_name = "Alpha"

	var issues := MapValidator.validate_manifest(manifest)
	assert_bool(MapValidationIssue.has_errors(issues)).is_true()


func test_validate_scene_returns_issues() -> void:
	var scene := auto_free(MapScene.new()) as MapScene

	var issues := MapValidator.validate_scene(scene)
	assert_bool(MapValidationIssue.has_errors(issues)).is_true()

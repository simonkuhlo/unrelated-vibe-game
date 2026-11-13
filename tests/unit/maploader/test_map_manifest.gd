extends GdUnitTestSuite


func test_manifest_validation_rules(
	id_str: String,
	has_scene: bool,
	display_name: String,
	has_thumbnail: bool,
	expected_errors: int,
	expected_warnings: int,
	_test_parameters := [
		["test_map", true, "Test Map", true, 0, 0],    # Valid
		["map_2", true, "Test Map", true, 0, 0],       # Valid, digits after a letter
		["", true, "Test Map", true, 1, 0],            # Missing ID
		["Test_Map", true, "Test Map", true, 1, 0],    # Invalid ID (uppercase)
		["test map", true, "Test Map", true, 1, 0],    # Invalid ID (space)
		["map-name", true, "Test Map", true, 1, 0],    # Invalid ID (dash)
		["1map", true, "Test Map", true, 1, 0],        # Invalid ID (leading digit)
		["_map", true, "Test Map", true, 1, 0],        # Invalid ID (leading underscore)
		["map_", true, "Test Map", true, 1, 0],        # Invalid ID (trailing underscore)
		["map__name", true, "Test Map", true, 1, 0],   # Invalid ID (double underscore)
		["test_map", false, "Test Map", true, 1, 0],   # Missing scene
		["test_map", true, "", true, 1, 0],            # Missing display name
		["test_map", true, "Test Map", false, 0, 1]    # Missing thumbnail (warning only)
	]
) -> void:
	var manifest := MapManifest.new()
	manifest.id = id_str
	if has_scene:
		manifest.scene = PackedScene.new()
	manifest.display_name = display_name
	if has_thumbnail:
		manifest.thumbnail = PlaceholderTexture2D.new()

	var issues := manifest.validate()
	var errors := 0
	var warnings := 0
	for issue in issues:
		if issue.severity == MapValidationIssue.Severity.ERROR:
			errors += 1
		elif issue.severity == MapValidationIssue.Severity.WARNING:
			warnings += 1

	assert_int(errors).is_equal(expected_errors)
	assert_int(warnings).is_equal(expected_warnings)
	assert_bool(manifest.is_valid()).is_equal(expected_errors == 0)


func test_manifest_with_only_warnings_is_valid() -> void:
	var manifest := MapManifest.new()
	manifest.id = &"test_map"
	manifest.display_name = "Test Map"
	manifest.scene = PackedScene.new()

	var issues := manifest.validate()
	assert_bool(MapValidationIssue.has_errors(issues)).is_false()
	assert_bool(manifest.is_valid()).is_true()

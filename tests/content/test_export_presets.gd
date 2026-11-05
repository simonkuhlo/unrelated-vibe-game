extends GdUnitTestSuite
## Guards the production export configuration.
##
## Shipping test content, reports, or the test framework in a build is a
## packaging regression that is cheap to catch here and expensive to notice
## later. The nightly workflow also inspects the exported PCK; this test keeps
## the preset honest on every pull request.

const PRESET_FILE := "res://export_presets.cfg"
const EXPECTED_PLATFORM := "Linux"
const REQUIRED_EXCLUDE_PATTERNS: Array[String] = [
	"tests/*",
	"reports/*",
	"addons/gdUnit4/*",
]


func test_preset_file_exists() -> void:
	assert_that(FileAccess.file_exists(PRESET_FILE)).is_true()


func test_linux_preset_excludes_test_content() -> void:
	var exclude_filter: String = _linux_preset_value("exclude_filter")
	assert_str(exclude_filter).is_not_empty()

	for pattern in REQUIRED_EXCLUDE_PATTERNS:
		assert_str(exclude_filter) \
			.override_failure_message("export_presets.cfg must exclude %s" % pattern) \
			.contains(pattern)


func test_linux_preset_exports_all_runtime_resources() -> void:
	assert_str(_linux_preset_value("export_filter")).is_equal("all_resources")
	assert_str(_linux_preset_value("export_path")).starts_with("build/")


func _linux_preset_value(key: String) -> String:
	var config := ConfigFile.new()
	var err := config.load(PRESET_FILE)
	assert_int(err) \
		.override_failure_message("Failed to load %s" % PRESET_FILE) \
		.is_equal(OK)
	if err != OK:
		return ""

	for section in config.get_sections():
		if not section.begins_with("preset."):
			continue
		if config.get_value(section, "platform", "") == EXPECTED_PLATFORM:
			return str(config.get_value(section, key, ""))

	return ""

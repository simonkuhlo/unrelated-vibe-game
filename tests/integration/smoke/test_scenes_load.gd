extends GdUnitTestSuite
## Every first-party scene must load as a PackedScene.
##
## This catches broken resource references and malformed scene files before
## they reach the editor or a running build. Instantiation stays out of scope:
## scenes may require runtime dependencies that a bare load cannot provide.

const SCENE_ROOTS: Array[String] = ["res://game", "res://system", "res://ui"]


func test_all_scenes_load() -> void:
	var scenes := PackedStringArray()
	for root in SCENE_ROOTS:
		_collect(root, scenes)

	assert_that(scenes).is_not_empty()

	for path in scenes:
		assert_that(load(path)) \
			.override_failure_message("Failed to load scene %s" % path) \
			.is_not_null()


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full_path, out)
		elif entry.ends_with(".tscn"):
			out.append(full_path)

		entry = dir.get_next()
	dir.list_dir_end()

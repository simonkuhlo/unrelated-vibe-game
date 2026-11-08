extends SceneTree
## Loads every first-party GDScript file so Godot's parser is the static gate.
##
## Usage:
##   godot --headless --path . -s res://tests/tools/check_scripts.gd
##
## Third-party code (addons/) and generated folders are skipped: they are pinned
## dependencies, not ours to police.

const EXCLUDED_DIRS: Array[String] = ["addons", "reports", "build"]


func _initialize() -> void:
	var scripts := PackedStringArray()
	_collect("res://", scripts)
	scripts.sort()

	var failed := PackedStringArray()
	for path in scripts:
		# load() compiles the script and its dependencies. A parse error returns
		# null and prints the engine diagnostics before we get here.
		if load(path) == null:
			failed.append(path)

	if failed.is_empty():
		print("Parsed %d GDScript files." % scripts.size())
		quit(0)
		return

	for path in failed:
		printerr("PARSE FAILED: %s" % path)
	printerr("%d of %d GDScript files failed to parse." % [failed.size(), scripts.size()])
	quit(1)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		# Skip hidden entries (.godot, .git, ...).
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := dir_path.path_join(entry)
		if dir.current_is_dir():
			if entry not in EXCLUDED_DIRS:
				_collect(full_path, out)
		elif entry.ends_with(".gd"):
			out.append(full_path)

		entry = dir.get_next()
	dir.list_dir_end()

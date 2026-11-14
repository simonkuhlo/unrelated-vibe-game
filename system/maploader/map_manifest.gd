@tool
class_name MapManifest
extends Resource

## Built-in map descriptor. `id` is the sole identity and must be lowercase
## `snake_case` (single underscores, starting with a letter). The folder under
## `game/maps/` matches the id. Runtime code treats `id` as read-only by
## convention; the editor is the only supported place to change it.

const ID_PATTERN := "^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"

static var _id_regex: RegEx

@export var id: StringName
@export var scene: PackedScene
@export var display_name: String = "Unnamed"
@export var thumbnail: Texture2D

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []

	if id.is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_missing", "Map ID is missing.", self))
	elif not _is_valid_id(id):
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_invalid", "Map ID must be lowercase snake_case (e.g. test_box).", self))
	elif not resource_path.is_empty():
		var expected_dir := "res://game/maps/%s" % id
		if resource_path.get_base_dir() != expected_dir:
			issues.append(MapValidationIssue.new(
				MapValidationIssue.Severity.ERROR,
				&"manifest_folder_mismatch",
				"Manifest must live in '%s' (found '%s')." % [expected_dir, resource_path.get_base_dir()],
				self
			))

	if scene == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"scene_missing", "Map scene is missing.", self))
	else:
		if not resource_path.is_empty() and not scene.resource_path.is_empty():
			if scene.resource_path.get_base_dir() != resource_path.get_base_dir():
				issues.append(MapValidationIssue.new(
					MapValidationIssue.Severity.ERROR,
					&"scene_folder_mismatch",
					"Map scene '%s' is not in the same directory as manifest '%s'." % [scene.resource_path.get_file(), resource_path.get_file()],
					self
				))

		var instance := scene.instantiate()
		if instance == null:
			issues.append(MapValidationIssue.new(
				MapValidationIssue.Severity.ERROR,
				&"scene_instantiate_failed",
				"Map scene failed to instantiate.",
				self
			))
		else:
			if not (instance is MapScene):
				issues.append(MapValidationIssue.new(
					MapValidationIssue.Severity.ERROR,
					&"scene_root_invalid",
					"Map scene root must be a MapScene (found %s)." % instance.get_class(),
					self
				))
			else:
				var map_scene := instance as MapScene
				# The instance is freed below, so point every aggregated issue at
				# the manifest instead of a scene node that will be dangling.
				for issue in map_scene.validate():
					issue.context = self
					issues.append(issue)
			instance.free()

	if display_name.is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"display_name_missing", "Map display name is missing.", self))

	if thumbnail == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"thumbnail_missing", "Map thumbnail is missing.", self))

	return issues


func is_valid() -> bool:
	return not MapValidationIssue.has_errors(validate())


func _is_valid_id(value: StringName) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	if _id_regex == null:
		return false

	# `$` in PCRE can match before a trailing newline; require the whole match
	# to cover the input so ids with whitespace are rejected.
	var text := str(value)
	var found := _id_regex.search(text)
	return found != null and found.get_string() == text


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

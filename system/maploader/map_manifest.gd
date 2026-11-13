@tool
class_name MapManifest
extends Resource

## Built-in map descriptor. `id` is the sole identity and must be lowercase
## `snake_case` (single underscores, starting with a letter). The folder under
## `game/maps/` matches the id.

const ID_PATTERN := "^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"

@export var id: StringName
@export var scene: PackedScene
@export var display_name: String = "Unnamed"
@export var thumbnail: Texture2D

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []

	if id.is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_missing", "Map ID is missing.", self))
	else:
		var regex := RegEx.create_from_string(ID_PATTERN)
		if regex == null or regex.search(str(id)) == null:
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_invalid", "Map ID must be lowercase snake_case (e.g. test_box).", self))

	if scene == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"scene_missing", "Map scene is missing.", self))

	if display_name.is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"display_name_missing", "Map display name is missing.", self))

	if thumbnail == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"thumbnail_missing", "Map thumbnail is missing.", self))

	return issues


func is_valid() -> bool:
	return not MapValidationIssue.has_errors(validate())


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

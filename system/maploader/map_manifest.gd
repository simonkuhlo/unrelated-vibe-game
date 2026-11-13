@tool
class_name MapManifest
extends Resource

@export var id: StringName
@export var scene: PackedScene
@export var display_name: String = "Unnamed"
@export var thumbnail: Texture2D

@export_tool_button("Validate") var _button_validate: Callable = validate

func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	
	if id.is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_missing", "Map ID is missing.", self))
	else:
		var regex = RegEx.new()
		regex.compile("^[a-z0-9_]+$")
		if not regex.search(id):
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"id_invalid", "Map ID must be lowercase snake_case.", self))
			
	if scene == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"scene_missing", "Map scene is missing.", self))
		
	if display_name.is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"display_name_missing", "Map display name is missing.", self))
		
	if thumbnail == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"thumbnail_missing", "Map thumbnail is missing.", self))
		
	return issues

func is_valid() -> bool:
	for issue in validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			return false
	return true

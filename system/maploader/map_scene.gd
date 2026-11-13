@tool
class_name MapScene
extends Node3D

@export var marker_root: MapMarkerCollection

@export_tool_button("Validate") var _button_validate: Callable = validate

func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	if marker_root == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"marker_root_missing", "Marker root is not assigned.", self))
	else:
		issues.append_array(marker_root.validate())
	return issues

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for issue in validate():
		if issue.severity == MapValidationIssue.Severity.ERROR:
			warnings.append(issue.format_string())
	return warnings

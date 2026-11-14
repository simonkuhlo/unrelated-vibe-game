@tool
class_name MapScene
extends Node3D

## Root node of a map scene. It exposes a single `Markers` child (a
## `MapMarkerCollection`) so consumers query markers through one typed root.
## Game-specific marker types are built on `game/` subclasses, not here.
##
## Validation requires the assigned collection to be a direct child of this
## scene and warns when the node is not named `Markers`.

@export var markers: MapMarkerCollection

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	if markers == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"markers_missing", "Markers root is not assigned.", self))
		return issues

	if markers.get_parent() != self:
		issues.append(MapValidationIssue.new(
			MapValidationIssue.Severity.ERROR,
			&"markers_not_child",
			"Markers root must be a direct child of the map scene.",
			markers
		))
		return issues
	if markers.name != &"Markers":
		issues.append(MapValidationIssue.new(
			MapValidationIssue.Severity.WARNING,
			&"markers_wrong_name",
			"Markers root should be named Markers.",
			markers
		))

	issues.append_array(markers.validate())
	return issues


func _get_configuration_warnings() -> PackedStringArray:
	return MapValidationIssue.format_all(validate())


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

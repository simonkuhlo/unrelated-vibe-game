@tool
class_name MapScene
extends Node3D

## Root node of a map scene. It exposes a single `Markers` child (a
## `MapMarkerCollection`) so consumers query markers through one typed root.
## Game-specific marker types are built on `game/` subclasses, not here.

@export var markers: MapMarkerCollection

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	if markers == null:
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"markers_missing", "Markers root is not assigned.", self))
	else:
		issues.append_array(markers.validate())
	return issues


func _get_configuration_warnings() -> PackedStringArray:
	return MapValidationIssue.format_all(validate())


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

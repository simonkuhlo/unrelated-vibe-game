@tool
class_name MapMarkerCollection
extends Node3D

## Marker root of a `MapScene`. Owns depth-first marker queries so map content
## does not need to know the tree shape. Marker order is depth-first tree order.

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func get_markers(filter: MapMarkerFilter = null) -> Array[MapMarker]:
	var markers: Array[MapMarker] = []
	_collect_markers(self, filter, markers)
	return markers


func _collect_markers(node: Node, filter: MapMarkerFilter, out: Array[MapMarker]) -> void:
	for child in node.get_children():
		if child is MapMarker:
			if filter == null or filter.matches(child):
				out.append(child)
		_collect_markers(child, filter, out)


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	if get_markers().is_empty():
		issues.append(MapValidationIssue.new(MapValidationIssue.Severity.WARNING, &"marker_collection_empty", "Marker collection is empty.", self))
	return issues


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

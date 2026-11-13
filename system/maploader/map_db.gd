@tool
class_name MapDB
extends Resource

## Ordered list of built-in maps. `manifest.id` is the sole identity; lookups
## are linear and there is no runtime index or cache.
##
## Validation state is advisory: `is_validated` only records that `validate()`
## ran after the last mutation of this DB. It does not observe manifest field
## edits, so a loader must call `validate()` before using the DB (see #40).

@export var maps: Array[MapManifest] = []:
	set(value):
		maps = value
		is_validated = false

var is_validated: bool = false

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	var seen_ids: Dictionary = {}

	for i in range(maps.size()):
		var manifest: MapManifest = maps[i]
		if manifest == null:
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"manifest_null", "Manifest at index %d is null." % i, self))
			continue

		issues.append_array(manifest.validate())

		if manifest.id.is_empty():
			continue
		if seen_ids.has(manifest.id):
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"duplicate_map_id", "Duplicate map ID: %s" % manifest.id, manifest))
		seen_ids[manifest.id] = true

	is_validated = true
	return issues


func is_valid() -> bool:
	return not MapValidationIssue.has_errors(validate())


func get_map(id: StringName) -> MapManifest:
	for manifest in maps:
		if manifest and manifest.id == id:
			return manifest
	return null


func has_map(id: StringName) -> bool:
	return get_map(id) != null


func get_maps(filter: MapFilter = null) -> Array[MapManifest]:
	var result: Array[MapManifest] = []
	for manifest in maps:
		if manifest == null:
			continue
		if filter == null or filter.matches(manifest):
			result.append(manifest)
	return result


func get_map_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for manifest in maps:
		if manifest and not manifest.id.is_empty():
			ids.append(manifest.id)
	return ids


func add_map(manifest: MapManifest) -> void:
	if manifest and not maps.has(manifest):
		maps.append(manifest)
		is_validated = false


func remove_map(id: StringName) -> void:
	for i in range(maps.size() - 1, -1, -1):
		if maps[i] and maps[i].id == id:
			maps.remove_at(i)
			is_validated = false


## Editor-only helper for clearing the built-in list. Runtime code should not
## rely on clearing the shared DB.
func clear_db() -> void:
	maps.clear()
	is_validated = false


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

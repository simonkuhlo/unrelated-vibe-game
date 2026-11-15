@tool
class_name MapDB
extends Resource

## Ordered list of built-in maps. `manifest.id` is the sole identity; lookups
## are linear and there is no runtime index or cache.
##
## There is no validation cache: callers, including the loader, must run
## `validate()` before using the DB.
##
## `validate()` checks manifest fields, ID format, uniqueness, folder location
## conventions, and scene content (including structure and marker validation).

@export var maps: Array[MapManifest] = []

@export_tool_button("Validate") var _button_validate: Callable = _validate_from_editor


func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	var manifests_by_id: Dictionary = {}

	for i in range(maps.size()):
		var manifest: MapManifest = maps[i]
		if manifest == null:
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"manifest_null", "Manifest at index %d is null." % i, self))
			continue

		issues.append_array(manifest.validate())

		if manifest.id.is_empty():
			continue

		if not manifests_by_id.has(manifest.id):
			manifests_by_id[manifest.id] = []
		manifests_by_id[manifest.id].append(manifest)

	for id: StringName in manifests_by_id:
		var duplicates: Array = manifests_by_id[id]
		if duplicates.size() > 1:
			var manifest_descriptions: Array[String] = []
			for m: MapManifest in duplicates:
				manifest_descriptions.append(_describe_manifest(m))
			var msg := "Duplicate map ID '%s' found in %d manifests (%s)." % [id, duplicates.size(), ", ".join(manifest_descriptions)]
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"duplicate_map_id", msg, self, id))

	return issues


func _describe_manifest(manifest: MapManifest) -> String:
	if not manifest.resource_path.is_empty():
		return manifest.resource_path
	if not manifest.display_name.is_empty():
		return "'%s'" % manifest.display_name
	return "<unnamed map manifest>"


func is_valid() -> bool:
	return not MapValidationIssue.has_errors(validate())


func get_map(id: StringName) -> MapManifest:
	if id.is_empty():
		return null
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


func remove_map(id: StringName) -> void:
	for i in range(maps.size() - 1, -1, -1):
		if maps[i] and maps[i].id == id:
			maps.remove_at(i)


## Editor-only helper for clearing the built-in list. Runtime code should not
## rely on clearing the shared DB.
func clear_db() -> void:
	maps.clear()


func _validate_from_editor() -> void:
	MapValidationIssue.log_all(self, validate())

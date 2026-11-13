@tool
class_name MapDB
extends Resource

@export var maps: Array[MapManifest] = []

var is_validated: bool = false

@export_tool_button("Validate") var _button_validate: Callable = validate

func validate() -> Array[MapValidationIssue]:
	var issues: Array[MapValidationIssue] = []
	var seen_ids := {}
	
	for i in range(maps.size()):
		var manifest: MapManifest = maps[i]
		if manifest == null:
			issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"manifest_null", "Manifest at index %d is null." % i, self))
			continue
			
		issues.append_array(manifest.validate())
		
		if not manifest.id.is_empty():
			if seen_ids.has(manifest.id):
				issues.append(MapValidationIssue.new(MapValidationIssue.Severity.ERROR, &"duplicate_map_id", "Duplicate map ID: %s" % manifest.id, self))
			seen_ids[manifest.id] = true
			
	is_validated = true
	return issues

func get_map(id: StringName) -> MapManifest:
	for manifest in maps:
		if manifest and manifest.id == id:
			return manifest
	return null

func has_map(id: StringName) -> bool:
	return get_map(id) != null

func get_maps(filter: MapFilter = null) -> Array[MapManifest]:
	if filter == null:
		return maps.duplicate()
	
	var filtered: Array[MapManifest] = []
	for manifest in maps:
		if manifest and filter.matches(manifest):
			filtered.append(manifest)
	return filtered

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

func clear_db() -> void:
	maps.clear()
	is_validated = false

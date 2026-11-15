@tool
class_name MapLoader
extends Node

## Synchronous map loader.
##
## Manages map instantiation under a host node. Validates maps against the DB
## before loading and provides handles to loaded content.

signal load_finished(result: MapLoadResult)
signal map_unloaded(map: LoadedMap)

@export var map_db: MapDB
@export var map_host: Node3D

var _active_map: LoadedMap


func load_map(id: StringName) -> MapLoadResult:
	var result := _execute_load(id)
	load_finished.emit(result)
	return result


func unload() -> void:
	if not is_loaded():
		_active_map = null
		return

	var map := _active_map
	_active_map = null

	var root := map.get_root()
	if is_instance_valid(root):
		if root.get_parent() == map_host:
			map_host.remove_child(root)
		root.queue_free()

	map.invalidate()
	map_unloaded.emit(map)


func is_loaded() -> bool:
	return _active_map != null and _active_map.is_valid()


func get_loaded_map() -> LoadedMap:
	if not is_loaded():
		return null
	return _active_map


func _execute_load(id: StringName) -> MapLoadResult:
	# 1. DB_INVALID
	if map_db == null:
		return MapLoadResult.new(MapLoadError.Code.DB_INVALID)

	# 2. NOT_FOUND
	var manifest := map_db.get_map(id)
	if id.is_empty() or manifest == null:
		return MapLoadResult.new(MapLoadError.Code.NOT_FOUND)

	# 3. HOST_INVALID
	if not is_instance_valid(map_host) or map_host.is_queued_for_deletion() or not map_host.is_inside_tree():
		return MapLoadResult.new(MapLoadError.Code.HOST_INVALID, manifest)
	if map_host.is_ancestor_of(self):
		return MapLoadResult.new(MapLoadError.Code.HOST_INVALID, manifest)

	# 4. ALREADY_LOADED
	if is_loaded():
		return MapLoadResult.new(MapLoadError.Code.ALREADY_LOADED, manifest)

	# 5. HOST_OCCUPIED
	if map_host.get_child_count() > 0:
		return MapLoadResult.new(MapLoadError.Code.HOST_OCCUPIED, manifest)

	# 6. Validation & Classification
	var all_issues := map_db.validate()
	var target_issues: Array[MapValidationIssue] = []
	var non_fatal_issues: Array[MapValidationIssue] = []

	var is_target_duplicate := map_db.get_map_ids().count(id) > 1

	for issue in all_issues:
		var is_target := false
		if issue.context == manifest:
			is_target = true
		elif issue.code == &"duplicate_map_id" and is_target_duplicate:
			# A30: duplicate_map_id issues have MapDB context, but we consider
			# them target-scoped if the target ID is actually duplicated.
			is_target = true

		if is_target and issue.is_error():
			target_issues.append(issue)
		else:
			non_fatal_issues.append(issue)

	if not non_fatal_issues.is_empty():
		MapValidationIssue.log_all(self, non_fatal_issues)

	if not target_issues.is_empty():
		var code := MapLoadError.Code.INVALID_MANIFEST

		# Classification precedence (A28)
		var has_scene_missing := false
		var has_scene_invalid := false

		if manifest.scene == null:
			has_scene_missing = true

		for issue in target_issues:
			match issue.code:
				&"scene_missing":
					has_scene_missing = true
				&"scene_instantiate_failed", &"scene_root_invalid":
					has_scene_invalid = true

		if has_scene_missing:
			code = MapLoadError.Code.SCENE_MISSING
		elif has_scene_invalid:
			code = MapLoadError.Code.INVALID_SCENE

		return MapLoadResult.new(code, manifest, null, target_issues)

	# 7. NONE (Success)
	var root := manifest.scene.instantiate() as MapScene
	# Pre-condition: manifest.validate() already checked it's a MapScene.
	# If instantiate fails here (rare if validate passed), it's a hard error.
	if root == null:
		return MapLoadResult.new(MapLoadError.Code.INVALID_SCENE, manifest)

	map_host.add_child(root)
	root.transform = Transform3D.IDENTITY

	_active_map = LoadedMap.new(id, manifest, root)
	return MapLoadResult.new(MapLoadError.Code.NONE, manifest, _active_map)

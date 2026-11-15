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
	_prune_invalid_handle()
	var result := _execute_load(id)
	load_finished.emit(result)
	return result


func unload() -> void:
	_prune_invalid_handle()
	if _active_map == null:
		return

	var map := _active_map
	_active_map = null

	var root := map.get_root()
	if root != null and is_instance_valid(map_host) and root.get_parent() == map_host:
		map_host.remove_child(root)
		root.queue_free()
	# A root detached or reparented outside the host is owned by external code:
	# leave it alive and only drop the loader's reference.

	map.invalidate()
	map_unloaded.emit(map)


func is_loaded() -> bool:
	return _active_map != null and _active_map.is_valid()


func get_loaded_map() -> LoadedMap:
	if not is_loaded():
		return null
	return _active_map


## Drops a handle whose root was externally freed, detached, reparented, or
## queued for deletion. A queued root is still a host child until the deferred
## deletion runs, so detach it immediately to keep the host free for an
## immediate next load. No signal is emitted because this is not a
## loader-initiated unload.
func _prune_invalid_handle() -> void:
	if _active_map == null or _active_map.is_valid():
		return

	var map := _active_map
	_active_map = null

	var root := map._peek_root()
	if root != null and root.is_queued_for_deletion() \
			and is_instance_valid(map_host) and root.get_parent() == map_host:
		map_host.remove_child(root)

	map.invalidate()


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
		elif is_target_duplicate and issue.code == &"duplicate_map_id" and issue.map_id == id:
			# A30: duplicate_map_id issues have MapDB context and carry the
			# duplicated ID in `map_id`, so unrelated duplicates stay non-fatal.
			is_target = true

		if is_target and issue.is_error():
			target_issues.append(issue)
		else:
			non_fatal_issues.append(issue)

	if not non_fatal_issues.is_empty():
		MapValidationIssue.log_warnings(self, non_fatal_issues)

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
	var instance := manifest.scene.instantiate()
	if not (instance is MapScene):
		if is_instance_valid(instance):
			instance.free()
		return MapLoadResult.new(MapLoadError.Code.INVALID_SCENE, manifest)

	var root := instance as MapScene
	map_host.add_child(root)
	root.transform = Transform3D.IDENTITY

	_active_map = LoadedMap.new(id, manifest, root, map_host)
	return MapLoadResult.new(MapLoadError.Code.NONE, manifest, _active_map)

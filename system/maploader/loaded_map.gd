@tool
class_name LoadedMap
extends RefCounted

## Valid handle to a loaded map instance.
##
## Invalidated immediately on unload. While id and manifest remain accessible
## after invalidation, root returns null.

var id: StringName
var manifest: MapManifest
var root: MapScene:
	get: return get_root()

var _root: MapScene
var _is_valid: bool = true


func _init(p_id: StringName, p_manifest: MapManifest, p_root: MapScene) -> void:
	id = p_id
	manifest = p_manifest
	_root = p_root


func get_root() -> MapScene:
	if not is_valid():
		return null
	return _root


func is_valid() -> bool:
	return _is_valid and is_instance_valid(_root) and not _root.is_queued_for_deletion() and _root.is_inside_tree()


func invalidate() -> void:
	_is_valid = false
	_root = null

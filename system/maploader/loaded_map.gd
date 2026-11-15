@tool
class_name LoadedMap
extends RefCounted

## Valid handle to a loaded map instance.
##
## Invalidated immediately on unload. While id and manifest remain accessible
## after invalidation, root returns null. A handle is valid only while its root
## is alive, not queued for deletion, and still parented to the loader's host
## (A31); roots detached or reparented by external code are no longer tracked.

var id: StringName
var manifest: MapManifest
var root: MapScene:
	get: return get_root()

var _root: MapScene
var _host: Node3D
var _is_valid: bool = true


func _init(p_id: StringName, p_manifest: MapManifest, p_root: MapScene, p_host: Node3D) -> void:
	id = p_id
	manifest = p_manifest
	_root = p_root
	_host = p_host


func get_root() -> MapScene:
	if not is_valid():
		return null
	return _root


func is_valid() -> bool:
	if not _is_valid or not is_instance_valid(_root):
		return false
	if _root.is_queued_for_deletion():
		return false
	return is_instance_valid(_host) and _root.get_parent() == _host


func invalidate() -> void:
	_is_valid = false
	_root = null
	_host = null


## Internal helper for loader cleanup: returns the tracked root even when the
## handle is otherwise invalid. Freed roots return null.
func _peek_root() -> MapScene:
	return _root if is_instance_valid(_root) else null

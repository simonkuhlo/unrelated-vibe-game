@tool
class_name MapLoadResult
extends RefCounted

## Outcome of a map load attempt.
##
## Carries the result code, target manifest, active map handle (on success),
## and any target-scoped validation issues (on failure).

var code: MapLoadError.Code = MapLoadError.Code.NONE
var manifest: MapManifest
var map: LoadedMap
var issues: Array[MapValidationIssue] = []


func _init(p_code: MapLoadError.Code, p_manifest: MapManifest = null, p_map: LoadedMap = null, p_issues: Array[MapValidationIssue] = []) -> void:
	code = p_code
	manifest = p_manifest
	map = p_map
	issues = p_issues


func is_ok() -> bool:
	return code == MapLoadError.Code.NONE


func format_message() -> String:
	match code:
		MapLoadError.Code.NONE:
			return "Map loaded successfully: %s" % manifest.id
		MapLoadError.Code.NOT_FOUND:
			return "Map not found."
		MapLoadError.Code.DB_INVALID:
			return "Map database is invalid or null."
		MapLoadError.Code.HOST_INVALID:
			return "Map host is invalid, null, or improperly configured."
		MapLoadError.Code.HOST_OCCUPIED:
			return "Map host is already occupied by other nodes."
		MapLoadError.Code.ALREADY_LOADED:
			return "A map is already loaded. Unload it before loading another."
		MapLoadError.Code.INVALID_MANIFEST:
			return "Map manifest validation failed for '%s'." % (manifest.id if manifest else "unknown")
		MapLoadError.Code.SCENE_MISSING:
			return "Map scene is missing for '%s'." % (manifest.id if manifest else "unknown")
		MapLoadError.Code.INVALID_SCENE:
			return "Map scene is invalid for '%s'." % (manifest.id if manifest else "unknown")
		_:
			return "Unknown load error code: %d" % code

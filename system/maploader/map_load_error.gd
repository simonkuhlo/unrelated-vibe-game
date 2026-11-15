@tool
class_name MapLoadError
extends Object

## Standalone enum for map loading outcomes.
##
## Codes are used in MapLoadResult to identify success or specific failure
## modes. Execution order in the loader determines check precedence.

enum Code {
	## Success.
	NONE,
	## requested ID resolves to null in the DB.
	NOT_FOUND,
	## Loader has no map_db assigned.
	DB_INVALID,
	## Host is null, invalid, or loader is a descendant of the host.
	HOST_INVALID,
	## Host already has children.
	HOST_OCCUPIED,
	## A map is already active in the loader.
	ALREADY_LOADED,
	## Validation failed for the target manifest (excluding scene/duplicate issues).
	INVALID_MANIFEST,
	## Target manifest is missing a scene or the scene is null.
	SCENE_MISSING,
	## Target scene failed to instantiate or its root is not a MapScene.
	INVALID_SCENE,
}

@tool
class_name MapValidator
extends RefCounted

## Thin aggregation helpers for cross-object validation. Components own their
## own rules; this class only forwards and null-guards so callers can validate
## optional references without branching. It is not a god object: add checks to
## the owning component, not here.


static func validate_db(db: MapDB) -> Array[MapValidationIssue]:
	if db == null:
		return []
	return db.validate()


static func validate_manifest(manifest: MapManifest) -> Array[MapValidationIssue]:
	if manifest == null:
		return []
	return manifest.validate()


static func validate_scene(scene: MapScene) -> Array[MapValidationIssue]:
	if scene == null:
		return []
	return scene.validate()

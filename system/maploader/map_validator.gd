@tool
class_name MapValidator
extends RefCounted

static func validate_db(db: MapDB) -> Array[MapValidationIssue]:
	if db == null: return []
	return db.validate()

static func validate_manifest(manifest: MapManifest) -> Array[MapValidationIssue]:
	if manifest == null: return []
	return manifest.validate()

static func validate_scene(scene: MapScene) -> Array[MapValidationIssue]:
	if scene == null: return []
	return scene.validate()

@tool class_name MapValidatorNew

func is_map_manifest_valid(manifest: MapManifestNew) -> bool:
	return manifest.is_valid()

func is_map_scene_valid(manifest: MapManifestNew) -> bool:
	return true

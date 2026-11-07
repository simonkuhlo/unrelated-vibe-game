class_name LoadedMap
extends RefCounted
## Borrowed handle over a [MapManifest] and a live [MapScene] root.
##
## The loader owns [member root] and is the only system allowed to free it.
## Consumers must not keep a handle after [code]unload_finished[/code] and must
## never call [code]queue_free()[/code] on [member root]. Check
## [method is_valid] before using a handle whose lifetime is uncertain.

var manifest: MapManifest
var root: MapScene


## Delegates to [method MapScene.get_spawn_points].
func get_spawn_points() -> Array[Transform3D]:
	return root.get_spawn_points()


## Delegates to [method MapScene.get_marker].
func get_marker(marker_name: StringName) -> Node3D:
	return root.get_marker(marker_name)


## Delegates to [method MapScene.get_bounds].
func get_bounds() -> AABB:
	return root.get_bounds()


## Reserved; delegates to [method MapScene.apply_setup]. No caller in v1.
func apply_setup(config: Dictionary) -> void:
	root.apply_setup(config)


## True while [member root] points at a live node.
func is_valid() -> bool:
	return root != null and is_instance_valid(root)

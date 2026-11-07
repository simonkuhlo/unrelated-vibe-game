class_name MapScene
extends Node3D
## Base class for map roots.
##
## A map scene may define two optional child containers:
## - [code]SpawnPoints/[/code]: [Node3D] children are generic player spawns.
## - [code]Markers/[/code]: [Node3D] children are looked up by node name.
##
## Consumers treat both containers and their children as read-only: do not
## reparent or free them. Marker names such as [code]RedBase[/code] are a
## gamemode-level contract, not a maploader convention.
##
## The loader adds the map to the tree before calling [method get_spawn_points],
## so spawn transforms are world-space.


## Returns world-space spawn transforms.
##
## Reads the [Node3D] children of the optional [code]SpawnPoints/[/code]
## container in child order. Returns an empty array when the container is
## missing. The map must be inside the tree; the loader guarantees this.
func get_spawn_points() -> Array[Transform3D]:
	var points: Array[Transform3D] = []
	var container := get_node_or_null(^"SpawnPoints")
	if container == null:
		return points
	for child in container.get_children():
		if child is Node3D:
			points.append((child as Node3D).global_transform)
	return points


## Returns the named [Node3D] child of the optional [code]Markers/[/code]
## container, or [code]null[/code] when the map does not define it.
func get_marker(marker_name: StringName) -> Node3D:
	var markers := get_node_or_null(^"Markers")
	if markers == null:
		return null
	return markers.get_node_or_null(String(marker_name)) as Node3D


## Returns the playable bounds in map-local space. Optional.
##
## The default is an empty [AABB], meaning "bounds not set". Maps may override
## this method to expose real bounds.
func get_bounds() -> AABB:
	return AABB()


## Reserved for a future map config/setup feature (#10).
##
## The loader and gamemode do not call this in v1. When wired, implementations
## must be deterministic and idempotent and must not depend on local state.
func apply_setup(_config: Dictionary) -> void:
	pass

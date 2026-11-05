class_name MapManifest
extends Resource
## Metadata for one map version.
##
## Manifests are intentionally dependency-free: every reference is a plain
## [String] so an installed manifest can be read before its map pack is mounted.

@export var map_id: StringName
@export var version: String
@export var content_hash: String
@export var package_hash: String = ""
@export var display_name: String
@export var scene_path: String
@export var package_path: String = ""
@export var thumbnail_path: String = ""
@export var player_min: int = 1
@export var player_max: int = 32
@export var tags: PackedStringArray = []
@export var server_scene_path: String = ""

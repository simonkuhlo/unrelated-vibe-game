@tool
extends Resource
class_name MapManifestNew

@export var id: StringName
@export var version: String
@export var scene: PackedScene

@export var display_name: String = "Unnamed"
@export var thumbnail: Texture2D


func is_valid() -> bool:
	return true

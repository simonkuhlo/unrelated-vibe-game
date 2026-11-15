extends Node

## Game bootstrap. Owns the built-in map DB and the map loader, exposes the
## world host and UI, and binds the map browser to the loader.

@export var map_db: MapDB

@onready var _world: Node3D = $World
@onready var _map_host: Node3D = $World/MapHost
@onready var _ui: CanvasLayer = $UI
@onready var _map_browser: MapBrowser = $UI/MapBrowser

var _map_loader: MapLoader


func _ready() -> void:
	_map_loader = MapLoader.new()
	_map_loader.name = "MapLoader"
	_map_loader.map_db = map_db
	_map_loader.map_host = _map_host
	add_child(_map_loader)

	_map_browser.bind(map_db, _map_loader)


func get_map_db() -> MapDB:
	return map_db


func get_map_loader() -> MapLoader:
	return _map_loader


func get_map_host() -> Node3D:
	return _map_host


func get_world() -> Node3D:
	return _world


func get_ui() -> CanvasLayer:
	return _ui


func get_map_browser() -> MapBrowser:
	return _map_browser

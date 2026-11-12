@tool
extends Resource
class_name MapDBNew

# Daft note: Double source of truth for map id: Manifest vs DB key
@export_storage var _maps: Dictionary[StringName, MapManifestNew]

@export var quick_add_map: MapManifestNew:
	set(value):
		add_map(value)

# Daft note: will need some form of confirm mechanism in the real product
@export_tool_button("Clear DB content") var button_clear = clear_db

func add_map(map: MapManifestNew) -> void:
	# Validation here
	if !map.is_valid():
		return
	_maps[map.id] = map
	print("Map added.")

func remove_map(id: StringName) -> void:
	pass

func get_map(id: StringName) -> void:
	pass

func clear_db() -> void:
	_maps.clear()
	print("Map DB cleared.")

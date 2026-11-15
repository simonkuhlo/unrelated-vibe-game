class_name MapBrowser
extends PanelContainer

## Minimal map browser. Bootstrap owns the DB and loader; this control only
## reads the DB for its list and uses the loader's public API and signals.

var _map_db: MapDB
var _loader: MapLoader
var _map_ids: Array[StringName] = []

@onready var _map_list: ItemList = %MapList
@onready var _load_button: Button = %LoadButton
@onready var _unload_button: Button = %UnloadButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	_map_list.item_selected.connect(_on_item_selected)
	_map_list.item_activated.connect(_on_item_activated)
	_load_button.pressed.connect(_on_load_pressed)
	_unload_button.pressed.connect(_on_unload_pressed)
	_update_buttons()


## Binds the browser to the bootstrap-owned DB and loader. Safe to call again
## with a different pair; the previous loader signals are disconnected first.
func bind(map_db: MapDB, map_loader: MapLoader) -> void:
	_disconnect_loader()
	_map_db = map_db
	_loader = map_loader

	if _loader != null:
		_loader.load_finished.connect(_on_load_finished)
		_loader.map_unloaded.connect(_on_map_unloaded)

	_refresh_list()

	if _loader == null:
		_set_status("No map loader configured.")
	elif _loader.is_loaded():
		_set_status("Loaded %s." % _display_name(_loader.get_loaded_map().manifest))
	elif _map_db == null:
		_set_status("No map database configured.")
	else:
		_set_status("Select a map to load.")

	_update_buttons()


## Selects a map in the list. Returns false when the id is not in the DB.
func select_map(id: StringName) -> bool:
	var index := _find_map_index(id)
	if index < 0:
		return false

	_map_list.select(index)
	_update_buttons()
	return true


func get_selected_map_id() -> StringName:
	var selected := _map_list.get_selected_items()
	if selected.is_empty():
		return &""

	var index := selected[0]
	if index < 0 or index >= _map_ids.size():
		return &""
	return _map_ids[index]


## Loads a map through the loader. With an empty id, loads the selected entry.
## The loader emits `load_finished` synchronously, so the status is updated
## before this method returns.
func request_load(id: StringName = &"") -> void:
	if _loader == null:
		_set_status("No map loader configured.")
		_update_buttons()
		return

	var target := id
	if target.is_empty():
		target = get_selected_map_id()
	if target.is_empty():
		_set_status("Select a map to load.")
		_update_buttons()
		return

	_loader.load_map(target)
	_update_buttons()


func request_unload() -> void:
	if _loader == null:
		return

	_loader.unload()
	_update_buttons()


func get_map_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_map_ids)
	return ids


func get_status_text() -> String:
	return _status_label.text


func _refresh_list() -> void:
	_map_list.clear()
	_map_ids.clear()

	if _map_db != null:
		for manifest in _map_db.get_maps():
			_map_ids.append(manifest.id)
			var label := manifest.display_name
			if label.is_empty():
				label = str(manifest.id)
			var index := _map_list.add_item(label, manifest.thumbnail)
			_map_list.set_item_metadata(index, manifest.id)

	if _map_list.item_count > 0:
		_map_list.select(0)


func _find_map_index(id: StringName) -> int:
	for i in range(_map_ids.size()):
		if _map_ids[i] == id:
			return i
	return -1


func _on_item_selected(_index: int) -> void:
	_update_buttons()


func _on_item_activated(_index: int) -> void:
	request_load()


func _on_load_pressed() -> void:
	request_load()


func _on_unload_pressed() -> void:
	request_unload()


func _on_load_finished(result: MapLoadResult) -> void:
	if result.is_ok():
		_set_status("Loaded %s." % _display_name(result.manifest))
	else:
		var lines := PackedStringArray([result.format_message()])
		lines.append_array(MapValidationIssue.format_all(result.issues))
		_set_status("\n".join(lines))
	_update_buttons()


func _on_map_unloaded(map: LoadedMap) -> void:
	_set_status("Unloaded %s." % _display_name(map.manifest))
	_update_buttons()


func _update_buttons() -> void:
	var has_selection := not get_selected_map_id().is_empty()
	var is_loaded := _loader != null and _loader.is_loaded()
	_load_button.disabled = _loader == null or not has_selection or is_loaded
	_unload_button.disabled = not is_loaded


func _disconnect_loader() -> void:
	if _loader == null:
		return

	if _loader.load_finished.is_connected(_on_load_finished):
		_loader.load_finished.disconnect(_on_load_finished)
	if _loader.map_unloaded.is_connected(_on_map_unloaded):
		_loader.map_unloaded.disconnect(_on_map_unloaded)


func _set_status(text: String) -> void:
	_status_label.text = text


func _display_name(manifest: MapManifest) -> String:
	if manifest == null:
		return "map"
	if not manifest.display_name.is_empty():
		return manifest.display_name
	return str(manifest.id)

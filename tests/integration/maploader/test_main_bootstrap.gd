extends GdUnitTestSuite
## Integration coverage for the Phase 3 Main bootstrap and map browser wiring.

const MAIN_SCENE_PATH := "res://game/main.tscn"
const MAP_DB_PATH := "res://game/maps/map_db.tres"
const SAMPLE_MAP_ID := &"test_box"

var _main: Node
var _browser: MapBrowser


func before_test() -> void:
	var scene := load(MAIN_SCENE_PATH) as PackedScene
	assert_that(scene).override_failure_message("Failed to load %s" % MAIN_SCENE_PATH).is_not_null()
	if scene == null:
		return

	_main = auto_free(scene.instantiate()) as Node
	add_child(_main)
	_browser = _main.get_map_browser()


func test_main_owns_loader_outside_map_host() -> void:
	var loader := _main.get_map_loader() as MapLoader
	var host := _main.get_map_host() as Node3D

	assert_that(loader).is_not_null()
	assert_that(host).is_not_null()
	assert_that(_main.get_node("World/MapHost")).is_equal(host)
	assert_that(_main.get_node("UI")).is_not_null()
	assert_that(_browser).is_not_null()
	assert_that(loader.map_db).is_equal(load(MAP_DB_PATH))
	assert_that(loader.map_db).is_equal(_main.get_map_db())
	assert_that(loader.map_host).is_equal(host)
	assert_that(loader.get_parent()).is_equal(_main)
	assert_bool(host.is_ancestor_of(loader)).is_false()


func test_browser_lists_builtin_maps() -> void:
	var expected := (_main.get_map_db() as MapDB).get_map_ids()
	var actual := _browser.get_map_ids()

	assert_int(actual.size()).is_equal(expected.size())
	for i in range(expected.size()):
		assert_that(actual[i]).is_equal(expected[i])

	assert_that(_browser.get_selected_map_id()).is_equal(expected[0])


func test_browser_load_and_unload_round_trip() -> void:
	var loader := _main.get_map_loader() as MapLoader
	var host := _main.get_map_host() as Node3D

	assert_bool(_browser.select_map(SAMPLE_MAP_ID)).is_true()
	_browser.request_load()

	assert_bool(loader.is_loaded()).is_true()
	assert_int(host.get_child_count()).is_equal(1)
	assert_that(loader.get_loaded_map().id).is_equal(SAMPLE_MAP_ID)
	assert_str(_browser.get_status_text()).contains("Test box")

	if host.get_child_count() == 1:
		var root := host.get_child(0) as MapScene
		assert_that(root).is_not_null()
		if root != null:
			var spawns := root.markers.get_markers(PlayerSpawnFilter.new())
			assert_int(spawns.size()).is_equal(1)
			assert_bool(spawns[0] is PlayerSpawnPoint).is_true()

	_browser.request_unload()

	assert_bool(loader.is_loaded()).is_false()
	assert_int(host.get_child_count()).is_equal(0)
	assert_str(_browser.get_status_text()).contains("Unloaded")


func test_browser_surfaces_load_error() -> void:
	var host := _main.get_map_host() as Node3D

	_browser.request_load(&"missing_map")

	assert_int(host.get_child_count()).is_equal(0)
	assert_str(_browser.get_status_text()).contains("Map not found")

extends GdUnitTestSuite
## Covers MapScene/LoadedMap behavior that needs a live scene tree:
## world-space spawn transforms and the freed-root lifecycle.


func test_spawn_points_use_world_space() -> void:
	var world := auto_free(Node3D.new()) as Node3D
	world.position = Vector3(10.0, 0.0, 0.0)
	add_child(world)

	var map := auto_free(MapScene.new()) as MapScene
	map.position = Vector3(0.0, 5.0, 0.0)
	world.add_child(map)

	var container := auto_free(Node3D.new()) as Node3D
	container.name = "SpawnPoints"
	container.position = Vector3(0.0, 0.0, 1.0)
	map.add_child(container)

	var spawn_a := auto_free(Marker3D.new()) as Marker3D
	spawn_a.name = "SpawnA"
	spawn_a.position = Vector3(0.0, 0.0, 3.0)
	container.add_child(spawn_a)

	var spawn_b := auto_free(Marker3D.new()) as Marker3D
	spawn_b.name = "SpawnB"
	spawn_b.position = Vector3(1.0, 0.0, 0.0)
	container.add_child(spawn_b)

	var points := map.get_spawn_points()

	assert_array(points).has_size(2)
	assert_vector(points[0].origin).is_equal(Vector3(10.0, 5.0, 4.0))
	assert_vector(points[1].origin).is_equal(Vector3(11.0, 5.0, 1.0))


func test_spawn_points_skip_non_node3d_children() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	add_child(map)

	var container := auto_free(Node3D.new()) as Node3D
	container.name = "SpawnPoints"
	map.add_child(container)

	var spawn := auto_free(Marker3D.new()) as Marker3D
	spawn.name = "SpawnA"
	container.add_child(spawn)

	var not_a_spawn := auto_free(Node.new()) as Node
	not_a_spawn.name = "NotASpawn"
	container.add_child(not_a_spawn)

	assert_array(map.get_spawn_points()).has_size(1)


func test_loaded_map_delegates_spawn_points() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	map.position = Vector3(3.0, 4.0, 5.0)
	add_child(map)

	var container := auto_free(Node3D.new()) as Node3D
	container.name = "SpawnPoints"
	map.add_child(container)

	var spawn := auto_free(Marker3D.new()) as Marker3D
	spawn.name = "SpawnA"
	spawn.position = Vector3(1.0, 2.0, 3.0)
	container.add_child(spawn)

	var loaded := LoadedMap.new()
	loaded.root = map

	var points := loaded.get_spawn_points()

	assert_array(points).has_size(1)
	assert_vector(points[0].origin).is_equal(Vector3(4.0, 6.0, 8.0))


func test_is_valid_is_false_after_root_is_freed() -> void:
	var map := auto_free(MapScene.new()) as MapScene
	add_child(map)
	var loaded := LoadedMap.new()
	loaded.root = map
	assert_bool(loaded.is_valid()).is_true()

	map.free()

	assert_bool(loaded.is_valid()).is_false()

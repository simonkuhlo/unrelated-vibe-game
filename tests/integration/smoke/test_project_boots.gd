extends GdUnitTestSuite
## Seed test: the main scene must exist and instantiate.


func test_main_scene_loads() -> void:
	var scene := load("res://game/main.tscn") as PackedScene
	assert_that(scene).is_not_null()
	var instance := auto_free(scene.instantiate()) as Node
	assert_that(instance).is_not_null()
	assert_that(instance.name).is_equal("Main")

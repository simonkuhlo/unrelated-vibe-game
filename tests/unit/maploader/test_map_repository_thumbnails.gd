extends GdUnitTestSuite
## Covers synchronous thumbnail loading and the refresh-scoped cache.

const QUERY_CATALOG := "res://tests/fixtures/maps/repository/catalog_queries.tres"


func test_thumbnail_loads_as_texture() -> void:
	var repository := _repository()
	var manifest := repository.find(&"alpha")

	var texture := repository.load_thumbnail(manifest)

	assert_that(texture).is_not_null()
	assert_that(texture).is_instanceof(Texture2D)


func test_thumbnail_with_empty_path_returns_null() -> void:
	var repository := _repository()
	var manifest := MapManifest.new()

	assert_that(repository.load_thumbnail(manifest)).is_null()


func test_thumbnail_with_missing_path_returns_null() -> void:
	var repository := _repository()
	var manifest := MapManifest.new()
	manifest.thumbnail_path = "res://tests/fixtures/maps/thumbnails/does_not_exist.png"

	assert_that(repository.load_thumbnail(manifest)).is_null()


func test_repeated_thumbnail_loads_return_the_cached_texture() -> void:
	var repository := _repository()
	var manifest := repository.find(&"alpha")

	var first := repository.load_thumbnail(manifest)
	var second := repository.load_thumbnail(manifest)

	assert_that(first).is_not_null()
	assert_that(second).is_same(first)


func test_refresh_clears_the_thumbnail_cache() -> void:
	var repository := _repository()
	var manifest := repository.find(&"alpha")
	var first := repository.load_thumbnail(manifest)

	repository.refresh()
	var second := repository.load_thumbnail(manifest)

	assert_that(first).is_not_null()
	assert_that(second).is_not_null()
	assert_that(second).is_not_same(first)


func _repository() -> MapRepository:
	var sources: Array[MapCatalogSource] = [
		MapCatalogSource.new(QUERY_CATALOG, MapCatalogSource.Kind.BUILTIN)
	]
	var repository := MapRepository.new(sources)
	repository.refresh()
	return repository

extends GdUnitTestSuite
## Covers repository catalog loading, entry validation, and duplicate policy.

const QUERY_CATALOG := "res://tests/fixtures/maps/repository/catalog_queries.tres"
const DUPLICATES_CATALOG := "res://tests/fixtures/maps/repository/catalog_duplicates.tres"
const UNKNOWN_FORMAT_CATALOG := "res://tests/fixtures/maps/repository/catalog_unknown_format.tres"
const INVALID_MAP_ID_CATALOG := "res://tests/fixtures/maps/repository/catalog_invalid_map_id.tres"
const INVALID_VERSION_CATALOG := "res://tests/fixtures/maps/repository/catalog_invalid_version.tres"
const INVALID_CONTENT_HASH_CATALOG := "res://tests/fixtures/maps/repository/catalog_invalid_content_hash.tres"
const INVALID_PACKAGE_HASH_CATALOG := "res://tests/fixtures/maps/repository/catalog_invalid_package_hash.tres"
const INVALID_PLAYER_RANGE_CATALOG := "res://tests/fixtures/maps/repository/catalog_invalid_player_range.tres"
const EMPTY_SCENE_PATH_CATALOG := "res://tests/fixtures/maps/repository/catalog_empty_scene_path.tres"
const MISSING_SCENE_CATALOG := "res://tests/fixtures/maps/repository/catalog_missing_scene.tres"
const CANONICAL_TEST_CATALOG := "res://tests/fixtures/maps/catalog.tres"
const MISSING_CATALOG := "res://tests/fixtures/maps/does_not_exist.tres"

const HASH_A := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const HASH_B := "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"


func test_loads_builtin_catalog() -> void:
	var repository := _repository(QUERY_CATALOG)

	repository.refresh()

	assert_that(repository.list()).has_size(6)
	assert_that(repository.find(&"alpha")).is_not_null()
	assert_str(repository.find(&"alpha").version).is_equal("1.10.0")


func test_canonical_test_catalog_loads() -> void:
	var repository := _repository(CANONICAL_TEST_CATALOG)

	repository.refresh()

	assert_that(repository.list()).is_empty()


func test_refresh_emits_catalog_changed() -> void:
	var repository := _repository(QUERY_CATALOG)
	var emissions := [0]
	repository.catalog_changed.connect(func() -> void: emissions[0] += 1)

	repository.refresh()
	repository.refresh()

	assert_int(emissions[0]).is_equal(2)


func test_empty_repository_is_valid() -> void:
	var sources: Array[MapCatalogSource] = []
	var repository := MapRepository.new(sources)

	repository.refresh()

	assert_that(repository.list()).is_empty()
	assert_that(repository.find(&"alpha")).is_null()


func test_empty_source_path_is_skipped() -> void:
	var repository := _repository("")

	repository.refresh()

	assert_that(repository.list()).is_empty()


func test_missing_source_path_is_skipped_with_warning() -> void:
	var repository := _repository(MISSING_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning("MapRepository: skipping missing catalog '%s'" % MISSING_CATALOG)

	assert_that(repository.list()).is_empty()


func test_installed_source_yields_no_entries() -> void:
	var repository := _repository(QUERY_CATALOG, MapCatalogSource.Kind.INSTALLED)

	repository.refresh()

	assert_that(repository.list()).is_empty()
	assert_that(repository.find(&"alpha")).is_null()


func test_unknown_builtin_format_version_is_a_hard_error() -> void:
	var repository := _repository(UNKNOWN_FORMAT_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_error(
			"MapRepository: catalog '%s' has unsupported format_version 999"
			% UNKNOWN_FORMAT_CATALOG
		)

	assert_that(repository.list()).is_empty()


func test_invalid_map_id_is_dropped_with_warning() -> void:
	var repository := _repository(INVALID_MAP_ID_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning(_invalid_warning(
			"Bad-Id", "1.0.0", INVALID_MAP_ID_CATALOG, "map_id must match ^[a-z0-9_]+$"
		))

	assert_that(repository.list()).is_empty()


func test_invalid_version_is_dropped_with_warning() -> void:
	var repository := _repository(INVALID_VERSION_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning(_invalid_warning(
			"invalid_version", "1.02.0", INVALID_VERSION_CATALOG, "version must be strict numeric semver"
		))

	assert_that(repository.list()).is_empty()


func test_invalid_content_hash_is_dropped_with_warning() -> void:
	var repository := _repository(INVALID_CONTENT_HASH_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning(_invalid_warning(
			"invalid_content_hash",
			"1.0.0",
			INVALID_CONTENT_HASH_CATALOG,
			"content_hash must be empty or sha256:<64 lowercase hex>"
		))

	assert_that(repository.list()).is_empty()


func test_invalid_package_hash_is_dropped_with_warning() -> void:
	var repository := _repository(INVALID_PACKAGE_HASH_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning(_invalid_warning(
			"invalid_package_hash",
			"1.0.0",
			INVALID_PACKAGE_HASH_CATALOG,
			"package_hash must be empty or sha256:<64 lowercase hex>"
		))

	assert_that(repository.list()).is_empty()


func test_invalid_player_range_is_dropped_with_warning() -> void:
	var repository := _repository(INVALID_PLAYER_RANGE_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning(_invalid_warning(
			"invalid_player_range",
			"1.0.0",
			INVALID_PLAYER_RANGE_CATALOG,
			"player_min must be <= player_max"
		))

	assert_that(repository.list()).is_empty()


func test_empty_scene_path_is_dropped_with_warning() -> void:
	var repository := _repository(EMPTY_SCENE_PATH_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning(_invalid_warning(
			"empty_scene_path", "1.0.0", EMPTY_SCENE_PATH_CATALOG, "scene_path must not be empty"
		))

	assert_that(repository.list()).is_empty()


func test_missing_builtin_scene_is_dropped_with_error() -> void:
	var repository := _repository(MISSING_SCENE_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_error(
			"MapRepository: built-in map 'missing_scene' version '1.0.0' scene not found: "
			+ "res://tests/fixtures/maps/scenes/does_not_exist.tscn"
		)

	assert_that(repository.list()).is_empty()


func test_duplicate_hashes_are_deduplicated_and_different_hashes_kept() -> void:
	var repository := _repository(DUPLICATES_CATALOG)

	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning("MapRepository: map 'dupe' version '1.0.0' has multiple content hashes")

	assert_that(repository.list()).has_size(2)
	assert_str(repository.find_exact(&"dupe", "1.0.0", HASH_A).content_hash).is_equal(HASH_A)
	assert_str(repository.find_exact(&"dupe", "1.0.0", HASH_B).content_hash).is_equal(HASH_B)


func _repository(
	path: String,
	kind: MapCatalogSource.Kind = MapCatalogSource.Kind.BUILTIN
) -> MapRepository:
	var sources: Array[MapCatalogSource] = [MapCatalogSource.new(path, kind)]
	return MapRepository.new(sources)


func _invalid_warning(map_id: String, version: String, catalog: String, problem: String) -> String:
	return "MapRepository: dropping invalid manifest '%s' version '%s' from '%s': %s" % [
		map_id,
		version,
		catalog,
		problem,
	]

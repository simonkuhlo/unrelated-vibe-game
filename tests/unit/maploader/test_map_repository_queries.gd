extends GdUnitTestSuite
## Covers deterministic ordering and repository query semantics.

const QUERY_CATALOG := "res://tests/fixtures/maps/repository/catalog_queries.tres"
const DUPLICATES_CATALOG := "res://tests/fixtures/maps/repository/catalog_duplicates.tres"

const HASH_A := "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const HASH_B := "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"


func test_list_is_deterministic() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	var actual: Array[String] = []
	for manifest in repository.list():
		actual.append("%s@%s" % [String(manifest.map_id), manifest.version])

	assert_that(actual).is_equal([
		"alpha@1.10.0",
		"alpha@1.9.0",
		"alpha@1.2.0",
		"bravo@1.0.0",
		"hashed@1.0.0",
		"zulu@0.1.0",
	])


func test_find_returns_highest_semver() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_str(repository.find(&"alpha").version).is_equal("1.10.0")


func test_find_unknown_map_returns_null() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_that(repository.find(&"missing")).is_null()


func test_find_version_returns_matching_entry() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_str(repository.find_version(&"alpha", "1.9.0").version).is_equal("1.9.0")


func test_find_version_unknown_returns_null() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_that(repository.find_version(&"alpha", "3.0.0")).is_null()


func test_find_exact_returns_matching_hash() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	var manifest := repository.find_exact(&"hashed", "1.0.0", HASH_A)

	assert_that(manifest).is_not_null()
	assert_str(manifest.display_name).is_equal("Hashed 1.0.0")


func test_find_exact_with_empty_hash_returns_preferred_entry() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	var manifest := repository.find_exact(&"hashed", "1.0.0", "")

	assert_that(manifest).is_not_null()
	assert_str(manifest.content_hash).is_equal(HASH_A)


func test_find_exact_with_wrong_version_returns_null() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_that(repository.find_exact(&"hashed", "2.0.0", HASH_A)).is_null()


func test_find_exact_with_wrong_hash_returns_null() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_that(repository.find_exact(&"hashed", "1.0.0", HASH_B)).is_null()


func test_find_exact_with_invalid_version_returns_null() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_that(repository.find_exact(&"hashed", "1.2", HASH_A)).is_null()


func test_has_exact() -> void:
	var repository := _repository(QUERY_CATALOG)
	repository.refresh()

	assert_bool(repository.has_exact(&"hashed", "1.0.0", HASH_A)).is_true()
	assert_bool(repository.has_exact(&"hashed", "1.0.0", HASH_B)).is_false()
	assert_bool(repository.has_exact(&"hashed", "1.0.0", "")).is_true()


func test_same_version_prefers_smallest_hash() -> void:
	var repository := _repository(DUPLICATES_CATALOG)
	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning("MapRepository: map 'dupe' version '1.0.0' has multiple content hashes")

	assert_str(repository.find(&"dupe").content_hash).is_equal(HASH_A)
	assert_str(repository.find_version(&"dupe", "1.0.0").content_hash).is_equal(HASH_A)
	assert_str(repository.find_exact(&"dupe", "1.0.0", "").content_hash).is_equal(HASH_A)
	assert_str(repository.find_exact(&"dupe", "1.0.0", HASH_B).content_hash).is_equal(HASH_B)


func test_list_orders_same_version_hashes_ascending() -> void:
	var repository := _repository(DUPLICATES_CATALOG)
	await assert_error(func() -> void: repository.refresh()) \
		.is_push_warning("MapRepository: map 'dupe' version '1.0.0' has multiple content hashes")

	var hashes: Array[String] = []
	for manifest in repository.list():
		hashes.append(manifest.content_hash)

	assert_that(hashes).is_equal([HASH_A, HASH_B])


func _repository(path: String) -> MapRepository:
	var sources: Array[MapCatalogSource] = [
		MapCatalogSource.new(path, MapCatalogSource.Kind.BUILTIN)
	]
	return MapRepository.new(sources)

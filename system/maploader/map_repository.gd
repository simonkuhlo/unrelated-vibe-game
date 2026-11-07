class_name MapRepository
extends RefCounted
## App-scoped local map database.
##
## v1 indexes built-in maps only. Installed sources are described by
## [MapCatalogSource] but deliberately yield no entries until downloadable map
## packs land. The repository validates metadata only; it does not load scenes,
## mount packs, hash content, or mutate game state.

signal catalog_changed()

const _MAP_ID_PATTERN := "\\A[a-z0-9_]+\\z"
const _VERSION_PATTERN := "\\A(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\z"
const _HASH_PATTERN := "\\Asha256:[0-9a-f]{64}\\z"
const _SOURCE_RANK_BUILTIN := 0
const _SOURCE_RANK_INSTALLED := 1

static var _map_id_regex: RegEx = RegEx.create_from_string(_MAP_ID_PATTERN)
static var _version_regex: RegEx = RegEx.create_from_string(_VERSION_PATTERN)
static var _hash_regex: RegEx = RegEx.create_from_string(_HASH_PATTERN)

var _sources: Array[MapCatalogSource] = []
var _entries: Array[_Entry] = []
var _thumbnail_cache: Dictionary = {}


class _Entry:
	var manifest: MapManifest
	var source_rank: int

	func _init(p_manifest: MapManifest, p_source_rank: int) -> void:
		manifest = p_manifest
		source_rank = p_source_rank


func _init(sources: Array[MapCatalogSource]) -> void:
	_sources.assign(sources)


## Reloads catalogs, re-validates entries, and emits [signal catalog_changed].
func refresh() -> void:
	_entries.clear()
	_thumbnail_cache.clear()

	var seen_keys: Dictionary = {}
	var hashes_by_version: Dictionary = {}
	for source in _ordered_sources():
		# Installed sources are described in v1 but load no entries until
		# downloadable map packs land (see docs/maploader.md).
		if source.kind != MapCatalogSource.Kind.BUILTIN:
			continue
		if source.path.is_empty():
			continue
		if not ResourceLoader.exists(source.path):
			push_warning("MapRepository: skipping missing catalog '%s'" % source.path)
			continue
		_collect_catalog(
			source,
			_source_rank(source.kind),
			seen_keys,
			hashes_by_version
		)

	_sort_entries()
	catalog_changed.emit()


## All valid entries in deterministic order. May contain multiple versions.
## Returned manifests are shared, read-only resources: do not mutate them.
func list() -> Array[MapManifest]:
	var result: Array[MapManifest] = []
	for entry in _entries:
		result.append(entry.manifest)
	return result


## Preferred entry for a map id (highest semver; built-in wins ties).
## Relies on the order applied by [method _sort_entries].
func find(map_id: StringName) -> MapManifest:
	for entry in _entries:
		if entry.manifest.map_id == map_id:
			return entry.manifest
	return null


## Preferred entry for a specific version, ignoring hash.
## Relies on the order applied by [method _sort_entries].
func find_version(map_id: StringName, version: String) -> MapManifest:
	for entry in _entries:
		if entry.manifest.map_id == map_id and entry.manifest.version == version:
			return entry.manifest
	return null


## Exact authority match. An empty [param content_hash] matches any hash for the
## version, which is the v1 built-in contract until content hashing lands.
func find_exact(map_id: StringName, version: String, content_hash: String) -> MapManifest:
	if content_hash.is_empty():
		return find_version(map_id, version)
	for entry in _entries:
		if entry.manifest.map_id == map_id \
				and entry.manifest.version == version \
				and entry.manifest.content_hash == content_hash:
			return entry.manifest
	return null


func has_exact(map_id: StringName, version: String, content_hash: String) -> bool:
	return find_exact(map_id, version, content_hash) != null


## Loads a thumbnail synchronously on demand and caches the result until
## [method refresh] runs. Returns [code]null[/code] when unavailable.
func load_thumbnail(manifest: MapManifest) -> Texture2D:
	if manifest == null or manifest.thumbnail_path.is_empty():
		return null

	var path := manifest.thumbnail_path
	if _thumbnail_cache.has(path):
		return _thumbnail_cache[path] as Texture2D

	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		# Bypass the engine-wide resource cache so the repository cache is the
		# only cache; this makes refresh() semantics observable and predictable.
		var resource := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE)
		if resource is Texture2D:
			texture = resource as Texture2D

	_thumbnail_cache[path] = texture
	return texture


## Sources in precedence order. Source kind, not construction order, decides
## which entry wins when two sources describe the same content.
func _ordered_sources() -> Array[MapCatalogSource]:
	var result: Array[MapCatalogSource] = []
	for source in _sources:
		if source != null:
			result.append(source)
	result.sort_custom(_is_source_before)
	return result


func _is_source_before(a: MapCatalogSource, b: MapCatalogSource) -> bool:
	var a_rank := _source_rank(a.kind)
	var b_rank := _source_rank(b.kind)
	if a_rank != b_rank:
		return a_rank < b_rank
	return a.path < b.path


func _collect_catalog(
	source: MapCatalogSource,
	source_rank: int,
	seen_keys: Dictionary,
	hashes_by_version: Dictionary
) -> void:
	var resource := ResourceLoader.load(source.path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		push_warning("MapRepository: could not load catalog '%s'" % source.path)
		return
	if not resource is MapCatalog:
		push_warning("MapRepository: '%s' is not a MapCatalog" % source.path)
		return

	var catalog := resource as MapCatalog
	if catalog.format_version != MapCatalog.CURRENT_FORMAT_VERSION:
		push_error(
			"MapRepository: catalog '%s' has unsupported format_version %d"
			% [source.path, catalog.format_version]
		)
		return

	for manifest in catalog.entries:
		if manifest == null:
			push_warning("MapRepository: dropping null manifest entry in '%s'" % source.path)
			continue
		_accept_manifest(manifest, source_rank, source.path, seen_keys, hashes_by_version)


func _accept_manifest(
	manifest: MapManifest,
	source_rank: int,
	catalog_path: String,
	seen_keys: Dictionary,
	hashes_by_version: Dictionary
) -> void:
	var problems := _validate_manifest(manifest)
	if not problems.is_empty():
		push_warning(
			"MapRepository: dropping invalid manifest '%s' version '%s' from '%s': %s"
			% [
				String(manifest.map_id),
				manifest.version,
				catalog_path,
				", ".join(problems),
			]
		)
		return

	var key := _dedupe_key(manifest)
	if seen_keys.has(key):
		return

	if source_rank == _SOURCE_RANK_BUILTIN \
			and not ResourceLoader.exists(manifest.scene_path, "PackedScene"):
		push_error(
			"MapRepository: built-in map '%s' version '%s' scene not found or not a PackedScene: %s"
			% [String(manifest.map_id), manifest.version, manifest.scene_path]
		)
		return

	if _has_other_hash(manifest, hashes_by_version):
		push_warning(
			"MapRepository: map '%s' version '%s' has multiple content hashes"
			% [String(manifest.map_id), manifest.version]
		)

	seen_keys[key] = true
	_remember_hash(manifest, hashes_by_version)
	_entries.append(_Entry.new(manifest, source_rank))


func _has_other_hash(manifest: MapManifest, hashes_by_version: Dictionary) -> bool:
	var seen_hashes: Dictionary = hashes_by_version.get(_version_key(manifest), {})
	for seen_hash in seen_hashes:
		if seen_hash != manifest.content_hash:
			return true
	return false


func _remember_hash(manifest: MapManifest, hashes_by_version: Dictionary) -> void:
	var version_key := _version_key(manifest)
	var seen_hashes: Dictionary = hashes_by_version.get(version_key, {})
	seen_hashes[manifest.content_hash] = true
	hashes_by_version[version_key] = seen_hashes


func _sort_entries() -> void:
	_entries.sort_custom(_is_sorted_before)


func _is_sorted_before(a: _Entry, b: _Entry) -> bool:
	var a_id := String(a.manifest.map_id)
	var b_id := String(b.manifest.map_id)
	if a_id != b_id:
		return a_id < b_id

	var version_order := _compare_versions(a.manifest.version, b.manifest.version)
	if version_order != 0:
		return version_order > 0

	if a.source_rank != b.source_rank:
		return a.source_rank < b.source_rank

	return a.manifest.content_hash < b.manifest.content_hash


static func _source_rank(kind: MapCatalogSource.Kind) -> int:
	match kind:
		MapCatalogSource.Kind.BUILTIN:
			return _SOURCE_RANK_BUILTIN
		MapCatalogSource.Kind.INSTALLED:
			return _SOURCE_RANK_INSTALLED
	return _SOURCE_RANK_INSTALLED


static func _version_key(manifest: MapManifest) -> String:
	return "%s|%s" % [String(manifest.map_id), manifest.version]


static func _dedupe_key(manifest: MapManifest) -> String:
	return "%s|%s" % [_version_key(manifest), manifest.content_hash]


static func _validate_manifest(manifest: MapManifest) -> PackedStringArray:
	var problems := PackedStringArray()

	if _map_id_regex.search(String(manifest.map_id)) == null:
		problems.append("map_id must match ^[a-z0-9_]+$")
	if _version_regex.search(manifest.version) == null:
		problems.append("version must be strict numeric semver")
	if not manifest.content_hash.is_empty() and _hash_regex.search(manifest.content_hash) == null:
		problems.append("content_hash must be empty or sha256:<64 lowercase hex>")
	if not manifest.package_hash.is_empty() and _hash_regex.search(manifest.package_hash) == null:
		problems.append("package_hash must be empty or sha256:<64 lowercase hex>")
	if manifest.scene_path.is_empty():
		problems.append("scene_path must not be empty")
	if manifest.player_min > manifest.player_max:
		problems.append("player_min must be <= player_max")

	return problems


static func _compare_versions(a: String, b: String) -> int:
	var a_parts := _parse_version(a)
	var b_parts := _parse_version(b)
	for index in 3:
		if a_parts[index] < b_parts[index]:
			return -1
		if a_parts[index] > b_parts[index]:
			return 1
	return 0


static func _parse_version(version: String) -> Array[int]:
	var parts: Array[int] = []
	for part in version.split("."):
		parts.append(part.to_int())
	return parts

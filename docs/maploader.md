# Map Loader

**Status:** Partially implemented. Map data and the built-in repository (#12) are
implemented; the loader, map content, and UI are pending.

This document defines the map loader system: the client-side map database, the
map loading lifecycle, and the contracts that the future multiplayer session and
gamemode systems use to interact with a loaded map.

## Purpose

The map loader is responsible for two things:

1. Knowing which maps a client has stored locally.
2. Loading and unloading one of those maps into the running game.

It deliberately does **not** know about networking, lobbies, gamemodes, or UI.
Those systems consume the loader through the contracts defined here.

## Terminology

| Term | Meaning |
|---|---|
| **Map** | Immutable, installable content: a manifest, a scene, its assets, and its markers. What the repository indexes and the loader loads. |
| **World** | The live runtime subtree where a loaded map and gamemode entities exist for the duration of a match. |
| **Map instance** | The instantiated map scene, rooted at a `MapScene` node. |
| **Gamemode** | The rules layered on top of a loaded map. Not covered by this document. |
| **Repository** | The app-scoped local map database. Answers "what maps do I have?" Owned by `Main`. |
| **Pack registry** | Future: the app-scoped record of PCKs mounted for the process lifetime. Not in v1. |
| **Loader** | The service that loads a map into a `MapHost`, using the repository. Session-scoped in the target design; owned by `Main` in v1. |

The key distinction is **map = content, world = runtime**. The session loads a
map into the world.

## Design principles

- **Separate concerns.** The repository knows what exists; the loader knows how
  to bring it into the tree; the gamemode knows what to do with it.
- **Local first.** Every peer resolves maps from its own repository. Authority
  sends map identity, never a scene path.
- **Deterministic content.** All peers must run identical map content. Matching
  is exact on `map_id + version` plus `content_hash` when a hash is present. v1
  built-in manifests leave the hash empty; the hashing pipeline is a separate
  workstream (see [Content hashing](#content-hashing-deferred)).
- **No scene transitions.** Maps are sub-scenes added to a host node. The main
  scene, session, and UI are never replaced by a map load.
- **Fail cleanly.** Every load ends in either `load_finished` or `load_failed`.
  Partial state is cleaned up before the loader reports the result.

## v1 scope

v1 ships **built-in maps only**. Installed packs, hashing, and the session layer
are designed here but not built until their own workstreams exist.

**In v1:**

- `MapManifest`, `MapCatalog`, `MapCatalogSource`, `MapRepository` (built-in
  source only), `MapScene`, `LoadedMap`, `MapLoader`, `MapHost`.
- `Main` bootstraps the repository and loads/unloads maps into `World/MapHost`.
- A minimal map browser UI: list local maps, show thumbnails, request
  load/unload.
- A gdUnit4 test suite under `tests/` (see [testing.md](testing.md)) and the
  `tests/fixtures/maps/test_box` fixture.
- Reserved manifest fields (`content_hash`, `package_hash`, `package_path`,
  `server_scene_path`) exist but are empty. `apply_setup()` exists as a no-op.

**Not in v1:**

- Content hashing and hash verification (separate workstream).
- `MapPackRegistry`, installed maps, `user://maps` catalogs, and the
  download/install flow (separate workstream).
- Async thumbnails, preview loading, headless/server scenes, and map
  config/setup ([#10](https://github.com/simonkuhlo/unrelated-vibe-game/issues/10)).
- Repo-wide test automation beyond the PR gate; the nightly export smoke is
  configured separately in `.github/workflows/`.

Because v1 has no hashing pipeline, an empty `content_hash` means "any hash for
this version" in `find_exact()` and `load_map()`. The exact-hash contract becomes
active once hashing lands.

## Core concepts

| Class | Type | Scope | Responsibility |
|---|---|---|---|
| `MapManifest` | `Resource` | data | Metadata for one map version. |
| `MapCatalog` | `Resource` | data | A persisted list of manifests. |
| `MapCatalogSource` | `RefCounted` | data | A catalog path plus its source kind. |
| `MapRepository` | `RefCounted` | app | Local map database and queries. |
| `MapLoader` | `Node` | session | Async load/unload lifecycle. |
| `MapHost` | `Node3D` | world | Container the map instance is added to. |
| `MapScene` | `Node3D` | map content | Base class for map roots. |
| `LoadedMap` | `RefCounted` | handle | Manifest + live map instance. |

`MapHost` is a plain `Node3D`; it does not need a custom script. It exists to
make placement explicit and to support future uses such as preview loading into
a `SubViewport`.

v1 has no pack registry and no installed-source implementation; those arrive
with downloadable maps (see [v1 scope](#v1-scope) and
[Future extensions](#future-extensions)).

## Data contracts

### `MapManifest`

A manifest describes one map version. It must be **dependency-free**: every
reference is a `String`, not a typed resource. This is what allows a manifest to
be read before an installed map pack is mounted.

```gdscript
class_name MapManifest
extends Resource

@export var map_id: StringName
@export var version: String
@export var content_hash: String
@export var package_hash: String = ""
@export var display_name: String
@export var scene_path: String
@export var package_path: String = ""
@export var thumbnail_path: String = ""
@export var player_min: int = 1
@export var player_max: int = 32
@export var tags: PackedStringArray = []
@export var server_scene_path: String = ""
```

Rules:

- `map_id` is a stable lowercase slug matching `^[a-z0-9_]+$`, e.g.
  `&"arena_foundry"`. It never changes for a map.
- `version` is a strict numeric semver string (`MAJOR.MINOR.PATCH`). Prerelease
  and build metadata are not supported. A content change requires a new version.
- `content_hash` identifies the map's logical content and is the authority for
  match checks once the hashing pipeline exists. It is comparable across
  built-in and installed sources. Format: `sha256:<64 lowercase hex>`, or empty.
  **v1 built-in manifests leave it empty**; hashing is a separate workstream.
  When empty, matching falls back to `map_id + version` (see
  [Content hashing](#content-hashing-deferred)).
- `package_hash` is reserved for installed packs and is empty in v1. When used,
  it is the SHA-256 of the `.pck` bytes for download/integrity checks and is
  never used for exact matching. Its format matches `content_hash`.
- All path fields are plain `String`s, intentionally without `@export_file`.
  Godot file hints imply editor-time project paths, but installed manifests are
  generated at runtime and resolve paths inside `user://` packs. A validation
  tool checks built-in paths instead.
- `scene_path` points at the map scene. For built-in maps it is under `res://`.
  For installed maps it is a versioned virtual path inside the mounted pack,
  e.g. `res://maps/arena_foundry/1.2.0/map.tscn`.
- `package_path` is reserved for installed packs and is empty in v1.
- `thumbnail_path` is loaded on demand. For built-in maps it points under
  `res://`. For installed maps it is a sidecar outside the pack at
  `user://maps/<map_id>/<version>/thumbnail.png`, so the repository can load it
  without mounting the pack. Never store a `Texture2D` on the manifest. The
  repository caches loaded thumbnails until `refresh()`.
- `server_scene_path` is reserved for a future headless/server variant. Empty
  means "use `scene_path`".

### Content hashing (deferred)

v1 does not compute, verify, or require content hashes. Built-in manifests leave
`content_hash` empty and the repository validates the format only. The hashing
pipeline is tracked in its own workstream.

The contract to implement when hashing lands:

- `content_hash` uses the format `sha256:<64 lowercase hex>` and identifies the
  map's logical content, independent of how it is distributed.
- A headless Godot script under `scripts/` computes a deterministic hash of the
  map scene and its dependency closure. Paths are relative to the **map root**,
  not the project root, so built-in and packed content hash identically. For each
  file, sorted by relative path, hash the file bytes with SHA-256, then hash the
  concatenation of `relative_path + "\0" + file_hash + "\n"`.
- Scene and resource files must be canonicalized (normalized `res://` references)
  before hashing. A `.tscn` embeds absolute resource paths and UIDs, so raw bytes
  are not distribution-independent.
- The dependency closure includes the scene and all resources it references
  (sub-scenes, meshes, materials, textures, scripts, audio, and so on). The
  manifest, catalog, and thumbnail are metadata, not part of the logical content
  hash.
- Installed packs use the same logical hash, computed over the source closure
  before packing. The PCK's own bytes are covered by the optional
  `package_hash`; PCK reproducibility is not required.
- The install flow verifies `package_hash` when present. The repository validates
  the format only; it cannot recompute either hash. A content change requires a
  new `version` and a new `content_hash`.
- The hash is **build-time trust**, not runtime verification. The loader never
  recomputes it, so "all peers run identical content" depends on the build
  pipeline being correct.

### `MapCatalog`

A catalog is a persisted list of manifests.

```gdscript
class_name MapCatalog
extends Resource

const CURRENT_FORMAT_VERSION := 1

@export var format_version: int = CURRENT_FORMAT_VERSION
@export var entries: Array[MapManifest] = []
```

The catalog is an **index/cache**, not the authority. Entries are validated
against the filesystem when the repository loads them. Invalid or stale entries
are dropped; catalog-level problems are handled as described below.

Catalog shapes differ by source:

- **Built-in catalogs** are hand-authored and may reference manifests with
  `ext_resource`; those manifests are real resource dependencies of the catalog.
- **Installed catalogs** embed manifest data and must not reference sidecar files
  with `ext_resource`, so uninstalling one map cannot break the whole catalog.

Catalog-to-manifest `ext_resource` references do not make the catalog itself a
guaranteed export dependency: `Main` references the catalog by a runtime string.
The export preset therefore still uses **Export all resources in the project**
(see [Export inclusion](#export-inclusion)).

If the installed catalog is missing, corrupt, or has an unknown `format_version`,
the repository rebuilds it from sidecars (future). A built-in catalog with an
unknown `format_version` is a **hard error**: the repository refuses that catalog
and yields no built-in entries, logging an error. Silently dropping entries would
empty the game without an obvious cause.

### `MapScene`

`MapScene` is the base class for map roots. It gives map authors a stable API and
gives the loader a way to validate a map scene.

```gdscript
class_name MapScene
extends Node3D

## Returns world-space spawn transforms.
## The loader guarantees the map is in the tree before this is called.
func get_spawn_points() -> Array[Transform3D]:
	var points: Array[Transform3D] = []
	var container := get_node_or_null(^"SpawnPoints")
	if container == null:
		return points
	for child in container.get_children():
		if child is Node3D:
			points.append((child as Node3D).global_transform)
	return points

## Returns a named marker, or null if the map does not define it.
func get_marker(marker_name: StringName) -> Node3D:
	var markers := get_node_or_null(^"Markers")
	if markers == null:
		return null
	return markers.get_node_or_null(String(marker_name)) as Node3D

## Returns the playable bounds in map-local space. Optional.
## An empty AABB() means "bounds not set".
func get_bounds() -> AABB:
	return AABB()

## Reserved for a future map config/setup feature.
## The loader and gamemode do not call this in v1. When wired, implementations
## must be deterministic and idempotent and must not depend on local state.
func apply_setup(_config: Dictionary) -> void:
	pass
```

**Marker convention:**

- `SpawnPoints/` contains `Marker3D` children used for generic player spawns.
- `Markers/` contains `Marker3D` children looked up by node name, e.g.
  `Markers/RedBase`, `Markers/BlueBase`, `Markers/ObjectiveA`.
- Markers and spawn points are read-only for consumers; do not reparent or
  free them.
- Marker names such as `RedBase` are a gamemode-level contract, not a generic
  `system/maploader` convention.
- Maps may override any method for custom behavior.

The loader rejects a scene whose root is not a `MapScene` with `INVALID_SCENE`.

### `LoadedMap`

`LoadedMap` is the handle passed to consumers. It is the only thing a gamemode
needs in order to interact with the map.

```gdscript
class_name LoadedMap
extends RefCounted

var manifest: MapManifest
var root: MapScene

func get_spawn_points() -> Array[Transform3D]:
	return root.get_spawn_points()

func get_marker(marker_name: StringName) -> Node3D:
	return root.get_marker(marker_name)

func get_bounds() -> AABB:
	return root.get_bounds()

func apply_setup(config: Dictionary) -> void:
	root.apply_setup(config)  # Reserved; no caller in v1.

func is_valid() -> bool:
	return root != null and is_instance_valid(root)
```

`LoadedMap` is a borrowed handle. The loader owns the map root and is the only
system allowed to free it. Consumers must not keep a `LoadedMap` reference after
`unload_finished`, and must never call `queue_free()` on `root`.

## Map repository

The repository is the client's local map database. It is **app-scoped** and
shared by the map browser UI and any session. `Main` creates it, calls
`refresh()` at startup, and injects it into the session and UI.

`refresh()` always emits `catalog_changed()`, even when the repository is empty
or a catalog is refused. Thumbnail loading bypasses Godot's engine-wide resource
cache so the repository's path cache is the only cache; `refresh()` therefore
releases cached thumbnails deterministically.

### Sources

| Source | Catalog path | Persistence | Notes |
|---|---|---|---|
| Built-in | `res://game/maps/catalog.tres` | Hand-authored | Immutable. May reference manifests with `ext_resource`. |
| Installed (future) | `user://maps/catalog.tres` | Generated | Must be self-contained and rebuildable. |

`MapRepository` receives source descriptors at construction, so it can apply
source precedence and ordering without hardcoding `game/maps`:

```gdscript
class_name MapCatalogSource
extends RefCounted

enum Kind { BUILTIN, INSTALLED }

var path: String
var kind: Kind

func _init(p_path: String, p_kind: Kind) -> void:
	path = p_path
	kind = p_kind
```

Empty or missing paths are skipped; a repository with no catalogs is valid but
empty. Source kind, not catalog order, defines precedence. Sources are processed
in source-rank order, then by path, so descriptor order cannot change which
entry wins.

v1 constructs the repository with the built-in descriptor only.

### Bootstrap and ownership

- `Main` (`game/main.gd`) owns the app-scoped `MapRepository`. There is no
  autoload.
- At startup, `Main` creates the repository with a built-in source descriptor
  (and an installed descriptor once that feature exists), calls `refresh()`, and
  injects it into the map-browser UI (and the session once it exists).
- v1 has no `MapPackRegistry`; it arrives with installed packs.
- The future install/uninstall flow calls `refresh()` after changing
  `user://maps`. `refresh()` re-validates entries, clears the thumbnail cache,
  and emits `catalog_changed()`.
- `find()`, `find_version()`, and `find_exact()` return `null` when no entry
  matches.

### Installed catalog rules (future, not in v1)

- Installed maps live in version-scoped directories:

  ```text
  user://maps/
  ├── catalog.tres
  └── <map_id>/
      └── <version>/
          ├── manifest.tres
          ├── thumbnail.png
          └── content.pck
  ```

- `manifest.tres` is a sidecar, readable without mounting the pack.
- `content.pck` contains the content with a versioned internal root
  `res://maps/<map_id>/<version>/`.
- `thumbnail.png` is a sidecar outside the pack so the map browser can show it
  before the pack is mounted.
- The catalog must embed manifest data rather than reference sidecar files with
  `ext_resource`. Otherwise uninstalling one map can break the whole catalog.
- If the catalog is missing, corrupt, or has an unknown `format_version`, the
  repository rebuilds it by scanning `user://maps/*/*/manifest.tres` in sorted
  path order.
- Installing a new version does not overwrite existing versions. Uninstalling a
  version removes its directory; remove the map directory when no versions
  remain.
- Godot cannot unmount a PCK. Once mounted, a pack stays mounted for the process
  lifetime. The versioned internal root prevents collisions between versions.

### Validation

The repository validates metadata only:

- `map_id` matches `^[a-z0-9_]+$` (stable lowercase slug).
- `version` matches `^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`
  (strict numeric semver; no leading zeros, prerelease, or build metadata).
- `content_hash` is empty or matches `^sha256:[0-9a-f]{64}$`. v1 built-in
  manifests use the empty form.
- `package_hash` is empty or matches `^sha256:[0-9a-f]{64}$`.
- `scene_path` is non-empty.
- `player_min <= player_max`.
- Invalid entries are dropped with a warning.
- Version ordering always uses numeric semver comparison, never string
  comparison (`1.10.0` sorts above `1.9.0`).
- Duplicate `(map_id, version, content_hash)` entries are silently deduplicated.
- Duplicate `(map_id, version)` entries with different hashes are **kept but
  warned about**. This is a broken content state, not an invalid one; keeping
  both lets `find_exact()` locate the content a peer actually has:
  - `find_exact()` is hash-authoritative and searches every entry.
  - `find()` and `find_version()` prefer built-in over installed, then the
    lexicographically smallest `content_hash`.
- `find()` selects the highest valid semver across sources; for equal versions,
  built-in wins.
- `list()` order is deterministic: `map_id` ascending, version descending, then
  source rank (built-in before installed), then `content_hash` ascending.
- Built-in entries are checked with `ResourceLoader.exists(scene_path)`; a missing
  scene drops the entry with an error.
- Installed entries are not scene-checked until their pack is mounted (future).
  The loader reports `SCENE_MISSING`, `PACK_MISSING`, or `PACK_LOAD_FAILED` at
  load time.

### API

```gdscript
class_name MapRepository
extends RefCounted

signal catalog_changed()

## Empty or missing catalog paths are skipped. Source kind defines precedence.
func _init(sources: Array[MapCatalogSource]) -> void

## Reloads catalogs, re-validates entries, and emits catalog_changed().
func refresh() -> void

## All valid entries in deterministic order. May contain multiple versions.
func list() -> Array[MapManifest]

## Preferred entry for a map id (highest semver; built-in wins ties).
## Returns null when the map is not present.
func find(map_id: StringName) -> MapManifest

## Preferred entry for a specific version, ignoring hash.
## Returns null when the version is not present.
## Built-in wins over installed; otherwise the smallest content_hash wins.
## Used by the loader to distinguish VERSION_MISMATCH from HASH_MISMATCH.
func find_version(map_id: StringName, version: String) -> MapManifest

## Exact authority match. Returns null when not present.
## An empty content_hash matches any hash for that version (v1 built-in maps).
func find_exact(
	map_id: StringName,
	version: String,
	content_hash: String
) -> MapManifest

func has_exact(
	map_id: StringName,
	version: String,
	content_hash: String
) -> bool

## Loads a thumbnail synchronously on demand. Returns null if unavailable.
## Built-in thumbnails are res:// resources; installed thumbnails are sidecar
## PNGs under user://maps/<map_id>/<version>/, so no pack mount is required.
## Results are cached by path until refresh() clears the cache.
## Callers must load at most one thumbnail per frame; do not fill a grid in
## _ready().
func load_thumbnail(manifest: MapManifest) -> Texture2D
```

The repository does not load scenes and does not mutate game state.

## Map loader

The loader is a `Node` owned by the session. It is configured with a repository
and a host container. v1 has no session yet, so `Main` owns the loader directly;
it moves under `Session` once that layer exists.

```gdscript
class_name MapLoader
extends Node

const INVALID_REQUEST_ID := -1

enum State {
	IDLE,
	RESOLVING,
	LOADING,
	INSTANTIATING,
	READY,
	UNLOADING,
	FAILED,
}

enum LoadError {
	NONE,
	INVALID_MANIFEST,
	NOT_FOUND,
	VERSION_MISMATCH,
	HASH_MISMATCH,
	PACK_MISSING,
	PACK_LOAD_FAILED,
	SCENE_MISSING,
	INVALID_SCENE,
	LOAD_FAILED,
	CANCELLED,
	TIMEOUT,
}

@export var load_timeout_sec: float = 30.0

var state: State = State.IDLE
var current: LoadedMap
var last_error: LoadError = LoadError.NONE
var last_error_message: String = ""
var last_error_request_id: int = INVALID_REQUEST_ID

signal load_started(request_id: int, map_id: StringName)
signal load_progress(request_id: int, ratio: float)
signal load_finished(request_id: int, map: LoadedMap)
signal load_failed(request_id: int, error: LoadError, message: String)
signal unload_finished()

func setup(
	repository: MapRepository,
	host: Node3D
) -> void

## True when state is IDLE or FAILED; load_map() would be accepted.
func can_load() -> bool

## True while a load or unload operation is active.
func is_busy() -> bool

## Starts an async load. Returns a positive request ID when accepted, or
## INVALID_REQUEST_ID when rejected. Rejected calls emit no signal.
## An empty content_hash matches any hash for the version (v1 built-in maps).
func load_map(map_id: StringName, version: String, content_hash: String) -> int

func cancel(request_id: int) -> bool
func unload() -> void  # coroutine; awaitable
```

### State machine

| State | Meaning | Allowed next |
|---|---|---|
| `IDLE` | No map, no work. | `RESOLVING` |
| `RESOLVING` | Looking up the manifest and validating the request. | `LOADING`, `FAILED` |
| `LOADING` | Threaded scene load in progress. | `INSTANTIATING`, `FAILED` |
| `INSTANTIATING` | Instantiating, adding to host, waiting one physics frame. | `READY`, `FAILED` |
| `READY` | A map is live in the host. | `UNLOADING` |
| `UNLOADING` | Freeing the map instance. | `IDLE` |
| `FAILED` | Last request failed; no map is live. `last_error*` describe it. | `RESOLVING`, `IDLE` |

`load_map()` is only accepted from `IDLE` or `FAILED` (see `can_load()`). From
any other state it returns `INVALID_REQUEST_ID` (-1), changes no state, and
does not emit a signal. It is also rejected when `host` is null or not inside the
tree; that is a programming error and additionally calls `push_error()`. A
rejected call is a state rejection only; content errors are reported
asynchronously through `load_failed`. Callers must `unload()` first when a map is
live.

`last_error`, `last_error_message`, and `last_error_request_id` retain the most
recent failure until the next accepted load, which clears them. This lets UI
attaching after a failure query why it happened.

### Request IDs

- Every accepted load gets a monotonically increasing positive request ID.
- `load_started` is emitted immediately after acceptance, before resolution.
- Every load signal carries that ID.
- `cancel(request_id)` only affects the matching active request and returns
  `true` when it cancelled something. It is only meaningful during `RESOLVING`,
  `LOADING`, or `INSTANTIATING`; in `READY`, callers use `unload()`.
- Cancellation completes through `load_failed(..., CANCELLED, ...)` and frees any
  partially instantiated map, so there is one completion path for callers.
- Stale signals can be ignored by comparing the ID.

### Loading sequence

1. `RESOLVING`: `repository.find_exact(id, version, hash)`. An empty `hash`
   matches any hash for that version (v1 built-in maps).
   - If it returns null, `find_version(id, version)` distinguishes
     `HASH_MISMATCH` (version exists, hash differs) from `VERSION_MISMATCH`
     (version missing) and `NOT_FOUND` (map missing). If `find_version` returns
     null, `find(id) == null` means `NOT_FOUND`; otherwise it is
     `VERSION_MISMATCH`.
   - Invalid manifest → `INVALID_MANIFEST`. This is defensive: `refresh()` drops
     invalid entries, so only a custom or mutated repository can produce it.
2. `LOADING`:
   - `ResourceLoader.load_threaded_request(scene_path, "PackedScene")` with the
     default cache mode (`CACHE_MODE_REUSE`). Packs are not mounted in v1; when
     installed maps land, mount the pack here as a blocking main-thread call
     behind a loading screen and report `PACK_MISSING`/`PACK_LOAD_FAILED`.
   - If the scene cannot be resolved → `SCENE_MISSING`.
   - Poll status from `_process`, emit `load_progress`, enforce the timeout.
3. `INSTANTIATING`: `ResourceLoader.load_threaded_get()`, then
   `PackedScene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)`.
   - Instantiation failure → `LOAD_FAILED`.
   - Root is not a `MapScene` → `INVALID_SCENE`.
   - Add to `host`, await one `physics_frame` so `_ready` and physics
     registration have run. The loader does not call `apply_setup()`; maps must
     be valid with default configuration.
4. `READY`: build `LoadedMap`, set `current`, emit `load_finished`.

The loader reports **map ready**, not **client ready**. Client readiness (gamemode
setup, handshake) belongs to the session.

### Unloading sequence

`unload()` is a single-flight operation. The loader keeps
`_unload_in_progress` plus an internal `_unload_done` signal: the first caller
owns the work, and any caller that arrives while it runs awaits `_unload_done`
instead of starting a second operation. `unload()` is a coroutine; callers use
`await loader.unload()`.

1. If an unload is already in progress, await `_unload_done`; do not start a
   second operation.
2. If a load is active, cancel it and await its terminal outcome
   (`load_failed(CANCELLED)`, `load_failed(TIMEOUT)`, or another terminal
   error). Do not touch the host until the active request has fully unwound. If
   the load completed successfully before cancellation took effect, free the
   resulting map below.
3. If no map is live, set `IDLE` and emit `unload_finished`.
4. Otherwise, free `current.root` (only the loader may free it), await
   `tree_exited`, clear `current`, set `IDLE`, emit `unload_finished`.
5. A request-generation guard prevents a stale continuation from instantiating
   into the host after cancellation or unload.
6. If `current.root` is already invalid, clear state and finish.
7. The gamemode must be torn down **before** the loader unloads. The loader does
   not know about gamemodes and will not clear their nodes.

Concurrent `unload()` callers await the same operation. `unload_finished` is
emitted once per unload operation, not once per caller.

### Concurrency and timeouts

- One load at a time. `load_map()` returns `INVALID_REQUEST_ID` when rejected;
  check `can_load()`/`is_busy()`. A rejected call emits no signal.
- `cancel()` is idempotent and only affects the matching active request.
- `unload()` is idempotent, single-flight, and awaitable.
- The loader sets `process_mode = PROCESS_MODE_ALWAYS`, so progress polling and
  timeout accounting continue while the tree is paused. Timeouts use a
  wall-clock deadline (`Time.get_ticks_msec()`), not a frame count.
- Exceeding `load_timeout_sec` cancels the request and emits
  `load_failed(..., TIMEOUT, ...)`.
- A failed or cancelled load always cleans up any partially instantiated map and
  leaves the host empty.

## Scene tree and placement

Target layout once the session exists:

```text
Main
├── Session              # owns MapLoader and the gamemode
├── World                # live runtime space
│   ├── MapHost          # loaded map instance lives here
│   └── GamemodeRoot     # gamemode-owned entities
└── UI
```

v1 has no `Session` or `GamemodeRoot` yet; `Main` owns the loader directly:

```text
Main                     # game/main.gd, owns MapRepository + MapLoader
├── World
│   └── MapHost          # loaded map instance lives here
└── UI
    └── MapBrowser       # minimal v1 map browser
```

Rules:

- The map instance is a child of `MapHost`, at a stable path on every peer.
- Authored map content, including replicated map-local props such as elevators,
  doors, and moving platforms, lives inside the map scene at stable paths.
- Runtime-spawned gameplay entities are spawned under `GamemodeRoot`, **never**
  inside the map scene. This keeps replication paths stable and map swaps clean.
- The map scene contains static environment, markers, authored map-local logic,
  and authored replicated props.
- The loader is the only system allowed to free the map root. Consumers must
  never `queue_free()` it.
- Never use `change_scene_to_file()` or `change_scene_to_packed()` to load a map.
  That would replace `Main`, destroy the session/UI, and break node paths.
- All peers must run identical map content, so replicated node paths match.
- Avoid runtime-generated node names on replicated nodes.

## Multiplayer integration

The session/lobby layer lives in `game/` and translates authority decisions into
local loader calls. `system/maploader` contains no RPCs. The session layer is not
part of v1; this section defines the contract it must follow.

### Selection

1. The authority (host) selects a `MapManifest` from its repository.
2. The session locks the selection for the loading phase.
3. The authority broadcasts `{map_id, version, content_hash}`.
   **Never send a scene path or a package path over the network.**

Until hashing lands, the broadcast `content_hash` is empty and peers match on
`map_id + version`.

### Client resolution

A client must be connected before it can receive the locked identity. After the
lock arrives, the client:

1. Calls `repository.find_exact(id, version, hash)`.
2. Reports `MAP_MISSING`, `MAP_MISMATCH`, or proceeds.
3. Calls `loader.load_map(id, version, hash)`.
4. Reports `MAP_LOADING`, then `MAP_READY` or `MAP_FAILED`.

The `MAP_*` values above are session protocol statuses, not
`MapLoader.LoadError` values. Downloading missing content is out of scope. The
report exists so the lobby can decide whether to abort, kick, or wait for a
future download flow.

### Readiness

There are three distinct levels:

| Level | Owner | Meaning |
|---|---|---|
| Resource loaded | Loader | Packed scene is in memory. |
| Map ready | Loader | Map is instantiated, in the host, and settled for one physics frame. |
| Client ready | Session | Map ready + gamemode setup complete. |

The lobby waits for all clients to be **client ready**, or a timeout, then enters
the in-game phase and starts the gamemode. The handshake order is: connect →
receive the locked map identity → load the map → report client-ready.

### Load-out

1. Authority signals the end of the match.
2. Session tears down the gamemode (despawn entities, disconnect signals).
3. Session calls `await loader.unload()`.
4. Session returns to preparation.

Late joiners connect first, receive the locked map identity, load and settle the
map, then report client-ready. They cannot load before connecting. The session
handles their readiness and any gamemode-specific catch-up.

## Gamemode integration

- Map and gamemode **resources** may load in parallel because they are
  independent.
- The gamemode is instantiated/started only after the map is `READY`.
- The session passes the `LoadedMap` to the gamemode, e.g.
  `gamemode.setup(map: LoadedMap)`. A gamemode's `_ready()` must not assume a map
  exists.
- The gamemode queries spawn points/markers, then spawns entities under
  `GamemodeRoot`. Neither the loader nor the gamemode calls `apply_setup()` in
  v1.
- Teardown order is always: gamemode first, then map.

`apply_setup()` remains on the API as a reserved hook for a future map
config/setup feature (tracked separately); see Future extensions.

Map-local replicated behavior (elevators, moving platforms) must follow the same
authority rules as the rest of the game. Prefer deterministic/derived state over
ad-hoc replication.

## Code layout

```text
system/maploader/
├── map_manifest.gd
├── map_catalog.gd
├── map_catalog_source.gd
├── map_repository.gd
├── map_loader.gd
├── map_scene.gd
└── loaded_map.gd

game/
├── main.gd        # bootstraps repository + loader
├── main.tscn
├── maps/          # built-in map content + catalog
└── session/       # future: authority, lobby handshake, gamemode orchestration

ui/
└── map_browser/   # minimal v1 map browser

tests/
├── unit/          # pure logic, including system/maploader
├── integration/   # scenes, signals, loader lifecycle
├── content/       # catalog and export validation
└── fixtures/      # test catalog, test maps, shared resources
```

`system/maploader` must not reference `game/`, multiplayer, or UI.
`map_pack_registry.gd` is not created in v1; it lands with downloadable maps.

## Built-in map layout

```text
game/maps/
├── catalog.tres
└── arena_foundry/
    ├── manifest.tres
    ├── map.tscn
    └── thumbnail.png
```

- `map.tscn` root extends `MapScene`.
- `manifest.tres` sets `scene_path = "res://game/maps/arena_foundry/map.tscn"`.
- `catalog.tres` lists the built-in manifests.
- `SpawnPoints/` and `Markers/` follow the conventions above.
- Map-owned assets (textures, meshes, audio) live inside `game/maps/<map_id>/`
  next to the scene. This is a deliberate exception to `assets/`: installed packs
  must be self-contained later, so map content cannot reference loose files in
  `assets/`. Shared project-wide assets stay in `assets/`.

Test content lives outside the built-in content tree and is excluded from
exports:

```text
tests/fixtures/maps/
├── catalog.tres
└── test_box/
    ├── manifest.tres
    ├── map.tscn
    └── thumbnail.png
```

### Export inclusion

`@export_file` is not used for manifest paths, and manifest path fields are
runtime strings, so Godot does not treat them as resource dependencies. The
export preset must use **Export all resources in the project** so
`catalog.tres`, `manifest.tres`, map scenes, and thumbnails are included.

The export preset must exclude `tests/*`, `reports/*`, and
`addons/gdUnit4/*`; export-all would otherwise ship the test catalog, test maps,
and the test framework.

Content validation lives in `tests/content/` and runs with the PR gate. The
nightly workflow exports a build and smoke-tests that every built-in catalog
entry resolves in the packaged game.

If build size becomes an issue later, switch to explicit export filters plus the
same validation.

## Non-goals

- Networking, RPCs, or lobby state in `system/maploader`.
- Downloading, installing, updating, or verifying map packs at runtime.
- Gamemode rules or entity spawning.
- Map config/setup. The `apply_setup()` hook is reserved and not wired in v1.
- Map browser UI beyond the minimal v1 list/load browser, and loading screens.
- Content hashing and hash verification in v1 (separate workstream).
- `MapPackRegistry` and installed maps in v1 (separate workstream).
- Scene transitions.
- Match state persistence or save games.
- Map editing or authoring tools.

## Future extensions

- **Downloadable maps.** `MapPackRegistry`, installed-source catalogs, sidecar
  manifests, versioned PCK internal roots, and a download/install flow. The
  repository interface already hides distribution.
- **Content hashing pipeline.** Headless hash script, canonical map-root-relative
  hashing, manifest verification, and CI enforcement. Until it lands,
  `content_hash` stays empty and matching uses `map_id + version`.
- **Map config/setup.** Wire `MapScene.apply_setup(config)` into the
  gamemode/session flow. The config must be authority-derived, deterministic,
  and idempotent. Tracked in [#10](https://github.com/simonkuhlo/unrelated-vibe-game/issues/10).
- **Async thumbnails.** Threaded thumbnail loading for large map-browser grids.
- **Load-process handle.** If concurrent or preview loads are added, expose a
  `MapLoadProcess` handle alongside the existing request-ID signal API.
- **Preview loading.** Load a map into a `SubViewport` via a separate host, with a
  mode that skips gameplay-only setup.
- **Headless/server scene.** Use `server_scene_path` when a dedicated server does
  not need the full visual map.
- **Async map preparation.** An optional `MapScene.prepare()` coroutine for
  navmesh baking or streaming, awaited before `READY`.
- **Preload/warm.** Load a map's resources without instantiating it, e.g. during
  preparation.
- **Version ranges.** Explicitly rejected for now; exact matching only.

## Test plan

Automated, headless where possible. v1 uses [gdUnit4](testing.md): unit tests
under `tests/unit/`, lifecycle tests under `tests/integration/`, and fixture
validation under `tests/content/`. Both tiers run in the PR gate.

### v1

| Test | Expected |
|---|---|
| Repository loads built-in catalog | Entries are listed and findable. |
| `find_exact` with correct id/version | Returns the manifest. |
| `find_exact` with empty hash | Returns the preferred entry for the version. |
| `find_exact` with wrong version | Returns `null`. |
| `find_exact` with wrong non-empty hash | Returns `null`. |
| `find()` with multiple versions | Returns the highest strict semver. |
| Invalid version / invalid hash format | Invalid entry dropped; warning emitted. |
| Built-in catalog with unknown `format_version` | Repository refuses the catalog and logs an error; no built-in entries. |
| Built-in entry with missing scene | Entry dropped with an error. |
| Duplicate same version, different hash | Both entries retained; warning; `find_exact()` finds the matching hash. |
| Successful load | State reaches `READY`, `current` is set, host has one child. |
| Successful unload | Host is empty, `current` is `null`, state is `IDLE`. |
| Missing map | `load_failed(NOT_FOUND)`, host empty. |
| Version mismatch | `load_failed(VERSION_MISMATCH)`, host empty. |
| Hash mismatch (synthetic hash in fixture) | `load_failed(HASH_MISMATCH)`, host empty. |
| Missing scene | `load_failed(SCENE_MISSING)`, host empty. |
| Scene root is not `MapScene` | `load_failed(INVALID_SCENE)`, host empty. |
| Cancel during load | `load_failed(CANCELLED)`, host empty, no stale signals. |
| Unload while loading | Cancellation completes before the host is cleared; one `unload_finished`. |
| Concurrent `unload()` calls | One operation, one `unload_finished`; all callers resume. |
| Second load while active | Returns `INVALID_REQUEST_ID`, state unchanged, no signal. |
| Paused tree during load | Progress/timeout polling continue; no hang. |
| Timeout | `load_failed(TIMEOUT)`, host empty. |
| Failed load query | `last_error` / `last_error_message` retained. |
| `apply_setup` not invoked | Loader completes without calling `apply_setup`. |
| Thumbnail missing | `load_thumbnail()` returns `null`. |
| Thumbnail cache | Repeated calls return the cached texture. |
| Thumbnail cache invalidation | `refresh()` clears the cache. |
| Test catalog | Repository constructed with `tests/fixtures/maps/catalog.tres` loads `test_box` (content and assertion added in [#18](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18)). |

### Deferred (with their workstreams)

| Test | Expected |
|---|---|
| Missing/corrupt pack | `load_failed(PACK_MISSING)` / `PACK_LOAD_FAILED`. |
| Installed catalog rebuild | Missing/corrupt catalog rebuilt from `user://maps/*/*/manifest.tres`. |
| Version-scoped installed layout | Rebuild recovers every installed version. |
| Installed thumbnail sidecar | `load_thumbnail()` works without mounting the pack. |
| Repository source precedence | Built-in wins for equal versions; installed entries remain findable by exact hash. |
| Content hash | CI recomputes the manifest hash and fails on drift. |
| Exported build | Export-all plus `tests/*`, `reports/*`, and `addons/gdUnit4/*` exclusion; every built-in catalog entry resolves. |

Test content: `tests/fixtures/maps/test_box/` with a simple `MapScene`, two
spawn points, one named marker, and a manifest that carries a synthetic non-empty
`content_hash` for the mismatch tests.

## Decisions log

| Decision | Choice |
|---|---|
| Content term | **Map** for immutable content; **world** for the live runtime subtree. |
| Distribution | Built-in maps in v1; downloadable packs later behind the same repository interface. |
| Repository scope | App lifetime, owned by `Main`, injected into the session and UI. |
| Pack registry | Out of v1. App-scoped `MapPackRegistry` lands with downloadable maps; packs stay mounted for the process lifetime. |
| Loader scope | Session lifetime in the target design; `Main` owns it directly in v1. Loads into an explicit `MapHost`. |
| Match policy | Exact `map_id + version + content_hash` when a hash is present; empty hash matches any hash for the version in v1. Mismatches are reported, never silently loaded. |
| Concurrency | One load at a time; `unload()` is single-flight and awaitable. |
| Unload single-flight | Internal `_unload_in_progress` flag plus an `_unload_done` signal; the first caller owns the work, later callers await the signal. |
| Request rejection | `load_map()` returns an `int` request ID, or `INVALID_REQUEST_ID` (-1) when `can_load()` is false or `host` is invalid. Rejected calls emit no signal. |
| Repository sources | Source descriptors `{path, kind}`; source kind defines precedence and rank. v1 passes the built-in descriptor only. |
| Installed layout | Future: version-scoped directories `user://maps/<map_id>/<version>/{manifest.tres, thumbnail.png, content.pck}`. |
| Source precedence | Built-in wins over installed for the same `(map_id, version)`; `find()` uses highest strict semver. |
| Duplicate policy | Keep entries with the same version but different hashes (warned, not invalid); `find_exact()` is hash-authoritative; built-in preferred for browsing. |
| Content hash | Deferred. Field reserved and empty in v1; exact-hash matching activates when the hashing workstream lands. The future hash is canonical and map-root-relative, not raw file bytes. |
| Path schema | One `MapManifest`; all paths are plain runtime `String`s. |
| Export | Export all resources in the project; exclude `tests/*`, `reports/*`, and `addons/gdUnit4/*`; validate and smoke-test exported builds in the nightly workflow. |
| Gamemode access | `LoadedMap` + `MapScene` read API; `apply_setup()` is reserved and not called in v1. |
| Thumbnails | Sidecar outside packs; synchronous `load_thumbnail()` with repository cache cleared by `refresh()`; callers batch. |
| Map assets | Map-owned assets are co-located under `game/maps/<map_id>/` so packs can be self-contained; shared assets stay in `assets/`. |
| Built-in catalog `format_version` | Unknown value is a hard error; the catalog is refused rather than silently emptied. |
| Loader cache mode | `CACHE_MODE_REUSE` for threaded scene loads in v1. |
| Tests | gdUnit4 6.2.3; tiers under `tests/`; PR gate runs parse, unit, and integration. |
| Test content | `tests/fixtures/maps/` with a separate test catalog. |
| Persistence | Godot Resources: `MapCatalog` + `MapManifest`; manifests are dependency-free. |
| Scene transitions | Never used for maps. |

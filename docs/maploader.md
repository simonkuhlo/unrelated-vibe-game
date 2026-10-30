# Map Loader

**Status:** Design / contracts. No implementation yet.

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
| **Repository** | The app-scoped local map database. Answers "what maps do I have?" |
| **Loader** | The session-scoped service that loads a map into a `MapHost`. |

The key distinction is **map = content, world = runtime**. The session loads a
map into the world.

## Design principles

- **Separate concerns.** The repository knows what exists; the loader knows how
  to bring it into the tree; the gamemode knows what to do with it.
- **Local first.** Every peer resolves maps from its own repository. Authority
  sends map identity, never a scene path.
- **Deterministic content.** All peers must run identical map content. Matching
  is exact on `map_id + version + content_hash`.
- **No scene transitions.** Maps are sub-scenes added to a host node. The main
  scene, session, and UI are never replaced by a map load.
- **Fail cleanly.** Every load ends in either `load_finished` or `load_failed`.
  Partial state is cleaned up before the loader reports the result.

## Core concepts

| Class | Type | Scope | Responsibility |
|---|---|---|---|
| `MapManifest` | `Resource` | data | Metadata for one map version. |
| `MapCatalog` | `Resource` | data | A persisted list of manifests. |
| `MapRepository` | `RefCounted` | app | Local map database and queries. |
| `MapLoader` | `Node` | session | Async load/unload lifecycle. |
| `MapHost` | `Node3D` | world | Container the map instance is added to. |
| `MapScene` | `Node3D` | map content | Base class for map roots. |
| `LoadedMap` | `RefCounted` | handle | Manifest + live map instance. |

`MapHost` is a plain `Node3D`; it does not need a custom script. It exists to
make placement explicit and to support future uses such as preview loading into
a `SubViewport`.

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
@export var display_name: String
@export_file("*.tscn") var scene_path: String
@export_file("*.pck") var package_path: String = ""
@export_file("*.png", "*.jpg", "*.webp") var thumbnail_path: String
@export var player_min: int = 1
@export var player_max: int = 32
@export var tags: PackedStringArray = []
@export var server_scene_path: String = ""
```

Rules:

- `map_id` is a stable slug, e.g. `&"arena_foundry"`. It never changes for a map.
- `version` is a semver string. A content change requires a new version.
- `content_hash` is the SHA-256 of the installable content (for installed maps,
  the pack). It is provided at build/install time and is the authority for
  match checks.
- `scene_path` points at the map scene. For built-in maps it is under `res://`.
  For installed maps it is a versioned virtual path inside the mounted pack,
  e.g. `res://maps/arena_foundry/1.2.0/map.tscn`.
- `package_path` is empty for built-in maps and points at the pack for installed
  maps.
- `thumbnail_path` is loaded on demand. Never store a `Texture2D` on the
  manifest.
- `server_scene_path` is reserved for a future headless/server variant. Empty
  means "use `scene_path`".

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
are dropped with a warning.

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
func get_bounds() -> AABB:
	return AABB()

## Applies deterministic, authority-derived setup. Optional.
## Implementations must be idempotent and must not depend on local state.
func apply_setup(_config: Dictionary) -> void:
	pass
```

**Marker convention:**

- `SpawnPoints/` contains `Marker3D` children used for generic player spawns.
- `Markers/` contains `Marker3D` children looked up by node name, e.g.
  `Markers/RedBase`, `Markers/BlueBase`, `Markers/ObjectiveA`.
- Maps may override any method for custom behavior.

The loader rejects a scene whose root is not a `MapScene`.

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
	root.apply_setup(config)

func is_valid() -> bool:
	return root != null and is_instance_valid(root)
```

Consumers must not keep a `LoadedMap` reference after `unload_finished`.

## Map repository

The repository is the client's local map database. It is **app-scoped** and
shared by the map browser UI and any session. It is injected into the loader.

### Sources

| Source | Catalog path | Persistence | Notes |
|---|---|---|---|
| Built-in | `res://game/maps/catalog.tres` | Hand-authored | Immutable. May reference manifests with `ext_resource`. |
| Installed (future) | `user://maps/catalog.tres` | Generated | Must be self-contained and rebuildable. |

`MapRepository` receives its catalog paths at construction. It does not hardcode
`game/maps`, so `system/maploader` stays portable.

### Installed catalog rules (future)

- Installed maps live in `user://maps/<map_id>/`:
  - `manifest.tres` — a sidecar, readable without mounting the pack.
  - `<version>.pck` — the content, with a versioned internal root
    `res://maps/<map_id>/<version>/`.
- The catalog must embed manifest data rather than reference sidecar files with
  `ext_resource`. Otherwise uninstalling one map can break the whole catalog.
- If the catalog is missing, corrupt, or has an unknown `format_version`, the
  repository rebuilds it by scanning `user://maps/*/manifest.tres`.
- Godot cannot unmount a PCK. Once mounted, a pack stays mounted for the process
  lifetime. The versioned internal root prevents collisions between versions.

### Validation

The repository validates metadata only:

- `map_id`, `version`, `content_hash`, and `scene_path` are non-empty.
- `player_min <= player_max`.
- Duplicate `(map_id, version)` entries are resolved deterministically (first
  wins) with a warning.
- Built-in entries may be checked with `ResourceLoader.exists(scene_path)`.
- Installed entries are not scene-checked until their pack is mounted. The loader
  reports `SCENE_MISSING` / `PACK_MISSING` if resolution fails at load time.

### API

```gdscript
class_name MapRepository
extends RefCounted

signal catalog_changed()

func _init(catalog_paths: PackedStringArray) -> void

## Reloads catalogs and re-validates entries.
func refresh() -> void

## All valid entries. May contain multiple versions of the same map.
func list() -> Array[MapManifest]

## Preferred entry for a map id (highest semver). For UI selection.
func find(map_id: StringName) -> MapManifest

## Entry for a specific version, ignoring hash.
## Used by the loader to distinguish VERSION_MISMATCH from HASH_MISMATCH.
func find_version(map_id: StringName, version: String) -> MapManifest

## Exact authority match. Returns null when not present.
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

## Loads a thumbnail on demand. Returns null if unavailable.
func load_thumbnail(manifest: MapManifest) -> Texture2D
```

The repository does not load scenes and does not mutate game state.

## Map loader

The loader is a `Node` owned by the session. It is configured with a repository
and a host container.

```gdscript
class_name MapLoader
extends Node

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
	SCENE_MISSING,
	PACK_MISSING,
	LOAD_FAILED,
	CANCELLED,
	TIMEOUT,
	BUSY,
}

@export var load_timeout_sec: float = 30.0

var state: State = State.IDLE
var current: LoadedMap

signal load_started(request_id: int, map_id: StringName)
signal load_progress(request_id: int, ratio: float)
signal load_finished(request_id: int, map: LoadedMap)
signal load_failed(request_id: int, error: LoadError, message: String)
signal unload_finished()

func setup(repository: MapRepository, host: Node3D) -> void
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
| `FAILED` | Last request failed; no map is live. | `RESOLVING`, `IDLE` |

`load_map()` is only accepted from `IDLE` or `FAILED`. From any other state it
returns `-1` and does not emit a signal. Callers must `unload()` first.

### Request IDs

- Every accepted load gets a monotonically increasing positive request ID.
- `load_started` is emitted immediately after acceptance, before resolution.
- Every load signal carries that ID.
- `cancel(request_id)` only affects the matching active request and returns
  `true` when it cancelled something.
- Cancellation completes through `load_failed(..., CANCELLED, ...)`, so there is
  one completion path for callers.
- Stale signals can be ignored by comparing the ID.

### Loading sequence

1. `RESOLVING`: `repository.find_exact(id, version, hash)`.
   - If it returns null, `find_version(id, version)` distinguishes
     `HASH_MISMATCH` (version exists, hash differs) from `VERSION_MISMATCH`
     (version missing) and `NOT_FOUND` (map missing).
   - Invalid manifest → `INVALID_MANIFEST`.
2. `LOADING`: if `package_path` is set and the pack is not mounted, mount it.
   The loader tracks mounted packs for the process lifetime, since Godot cannot
   unmount them. Then
   `ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)`.
   Poll status from `_process`, emit `load_progress`, enforce the timeout.
3. `INSTANTIATING`: `ResourceLoader.load_threaded_get()`, then
   `PackedScene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)`.
   - Missing scene → `SCENE_MISSING`.
   - Root is not a `MapScene` → `LOAD_FAILED`.
   - Add to `host`, await one `physics_frame` so `_ready` and physics
     registration have run.
4. `READY`: build `LoadedMap`, set `current`, emit `load_finished`.

The loader reports **map ready**, not **client ready**. Client readiness (gamemode
setup, handshake) belongs to the session.

### Unloading sequence

1. If a load is active, `cancel()` it first.
2. If no map is live, reset to `IDLE` and emit `unload_finished` on the next
   process frame.
3. Otherwise, `current.root.queue_free()`, await `tree_exited`, clear `current`,
   set `IDLE`, emit `unload_finished`.
4. The gamemode must be torn down **before** the loader unloads. The loader does
   not know about gamemodes and will not clear their nodes.

### Concurrency and timeouts

- One load at a time. `BUSY` is synchronous (return value), not a signal.
- `cancel()` is idempotent.
- `unload()` is idempotent and awaitable.
- Exceeding `load_timeout_sec` cancels the request and emits `TIMEOUT`.
- A failed or cancelled load always cleans up any partially instantiated map and
  leaves the host empty.

## Scene tree and placement

```text
Main
├── Session              # owns MapLoader and the gamemode
├── World                # live runtime space
│   ├── MapHost          # loaded map instance lives here
│   └── GamemodeRoot     # gamemode-owned entities
└── UI
```

Rules:

- The map instance is a child of `MapHost`, at a stable path on every peer.
- Dynamic/networked entities are spawned under `GamemodeRoot`, **never** inside
  the map scene. This keeps replication paths stable and map swaps clean.
- The map scene contains static environment, markers, and map-local logic only.
- Never use `change_scene_to_file()` or `change_scene_to_packed()` to load a map.
  That would replace `Main`, destroy the session/UI, and break node paths.
- All peers must run identical map content, so replicated node paths match.
- Avoid runtime-generated node names on replicated nodes.

## Multiplayer integration

The session/lobby layer lives in `game/` and translates authority decisions into
local loader calls. `system/maploader` contains no RPCs.

### Selection

1. The authority (host) selects a `MapManifest` from its repository.
2. The session locks the selection for the loading phase.
3. The authority broadcasts `{map_id, version, content_hash}`.
   **Never send a scene path or a package path over the network.**

### Client resolution

Each client:

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
the in-game phase and starts the gamemode.

### Load-out

1. Authority signals the end of the match.
2. Session tears down the gamemode (despawn entities, disconnect signals).
3. Session calls `await loader.unload()`.
4. Session returns to preparation.

Late joiners load the locked map before joining; the session handles their
readiness and any gamemode-specific catch-up.

## Gamemode integration

- Map and gamemode **resources** may load in parallel because they are
  independent.
- The gamemode is instantiated/started only after the map is `READY`.
- The session passes the `LoadedMap` to the gamemode, e.g.
  `gamemode.setup(map: LoadedMap)`. A gamemode's `_ready()` must not assume a map
  exists.
- The gamemode queries spawn points/markers, optionally calls
  `map.apply_setup(config)`, then spawns entities under `GamemodeRoot`.
- Teardown order is always: gamemode first, then map.

### Deterministic setup

`apply_setup(config: Dictionary)` is for map configuration that depends on the
gamemode, such as locking doors, enabling a zone, or changing ambience.

- `config` is derived from authority-provided gamemode configuration.
- All peers receive the same config.
- Implementations must be deterministic and idempotent.
- The map validates or ignores unknown keys.
- Do not replicate individual map state that can be derived from `config`.
- If randomness is required, derive it from an authority-provided seed.

Map-local replicated behavior (elevators, moving platforms) must follow the same
authority rules as the rest of the game. Prefer deterministic/derived state over
ad-hoc replication.

## Code layout

```text
system/maploader/
├── map_manifest.gd
├── map_catalog.gd
├── map_repository.gd
├── map_loader.gd
├── map_scene.gd
└── loaded_map.gd

game/
├── maps/          # built-in map content + catalog
└── session/       # authority, lobby handshake, gamemode orchestration
```

`system/maploader` must not reference `game/`, multiplayer, or UI.

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

### Export inclusion

`@export_file` produces a `String` at runtime and does **not** create a resource
dependency. Exported builds must include the map scenes and thumbnails. Verify
this with an export build, or add a build-time validation step that checks
`ResourceLoader.exists()` for every built-in catalog entry.

## Non-goals

- Networking, RPCs, or lobby state in `system/maploader`.
- Downloading, installing, updating, or verifying map packs at runtime.
- Gamemode rules or entity spawning.
- Map browser / loading screen UI.
- Scene transitions.
- Match state persistence or save games.
- Map editing or authoring tools.

## Future extensions

- **Downloadable maps.** Sidecar manifests, versioned PCK internal roots, and a
  download/install flow. The repository interface already hides distribution.
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

Automated, headless where possible:

| Test | Expected |
|---|---|
| Repository loads built-in catalog | Entries are listed and findable. |
| `find_exact` with correct id/version/hash | Returns the manifest. |
| `find_exact` with wrong version/hash | Returns `null`. |
| Successful load | State reaches `READY`, `current` is set, host has one child. |
| Successful unload | Host is empty, `current` is `null`, state is `IDLE`. |
| Missing map | `load_failed(NOT_FOUND)`, host empty. |
| Hash mismatch | `load_failed(HASH_MISMATCH)`, host empty. |
| Cancel during load | `load_failed(CANCELLED)`, host empty, no stale signals. |
| Second load while active | Returns `-1`, state unchanged. |
| Scene root is not `MapScene` | `load_failed(LOAD_FAILED)`, host empty. |
| Timeout | `load_failed(TIMEOUT)`, host empty. |
| Export build | Built-in map scenes and thumbnails are present. |

Test content: `game/maps/test_box/` with a simple `MapScene`, two spawn points,
and one named marker.

## Decisions log

| Decision | Choice |
|---|---|
| Content term | **Map** for immutable content; **world** for the live runtime subtree. |
| Distribution | Built-in maps now; downloadable packs later behind the same repository interface. |
| Repository scope | App lifetime, shared by UI and sessions. |
| Loader scope | Session lifetime, owned by `Session`, loads into an explicit `MapHost`. |
| Match policy | Exact `map_id + version + content_hash`; mismatch is reported, never silently loaded. |
| Concurrency | `load_map()` returns `BUSY` while active; caller must `cancel()` first. |
| Gamemode access | `LoadedMap` + `MapScene` read API + deterministic `apply_setup(config)`. |
| Persistence | Godot Resources: `MapCatalog` + `MapManifest`; manifests are dependency-free. |
| Scene transitions | Never used for maps. |

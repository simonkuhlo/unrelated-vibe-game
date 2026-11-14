# Map Loader

**Status:** Active — Phase 0 closed 2026-11-13; Phase 1 (data model) closed
2026-11-13; Phase 2 (synchronous loader) unblocked 2026-11-14 by #40.

The rework moves map data authoring into the Godot editor and treats the
editor's resource graph as the authority:

- **Editor-first authoring.** Map data is created and edited through the inspector.
- **Direct resource references.** Manifests hold `PackedScene` and `Texture2D`
  references instead of dependency-free string paths.
- **Single DB authority.** One `MapDB` resource holds the built-in maps; the
  loader is configured with a reference to the DB it should use.
- **Built-in maps only.** Installed packs, content hashing, and multi-version
  resolution are deferred.
- **Synchronous v1 loader.** The loader keeps the existing high-level concept
  (`MapHost` placement, loader-owned map root, `LoadedMap` handle, signal-based
  completion, no scene transitions). Async loading is a separate v2 issue
  ([#36](https://github.com/simonkuhlo/unrelated-vibe-game/issues/36)).

## Data model

- **`MapDB`** (`Resource`, `@tool`): `@export var maps: Array[MapManifest]`. Linear
  lookup, no runtime index/cache. `add_map()`, `remove_map()`, `get_map(id)`,
  `has_map(id)`, `get_maps(filter: MapFilter = null)`, `get_map_ids()`,
  `validate()`, `is_valid()`. `get_maps()` always returns an independent array
  copy that skips null rows. There is no validation cache.
- **`MapManifest`** (`Resource`, `@tool`): v1 fields are `id`, `scene`,
  `display_name`, `thumbnail`. `version` is dropped; version metadata returns with
  packs (#17). `id` must match `^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$` — lowercase
  `snake_case`, single underscores, starting with a letter.
- **`MapScene`** (`Node3D`, `@tool`): map root with `markers: MapMarkerCollection`,
  assigned to a `Markers` child via a typed node export. No other marker API is
  exposed. Validation requires the collection to be a direct child and warns
  when the node is not named `Markers`. Game-specific markers live in `game/` on
  a game-level subclass.
- **`MapMarker`** (`Marker3D`, `@tool`): base marker class. Only this ships in v1;
  typed markers are built on demand in `game/`.
- **`MapMarkerCollection`** (`Node3D`, `@tool`): script on the `Markers` root with
  `get_markers(filter: MapMarkerFilter = null) -> Array[MapMarker]`.
- **`MapFilter` / `MapMarkerFilter`** (`Resource`, `@tool`): filter base types
  with a default `matches()` returning true. Concrete filters are deferred.
- **`MapValidationIssue`** (`RefCounted`, `@tool`): `severity` (`ERROR`/`WARNING`),
  `code` (`StringName`), `message`, and `context`. `is_error()`,
  `format_string()`, and the shared static helpers `has_errors()`,
  `format_all()`, `log_all()`.
## Identity and validation

- `manifest.id` is the sole identity. Runtime code treats ids as read-only by
  convention, like the array copies returned by `get_maps()`; the export is not
  enforced as immutable. Editing an id at editor time does not require re-adding
  the map.
- There is no validation cache. `MapDB` does not track whether validation ran;
  the loader always calls `validate()` when it loads a DB, and editor tooling
  re-runs it on demand. `MapDB.is_valid()` runs validation and reports whether
  there are ERROR issues.
- Components return `Array[MapValidationIssue]` from `validate()`. IDs are unique
  per DB and duplicate detection is part of validation, not a separate editor
  mechanism.
- `MapDB.validate()` validates the whole DB, scenes included: it instantiates
  every manifest's scene to verify a `MapScene` root and a valid markers
  collection. The loader runs it on every load (A17).
- `MapManifest.validate()` enforces the location contract: the manifest must live
  in `res://game/maps/<id>/` and the scene must be in the same folder. Both
  violations are ERRORs.
- Issues aggregated from an instantiated scene point at the manifest, not the
  scene nodes, because the instance is freed before `validate()` returns.
- Validation triggers: `@export_tool_button("Validate")` on `MapDB`,
  `MapManifest`, `MapScene`, and `MapMarkerCollection`;
  `MapScene._get_configuration_warnings()`; the CI content test. No custom
  `EditorInspectorPlugin` in v1.
- Tool buttons call `MapValidationIssue.log_all()`. Godot discards a tool
  callable's return value, so returning issues without logging would make the
  button silently do nothing. Errors and warnings land in the editor
  Output/Errors panel.
- `MapScene._get_configuration_warnings()` surfaces **all** issues (errors and
  warnings), so validation results that only raise warnings are still visible in
  the scene dock.

### Authoring a built-in map

1. Create `game/maps/<map_id>/`; the folder name matches `manifest.id`.
2. Add `map_manifest.tres` (`MapManifest`) and `map_scene.tscn` (`MapScene` with a
   `Markers` child using `MapMarkerCollection`).
3. Add the manifest to `game/maps/map_db.tres` through the inspector.
4. Click **Validate** on the manifest, scene, and DB and fix every ERROR.
5. Run `pwsh ./scripts/verify.ps1`. The content test is the CI authority for the
   built-in DB.

## Loader

The synchronous v1 loader is a `Node` configured through exports on the loader
node (`map_db: MapDB`, `map_host: Node3D`), not `setup(db, host)`. The loader
lives outside the host. It never uses an unvalidated DB: there is no cached
validation state, so it calls `MapDB.validate()` on every load (A17).

### Load API

- `load_map(id: StringName) -> MapLoadResult`.
- Emits exactly one terminal `load_finished(result: MapLoadResult)` signal,
  synchronously, before returning. There are no separate success/failure
  signals.
- The result is the API contract; the signal lets UI react without polling.
- Loading never aborts the caller. Every failure is a result with a non-`NONE`
  code, and the host is left in its prior state: empty for a first load,
  unchanged when a map was already active.
- `is_loaded() -> bool` and `get_loaded_map() -> LoadedMap`.
- `MapLoadError` is a standalone enum; `MapLoadResult` carries the outcome.

### Error surface

`MapLoadError.Code`: `NONE` (success), `NOT_FOUND`, `DB_INVALID`,
`HOST_INVALID`, `HOST_OCCUPIED`, `ALREADY_LOADED`, `INVALID_MANIFEST`,
`SCENE_MISSING`, `INVALID_SCENE`.

`MapLoadResult` (`RefCounted`) exposes `code`, `manifest`, `map`, `issues`
(`Array[MapValidationIssue]`), `is_ok()`, and `format_message()`.

| Situation | Code |
|---|---|
| Empty id or id not in the DB | `NOT_FOUND` |
| `map_db` is null, or the DB has fatal DB-level errors for the target | `DB_INVALID` |
| `map_host` is null, not in the tree, or the loader is a descendant of the host | `HOST_INVALID` |
| The host already has children | `HOST_OCCUPIED` |
| A map is already loaded | `ALREADY_LOADED` |
| The target manifest fails validation with ERRORs | `INVALID_MANIFEST` |
| `manifest.scene` is null | `SCENE_MISSING` |
| Instantiation fails or the root is not a `MapScene` | `INVALID_SCENE` |

### Validation scope

`MapDB.validate()` is DB-wide (A18), but the loader's failure scope is
target-scoped:

- Fatal: ERROR issues whose `context` is the requested manifest, plus
  duplicate-id ERRORs for the requested id.
- Non-fatal: every other issue. The loader logs them with
  `MapValidationIssue.log_all()` and still loads, so one broken map cannot block
  every map in the DB.
- WARNINGs never block.

### Host contract

- `map_host` must be in the tree and empty (`get_child_count() == 0`); the host
  is reserved for loader content.
- The loader must not be a descendant of the host.
- The loader adds the map root as a direct child of the host and resets the
  root's transform to identity. The host transform owns placement; maps do not
  re-place themselves.
- The loader owns and frees only the map root it added. It never frees gamemode
  nodes or other host children.

### Single-flight

- A second load while a map is loaded is rejected with `ALREADY_LOADED`; the
  active map is untouched. v1 does not auto-unload or replace; callers unload
  first.
- A failed load never disturbs the active map.
- If external code frees or detaches the root, the loader treats the map as no
  longer loaded: `is_loaded()` returns false and the next `load_map()` proceeds.

### `LoadedMap`

- `LoadedMap` is a thin `RefCounted` handle: `id`, `manifest`, `root`
  (`MapScene`), and `is_valid()`. It is not a marker facade; query markers
  through `root.markers` (A12).
- Unload invalidates the handle immediately, even though the node is freed with
  `queue_free()`.
- The loader settles state before emitting a signal, so handlers may call
  `unload()` (which unloads normally) or `load_map()` (which returns
  `ALREADY_LOADED`).

### Unload semantics

- `unload() -> void` is idempotent.
- A real unload detaches the root from the host immediately, invalidates the
  handle, calls `queue_free()` on the root, clears loader state, and emits
  `map_unloaded(map: LoadedMap)` exactly once.
- Unloading with nothing loaded is a no-op and emits no signal.

## Decision log

### Loader decisions (2026-11-14, #40)

| # | Decision |
|---|---|
| A22 | `load_map(id) -> MapLoadResult` emits one terminal `load_finished(result)` signal synchronously before returning. No split success/failure signals. |
| A23 | Standalone `MapLoadError` enum (`NONE`, `NOT_FOUND`, `DB_INVALID`, `HOST_INVALID`, `HOST_OCCUPIED`, `ALREADY_LOADED`, `INVALID_MANIFEST`, `SCENE_MISSING`, `INVALID_SCENE`). `MapLoadResult` carries `code`, `manifest`, `map`, `issues`, `is_ok()`, `format_message()`. |
| A24 | Single-flight: reject a second load with `ALREADY_LOADED`; a failed load leaves the active map untouched. No auto-unload/replace in v1. |
| A25 | `map_host: Node3D` must be in-tree and empty; the loader must not be a descendant of the host. The loader adds the map root under the host and resets it to identity; the host owns placement. |
| A26 | `LoadedMap` is a thin `RefCounted` handle (`id`, `manifest`, `root`, `is_valid()`), not a marker facade, invalidated immediately on unload. |
| A27 | `unload()` is idempotent: detach, invalidate, `queue_free()`, clear state, emit `map_unloaded` once for real unloads only. Externally freed/detached roots count as no longer loaded. |
| A28 | The loader always runs DB-wide `validate()`, but only target-scoped ERRORs (context is the requested manifest, plus duplicate ids for that id) block the load. Other issues are logged. This refines A18's loader behavior; A18 still governs what `validate()` covers. |
| A29 | The game-level marker split (`PlayerSpawnPoint extends MapMarker`, `PlayerSpawnFilter extends MapMarkerFilter`, `player_index: int`) belongs in `game/` and lands with #15 via #50. The loader exposes no spawn API (A10, A12). |

## File layout

```text
system/maploader/
  map_db.gd                 # MapDB
  map_manifest.gd           # MapManifest
  map_scene.gd              # MapScene
  map_marker.gd             # MapMarker
  map_marker_collection.gd  # MapMarkerCollection
  map_marker_filter.gd      # MapMarkerFilter
  map_filter.gd             # MapFilter
  map_validation_issue.gd   # MapValidationIssue
  # Phase 2 (#13):
  map_load_error.gd         # MapLoadError
  map_load_result.gd        # MapLoadResult
  loaded_map.gd             # LoadedMap
  map_loader.gd             # MapLoader
```

- `game/maps/<map_id>/`: `map_manifest.tres`, `map_scene.tscn`, thumbnail, and
  map-owned assets.
- IDs are lowercase `snake_case`; the folder name matches the id.
- Directory name is `maploader` (matches docs and issue labels).

## Deferred items

- Game-level marker subclass — [#15](https://github.com/simonkuhlo/unrelated-vibe-game/issues/15). Spawn selection itself is out of scope (A10).
- Map config/setup (`apply_setup()`) — [#10](https://github.com/simonkuhlo/unrelated-vibe-game/issues/10).
- Async loader — [#36](https://github.com/simonkuhlo/unrelated-vibe-game/issues/36).
- Downloadable packs — [#17](https://github.com/simonkuhlo/unrelated-vibe-game/issues/17).
- Content hashing — [#16](https://github.com/simonkuhlo/unrelated-vibe-game/issues/16).

## Related

- [Maploader Roadmap](maploader-roadmap.md)
- [Issue #46: Phase 1 review follow-ups](https://github.com/simonkuhlo/unrelated-vibe-game/issues/46)
- [Issue #47: Phase 1 review design leftovers](https://github.com/simonkuhlo/unrelated-vibe-game/issues/47)
- [Issue #40: loader API/host contract/unload semantics](https://github.com/simonkuhlo/unrelated-vibe-game/issues/40)
- [Issue #13: synchronous v1 loader](https://github.com/simonkuhlo/unrelated-vibe-game/issues/13)
- [Issue #15: Main bootstrap and map browser](https://github.com/simonkuhlo/unrelated-vibe-game/issues/15)
- [Issue #50: game-level spawn marker](https://github.com/simonkuhlo/unrelated-vibe-game/issues/50)
- [Issue #18: tests for the new data model](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18)

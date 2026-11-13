# Map Loader

**Status:** Active — Phase 0 closed 2026-11-13; data model finalized.

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

## Phase 0 decisions (2026-11-13)

### Data model

- **`MapDB`** (`Resource`, `@tool`): `@export var maps: Array[MapManifest]`. Linear
  lookup, no runtime index/cache. `add_map()`, `remove_map()`, `get_map(id)`,
  `has_map(id)`, `get_maps(filter: MapFilter)`, `get_map_ids()`.
- **`MapManifest`** (`Resource`, `@tool`): v1 fields are `id`, `scene`, `display_name`,
  `thumbnail`. `version` is dropped; version metadata returns with packs (#17).
- **`MapScene`** (`Node3D`): map root exposing a single `Markers` root via a typed
  node export. Game-specific markers live in `game/` on a game-level subclass.
- **`MapMarker`** (`Marker3D`): base marker class. Only this ships in v1; typed
  markers are built on demand in `game/`.
- **`MapMarkerCollection`** (`Node3D`): script on the `Markers` root with
  `get_markers(filter: MapMarkerFilter = null) -> Array[MapMarker]`.
- **`MapFilter` / `MapMarkerFilter`** (`Resource`): filter base types with a
  default `matches()` returning true. Concrete filters are deferred.
- **`MapValidationIssue`**: `severity` (`ERROR`/`WARNING`), `code` (`StringName`),
  `message`, and context. Components expose `validate() -> Array[MapValidationIssue]`.
- **`MapValidator`**: thin aggregator for cross-object/content checks. No god object.

### Identity and validation

- `manifest.id` is the sole identity. Format: `StringName`, lowercase `snake_case`.
- Ids are read-only at runtime. Editing an id at editor time does not require
  re-adding the map.
- `MapDB` tracks a validation state. If modified and not manually revalidated, it
  must be revalidated before the loader uses it. Duplicate checking is part of
  validation, not a separate editor mechanism.
- Validation triggers: `@export_tool_button("Validate")` on `MapDB`, `MapManifest`,
  and `MapScene`; `MapScene._get_configuration_warnings()`; CI content test.
  No custom `EditorInspectorPlugin` in v1.

### Loader

- Configured through exports on the loader node (`map_db: MapDB`, `map_host: Node3D`),
  not `setup(db, host)`.
- The loader API, host contract, and unload semantics are **deferred to #40**.

## File layout

```
system/maploader/
  map_db.gd                 # MapDB
  map_manifest.gd           # MapManifest
  map_scene.gd              # MapScene
  map_marker.gd             # MapMarker
  map_marker_collection.gd  # MapMarkerCollection
  map_marker_filter.gd      # MapMarkerFilter
  map_filter.gd             # MapFilter
  map_validation_issue.gd   # MapValidationIssue
  map_validator.gd          # MapValidator (thin aggregator)
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

- Loader API, host contract, and unload semantics — [#40](https://github.com/simonkuhlo/unrelated-vibe-game/issues/40).
- Async loader — [#36](https://github.com/simonkuhlo/unrelated-vibe-game/issues/36).
- Downloadable packs — [#17](https://github.com/simonkuhlo/unrelated-vibe-game/issues/17).
- Content hashing — [#16](https://github.com/simonkuhlo/unrelated-vibe-game/issues/16).
- Map config/setup — [#10](https://github.com/simonkuhlo/unrelated-vibe-game/issues/10).

## Related

- [Maploader Design Session Roadmap](maploader-design-session-roadmap.md)
- [Issue #40: loader API/host contract/unload semantics](https://github.com/simonkuhlo/unrelated-vibe-game/issues/40)
- [Issue #13: synchronous v1 loader](https://github.com/simonkuhlo/unrelated-vibe-game/issues/13)
- [Issue #15: Main bootstrap and map browser](https://github.com/simonkuhlo/unrelated-vibe-game/issues/15)
- [Issue #18: tests for the new data model](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18)
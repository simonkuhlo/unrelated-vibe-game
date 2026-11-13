# Map Loader

**Status:** Active — Phase 0 closed 2026-11-13; Phase 1 (data model) closed
2026-11-13. Phase 2 is gated on #40.

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
  `validate()`, `is_valid()`, `is_validated`. `get_maps()` always returns an
  independent array copy that skips null rows.
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
- **`MapValidator`** (`RefCounted`, `@tool`): thin aggregator for cross-object
  and null-safe checks. No god object; rules live on the owning component.

## Identity and validation

- `manifest.id` is the sole identity. Runtime code treats ids as read-only by
  convention, like the array copies returned by `get_maps()`; the export is not
  enforced as immutable. Editing an id at editor time does not require re-adding
  the map.
- `MapDB.is_validated` is **advisory state**: it records that `validate()` ran
  after the last mutation of the DB (`add_map`, `remove_map`, `clear_db`, or a
  `maps` property assignment). It does not observe manifest field edits, and
  direct element mutation (`db.maps.append(...)`) bypasses it. Use the `MapDB`
  API for runtime changes.
- A loader must call `validate()` before using a DB; `is_validated == true` alone
  is not proof that the content is valid. `MapDB.is_valid()` runs validation and
  reports whether there are ERROR issues.
- Components return `Array[MapValidationIssue]` from `validate()`. IDs are unique
  per DB and duplicate detection is part of validation, not a separate editor
  mechanism.
- `MapDB.validate()` checks manifest fields, ID format, and uniqueness. It does
  **not** instantiate or validate map scenes; scene structure is checked by
  `MapScene.validate()` and the CI content test. Where loader-side scene
  validation lives is a Phase 2 decision ([#40](https://github.com/simonkuhlo/unrelated-vibe-game/issues/40)).
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

- Configured through exports on the loader node (`map_db: MapDB`, `map_host: Node3D`),
  not `setup(db, host)`.
- The loader API, host contract, and unload semantics are **deferred to #40**.
  Phase 2 (`MapLoader`, `LoadedMap`, error types) must not start before #40 is
  closed.

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
  map_validator.gd          # MapValidator (thin aggregator)
  # Phase 2, planned (gated on #40):
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
- Phase 1 review leftovers (scene-validation ownership, validation-state API, game marker subclass) — [#47](https://github.com/simonkuhlo/unrelated-vibe-game/issues/47).
- Async loader — [#36](https://github.com/simonkuhlo/unrelated-vibe-game/issues/36).
- Downloadable packs — [#17](https://github.com/simonkuhlo/unrelated-vibe-game/issues/17).
- Content hashing — [#16](https://github.com/simonkuhlo/unrelated-vibe-game/issues/16).
- Map config/setup — [#10](https://github.com/simonkuhlo/unrelated-vibe-game/issues/10).

## Related

- [Maploader Roadmap](maploader-roadmap.md)
- [Issue #46: Phase 1 review follow-ups](https://github.com/simonkuhlo/unrelated-vibe-game/issues/46)
- [Issue #47: Phase 1 review design leftovers](https://github.com/simonkuhlo/unrelated-vibe-game/issues/47)
- [Issue #40: loader API/host contract/unload semantics](https://github.com/simonkuhlo/unrelated-vibe-game/issues/40)
- [Issue #13: synchronous v1 loader](https://github.com/simonkuhlo/unrelated-vibe-game/issues/13)
- [Issue #15: Main bootstrap and map browser](https://github.com/simonkuhlo/unrelated-vibe-game/issues/15)
- [Issue #18: tests for the new data model](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18)

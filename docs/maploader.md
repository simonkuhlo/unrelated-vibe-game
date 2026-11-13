# Map Loader

**Status:** Rework in progress ([#35](https://github.com/simonkuhlo/unrelated-vibe-game/issues/35)).
The previous catalog/repository design has been removed. This document is a
short current-state note; the full v1 contract, decisions log, and test plan
will be rewritten with the implementation.

## Direction

The rework moves map data authoring into the Godot editor and treats the
editor's resource graph as the authority:

- **Editor-first authoring.** Map data is created and edited through the
  inspector.
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

## Current state

| Area | State | Location or issue |
|---|---|---|
| Data model | Draft, additive | `system/maploader_new/` |
| Built-in content seed | Draft | `game/maps/map_db.tres`, `game/maps/test_box/` |
| Synchronous loader | Not implemented | [#13](https://github.com/simonkuhlo/unrelated-vibe-game/issues/13) |
| Main bootstrap and map browser | Not implemented | [#15](https://github.com/simonkuhlo/unrelated-vibe-game/issues/15) |
| Tests for the new model | Not implemented | [#18](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18) |
| Async loader | Deferred | [#36](https://github.com/simonkuhlo/unrelated-vibe-game/issues/36) |
| Downloadable packs | Deferred | [#17](https://github.com/simonkuhlo/unrelated-vibe-game/issues/17) |
| Content hashing | Deferred | [#16](https://github.com/simonkuhlo/unrelated-vibe-game/issues/16) |
| Map config/setup | Deferred | [#10](https://github.com/simonkuhlo/unrelated-vibe-game/issues/10) |

The draft classes still use a `_new` suffix and contain known sketch points.
Do not treat them as the final API until [#35](https://github.com/simonkuhlo/unrelated-vibe-game/issues/35)
finalizes them.

## Removed old model

The cleanup for #35 removed the superseded catalog/repository implementation
from `system/maploader/`:

- `MapManifest` (string-path manifest)
- `MapCatalog` and `MapCatalogSource`
- `MapRepository`
- `MapScene` (untyped `SpawnPoints/` and `Markers/` conventions)
- `LoadedMap` (handle over the old `MapScene`)

Their unit/integration suites and `tests/fixtures/maps/` fixtures were removed
with them. The old design remains available in git history and in the #35
discussion.

Replacement tests and contracts are tracked in
[#18](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18) and the
implementation issues above.

## Related

- [Maploader Design Session Roadmap](maploader-design-session-roadmap.md)
- [Issue #38: housekeeping and issue graph cleanup](https://github.com/simonkuhlo/unrelated-vibe-game/issues/38)
- [Issue #13: synchronous v1 loader](https://github.com/simonkuhlo/unrelated-vibe-game/issues/13)
- [Issue #15: Main bootstrap and map browser](https://github.com/simonkuhlo/unrelated-vibe-game/issues/15)
- [Issue #18: tests for the new data model](https://github.com/simonkuhlo/unrelated-vibe-game/issues/18)

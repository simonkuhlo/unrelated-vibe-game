# Maploader Roadmap

**Status:** Active — Phase 0 closed 2026-11-13; Phase 1 closed 2026-11-13. Phase 2 is
gated on #40.

## Summary

The maploader v1 rework (#35) left behind additive `_new` draft classes. This document
records the Phase 0 design decisions and the roadmap to finalize the data model and
establish the v1 contracts.

## Roadmap

### Phase 0 — Design Session (Gate) — **CLOSED 2026-11-13**
- [x] Finalize the DB shape/identity (`MapDB` array, `manifest.id` sole identity).
- [x] Finalize the manifest fields (v1: `id`, `scene`, `display_name`, `thumbnail`; `version` dropped).
- [x] Finalize the `MapScene` marker contract (`Markers` root, `MapMarker`, filter-based API).
- [x] Finalize validation ownership and error surfacing (structured issues, `MapDB` validation state).
- [x] Finalize loader API/unload semantics — **deferred to #40**.
- [x] Create #40 for the deferred loader design discussion.

### Phase 1 — Finalize Data Model (#18) — **CLOSED 2026-11-13**
- [x] Rename `system/maploader_new/` to `system/maploader/` (drop `_new`).
- [x] Implement `MapDB`, `MapManifest`, `MapScene`, `MapMarker`, `MapMarkerCollection`, `MapMarkerFilter`, `MapFilter`, `MapValidator`, `MapValidationIssue`.
- [x] Add unit tests for DB, manifest, marker collection, validation.
- [x] Add content tests.
- [x] Update `game/maps/test_box` to the final marker model.
- [x] Update `docs/maploader.md`.

Phase 1 closeout follow-ups landed in #44: strict snake_case ids, `MapScene.markers`
and the `Markers` node name aligned with decision A8, validation feedback from tool
buttons, and validation-state/tests/docs cleanup. Phase 1 review follow-ups landed
in #46: stronger content-test scene checks, marker-root validation, stricter ID
handling, and documentation of the id/validation conventions. Design-level
leftovers are tracked in #47.

### Phase 2 — Synchronous Loader (#13) — **GATED ON #40**
- Implement `MapLoader` and `LoadedMap` per #40.
- Loader-owned map root, terminal signal-based completion.

### Phase 3 — Main & Bootstrap (#15)
- Wire `Main` -> `World/MapHost`.
- Minimal map browser.

### Phase 4 — V1 Closeout
- Finalize `docs/maploader.md` and related documentation.

## Decisions (2026-11-13)

| # | Decision |
|---|---|
| A1 | `MapDB.maps: Array[MapManifest]` + linear lookup. No runtime index/cache. |
| A2 | `manifest.id` is the sole identity. Duplicates detected by `MapDB.validate()`. Ids read-only at runtime. `MapDB` tracks validation state — must be revalidated before the loader uses it. No custom inspector plugin. |
| A3 | Id format: `StringName`, lowercase `snake_case`. |
| A4 | `version` dropped from the v1 manifest. |
| A5 | `id`, `scene`, `display_name` required; `thumbnail` warning only. |
| A6 | `get_maps(filter: MapFilter)` returns an array copy; read-only is a documented convention. `clear_db` is editor-only. |
| A7 | Plain array inspector; no `quick_add_map`. |
| A8 | `MapScene` exposes only a `Markers` root via a typed node export. Game-level subclass for game-specific markers. |
| A9 | `MapMarker extends Marker3D`; `MapMarkerCollection extends Node3D`; filter-based API. Only the base `MapMarker` ships in v1. |
| A10 | Multiplayer spawn indexing/selection is out of scope for this system. |
| A11 | `SpawnPoint`/`PlayerSpawnPoint`/`ItemSpawnPoint` are not v1 classes. |
| A12 | `MapScene` does not shortcut the `Markers` API. |
| A13 | Marker order: depth-first tree order. |
| A14 | Validation triggers: `@export_tool_button("Validate")` on `MapDB`/`MapManifest`/`MapScene`, `_get_configuration_warnings()`, CI content test. No editor plugin. |
| A15 | Loader configured through exports on the loader node (`map_db`, `map_host`), not `setup(db, host)`. |
| A16 | Loader API, host contract, and unload semantics deferred to #40. |

## Deferred items

- Loader API, host contract, and unload semantics — #40.
- Async loader — #36.
- Downloadable packs — #17.
- Content hashing — #16.
- Map config/setup — #10.

# Maploader Design Session Roadmap

**Status:** Draft.

## Summary
The maploader v1 rework (#35) left behind additive `_new` draft classes. This document outlines the roadmap to finalize the data model and establish the v1 contracts, following the roadmap established in the recent design review.

## Roadmap

### Phase 0 — Design Session (Gate)
- Finalize the DB shape/identity.
- Finalize the manifest fields (v1: `id`, `display_name`, `scene`, `thumbnail`).
- Finalize `MapScene` spawn point contract.
- Finalize validation ownership and error surfacing.
- Finalize loader API/unload semantics.

### Phase 1 — Finalize Data Model (#18)
- Rename `system/maploader_new/` to `system/maploader/` (drop `_new`).
- Implement `MapDB`, `MapManifest`, `MapScene`, `SpawnPointCollection`.
- Add unit tests for DB, manifest, spawn collection.
- Add content tests.
- Update `docs/maploader.md`.

### Phase 2 — Synchronous Loader (#13)
- Implement `MapLoader` and `LoadedMap`.
- Loader-owned map root, terminal signal-based completion.

### Phase 3 — Main & Bootstrap (#15)
- Wire `Main` -> `World/MapHost`.
- Minimal map browser.

### Phase 4 — V1 Closeout
- Finalize `docs/maploader.md` and related documentation.

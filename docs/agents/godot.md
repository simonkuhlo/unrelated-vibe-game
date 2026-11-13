# Godot File Hygiene

**Status:** Active. Checklist for scene, resource, asset, and project-setting changes.

Use this checklist when changing scenes, resources, assets, project settings, or
tests that depend on the Godot import cache.

## Do not touch

- `.godot/` — generated import cache; already gitignored.
- `reports/` — generated gdUnit4 reports; already gitignored.
- `build/` — generated exports; already gitignored.
- `addons/gdUnit4/` — vendored dependency. Upgrade it only through
  `docs/testing.md#framework-upgrades`.
- `.uid` and `.import` files — keep them. They connect scripts, scenes, and
  assets to stable IDs and import settings.

## Prefer the editor

Prefer the Godot editor for `.tscn` and `.tres` changes. It preserves UIDs,
resource IDs, and formatting.

If you must hand-edit a `.tscn` or `.tres`:

- preserve `format=3`
- preserve `uid="uid://..."`
- preserve `load_steps=N`
- preserve `ext_resource` and `sub_resource` IDs
- keep `[node ...]` paths and ownership intact
- do not reorder resources blindly
- run the parser gate afterward

## Tool scripts and validation

- Editor-facing classes (anything used by `@export_tool_button`,
  `_get_configuration_warnings()`, or the inspector) must be `@tool`. Headless CI
  does not execute editor paths, so broken editor feedback passes tests.
- `@export_tool_button` discards the callable's return value. A validation button
  must report results itself (log or push warnings/errors) instead of returning an
  issue array. Follow `MapValidationIssue.log_all()` in `system/maploader/`.
- Surface warnings as well as errors from `_get_configuration_warnings()`;
  otherwise warning-only checks are invisible during authoring.
- Validation state kept on a resource is advisory. If it can go stale through
  inspector edits or direct array mutation, document what it means and make
  consumers re-validate instead of trusting the flag.

## Assets

- Do not rewrite binary assets unless the issue asks for it.
- Keep map-owned assets under `game/maps/<map_id>/`.
- Keep shared project assets under `assets/`.
- Keep test fixtures under `tests/fixtures/`, not in production folders.
- Do not copy large production assets into tests.

## Project settings

- Prefer the editor for `project.godot` changes.
- Autoloads, input actions, physics settings, and rendering changes affect the
  whole project. Document them and add tests where possible.
- Do not change the pinned engine version (`.godot-version`) without a dedicated
  upgrade issue and PR.

## Tests

- Test tiers and policy: `docs/testing.md`.
- Unit tests must not depend on the scene tree.
- Integration tests own scenes, signals, and lifecycle.
- Content tests own map database entries, manifests, and export filters.
- Free every node you create. gdUnit4 reports orphans as exit `101`.
- Bound every wait with a timeout.
- Do not write to `res://`; use `user://` and clean up.
- Headless Godot does not deliver `InputEvent`s. Do not write input-simulation
  tests for headless runs.

## Verify

After scene, resource, asset, or project-setting changes:

```bash
pwsh ./scripts/check.ps1
pwsh ./scripts/verify.ps1
```

On Windows PowerShell:

```powershell
.\scripts\check.ps1
.\scripts\verify.ps1
```

If Godot is not on `PATH`, set `GODOT_BIN` or pass `-GodotBin`.

## Related

- `AGENTS.md`
- `docs/testing.md`
- `docs/architecture.md`
- `docs/maploader.md`

# Testing

**Status:** Active. Foundation implemented in #21; CI gates implemented in #22.
**Framework:** gdUnit4 6.2.3, vendored under `addons/gdUnit4/`.
**Pinned engine:** Godot 4.7.2 (`.godot-version`).

## What testing is for

Tests are **executable contracts and regression alarms**, not a coverage score.
They exist so that changes to `system/`, `game/`, and content can be made
quickly without silently breaking something else.

Tests answer three questions:

1. Does the project still parse, import, and boot?
2. Do the contracts and invariants we rely on still hold?
3. Did a specific bug stay fixed?

Tests do not judge feel, visuals, audio, latency, or platform behavior. Those
are human checks recorded in the PR.

## Tiers

| Tier | Directory | Runs | Purpose |
|---|---|---|---|
| Parse/import/boot | repo | Every PR | Broken scripts, resources, scenes |
| Unit | `tests/unit/` | Every PR | Pure logic, APIs, invariants, no scene tree |
| Integration | `tests/integration/` | Every PR | Scenes, signals, lifecycle, UI wiring |
| Content | `tests/content/` | Every PR + nightly | Manifests, catalogs, export filters |
| Export/boot smoke | CI nightly | Nightly | Packaging and startup |
| Multiplayer loopback | `tests/network/` (future) | Deferred | Protocol and state-machine regressions |

Keep unit tests free of scene dependencies. If a test needs a scene, a signal,
or engine state, it belongs in `integration/`.

## Layout

```text
tests/
  unit/
    smoke/
    maploader/        # mirrors system/maploader
  integration/
    smoke/
    maploader/
  content/
  fixtures/
    maps/
  tools/              # tooling invoked by scripts/ (excluded from exports)
```

Suite files are named `test_*.gd` and extend `GdUnitTestSuite`. Test methods
start with `test_`. Discovery is by directory and base class; there is no
registration file.

Fixtures are shared scenes, resources, and small data files under
`tests/fixtures/`. Do not copy large production assets into tests.

## Policy

- **Behavior changes include tests.** If behavior changes and no test changes,
  the PR is incomplete.
- **Bug fixes include a regression test** that fails before the fix.
- **Manual escape hatch.** If automation is genuinely impractical, the PR must
  say why and list exact manual steps, including what to click, what to observe,
  and what counts as a pass. "Tested locally" is not a manual test.
- **Never weaken the gate.** Do not delete, skip, or loosen a test, or remove a
  CI check, to get a green build. Fix the cause or open an issue.
- **No coverage threshold.** Coverage is a diagnostic, not a target.
- **No silent retries.** Flaky tests are fixed or quarantined with a linked
  issue and a skip reason, not retried until they pass.

## Writing a test

```gdscript
extends GdUnitTestSuite


func test_manifest_defaults() -> void:
	var manifest := MapManifest.new()

	assert_that(String(manifest.map_id)).is_empty()
	assert_int(manifest.player_min).is_equal(1)
	assert_int(manifest.player_max).is_equal(32)
```

Parameterized tests put the cases in a default `_test_parameters` argument:

```gdscript
func test_player_range(player_min: int, player_max: int, _test_parameters := [
	[1, 32],
	[2, 4],
]) -> void:
	var manifest := MapManifest.new()
	manifest.player_min = player_min
	manifest.player_max = player_max

	assert_bool(manifest.player_min <= manifest.player_max).is_true()
```

Useful rules:

- Assert behavior and public contracts, not private methods.
- Prefer real fixtures and fakes over deep mocks.
- One behavior per test; the test name states the behavior.
- Bound every async wait (`await_signal_on(..., timeout)`), never wait forever.
- Free nodes with `auto_free()` or add them to the tree and free them explicitly.
- gdUnit4 reports orphan nodes automatically; do not leave nodes behind.

## Running tests

```powershell
# Everything: static checks + unit + integration + content
.\scripts\verify.ps1

# Fast tier while iterating
.\scripts\test.ps1 -Tier unit

# One suite or one file
.\scripts\test.ps1 -Path tests/unit/smoke/test_framework_smoke.gd

# Static checks only
.\scripts\check.ps1
```

Scripts resolve Godot from `-GodotBin`, `GODOT_BIN`, `GODOT`, the Steam install
location, or `PATH`, in that order. They warn when the binary does not match
`.godot-version`.

Reports are written to `reports/report_<n>/` (`results.xml` and `index.html`)
and are gitignored.

### Exit codes

gdUnit4 returns `0` for pass, `100` for test failures, and `101` for warnings
and orphan nodes. `scripts/test.ps1` treats every non-zero code as a failure.

gdUnit4 also returns `0` when it collects **zero** tests. The script guards
against that: if the report contains no `testcase` elements, the run fails.

### Headless limitation

gdUnit4 v6 requires `--ignoreHeadlessMode` for headless runs, and the flag must
be passed **after** the `-s` script path. This is handled by `scripts/test.ps1`.

In headless mode Godot does not deliver `InputEvent`s, so tests that simulate
UI input do not work. Do not write input-simulation tests until gdUnit4 v7 is
adopted (it adds true headless scene-runner support). If such a test becomes
necessary earlier, run that job under `xvfb` on Linux instead of assuming it
works headless.

## CI gates

Every pull request runs:

- `static`: import, parse every first-party `.gd`, boot the main scene.
- `test`: gdUnit4 unit + integration + content, JUnit/HTML report artifacts,
  zero-test guard, fail on exit `100`/`101`.
- `CI`: an aggregate job that is the only required branch-protection check.

The gate targets five minutes. Slow or environment-heavy checks (export, boot
smoke) run nightly, not on PRs. See [ci.md](ci.md) for workflow details,
artifacts, and the branch-protection setup.

## Determinism rules

- Seed random number generators; never rely on wall-clock timing.
- No sleeps for synchronization; await signals with a bounded timeout.
- No external network access in PR tests.
- Do not write to `res://`; use `user://` and clean up afterward.
- Change project settings only through engine APIs; gdUnit4 restores settings
  around each suite and test.
- Reset global state (autoloads, input actions, physics settings) in
  `before_test()`/`after_test()` if the test touches it.

## Export exclusion

Production exports must exclude:

- `tests/*`
- `reports/*`
- `addons/gdUnit4/*`

The rules live in `export_presets.cfg` and are guarded by
`tests/content/test_export_presets.gd` on every pull request. The nightly
workflow verifies the built `.pck` contains `game/main.tscn` but not `tests/` or
`addons/gdUnit4/`, then boots the exported build.

## Framework upgrades

gdUnit4 is pinned. Upgrade deliberately, in a dedicated PR:

1. Read the release notes and the supported Godot version.
2. Replace `addons/gdUnit4/` with the new release.
3. Update the version in this document and `addons/gdUnit4/plugin.cfg`.
4. Run `.\scripts\verify.ps1` and the nightly export.
5. Check whether the `--ignoreHeadlessMode` workaround can be removed (v7+).

Do not run update checks in CI; update notifications are disabled in
`project.godot`.

## Manual testing

Manual tests are valid only when automation is impractical. Record them in the
PR under **Manual test**:

- Preconditions (branch, map, scene, build).
- Exact steps.
- Expected result.
- What was actually observed.

Example:

```text
Manual test: map browser list
1. Open the project in Godot 4.7.2 and run Main.
2. Open the map browser.
Expected: the built-in catalog lists every map with a thumbnail.
Observed: two maps listed, thumbnails loaded, scrolling stayed smooth.
```

## Troubleshooting

- **"Godot executable not found"** — set `GODOT_BIN` or pass `-GodotBin`.
- **Version warning** — install the version in `.godot-version`.
- **No tests collected** — the path passed to `-Path` is wrong or the suite does
  not extend `GdUnitTestSuite`.
- **Tests hang** — a wait is unbounded; add a timeout and await a signal.
- **Orphan warning (exit 101)** — a node was created and not freed; use
  `auto_free()` or free it in the test.

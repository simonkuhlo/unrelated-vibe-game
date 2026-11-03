# Testing framework evaluation: GUT vs gdUnit4

**Date:** 2026-11-03
**Status:** Accepted. gdUnit4 6.2.3 was adopted in #21 after a compatibility spike on Godot 4.7.2 (Windows). Linux is verified by CI.
**Scope:** Choosing a base for the project's automated test system
**Related:** [Issue #11](https://github.com/simonkuhlo/unrelated-vibe-game/issues/11), [Issue #21](https://github.com/simonkuhlo/unrelated-vibe-game/issues/21), [Map Loader test plan](../maploader.md#test-plan)
**Recommendation:** gdUnit4 6.2.3, with GUT 9.7.1 as the fallback if truly headless scene/input testing is required today

---

## 1. Executive summary

Both GUT and gdUnit4 are mature, MIT-licensed Godot 4 testing frameworks that can serve as the base of a scalable test system. They both support test discovery by convention, assertions, test doubles/mocks, parameterized tests, hooks, asynchronous tests, JUnit XML output, and command-line execution. Neither is a risky or unusual choice.

The differences are mostly about **what comes in the box** and **how closely the project follows the latest Godot release**:

- **GUT 9.7.1** is the simpler, more widely used option. Its command-line runner is straightforward and is commonly used with `--headless`. It has a smaller API surface, a large body of examples, and an established community. However, Godot 4.7 support lives on a dedicated `godot_4_7` branch while `main` targets Godot 4.6, and GUT provides fewer automatic guardrails for test isolation and diagnostics.
- **gdUnit4 6.2.3** is the more capable, faster-moving option. It adds a scene runner with input simulation, automatic orphan-node reporting with stack traces, per-test timeouts, optional flaky-test retries, project-settings snapshot/restore, HTML reports, and an official GitHub Action. It supports Godot 4.7 directly in its stable line and is already developing v7 for Godot 4.7/4.8. Its main drawback today is that gdUnit4 v6 needs `--ignoreHeadlessMode` for headless runs, and true headless scene-runner support is in v7, which was not yet tagged at the time of this research.

For this project, the long-term fit favors **gdUnit4**. The project is a 3D multiplayer game at the very beginning of its test suite. The tests that will matter later are not only pure functions; they will involve scenes, nodes, input, physics, map loading/unloading, and network timing. gdUnit4's scene runner, orphan detection, per-test timeouts, and isolation features are directly aligned with those needs. The headless limitation is temporary and does not block the first map-loader tests, which are logic/resource/lifecycle tests rather than input-simulation tests.

GUT remains a defensible choice if the team values simplicity and immediate, workaround-free headless execution more than advanced scene-testing and diagnostics features.

This evaluation does not implement either framework. It records the research and the reasoning behind the recommendation.

---

## 2. Project context and constraints

The decision should be judged against this project, not in the abstract.

| Constraint / context | Implication |
|---|---|
| Godot 4.7, Forward+, Jolt Physics | The framework must support Godot 4.7 now and survive future Godot upgrades. |
| 3D multiplayer game (planned) | Tests will eventually cover scenes, player/entity lifecycle, physics, networking, and UI, not just pure functions. |
| No GDScript or tests exist yet | There is no migration cost. This is the cheapest time to choose a framework. |
| `system/` is intended to be reusable and game-agnostic | Tests for `system/` should not pull in `game/` or `ui/`; test layout should respect the architecture boundaries. |
| `docs/maploader.md` contains the first detailed test plan (~30 v1 cases) | The framework must handle resource fixtures, load/unload lifecycles, async signals, error paths, and test maps. |
| `docs/architecture.md` already reserves `tests/` and excludes test content from exports | The chosen framework and its addon must not ship in production builds. |
| Issue-driven, agent-assisted workflow | The runner must be deterministic, scriptable, machine-readable, and easy to invoke without editor clicks. |
| Windows-first development, GitHub hosting | The local wrapper must handle Windows paths and the Steam Godot executable. CI is not yet configured. |
| Existing decision in `docs/maploader.md`: "minimal headless GDScript runner; no third-party addon" | Adopting GUT or gdUnit4 is a deliberate reversal of that decision and must be recorded if accepted. Issue #11 explicitly excludes replacing the runner with GUT/gdUnit4. |

### 2.1 The existing decision that this research challenges

`docs/maploader.md` currently says the v1 test plan uses a minimal `tests/run_tests.gd` runner with no third-party addon. Issue #11 implements that runner and lists "Replacing the runner with GUT/gdUnit4" as out of scope.

That was a reasonable default while the project had no tests. The trade-off changes once the test suite is expected to grow beyond a handful of map-loader checks:

- A custom runner starts with discovery and a few asserts, then accumulates async helpers, doubles, fixtures, reporting, timeouts, and isolation logic.
- Those are exactly the problems GUT and gdUnit4 already solve.
- The cost of adopting a framework is a third-party dependency; the cost of maintaining a home-grown runner is ongoing and grows with the suite.

If a framework is adopted, the "minimal runner / no addon" decision and the scope of issue #11 should be revisited together.

---

## 3. Research method

The evaluation used:

- Official documentation for both frameworks.
- GitHub release history and release notes.
- GitHub repository metadata and activity (stars, open issues, last push, branch state).
- Source inspection of the GUT test class and CLI entry point.
- Source inspection of gdUnit4 settings, CLI entry point, and the official GitHub Action.
- Compatibility matrices published by both projects.
- The project's own architecture, map-loader design, and issue #11.

**Limitations:**

- No hands-on spike was run in the Godot editor.
- No benchmark of discovery time, suite runtime, or memory usage was performed.
- Qualitative ratings such as "simpler" or "more agent-friendly" are judgments, not measurements.
- Version facts are as of **2026-11-03** and will age. The source links are included so the data can be re-checked.

---

## 4. Framework snapshots

### 4.1 GUT (Godot Unit Test)

- **Evaluated version:** 9.7.1 (published 2026-07-10).
- **Godot compatibility:** 9.7.1 targets Godot 4.7.x on the `godot_4_7` branch. The `main` branch is documented as 4.6.x.
- **License:** MIT.
- **Installation:** Asset Library or manual copy of `addons/gut`; enable the plugin for editor use.
- **Core model:** test scripts extend `GutTest`; methods starting with `test_` are run. Test scripts are discovered by directory, prefix, and suffix conventions.
- **Notable features:**
  - Large assertion and utility API.
  - Inner test classes for grouping related tests.
  - Full doubles, partial doubles, stubbing, and spies.
  - Parameterized tests.
  - Async helpers: `wait_for_signal`, `wait_seconds`, `wait_process_frames`, `wait_physics_frames`, `wait_until`, `wait_while`.
  - Error tracking for engine errors, `push_error`, and `push_warning`.
  - `assert_no_new_orphans()` and orphan counting.
  - JUnit XML export.
  - Command-line runner and VSCode extension.
- **Community:** Long-lived project (created 2016), approximately 2,775 GitHub stars, 156 forks, roughly 82 open issues at the time of research. Maintained primarily by one author.
- **Footprint:** Approximately 2.43 MB and 259 files in `addons/gut` at the evaluated branch.

### 4.2 gdUnit4

- **Evaluated version:** 6.2.3 (published 2026-11-01).
- **Godot compatibility:** v6.2.x supports Godot 4.5 through 4.7.1. The `master` branch identifies as v7.0.0 and lists Godot 4.7, 4.7.1, and 4.8-dev support.
- **License:** MIT.
- **Installation:** Asset Library or manual copy of `addons/gdUnit4`; enable the plugin.
- **Core model:** test suites extend `GdUnitTestSuite`; test methods start with `test_`. The editor inspector discovers suites; the CLI can run files or directories directly.
- **Notable features:**
  - Fluent assertion API (`assert_that(...).is_equal(...)`, specialized assertions).
  - Mocks, spies, argument matchers, scene mocking.
  - Parameterized tests and fuzzing.
  - Scene runner with mouse, keyboard, touch, and custom input simulation.
  - Session hooks and per-suite hooks.
  - Automatic orphan-node reporting with stack traces (Godot 4.5+).
  - Per-test timeouts (default 5 minutes, configurable per case).
  - Flaky-test detection with configurable retries (disabled by default).
  - Project-settings snapshot/restore around suites and tests (enabled by default).
  - HTML and JUnit XML reports, report history, and log capture.
  - Official GitHub Action and editor test generation.
  - C# support through GdUnit4Net (not relevant to this GDScript project, but future-proofing).
- **Community:** Created 2022, now hosted under `godot-gdunit-labs`. Approximately 1,287 GitHub stars, 81 forks, roughly 12 open issues at the time of research. Org-backed with frequent releases and sponsor support.
- **Footprint:** Approximately 2.27 MB and 613 files in `addons/gdUnit4` at v6.2.3.

---

## 5. Comparison

### 5.1 Capability matrix

Ratings are relative to this project's needs: a growing 3D multiplayer Godot 4.7 project with headless CI aspirations. `Strong` means the framework covers the need well out of the box; `Adequate` means it is possible but requires manual work or conventions; `Mixed` means there is a material caveat.

| Criterion | GUT 9.7.1 | gdUnit4 6.2.3 | Notes |
|---|---|---|---|
| Godot 4.7 support | Good | **Strong** | GUT uses a dedicated 4.7 branch; gdUnit4 supports 4.7 in its stable v6 line. |
| Release cadence / maintenance | Moderate | **Strong** | GUT's 4.7 branch had no commits after 2026-07-09; gdUnit4 released 6.2.3 on 2026-11-01 and is actively developing v7. |
| Headless execution today | **Strong** | Mixed | GUT's CLI is commonly run with `--headless`. gdUnit4 v6 requires `--ignoreHeadlessMode`; v7 adds true headless scene-runner support but was not tagged at the time of research. |
| Assertions | **Strong** | **Strong** | GUT is simpler; gdUnit4 is more expressive and has richer failure output. |
| Doubles / mocks / spies | **Strong** | **Strong** | Both are capable. GUT's 4.7 doubles return type-appropriate defaults instead of `null`, which can create subtle false positives. |
| Parameterized tests | **Strong** | **Strong** | Both support them. |
| Async / signal testing | **Strong** | **Strong** | Both have signal assertions and bounded waits. gdUnit4 adds per-test timeouts. |
| Scene/integration testing | Adequate | **Strong** | gdUnit4 has a dedicated scene runner with input simulation and scene accessors. GUT can load and manipulate scenes, but input and cleanup are more manual. |
| Orphan-node detection | Adequate | **Strong** | GUT has an explicit `assert_no_new_orphans()`; gdUnit4 reports orphan nodes automatically with creation stack traces. |
| Test isolation | Adequate | **Strong** | gdUnit4 snapshots/restores project settings by default. No equivalent automatic behavior was found in GUT's docs. |
| Per-test timeout | Not found | **Strong** | gdUnit4 can fail a test after a configured timeout. GUT has timeouts for individual waits, but a hung test relies on the outer process/CI timeout. |
| Flaky-test retry | Not found | **Strong** | gdUnit4 can rerun failed tests and mark them flaky. Use sparingly, but useful for timing-sensitive tests. |
| Reporting | Good | **Strong** | GUT exports JUnit XML. gdUnit4 exports JUnit and HTML and keeps a report history. |
| CI integration | Good | **Strong** | gdUnit4 has an official GitHub Action. No official GUT action comparable to it was identified; GUT's CLI is still straightforward to wire up. |
| Test discovery / editor UX | **Strong** | **Strong** | Both have editor panels and convention-based discovery. gdUnit4 can generate a test case from a function in the script editor. |
| API simplicity | **Strong** | Good | GUT's `assert_eq`-style API is easier to learn. gdUnit4's fluent API is more expressive but has more concepts. |
| Agent / LLM familiarity | **Strong** | Good | GUT's longer history and larger community mean more examples in training data. gdUnit4's docs are comprehensive. This is qualitative. |
| Upgrade churn | Good | Mixed | GUT's 9.x API is stable, but the 4.7 branch complicates updates. gdUnit4 has frequent major versions tied to Godot releases (v5, v6, v7). |
| Footprint / license | Equal | Equal | Both MIT and roughly 2.3 MB as addons. |

### 5.2 Weighted view

This is an illustrative weighting, not a precise measurement. It makes the trade-off explicit.

Weights: Godot 4.7/maintenance 20%, headless/CI 15%, authoring features 15%, scene/integration testing 15%, isolation/diagnostics 15%, reporting 5%, simplicity 10%, community 5%.

| Criterion | Weight | GUT | gdUnit4 |
|---|---:|---:|---:|
| Godot 4.7 / maintenance | 20% | 4 | 5 |
| Headless / CI today | 15% | 5 | 3 |
| Authoring features | 15% | 4 | 5 |
| Scene / integration testing | 15% | 3 | 5 |
| Isolation / diagnostics | 15% | 3 | 5 |
| Reporting | 5% | 3 | 5 |
| Simplicity | 10% | 5 | 4 |
| Community | 5% | 5 | 4 |
| **Weighted total** | **100%** | **3.95** | **4.55** |

The result is close enough that a short hands-on spike is still worthwhile. The weighting also shows where GUT wins: immediate headless simplicity and approachability. If "headless today" is weighted much more heavily, the gap narrows further.

---

## 6. Detailed findings

### 6.1 Godot 4.7 support and maintenance

**GUT:**

- GUT 9.7.1 is the release for Godot 4.7.x. It lives on the `godot_4_7` branch; the repository README describes `main` as targeting 4.6.x.
- The 4.7 branch's last commit at the time of research was 2026-07-09 ("Version bump, documentation for 9.7.1 release"). `main` received later commits, with the latest around 2026-08-18.
- This is a support-branch strategy, not an abandoned project. But it means 4.7-specific fixes may not automatically flow from `main`, and the project may need to track a branch rather than the default branch.
- GUT 9.7.0 was a breaking release for doubles because Godot 4.7 became stricter about return types. Doubles now return type-appropriate values (`0`, `""`, etc.) instead of `null`. Stubbing an invalid return value produces a GUT error and an engine error. This can cause subtle false positives or negatives if tests assume `null`.

**gdUnit4:**

- gdUnit4 6.2.3 explicitly supports Godot 4.5 through 4.7.1. Its release notes include 4.7-specific fixes, such as a fresh-editor font-size fix and scene-runner input delivery fixes.
- The `master` branch is v7.0.0 and lists Godot 4.7, 4.7.1, and 4.8-dev support. At the time of research, no v7 tag was present in the repository; v6.2.3 was the latest stable release.
- gdUnit4 releases frequently: v6.2.0 in July 2026, v6.2.1 in August, v6.2.2 in October, and v6.2.3 in November.
- The trade-off is more major-version churn. v5 targeted Godot 4.3/4.4, v6 targets 4.5+, and v7 targets 4.7+. That is manageable if the project pins versions and upgrades deliberately, but it is more movement than GUT's 9.x line.

**Project implication:** gdUnit4 has the healthier 4.7 story right now and a clearer path to 4.8. GUT is usable on 4.7, but the compatibility branch adds a maintenance consideration for a project that intends to grow over multiple Godot versions.

### 6.2 Headless execution and CI

**GUT:**

- The CLI entry point is `addons/gut/gut_cmdln.gd`, a `SceneTree` script. The official command-line docs show:
  - `godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd`
  - `-gexit` to exit after running.
  - Return code `0` when all tests pass and `1` when any fail (pending tests do not affect the return value).
- The docs' examples do not consistently show `--headless`, but the runner is designed to run outside the editor and community usage commonly adds `--headless`. A hands-on spike should confirm the exact Godot 4.7/Windows behavior, especially for scene and input tests.
- GUT exports JUnit XML with `-gjunit_xml_file`.
- GUT has a VSCode extension for running tests from the editor. No official GitHub Action comparable to gdUnit4's was identified; CI wiring is a matter of invoking the CLI.

**gdUnit4:**

- The CLI entry point is `res://addons/gdUnit4/bin/GdUnitCmdTool.gd`, with `runtest.cmd` / `runtest.sh` wrappers.
- The CLI returns:
  - `0` for all tests passed.
  - `100` for test failures.
  - `101` for warnings.
- By default, gdUnit4 aborts on the first test failure; `-c`/`--continue` runs the complete set.
- Reports default to `res://reports/`, with `-rd` to change the directory and `-rc` to control how many reports are kept. It generates `index.htm` and `results.xml` (JUnit).
- **Headless caveat:** gdUnit4 v6 rejects headless execution unless `--ignoreHeadlessMode` is passed. The official GitHub Action's `headless` input documents that headless mode requires v7 or newer; for v6 it needs `--ignoreHeadlessMode`. v7 adds true headless scene-runner support by hosting the scene under test in its own viewport. That work was merged on 2026-11-01, but v7 was not yet a tagged stable release at the time of research.
- gdUnit4 has an official GitHub Action that installs Godot and gdUnit4, runs tests, publishes results, and uploads reports. It can also use an already-installed plugin version.
- On Windows, the `runtest.cmd` wrapper requires `GODOT_BIN` or `--godot_binary`, and the CLI supports ANSI-colored output. A project wrapper can bypass the wrapper and call Godot directly.

**Project implication:** GUT is easier to run truly headless today. gdUnit4 v6 is usable headlessly with a documented bypass flag, which is acceptable for the map-loader tests because they do not use the scene runner. If headless input/UI scene tests are a near-term requirement, that is the strongest argument for GUT or for waiting for gdUnit4 v7. If those tests are a later concern, gdUnit4's temporary flag is a small cost.

### 6.3 Test authoring

**GUT:**

- Simple, explicit assertions: `assert_eq`, `assert_ne`, `assert_true`, `assert_false`, `assert_null`, `assert_not_null`, `assert_has`, `assert_does_not_have`, signal assertions, deep comparisons, and more.
- Inner test classes let related tests share context and setup without creating many files.
- Full and partial doubles, stubbing, and spies. Doubles are generated from scripts/scenes and freed automatically after each test. Static methods and native methods have documented workarounds and limitations.
- Parameterized tests are supported.
- Async helpers include `wait_for_signal`, `wait_seconds`, `wait_process_frames`, `wait_physics_frames`, `wait_until`, and `wait_while`. The wait helpers have their own timeouts and a `did_wait_timeout()` check.
- Error tracking can assert on engine errors, `push_error`, and `push_warning`.
- `autofree`, `autoqfree`, `add_child_autofree`, and `add_child_autoqfree` help with node cleanup.
- `assert_no_new_orphans()` checks for orphaned nodes, but it must be called explicitly.

**gdUnit4:**

- Fluent assertions (`assert_that(value).is_equal(expected)`, `assert_str`, `assert_array`, `assert_dict`, `assert_signal`, and specialized types) produce detailed failure reports.
- Mocks and spies can target classes and scenes, with argument matchers.
- Parameterized tests and fuzzing are built in.
- The scene runner can simulate mouse clicks/movements, keyboard input, touch input, and custom actions; it can wait for signals or function return values and access scene nodes.
- Session hooks and suite/test hooks support setup and teardown at multiple levels.
- `auto_free` and related helpers manage object lifetimes; orphan detection is automatic.
- Per-test timeouts prevent a single hung test from blocking the entire suite.
- Flaky-test retries can be enabled, with a configurable retry count.

**Project implication:** Both are more than sufficient for the map-loader suite. gdUnit4 has the edge for the later gameplay, physics, and UI suites, where scene input, timeouts, and orphan detection matter more. GUT's simpler assertions and inner classes are attractive for a small, logic-heavy suite.

### 6.4 Isolation, diagnostics, and maintainability

This is where the frameworks diverge most for a suite that will grow.

**gdUnit4's built-in guardrails:**

- **Project settings snapshot/restore:** Enabled by default. gdUnit4 saves and restores project settings around each suite, after `before()`, and after each test case/retry. This prevents tests that change input mappings, physics settings, or other project configuration from leaking into later tests.
- **Orphan-node reporting:** Automatically counts orphan nodes per test, including during `before()` and `before_test()`, and reports them. Detailed reporting with creation stack traces is opt-in via `collect_orphan_node_details()` because it has a runtime cost, but the count is automatic.
- **Per-test timeout:** Default 5 minutes, configurable per test. This is valuable for loader timeouts, network tests, and any test that awaits an event that may never arrive.
- **Flaky-test handling:** Optional retries with flaky marking. Useful for timing-sensitive tests, but should not be used to hide nondeterminism.
- **Error reporting:** Can treat `push_error()` and GDScript errors as test failures. This is configurable and worth enabling for a game project.

**GUT's approach:**

- Orphan detection exists but is explicit (`assert_no_new_orphans()`); a test can forget to call it.
- Error tracking exists and is capable.
- Wait helpers have timeouts, but no framework-level per-test timeout was found.
- No automatic project-settings snapshot/restore was found in the docs.
- No built-in flaky-test retry was found.
- Tests and doubles are freed automatically, which covers a large part of cleanup.

**Project implication:** A growing suite tends to accumulate order-dependent failures and forgotten cleanup. gdUnit4's defaults reduce the need for discipline and custom helpers. GUT can achieve similar results with conventions, but the conventions must be written and enforced by the team.

### 6.5 Reporting and CI integration

- **GUT:** JUnit XML export, console output, and a VSCode extension. Good enough for most CI systems.
- **gdUnit4:** JUnit XML, HTML report with failure details and logs, report history, and an official GitHub Action that can publish results. This reduces the amount of custom CI work.

The project does not have CI yet, and `docs/maploader.md` treats CI as a separate workstream. Still, the test framework should not make CI harder later. gdUnit4 is more CI-ready out of the box, with the caveat about headless mode in v6.

### 6.6 Simplicity, community, and agent-assisted development

- **GUT** is simpler to learn and has a larger community, more tutorials, and more examples. That is a real advantage for a small team and for agent-generated tests, which often benefit from familiar patterns.
- **gdUnit4** has a richer API and more concepts, but its documentation is thorough and its editor can generate test scaffolding from a function. The fluent assertions produce better failure messages, which helps when an agent iterates on a failing test.
- This project's `AGENTS.md` workflow relies heavily on agents. A framework with deterministic commands, machine-readable reports, and clear failure messages is valuable. Both qualify; gdUnit4's reports and failure diagnostics are stronger, while GUT's API is easier to imitate.

This criterion is qualitative and should be validated with a small spike if the decision is close.

### 6.7 Footprint, installation, and licensing

- Both are MIT-licensed and can be vendored into the repository.
- Both install as a Godot addon under `addons/` and require enabling the editor plugin.
- Both are roughly the same size (about 2.3 MB in the evaluated versions), so repository bloat is not a differentiator.
- gdUnit4 has more files (613 vs 259 in the evaluated versions), which adds some repository noise but does not materially change the decision.
- Both have update-check features. For a pinned dependency, update notifications should be disabled or ignored, and upgrades should be deliberate.
- Test addons and test content should be excluded from production exports. That is a packaging concern for either choice.

---

## 7. How the frameworks fit this project's test plan

### 7.1 Map loader tests

The map loader test plan in `docs/maploader.md` is the first real workload. It includes:

- Catalog loading and validation.
- Exact version/hash matching and semver selection.
- Invalid entries, missing scenes, duplicate versions, and format-version errors.
- Loader state transitions and signals.
- Load/unload, cancellation, concurrent unload, timeout, and failures.
- Thumbnail loading and cache behavior.
- Test catalogs and test map fixtures.

Most of these are logic, resource, and scene-lifecycle tests. They need:

- Fixture resources and test maps.
- Async signal waiting with timeouts.
- Error-path assertions.
- Cleanup between tests.
- Parameterized cases for version/hash/error matrices.
- A way to run a subset quickly.

Both frameworks can do this. gdUnit4's per-test timeout and orphan detection are useful for load/unload and failure-path tests. GUT's simpler assertions and `wait_for_signal` are also a good fit. Neither choice blocks the map loader.

### 7.2 Future gameplay, physics, and UI tests

This is where the decision matters more:

- **Scene runner:** gdUnit4's scene runner is a significant advantage for input, movement, interaction, and UI tests. GUT requires more manual input-event construction and scene management.
- **Orphan detection:** Entity spawning/despawning and map unloading are exactly the kind of code that leaks nodes. gdUnit4's automatic reporting is a strong maintainability feature.
- **Timeouts and flaky retries:** Physics and network tests are timing-sensitive. gdUnit4 has built-in handling; GUT relies on the test author and CI timeout.
- **Project settings isolation:** As the project adds input actions, physics settings, and network configuration, tests that modify project settings become more likely. gdUnit4's snapshot/restore reduces cross-test contamination.

### 7.3 Test layout

Two layouts are plausible:

**Root `tests/` with tiers and mirrored source:**

```text
tests/
  smoke/
  unit/
    system/
    game/
  integration/
    system/
    game/
  scenes/
  fixtures/
  maps/
```

Benefits: clear fast/slow separation, easy export exclusion (`tests/*`), one place to find tests, and straightforward CI path filters.

Drawback: tests for `system/` are not co-located with the system code, which slightly weakens the "copy `system/` into another project" story.

**Co-located tests:**

```text
system/maploader/tests/
game/session/tests/
tests/fixtures/
tests/maps/
```

Benefits: a system and its tests travel together; boundaries are obvious.

Drawbacks: export exclusion is more complex, test discovery needs multiple roots or recursive rules, and fast/slow tiers are less obvious.

The architecture currently says `tests/` holds test fixtures and the headless runner, so the root layout is the smaller documentation change. The co-located layout is worth considering if `system/` portability becomes a priority. This is an open decision, not a reason to prefer one framework over the other.

### 7.4 Export and packaging

For either framework:

- `tests/*` should be excluded from exports.
- The test addon (`addons/gut/*` or `addons/gdUnit4/*`) should be excluded from production builds.
- Generated reports (for example `reports/*`) should be gitignored and excluded from exports.
- Test maps and fixtures must remain loadable in the editor and in headless runs, so they should not use `.gdignore` just to hide them from exports. Export filters are the right tool.

This is a documentation and packaging task that applies regardless of the framework choice.

---

## 8. Risks and mitigations

| Risk | GUT | gdUnit4 | Mitigation |
|---|---|---|---|
| Framework lags Godot upgrades | 4.7 support on a dedicated branch; 4.7 branch had no commits after 2026-07-09 | Frequent major versions; v7 not yet stable | Pin versions; review at each Godot upgrade; keep a small spike project for compatibility checks. |
| Headless limitations | Generally headless-friendly, but scene/input behavior should be verified | v6 needs `--ignoreHeadlessMode`; true headless scene runner is v7 | Use v6 with the flag for logic/lifecycle tests; wait for v7 for headless scene-runner tests; or choose GUT if headless input tests are immediate. |
| Test isolation | Orphan checks and cleanup are manual | Defaults are stronger, but no framework can prevent all shared state | Document conventions; use per-test setup/teardown; rely on orphan detection and settings restore. |
| False positives from doubles | 4.7 doubles return type defaults instead of `null` | Mocking has its own limitations | Prefer real fixtures/fakes over mocks; assert behavior, not implementation details; review double usage. |
| Flaky async tests | Wait helpers have timeouts, but no per-test timeout/retry | Timeouts and retries available, but retries can mask bugs | Bound every wait; use timeouts; treat retries as a diagnostic, not a fix. |
| False green when zero tests run | CLI path/config mistakes could collect no tests | Same | The wrapper should verify that at least one test ran, not just that the process exited 0. |
| Addon noise in the repo | ~2.4 MB, ~259 files | ~2.3 MB, ~613 files | Vendor the addon, exclude it from project-wide searches/lint, and document the pinned version. |
| Test code shipping in builds | Addon and `tests/` can be included by export-all | Same | Exclude test addons, tests, and reports in export presets. |
| Upgrade churn | Stable 9.x API, but branch strategy | Frequent majors tied to Godot versions | Pin exact versions; upgrade in a dedicated branch; run the full suite after upgrades. |

---

## 9. Conclusion

### 9.1 Recommendation

**Use gdUnit4 6.2.3 as the base if the project is optimizing for long-term test capability and maintainability.**

**Decision (2026-11-03):** Accepted and implemented in #21. The compatibility
spike ran gdUnit4 6.2.3 on Godot 4.7.2 headless on Windows:

- Nested-directory discovery, parameterized tests, and async signal waits work.
- Failures return `100`; orphan warnings return `101`; a clean run returns `0`.
- A run that collects zero tests returns `0`, so the wrapper guards against it.
- `--ignoreHeadlessMode` is required and must be passed after the `-s` script
  path.

GUT remains the fallback but was not needed. See [../testing.md](../testing.md)
for the implemented policy and commands.

The strongest reasons are:

1. **It matches the project's future test surface.** Scene runner, input simulation, orphan detection, per-test timeouts, and settings isolation are directly useful for a 3D multiplayer game.
2. **It has the stronger Godot 4.7/4.8 story.** Stable 4.7 support now, active maintenance, and a v7 line already targeting 4.8-dev.
3. **It reduces custom test infrastructure.** Reports, CI integration, timeouts, isolation, and diagnostics are already solved.
4. **The headless gap does not block the first suite.** The map-loader tests are logic/resource/lifecycle tests and can run with `--ignoreHeadlessMode` on v6. The flag can be removed when v7 is stable.

### 9.2 When GUT is the better choice

Choose **GUT 9.7.1** instead if:

- Truly headless execution with no bypass flags is a hard requirement today.
- The team prioritizes the simplest possible API and the largest body of examples.
- Scene-runner-style input tests, automatic orphan detection, per-test timeouts, and flaky retries are not expected to matter in the near term.
- The team is comfortable tracking the `godot_4_7` branch and re-evaluating when Godot 4.8 arrives.

GUT is not a compromise choice. It is a mature framework that can carry the project for a long time. The recommendation is based on the expected shape of the suite, not on GUT being unsuitable.

### 9.3 Decision confidence

**Medium-high.** The version and feature facts are solid. The main uncertainty is how much the project will invest in scene/input/network testing versus pure logic tests, and whether the temporary gdUnit4 headless flag is acceptable. A short spike would resolve those questions quickly:

- Install both frameworks in a throwaway branch or separate worktree.
- Write the same smoke test and one async/map-loader-style test in each.
- Run both with `--headless` on Windows and compare exit codes, output, and failure messages.
- Try a scene test with input and observe cleanup/orphan reporting.
- Check editor discovery and the cost of running a subset.

That spike is the only missing piece of evidence.

---

## 10. Suggested next steps (not implementation)

If the project wants to act on this research:

1. **Record the decision** in the appropriate design docs. This research contradicts the "minimal runner / no third-party addon" decision in `docs/maploader.md` and the scope of issue #11, so both need an explicit update if a framework is adopted.
2. **Decide the test layout** separately: root `tests/` with tiers, or co-located tests for portability.
3. **Decide the CI timeline** separately. The framework choice should not force CI work now, but the runner should be scriptable enough to add CI later.
4. **Keep the recommendation provisional until a spike is done** if the team is split. The evaluation is close enough that hands-on evidence is more valuable than more desk research.
5. **Revisit the choice when gdUnit4 v7 is tagged**, especially if headless scene-runner tests become important.

No framework was installed and no test code was written as part of this research.

---

## 11. Sources

All URLs were accessed on 2026-11-03 unless otherwise noted.

### GUT

- Repository and README: <https://github.com/bitwes/Gut>
- Release 9.7.1: <https://github.com/bitwes/Gut/releases/tag/v9.7.1>
- Release 9.7.0 (Godot 4.7 changes): <https://github.com/bitwes/Gut/releases/tag/v9.7.0>
- Issue #816, "GUT and Godot 4.7": <https://github.com/bitwes/Gut/issues/816>
- Command-line documentation: <https://gut.readthedocs.io/en/v9.7.1/Command-Line.html>
- Doubles documentation: <https://gut.readthedocs.io/en/v9.7.1/Doubles.html>
- `GutTest` class reference: <https://gut.readthedocs.io/en/v9.7.1/class_ref/class_guttest.html>
- CLI entry point: <https://github.com/bitwes/Gut/blob/godot_4_7/addons/gut/gut_cmdln.gd>
- Repository metadata and branch activity: GitHub REST API, `repos/bitwes/Gut`, 2026-11-03.

### gdUnit4

- Repository and README: <https://github.com/godot-gdunit-labs/gdUnit4>
- Release 6.2.3: <https://github.com/godot-gdunit-labs/gdUnit4/releases/tag/v6.2.3>
- Installation: <https://godot-gdunit-labs.github.io/gdUnit4/latest/first_steps/install/>
- Settings: <https://godot-gdunit-labs.github.io/gdUnit4/latest/first_steps/settings/>
- Command-line tool: <https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/cmd/>
- Orphan-node reporting: <https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/orphan/>
- CI documentation: <https://godot-gdunit-labs.github.io/gdUnit4/latest/faq/ci/>
- Headless scene-runner issue #1475: <https://github.com/godot-gdunit-labs/gdUnit4/issues/1475>
- Official GitHub Action: <https://github.com/MikeSchulze/gdUnit4-action>
- CLI entry point: <https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/bin/GdUnitCmdTool.gd>
- Settings source: <https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/src/core/GdUnitSettings.gd>
- Windows test wrapper: <https://github.com/godot-gdunit-labs/gdUnit4/blob/v6.2.3/addons/gdUnit4/runtest.cmd>
- Repository metadata and release history: GitHub REST API, `repos/godot-gdunit-labs/gdUnit4`, 2026-11-03.

### Project

- Architecture: [`docs/architecture.md`](../architecture.md)
- Map loader design and test plan: [`docs/maploader.md`](../maploader.md)
- Issue #11, "test: add minimal headless GDScript test runner": <https://github.com/simonkuhlo/unrelated-vibe-game/issues/11>
- Agent workflow rules: [`AGENTS.md`](../../AGENTS.md)

### Version and health snapshot

| Data point | GUT | gdUnit4 |
|---|---:|---:|
| Latest evaluated release | 9.7.1 (2026-07-10) | 6.2.3 (2026-11-01) |
| Godot 4.7 support | `godot_4_7` branch | v6.2.x stable |
| Stars (approx.) | 2,775 | 1,287 |
| Forks (approx.) | 156 | 81 |
| Open issues (approx.) | 82 | 12 |
| Last push at research time | 2026-08-18 | 2026-11-03 |
| License | MIT | MIT |
| Addon size (approx.) | 2.43 MB | 2.27 MB |

The star, fork, and issue counts are health signals, not quality scores. They are included to show community size and maintenance activity, not to replace hands-on evaluation.

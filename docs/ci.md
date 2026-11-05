# Continuous Integration

**Status:** Active. Added in #22 on top of the testing foundation from #21.

The CI entry points are the same PowerShell scripts used locally, invoked through
`pwsh` on `ubuntu-latest`. This keeps local and CI behavior identical; see
[testing.md](testing.md) for the test policy itself.

## Workflows

### `.github/workflows/ci.yml`

Triggers:

- `pull_request`
- `push` to `main`
- `workflow_dispatch`

Jobs:

| Job | What it runs | Notes |
|---|---|---|
| `static` | `pwsh ./scripts/check.ps1` | Import, parse every first-party `.gd`, boot the main scene |
| `test` | `pwsh ./scripts/test.ps1` | gdUnit4 unit + integration + content, zero-test guard |
| `CI` | Result gate | Only required branch-protection check |

`test` uploads `reports/` as the `gdunit4-reports` artifact on every run,
including failures. The `CI` gate uses `if: always()` and explicitly fails
unless **both** `static` and `test` are `success`; a skipped or cancelled
dependency can never look green.

Concurrency cancels superseded pull-request runs. `permissions` is read-only.

### `.github/workflows/nightly.yml`

Triggers: daily schedule (`03:00 UTC`) and manual dispatch.

Steps:

1. Run `pwsh ./scripts/verify.ps1`.
2. Export the Linux build through the `Linux` preset in `export_presets.cfg`.
3. Boot the exported binary headless.
4. Inspect the exported `.pck`:
   - `game/main.tscn` must be present (positive control).
   - `tests/` and `addons/gdUnit4/` must be absent.

The export is uploaded only when the job fails, to make packaging failures
debuggable.

## Godot installation

Both workflows use `chickensoft-games/setup-godot@v2` with `version: 4.7.2` and
`use-dotnet: false`. The nightly adds `include-templates: true`. The action
caches the Godot download and export templates between runs.

If the action cannot resolve a future Godot release, replace it with a pinned
download of the matching `Godot_v<version>-stable_linux.x86_64.zip` and
`export_templates.tpz` from the official Godot release. Keep the version in
sync with `.godot-version`.

## Export configuration

`export_presets.cfg` defines one `Linux` preset:

- `export_filter = "all_resources"`
- `exclude_filter = "tests/*,reports/*,addons/gdUnit4/*"`
- `export_path = "build/linux/unrelated-vibe-game.x86_64"`
- `binary_format/embed_pck = false` so the nightly can inspect the `.pck`

`tests/content/test_export_presets.gd` asserts these values on every pull
request, so a bad edit fails before the nightly does.

## Local parity

Run the same entry points locally:

```powershell
.\scripts\check.ps1
.\scripts\test.ps1
.\scripts\verify.ps1
```

The scripts resolve Godot from `-GodotBin`, `GODOT_BIN`, `GODOT`, the Steam
install location, or `PATH`, in that order. See [testing.md](testing.md#running-tests).

## Artifacts

- PR runs: `gdunit4-reports` (JUnit XML + HTML, under `reports/`).
- Nightly failures: `nightly-export` (the `build/` output).

Artifacts are never committed; `reports/` and `build/` are gitignored.

## First-run behavior

For pull requests from branches in this repository, GitHub runs the workflow
from the PR head, so the pull request that introduces `ci.yml` does run its own
`CI`. This was verified on #24: `static`, `test`, and the `CI` gate all passed
on `ubuntu-latest`, including the gdUnit4 suites.

The required `CI` check can be configured as soon as the workflow has run at
least once, because GitHub only offers checks it has seen. The run on #24
satisfies that.

Pull requests from forks use the base branch's workflow and get a read-only
token. This repository does not accept fork PRs, so that path is not a concern
here.

## Branch protection

The repository already has two rulesets targeting `main`:

- `main-1` blocks deletion and non-fast-forward pushes.
- `main-2` requires a pull request and code-owner review.

Add the remaining requirements at any point after `CI` has run:

1. Open **Settings → Rules → Rulesets → `main-2`**.
2. Enable **Require status checks to pass** and add **`CI`**.
3. Enable **Require branches to be up to date before merging**.
4. Restrict **Allowed merge methods** to **Squash** only.
5. Keep force-push and deletion blocked (already covered by `main-1`).
6. In **Settings → General**, enable **Automatically delete head branches**.

The equivalent ruleset body for the `main-2` pull request rule is:

```json
{
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "required_reviewers": [],
        "require_code_owner_review": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": false,
        "required_status_checks": [{ "context": "CI" }]
      }
    }
  ]
}
```

Apply it with:

```bash
gh api repos/simonkuhlo/unrelated-vibe-game/rulesets/<ruleset-id> \
  --method PUT --input ruleset.json
```

Read the current body first and preserve rules you do not intend to change.

## Verifying the gate

Failure propagation was verified before merge on throwaway PR #25: a suite with
`assert_bool(true).is_false()` made `test` fail (gdUnit4 exit `100`), `static`
stay green, and the aggregate `CI` gate fail. The PR and branch were deleted
afterward. This proves the gate cannot pass while a suite fails; it does not by
itself prove a merge is blocked until `CI` is required by branch protection.

Once `CI` is required, prove it actually blocks merges:

1. Open a throwaway branch with a deliberately failing test (for example,
   `assert_that(true).is_false()`).
2. Open a pull request and confirm the `CI` check fails.
3. Confirm the merge button is disabled, then close the pull request and delete
   the branch.

Also confirm the zero-test guard: delete or rename every `test_*.gd`, push, and
verify `test.ps1` fails instead of reporting a green run.

# Issue Workflow

Use this runbook when you are implementing or fixing a GitHub issue. It assumes
you can run `git`, `gh`, and the project scripts.

The primary development environment is Linux. Use `pwsh ./scripts/...`; on
Windows PowerShell, substitute `.\scripts\...`.

## 0. Preconditions

```bash
git status --porcelain
git branch --show-current
gh auth status
```

- The working tree must be clean, or you must know what the existing changes are.
- You must not be on `main`.
- `gh` must be authenticated. If it is not, stop and ask.
- Godot 4.7.2 must be available. The scripts check `-GodotBin`, `GODOT_BIN`,
  `GODOT`, common install locations, then `godot` on `PATH`.

## 1. Read the issue

```bash
gh issue view 123 --json number,title,body,labels,assignees,comments
gh issue view 123 --comments
```

Read the linked docs and code. If the issue lacks a goal, acceptance criteria,
a test plan, or enough file/area pointers, comment and ask instead of guessing.

If the issue names a path that does not exist, follow the repo and note the
drift in the issue or PR.

## 2. Claim the issue

```bash
gh issue edit 123 --add-assignee "@me" --add-label "agent-in-progress"
```

Post a short plan:

```powershell
$plan = @'
## Plan

- Read: <docs and files>
- Change: <what will change>
- Test: <suite or manual check>
- Verify: `pwsh ./scripts/verify.ps1`
- Risks/unknowns: <none or list>
'@
$planFile = Join-Path $env:TEMP "issue-123-plan.md"
Set-Content -LiteralPath $planFile -Value $plan -Encoding utf8
gh issue comment 123 --body-file $planFile
```

If the label does not exist, skip it and say so in the PR.

## 3. Create a branch

```bash
git fetch origin
git checkout -b feat/123-short-description origin/main
git branch --show-current
```

Use the conventional branch type from `AGENTS.md`: `feat/`, `fix/`, `chore/`,
`docs/`, `refactor/`, `test/`, `perf/`, or `ci/`.

### Worktree variant

Use a worktree when another agent or session is already using the main checkout:

```bash
git fetch origin
git worktree add ../unrelated-vibe-game-issue-123 -b feat/123-short-description origin/main
cd ../unrelated-vibe-game-issue-123
```

Clean up after the PR is merged:

```bash
git worktree remove ../unrelated-vibe-game-issue-123
git worktree prune
```

## 4. Implement

- Keep commits focused and conventional.
- Change only what the issue needs.
- Add or update tests for behavior changes. Bug fixes need a regression test
  that fails before the fix.
- Update docs when behavior, architecture, or workflow changes.
- Do not edit `addons/gdUnit4/`, generated directories, or unrelated files.
- Re-check the branch before every commit:

```bash
git branch --show-current
```

## 5. Verify

Fast loop:

```bash
pwsh ./scripts/check.ps1
pwsh ./scripts/test.ps1 -Tier unit
```

Full gate:

```bash
pwsh ./scripts/verify.ps1
```

One suite:

```bash
pwsh ./scripts/test.ps1 -Path tests/unit/maploader/test_map_repository_queries.gd
```

If Godot is not found:

```bash
GODOT_BIN=/path/to/godot pwsh ./scripts/verify.ps1
# or
pwsh ./scripts/verify.ps1 -GodotBin /path/to/godot
```

If you cannot run Godot, say so in the PR instead of claiming tests passed.

## 6. Open a draft PR

```bash
git push -u origin <branch-name>
```

Write the body to a file, then create the PR:

```powershell
$body = @'
## Summary

<what changed>

## Related Issue

Closes #123

## Changes

- <key changes>

## Automated Tests

- <suites added or updated>
- <why no test changes are needed, if applicable>

## Manual Test

<only if automation is impractical: steps, expected, observed>

## Verification

- [ ] `pwsh ./scripts/verify.ps1` passes locally
- [ ] CI is green
'@
$bodyFile = Join-Path $env:TEMP "pr-body.md"
Set-Content -LiteralPath $bodyFile -Value $body -Encoding utf8
gh pr create --draft --title "feat: ... (#123)" --body-file $bodyFile
```

Default to a draft PR unless the user says otherwise. Link the issue with
`Closes #123` or `Fixes #123`.

## 7. Watch CI

```bash
gh pr checks --watch
gh pr checks
gh pr view --json number,title,state,isDraft,mergeable,statusCheckRollup,url
```

Read a failure:

```bash
gh run view <run-id> --log-failed
```

Common failures:

| Symptom | Check |
|---|---|
| Godot executable not found | Set `GODOT_BIN` or pass `-GodotBin`. |
| Godot version warning | Install the version in `.godot-version`. |
| Parse failure | Run `pwsh ./scripts/check.ps1` and read the first error. |
| No tests collected | The `-Path` is wrong or the suite does not extend `GdUnitTestSuite`. |
| Exit `101` | Orphan nodes or warnings; free nodes with `auto_free()` or explicitly. |
| Input-simulation test fails headless | gdUnit4 v6 does not deliver input headless; see `docs/testing.md`. |
| Workflow/action infrastructure failure | Stop and ask; do not edit tests or CI to hide it. |

Do not weaken, skip, or delete tests or CI checks to get green. Fix the cause or
open an issue.

## 8. Report back

Tell the user:

- the PR link
- what changed
- what was verified
- any manual test
- any blockers, drift, or risky follow-ups

Do not mark the PR ready or merge it unless the user asks.

## 9. Closeout

After the PR is merged:

```bash
gh issue comment 123 --body "Implemented in #<pr>."
git worktree remove ../unrelated-vibe-game-issue-123
git worktree prune
git branch -d <branch-name>
```

Only use `gh pr merge --squash --delete-branch` when the user explicitly asks.

## Related

- `AGENTS.md`
- `docs/testing.md`
- `docs/ci.md`
- `docs/agents/repo-meta.md`
- `docs/agents/godot.md`

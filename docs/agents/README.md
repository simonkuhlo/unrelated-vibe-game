# Agent Runbooks

**Status:** Active. Entry point for the agent runbooks.

These files are for agents that need exact instructions, and for humans who are
directing them. They are intentionally separate from `AGENTS.md` so capable
agents do not have to read them.

If you are a capable agent, `AGENTS.md`, `docs/testing.md`, `docs/ci.md`, the
issue, and the relevant code are usually enough. Use these runbooks when you
need exact commands, are doing repo-meta work, or are editing Godot files.

## Task router

| Task | Read | Use when |
|---|---|---|
| Implement or fix an issue | `docs/agents/issue-workflow.md` | You need the full claim → branch → verify → PR → CI flow. |
| Change CI, templates, labels, rulesets, docs indexes, or scripts | `docs/agents/repo-meta.md` | The change affects repository infrastructure rather than game behavior. |
| Edit scenes, resources, assets, or Godot project settings | `docs/agents/godot.md` | You need file-hygiene rules and verification steps. |
| Write an issue brief for an agent | `docs/agents/issue-brief.md` | You are handing work to a less-capable agent. |
| Direct or review an agent | `docs/agents/human-guide.md` | You are choosing an agent's context or reviewing its PR. |

## Repo map

| Path | Purpose |
|---|---|
| `AGENTS.md` | Entrypoint and non-negotiable rules. |
| `docs/testing.md` | Test tiers, policy, determinism, commands, troubleshooting. |
| `docs/ci.md` | CI jobs, artifacts, target branch protection, local parity. |
| `docs/architecture.md` | `system/`, `game/`, `ui/`, `tests/`, and design boundaries. |
| `docs/maploader.md` | Editor-first maploader rework status and current state. |
| `scripts/verify.ps1` | Pre-PR gate: static checks plus all test tiers. |
| `scripts/check.ps1` | Import, parse every first-party `.gd`, boot the main scene. |
| `scripts/test.ps1` | gdUnit4 suites; supports `-Tier` and `-Path`. |
| `tests/tools/check_scripts.gd` | Parser gate invoked by `check.ps1`. |
| `.github/workflows/ci.yml` | PR CI: `static`, `test`, and the `CI` gate. |
| `.github/workflows/nightly.yml` | Export, boot, and PCK-content smoke test. |
| `.github/ISSUE_TEMPLATE/` | Bug, feature, and chore issue forms. |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR body checklist. |
| `system/maploader_new/` | Draft editor-first map data model (rework in progress, #35). |
| `game/maps/` | Built-in map DB resource and map content. |
| `game/main.tscn` | Current main scene. |

## Read only what you need

Always read:

- `AGENTS.md`
- the issue, including comments
- the domain doc named by the issue or by `docs/architecture.md`
- the files you are about to change and their tests

Do not read unless the task explicitly needs it:

- `addons/gdUnit4/` — vendored dependency
- `.godot/`, `reports/`, `build/` — generated
- `docs/research/` — decision inputs, not current specs
- `docs/future/ideas/` — ideas, not accepted plans
- unrelated fixtures or production assets

If an issue names a path that does not exist, follow the repo and note the drift
in the issue or PR. Code, tests, and config beat issue text.

## Current state vs target state

Some docs describe the target design. Before assuming a setting or feature is
live, check the repo or GitHub:

```bash
git branch --show-current
gh auth status
gh api repos/{owner}/{repo}/rulesets
gh api repos/{owner}/{repo}/rulesets/<id>
gh label list
gh workflow list
```

`docs/ci.md` has a current-state section and the target branch-protection setup.
Do not assume required checks, CODEOWNERS, or squash-only merges are active just
because the target section says they should be.

## Agent etiquette

1. Claim the issue before starting.
2. Post a short plan as an issue comment.
3. Use one branch or worktree per issue.
4. Keep the PR small and linked to the issue.
5. Report path or doc drift instead of silently working around it.
6. Do not merge, mark ready, or delete branches unless the user asks.
7. Leave the worktree and issue tidy when done.

## Stop and ask

Stop and ask when:

- the issue lacks acceptance criteria or a test plan
- the issue's paths conflict with the repo
- two docs disagree about the current design
- the change touches rulesets, branch protection, secrets, Actions permissions,
  CODEOWNERS, or repository settings
- `gh` returns 403/404
- CI fails for infrastructure reasons
- you cannot explain a test failure

## Runbooks

- [Issue workflow](issue-workflow.md)
- [Repo-meta work](repo-meta.md)
- [Godot file hygiene](godot.md)
- [Issue brief template](issue-brief.md)
- [Human guide](human-guide.md)

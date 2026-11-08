# Agent Instructions for unrelated-vibe-game

This document defines how AI agents should work on this Godot 4 multiplayer 3D project. Follow these rules strictly.

## Start Here

Read this file first. Then read only the context pack for your task. Do not read the whole repo.

| Task | Read next |
|---|---|
| Capable agent implementing an issue | `docs/testing.md`, `docs/ci.md`, the issue, the relevant domain doc and code. Skip `docs/agents/*` unless you need exact commands. |
| Less-capable agent implementing an issue | `docs/agents/README.md`, then `docs/agents/issue-workflow.md` |
| Repo-meta work (CI, templates, labels, rulesets, docs, scripts) | `docs/agents/repo-meta.md` |
| Editing Godot scenes, resources, or assets | `docs/agents/godot.md` |
| Human directing an agent | `docs/agents/human-guide.md` |

The primary development environment is Linux. Use `pwsh ./scripts/...` in examples; Windows PowerShell users can substitute `.\scripts\...`.

## Core Principles

- **Never touch `main` directly** - Agents must NEVER commit, push, or make changes directly to the `main` branch unless explicitly and unambiguously instructed to do so by the user.
- **Issue-driven development** - All work should be tied to a GitHub issue.
- **Work in isolation** - Use feature branches, and consider worktrees for parallel work.
- **PRs by default** - Changes flow through pull requests with squash merges.

## Git Workflow

### Branch Naming
Always use conventional branch naming:
```
<type>/<issue-number>-<short-description>
```

**Types:**
- `feat/` - New features
- `fix/` - Bug fixes
- `chore/` - Maintenance, dependencies, tooling
- `docs/` - Documentation changes
- `refactor/` - Code refactoring without changing behavior
- `test/` - Adding or updating tests
- `perf/` - Performance improvements
- `ci/` - CI/CD changes

**Examples:**
- `feat/123-add-player-movement`
- `fix/45-resolve-network-sync-issue`
- `chore/67-update-godot-deps`

Keep descriptions short, lowercase, kebab-case.

### Starting Work on an Issue

0. **Check that the issue is ready**: It must have a clear goal, acceptance criteria, a test plan, and enough file/area pointers to start. If not, comment on the issue and ask instead of guessing.
1. **Understand the issue**: Read it with `gh issue view <number> --json number,title,body,labels,assignees,comments`.
2. **Claim it**: Assign yourself, add the in-progress label, and post a short plan.
   ```bash
   gh issue edit <number> --add-assignee "@me" --add-label "agent-in-progress"
   gh issue comment <number> --body-file <plan-file>
   ```
   If the label does not exist, skip the label and say so in the PR.
3. **Sync with main**: Fetch the latest `main` without checking it out.
   ```bash
   git fetch origin
   ```
4. **Create a branch from `origin/main`**:
   ```bash
   git checkout -b feat/123-short-description origin/main
   ```
5. **Verify**: Confirm you're not on `main` before making any changes
   ```bash
   git branch --show-current
   ```

### Making Changes

1. **Commit often with conventional commits**: Use clear, descriptive commit messages
   ```
   feat: add player movement system (#123)
   fix: resolve collision detection issue (#123)
   refactor: simplify network message handling
   ```
   - Reference the issue number in commits when relevant
   - Keep commits focused and atomic
   - Use conventional commit format when possible

2. **Stay on your branch**: Double-check your branch before every commit
   ```bash
   git branch --show-current
   ```

### Completing Work

1. **Push your branch**
   ```bash
   git push -u origin <branch-name>
   ```

2. **Open a Pull Request automatically**: Write the body to a file, then create a draft PR.
   ```powershell
   $body = @'
   ## Summary
   <brief description of changes>

   ## Related Issue
   Closes #<issue-number>

   ## Changes
   - <list key changes>

   ## Testing
   - [ ] `pwsh ./scripts/verify.ps1` passes
   - [ ] Automated tests added/updated for behavior changes
   - [ ] Manual test recorded below (only if automation is impractical)

   <how to test>
   '@
   $bodyFile = Join-Path $env:TEMP "pr-body.md"
   Set-Content -LiteralPath $bodyFile -Value $body -Encoding utf8
   gh pr create --draft --title "<descriptive title>" --body-file $bodyFile
   ```
   - Default to **draft PRs** unless explicitly told otherwise
   - Always link the issue with `Closes #123` or `Fixes #123`
   - Provide a clear summary of changes
   - Record any manual-only verification with exact steps and expected results
   - After opening the PR, watch CI with `gh pr checks --watch` and read failures with `gh run view <run-id> --log-failed`
   - Do not mark the PR ready or merge it unless the user asks. Full runbook: `docs/agents/issue-workflow.md`.

3. **Report back**: Let the user know the PR is created with the link

### Definition of Done

A change is done when:

- `pwsh ./scripts/verify.ps1` passes locally (Windows PowerShell: `.\scripts\verify.ps1`).
- Behavior changes have added or updated tests; bug fixes have a regression test.
- Any manual-only verification is recorded in the PR with exact steps and
  expected results.
- Docs are updated when behavior, architecture, or workflow changed.
- The required `CI` check is green when branch protection requires it (see [docs/ci.md](docs/ci.md)).
- The PR links its issue and is on a branch, never `main`.

## Parallel Work with Worktrees

For parallel work on multiple issues, use git worktrees to avoid conflicts:

```bash
# Create a worktree from the latest main
git fetch origin
git worktree add ../unrelated-vibe-game-issue-123 -b feat/123-description origin/main
cd ../unrelated-vibe-game-issue-123
```

Or use OpenCode's worktree tools if available. Each agent/worktree should work on its own issue independently.

**Cleanup**: After a PR is merged, remove worktrees with `git worktree remove <path>` and run `git worktree prune`.

## Repo-Meta Work

Repo-meta changes include CI workflows, issue/PR templates, labels, rulesets, scripts, docs indexes, and repository settings. Follow `docs/agents/repo-meta.md`.

- Safe on a branch: docs, tests, scripts, issue/PR templates.
- Ask a human first: rulesets, branch protection, required checks, CODEOWNERS, secrets, Actions permissions, repository settings, and major dependency upgrades.
- Never: force-push `main`, delete issues or branches, disable CI, or change test policy to get green.

## Safety Rules (Non-Negotiable)

- ❌ **NEVER** `git commit` to `main` or `master`
- ❌ **NEVER** `git push` to `main` or `master`
- ❌ **NEVER** merge, rebase, or reset on `main` without explicit permission
- ❌ **NEVER** delete, skip, or loosen tests or CI checks to get a green build
- ❌ **NEVER** change branch protection, rulesets, required checks, CODEOWNERS, secrets, or Actions permissions without explicit human approval
- ❌ **NEVER** edit `addons/gdUnit4/`, commit `.godot/`, `reports/`, or `build/`, or delete `.uid`/`.import` files
- ❌ **NEVER** merge a PR unless the user explicitly asks
- ✅ **ALWAYS** branch from latest `origin/main`
- ✅ **ALWAYS** verify current branch with `git branch --show-current` before committing
- ✅ **ALWAYS** create PRs for changes to `main` (squash merges preferred)
- ✅ **ALWAYS** link issues in PRs
- ✅ **ALWAYS** treat repo code/tests/config as authoritative over stale issue text; note drift in the PR

## Tools & Commands

- **GitHub CLI (`gh`)**: Read issues, claim them, create PRs, and check CI.
  ```bash
  gh auth status
  gh issue view <number>
  gh pr create --draft --body-file <file>
  gh pr checks --watch
  gh run view <run-id> --log-failed
  ```
  If `gh` returns 403/404, stop and ask; the active account may lack the required scope.
- **Git**: Standard git operations, always branch-aware. Branch from `origin/main`.
- **OpenCode worktree tools**: Use when available for clean parallel work. Otherwise use `git worktree`.
- **Godot**: Linux uses `GODOT_BIN` or `godot` on `PATH`; Windows also checks the Steam install. See `docs/getting-started.md`.

## Godot-Specific Notes

- Project root is at repo root (`project.godot` is here)
- Main scene: `res://game/main.tscn`
- Godot uses `res://` paths - be mindful of these when referencing files
- Don't commit `.godot/`, `reports/`, or `build/` (already gitignored)
- Keep `.uid` and `.import` files; do not delete or regenerate them casually
- Do not edit `addons/gdUnit4/`; it is vendored
- Prefer the editor for `.tscn`/`.tres`; if hand-editing, preserve UIDs, `format=3`, `load_steps`, and `ext_resource` IDs
- Be careful with binary files in `assets/`
- Full checklist: `docs/agents/godot.md`

## Coding Guidelines

### General Principles

- **Follow project structure**: Respect the boundaries between `system/`, `game/`, `ui/`, and `assets/` as described in [docs/architecture.md](docs/architecture.md).
- **Keep it simple**: Prefer clarity over cleverness. Write code that is easy for other agents/humans to understand.
- **Composition over inheritance**: Favor composing nodes/resources over deep inheritance hierarchies where possible.
- **Signal-driven design**: Use Godot signals for decoupled communication, especially between game logic and UI.
- **Ask when uncertain**: If you're unsure about where code belongs or architectural decisions, ask the user before proceeding.

### GDScript Conventions

- **Naming**:
  - Files and directories: `snake_case.gd`, `snake_case.tscn` (or `snake_case.tres`)
  - Classes: `PascalCase` (use `class_name`)
  - Variables and functions: `snake_case`
  - Constants: `UPPER_SNAKE_CASE`
  - Private members: prefix with `_` (e.g., `_internal_state`)
- **Typing**: Prefer static typing in GDScript (`var health: int = 100`) for clarity and to catch errors early.
- **Node references**: Use `@onready var node: NodeType = $Path` when possible. Avoid hardcoding long node paths; prefer exports or passing references.
- **Exports**: Use `@export` for values that should be configurable in the editor.
- **Comments**: Add comments for non-obvious logic, workarounds, or multiplayer-specific concerns. Avoid redundant comments.
- **Formatting**: Follow Godot's default GDScript style. Keep functions focused and reasonably sized.

### Architecture Boundaries

- **`system/`** - Game-agnostic, reusable systems (item system, attribute system, entities, hit/hurtboxes, etc.). Must not depend on `game/` or `ui/`. These should be portable to other projects.
- **`game/`** - Game-specific logic built on top of `system/`. Can depend on `system/`. Should expose clean signals and "endpoints" (methods) for other systems/UI to interact with.
- **`ui/`** - Presentation layer only. Must not contain game rules or directly manipulate game internals. Read state via signals/properties from `game/` or `system/`, and call endpoints provided by them. Keep UI decoupled.
- **`assets/`** - All raw assets (models, textures, audio, etc.). No code should live here.

### Scenes, Resources, and Organization

- **Scenes**: Prefer scene files (`.tscn`) for reusable entities/components. Keep the scene tree logical and avoid deeply nested, hard-to-navigate trees.
- **Scripts**: Attach scripts to nodes that own behavior. A scene and its primary script should be co-located when tightly coupled.
- **Resources**: Use custom `Resource` classes (`.tres`) for data definitions (items, attributes, configs) to enable reuse and editor tooling.
- **Autoloads**: Use `@onready` singletons (Project Settings > Globals/Autoloads) sparingly and only for truly global concerns. Document autoloads if added.
- **File locations**: Place files according to their responsibility. If you're creating a reusable system, it goes in `system/`. If it's specific to this game's rules, it goes in `game/`.

### Multiplayer Considerations (Planned)

Since multiplayer is planned, keep these in mind even for early work:

- **Authority**: Be explicit about server/client authority. Assume code will run in a networked context.
- **RPCs**: Use `@rpc` annotations properly when syncing. Validate actions on the server where appropriate.
- **State sync**: Keep network-synced state minimal and deterministic where possible. Avoid sending unnecessary data.
- **Local vs network**: Design APIs that can work in both single-player and multiplayer modes.
- **Testing**: Use `scripts/run-multiplayer.ps1` to test with multiple instances when working on networked features.

### Testing

- **Pre-PR gate**: `pwsh ./scripts/verify.ps1` (Windows PowerShell: `.\scripts\verify.ps1`). It imports the project, parses every first-party `.gd`, boots the main scene, and runs the gdUnit4 suites.
- **Tests are required for behavior changes.** Bug fixes include a regression test that fails before the fix.
- **Never weaken the gate**: do not delete, skip, or loosen tests or CI checks to get a green build. Fix the cause or open an issue.
- **Manual escape hatch**: if automation is genuinely impractical, record exact steps, expected results, and observed results in the PR. "Tested locally" is not acceptable.
- Full policy, tiers, determinism rules, and troubleshooting: [docs/testing.md](docs/testing.md).

### Best Practices for Agents

- **Understand before changing**: Read related files, scenes, and docs to understand existing patterns before making changes.
- **Small, focused changes**: Keep PRs small and focused on a single issue/concern.
- **Preserve existing style**: Match the style and patterns of surrounding code.
- **No unrelated changes**: Don't refactor or reformat unrelated code.
- **Test when possible**: Run `pwsh ./scripts/verify.ps1` (Windows PowerShell: `.\scripts\verify.ps1`) for any code change. If you
  cannot run Godot, say so in the PR instead of claiming tests passed.
- **Document significant additions**: If you add a new system or pattern, update relevant docs in `docs/`.
- **Respect git rules**: Always follow the git workflow in this document. Never commit/push to `main`.

## Stop and Ask

Stop and ask the user when:

- the issue lacks acceptance criteria or a test plan
- the issue's paths conflict with the repo
- two docs disagree about the current design
- the change touches rulesets, branch protection, secrets, Actions permissions, or CODEOWNERS
- `gh` returns 403/404 or CI fails for infrastructure reasons
- you cannot explain a test failure

When sources conflict, use this order: code/tests/config > `AGENTS.md` and `docs/*` > issue body/PR comments > `docs/research` and `docs/future/ideas`.

## Getting Help

If you're unsure about branch naming, whether to touch main, coding conventions, where code should live, or whether a change is repo-meta or risky, **ask the user** before proceeding. Do not guess.

Less-capable agents should start at `docs/agents/README.md`. Humans directing agents should read `docs/agents/human-guide.md`.

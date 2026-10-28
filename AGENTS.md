# Agent Instructions for unrelated-vibe-game

This document defines how AI agents should work on this Godot 4 multiplayer 3D project. Follow these rules strictly.

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

1. **Understand the issue**: Read the issue thoroughly using `gh issue view <number>`. Understand acceptance criteria and any related context.
2. **Sync with main**: Always start from the latest `main`
   ```bash
   git fetch origin
   git checkout main
   git pull origin main
   ```
3. **Create a branch**: Create and checkout a new branch
   ```bash
   git checkout -b feat/123-short-description
   ```
4. **Verify**: Confirm you're not on `main` before making any changes
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

2. **Open a Pull Request automatically**: Use `gh` CLI to create a PR
   ```bash
   gh pr create --draft --title "<descriptive title>" --body "$(cat <<'EOF'
   ## Summary
   <brief description of changes>
   
   ## Related Issue
   Closes #<issue-number>
   
   ## Changes
   - <list key changes>
   
   ## Testing
   <how to test>
   EOF
   )"
   ```
   - Default to **draft PRs** unless explicitly told otherwise
   - Always link the issue with `Closes #123` or `Fixes #123`
   - Provide a clear summary of changes

3. **Report back**: Let the user know the PR is created with the link

## Parallel Work with Worktrees

For parallel work on multiple issues, use git worktrees to avoid conflicts:

```bash
# Create a worktree for a new issue
git worktree add ../unrelated-vibe-game-issue-123 -b feat/123-description main
cd ../unrelated-vibe-game-issue-123
```

Or use OpenCode's worktree tools if available. Each agent/worktree should work on its own issue independently.

**Cleanup**: After a PR is merged, remove worktrees with `git worktree remove <path>`.

## Safety Rules (Non-Negotiable)

- ❌ **NEVER** `git commit` to `main` or `master`
- ❌ **NEVER** `git push` to `main` or `master`
- ❌ **NEVER** merge, rebase, or reset on `main` without explicit permission
- ✅ **ALWAYS** branch from latest `main`
- ✅ **ALWAYS** verify current branch with `git branch --show-current` before committing
- ✅ **ALWAYS** create PRs for changes to `main` (squash merges preferred)
- ✅ **ALWAYS** link issues in PRs

## Tools & Commands

- **GitHub CLI (`gh`)**: Use for reading issues (`gh issue view`), creating PRs (`gh pr create`), checking status (`gh pr view`)
- **Git**: Standard git operations, always branch-aware
- **OpenCode worktree tools**: Use when available for clean parallel work

## Godot-Specific Notes

- Project root is at repo root (`project.godot` is here)
- Main scene: `res://game/main.tscn` (based on project.godot)
- Godot uses `res://` paths - be mindful of these when referencing files
- Don't commit `.godot/` (already gitignored)
- Be careful with binary files in `assets/`

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

### Best Practices for Agents

- **Understand before changing**: Read related files, scenes, and docs to understand existing patterns before making changes.
- **Small, focused changes**: Keep PRs small and focused on a single issue/concern.
- **Preserve existing style**: Match the style and patterns of surrounding code.
- **No unrelated changes**: Don't refactor or reformat unrelated code.
- **Test when possible**: If you can run/test in Godot, do a quick sanity check. At minimum, ensure scripts have valid syntax.
- **Document significant additions**: If you add a new system or pattern, update relevant docs in `docs/`.
- **Respect git rules**: Always follow the git workflow in this document. Never commit/push to `main`.

## Getting Help

If you're unsure about branch naming, whether to touch main, coding conventions, or where code should live, **ask the user** before proceeding.

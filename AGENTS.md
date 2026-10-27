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
- Main scene: `res://game/scenes/main.tscn` (based on project.godot)
- Godot uses `res://` paths - be mindful of these when referencing files
- Don't commit `.godot/` (already gitignored)
- Be careful with binary files in `assets/`

## Getting Help

If you're unsure about branch naming, whether to touch main, or anything git-related, **ask the user** before proceeding.

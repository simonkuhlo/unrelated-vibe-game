# Contributing

## Environment

Linux is the primary development environment; CI runs on `ubuntu-latest`.
Windows works as a fallback. Use PowerShell 7+ (`pwsh`) so local commands match
CI. On Windows PowerShell, substitute `.\scripts\...` for `pwsh ./scripts/...`.

## Workflow
This project uses an issue-driven workflow. See [AGENTS.md](AGENTS.md) for detailed agent instructions.

### Quick Start
1. Pick an issue from GitHub Issues
2. Create a branch: `type/123-short-description` (e.g., `feat/123-add-feature`)
3. Make changes, commit with conventional commits
4. Push and open a PR (agents will do this automatically)
5. Merge via squash merge when approved

### Merge Strategy
Use **Squash and merge** to keep `main` history clean.

## Testing

Run the pre-PR gate before opening a pull request:

```bash
pwsh ./scripts/verify.ps1
```

It imports the project, parses all first-party scripts, boots the main scene,
and runs the gdUnit4 suites. Faster loops:

```bash
pwsh ./scripts/test.ps1 -Tier unit
pwsh ./scripts/test.ps1 -Path tests/unit/smoke/test_framework_smoke.gd
```

Policy:

- Behavior changes include tests; bug fixes include a regression test.
- If automation is impractical, explain why in the PR and record exact manual
  steps and expected results.
- Never weaken tests or CI to get a green build.
- CI runs the same scripts on Linux; wait for the aggregate `CI` check to pass
  before merging (see [docs/ci.md](docs/ci.md)).

See [docs/testing.md](docs/testing.md) for tiers, determinism rules, and the
framework upgrade procedure.

## Working with agents

- Less-capable agents start at [docs/agents/README.md](docs/agents/README.md)
  and follow [docs/agents/issue-workflow.md](docs/agents/issue-workflow.md).
- Humans directing agents should read
  [docs/agents/human-guide.md](docs/agents/human-guide.md).
- Repo-meta work (CI, templates, labels, rulesets, scripts) follows
  [docs/agents/repo-meta.md](docs/agents/repo-meta.md).

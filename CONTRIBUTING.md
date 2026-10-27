# Contributing

## Workflow
This project uses an issue-driven workflow. See [AGENTS.md](AGENTS.md) for detailed agent instructions.

### Quick Start
1. Pick an issue from GitHub Issues
2. Create a branch: `type/123-short-description` (e.g., `feat/123-add-feature`)
3. Make changes, commit with conventional commits
4. Push and open a PR (agents will do this automatically)
5. Merge via squash merge when approved

### Branch Protection (Recommended)
Since `main` is not currently protected on GitHub, consider enabling branch protection rules:
- Require pull request reviews before merging
- Require status checks to pass (if you add CI later)
- Restrict direct pushes to `main`
- Allow squash merging

You can set this up in GitHub: Settings → Branches → Add branch protection rule for `main`.

### Merge Strategy
Use **Squash and merge** to keep `main` history clean.

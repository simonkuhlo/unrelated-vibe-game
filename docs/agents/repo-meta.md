# Repo-Meta Work

Use this runbook for changes to the repository itself: CI, issue and PR
templates, labels, rulesets, scripts, docs indexes, Dependabot, and repository
settings.

Repo-meta work is still issue-driven and still goes through a branch and PR.
The difference is that some changes affect repository settings outside git and
need explicit human approval.

## Safe, ask, never

| Change | Rule |
|---|---|
| Docs, tests, scripts | Safe on a branch with `pwsh ./scripts/verify.ps1`. |
| Issue and PR templates | Safe on a branch, but validate the YAML and show the rendered result. |
| Workflow YAML | Safe on a branch. Keep `permissions: contents: read`, pin actions, and inspect the PR run. |
| Labels | Safe to create or edit, but do not delete default labels or labels in active use. |
| Dependabot config | Safe on a branch; do not auto-merge major updates. |
| Rulesets, branch protection, required checks, CODEOWNERS | Ask a human first. |
| Secrets, Actions permissions, repository settings | Ask a human first. |
| Force-push, delete issues/branches, releases | Never without explicit instruction. |

## Audit current state first

Do not assume the docs describe the live repository. Check:

```bash
gh repo view --json nameWithOwner,defaultBranchRef
gh api repos/{owner}/{repo}/rulesets
gh api repos/{owner}/{repo}/rulesets/<id>
gh label list
gh workflow list
gh run list --limit 10
gh api repos/{owner}/{repo}/contents/.github/CODEOWNERS
```

The classic branch-protection endpoint returns `404` when the repo uses
rulesets:

```bash
gh api repos/{owner}/{repo}/branches/main/protection
```

That is expected here. Use the rulesets endpoint instead.

## Current state (verified 2026-11-08)

- `main-1`: blocks deletion and non-fast-forward pushes.
- `main-2`: requires a pull request and `require_code_owner_review: true`.
- `main-2` has no required status checks and allows `merge`, `squash`, and
  `rebase`.
- There is no `.github/CODEOWNERS` file, so the code-owner requirement currently
  has no code owner to require.
- `docs/ci.md` describes the target setup (required `CI` check, squash-only,
  up-to-date branches). It is not fully applied yet.

These facts change. Re-run the audit commands before acting.

## Docs changes

- Add new docs to `docs/README.md`.
- Give every doc a status header: `Active`, `Draft`, `Idea`, or `Superseded`.
- Link related issues or PRs.
- Keep `docs/research/` and `docs/future/ideas/` marked as non-authoritative.
- Do not create orphan docs that are not linked from an index.
- When behavior, architecture, or workflow changes, update the matching doc.

## Issue and PR templates

- Templates live in `.github/ISSUE_TEMPLATE/` and
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Keep forms short; add fields only when they change what an agent can execute.
- Validate YAML locally before opening the PR.
- GitHub renders issue forms from the default branch. Do not assume a template
  change is visible in the UI until it is merged.
- Use `docs/agents/issue-brief.md` for a lightweight brief on existing issues
  instead of adding a new field for every possible context.

## Workflow changes

- Keep `permissions` read-only unless the job truly needs more.
- Keep action versions pinned to a tag; Dependabot updates them.
- Do not add secrets or change triggers without human approval.
- Test the workflow on a PR. `workflow_dispatch` only runs from the default
  branch, so it is not a substitute for a PR run.
- Read failures with:

```bash
gh run list --limit 10
gh run view <run-id> --log-failed
```

- Do not change CI to make a failing PR green. Fix the cause or open an issue.

## Label changes

Use `gh label create`, `gh label edit`, and `gh label delete`. Do not delete the
default labels or labels used by open issues. If you add a label that an agent
workflow depends on, document it here.

## Rulesets and branch protection

This is a high-risk change. Get explicit human approval before applying it.

1. Read the current body:

   ```bash
   gh api repos/{owner}/{repo}/rulesets
   gh api repos/{owner}/{repo}/rulesets/<id>
   ```

2. Save the current JSON.
3. Prepare the new JSON and diff it against the current body.
4. Apply it only with approval:

   ```bash
   gh api repos/{owner}/{repo}/rulesets/<id> --method PUT --input ruleset.json
   ```

5. Verify the result with the audit commands.
6. Record the change and the reason in the PR.

Do not bypass or disable a ruleset to merge a PR.

## Dependabot

- Review the changelog and the diff.
- Run `pwsh ./scripts/verify.ps1`.
- Do not auto-merge a major update.
- Framework upgrades follow `docs/testing.md#framework-upgrades`.

## Rollback

- Revert the PR for git-tracked changes.
- Restore the saved ruleset JSON for settings changes.
- If a workflow or template change breaks the repo, revert it first and
  investigate afterward.

## Related

- `AGENTS.md`
- `docs/ci.md`
- `docs/testing.md`
- `docs/agents/issue-workflow.md`
- `docs/agents/human-guide.md`

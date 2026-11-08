# Human Guide: Directing Agents

This guide is for humans choosing an agent's context and reviewing its work. It
is not required reading for capable agents.

## The issue is the prompt

A low-capability agent will follow the issue literally. If the issue is stale or
vague, the agent will implement the wrong thing. Before handing over work:

- Make sure the issue has a goal, scope, acceptance criteria, and a test plan.
- Add exact file paths or areas.
- State non-goals.
- State the verification command.
- Update the issue if the repo has moved since it was written.

Use [`issue-brief.md`](issue-brief.md) as an issue comment when the issue body is
not enough.

## Choose the smallest context pack

| Agent capability | Give it | Do not give it |
|---|---|---|
| Capable agent | `AGENTS.md`, `docs/testing.md`, `docs/ci.md`, the issue, the relevant code and domain doc | The whole `docs/agents/` folder, research notes, vendored addons |
| Less-capable agent | `AGENTS.md`, `docs/agents/README.md`, `docs/agents/issue-workflow.md`, the issue brief, the exact files | The whole repo, all docs, unrelated tests |
| Repo-meta agent | `AGENTS.md`, `docs/agents/repo-meta.md`, `docs/ci.md`, the relevant workflow/template files | Game code unless the meta change depends on it |
| Godot-editing agent | `AGENTS.md`, `docs/agents/godot.md`, `docs/testing.md`, the exact scene/resource and its tests | Unrelated assets or fixtures |
| Review/triage agent | `AGENTS.md`, the issue/PR, the diff, CI logs, the relevant docs | Write access or unrelated cleanup work |

If the agent only needs to change one file, say so. If it needs to understand a
contract, point at the doc section instead of the whole doc.

## What not to give an agent

- `addons/gdUnit4/` — vendored; editing it is almost always wrong.
- `.godot/`, `reports/`, `build/` — generated.
- `docs/research/` and `docs/future/ideas/` — useful context for a design
  decision, but not current specs.
- The full test suite output when one suite is enough.
- A whole PR thread when the issue and latest review comment are enough.

## Risky changes: approve explicitly

These should never be left to an agent's judgment:

- branch protection, rulesets, required checks, or CODEOWNERS
- repository secrets or Actions permissions
- deleting issues, branches, labels, or releases
- force-pushing `main`
- weakening or skipping tests or CI checks
- major dependency or engine upgrades
- changing the test policy or merge policy

If you want one of these changed, say so explicitly in the issue and in the PR
review. Otherwise the agent should stop and ask.

## Review checklist

When reviewing an agent PR:

- Is it on a branch, not `main`?
- Does it link the issue with `Closes #...`?
- Does it change only what the issue asks?
- Are behavior changes covered by tests?
- Does a bug fix include a regression test?
- Did it avoid generated files, vendored addons, and unrelated formatting?
- Did it update the right docs and index?
- Did it record manual verification with steps and observed results?
- Is `pwsh ./scripts/verify.ps1` green?
- Did it report any drift, blockers, or risky follow-ups?

## Prompt templates

### Capable agent

```text
Implement issue #123. Read AGENTS.md, docs/testing.md, docs/ci.md, the issue,
and the relevant code. Do not read the whole repo. Use a branch and draft PR.
Run pwsh ./scripts/verify.ps1. Do not merge.
```

### Less-capable agent

```text
Implement issue #123. Read AGENTS.md, then docs/agents/README.md and
docs/agents/issue-workflow.md. Follow the issue brief exactly. Use only the files
listed there unless you need one more and say why. Stop and ask if the issue or
repo is inconsistent.
```

### Repo-meta agent

```text
Do the repo-meta work in issue #123. Read AGENTS.md, docs/agents/repo-meta.md,
and docs/ci.md. Audit the current GitHub state first. Do not change rulesets,
branch protection, secrets, Actions permissions, or CODEOWNERS without asking.
```

### Review/triage agent

```text
Review PR #123 without editing files. Read AGENTS.md, the issue, the diff, and
CI logs. Report findings with file/line evidence, severity, and a recommended
fix. Open follow-up issues for non-blocking problems instead of making drive-by
changes.
```

## Parallel work

Use one worktree or branch per issue. Give each agent a distinct issue and tell
it not to touch the other worktree. If two agents must share a branch, say so
explicitly; otherwise assume they will conflict.

## Keeping docs current

- Put durable knowledge in `docs/`, not only in issue comments.
- Add new docs to `docs/README.md`.
- Mark ideas and research as non-authoritative.
- When a path or command changes, update the agent runbook in the same PR.
- When an agent repeatedly gets something wrong, add it to the runbook or the
  issue brief, not to `AGENTS.md`.

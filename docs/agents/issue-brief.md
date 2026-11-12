# Issue Brief Template

**Status:** Active. Template for handing work to a less-capable agent.

Use this as an issue comment when handing work to a less-capable agent, or as a
handoff comment when an agent stops. It gives the agent the context it cannot
discover reliably on its own.

Keep it short. If a field does not apply, write `none`.

```markdown
## Agent brief

- **Goal:** <one sentence>
- **Non-goals:** <what not to change>
- **Files/areas:** <exact paths or systems>
- **Contracts/invariants:** <APIs, signals, data shapes, authority rules>
- **Test plan:** <tier, suite, or exact manual steps>
- **Verification:** <commands and expected result>
- **Risks/unknowns:** <none or list>
- **Human decisions needed:** <none or list>
```

## Example

```markdown
## Agent brief

- **Goal:** Add a regression test for a required export exclusion.
- **Non-goals:** Do not change the export preset or CI configuration.
- **Files/areas:** `tests/content/test_export_presets.gd`, `export_presets.cfg`
- **Contracts/invariants:** The Linux preset exports all runtime resources and
  excludes `tests/*`, `reports/*`, and `addons/gdUnit4/*`.
- **Test plan:** Content test in `tests/content/`.
- **Verification:** `pwsh ./scripts/test.ps1 -Path
  tests/content/test_export_presets.gd`, then
  `pwsh ./scripts/verify.ps1`.
- **Risks/unknowns:** none.
- **Human decisions needed:** none.
```

## Rules

- Point at real files. Check the paths before posting.
- State what is out of scope.
- Name the test tier and suite.
- Include the exact verification command.
- If the agent must ask before acting, say so explicitly.
- If the issue text is stale, say which repo path wins.

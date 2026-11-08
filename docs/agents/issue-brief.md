# Issue Brief Template

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

- **Goal:** Add a regression test for duplicate map versions with different hashes.
- **Non-goals:** Do not change repository validation or ordering.
- **Files/areas:** `tests/unit/maploader/test_map_repository_queries.gd`,
  `tests/fixtures/maps/repository/catalog_duplicates.tres`
- **Contracts/invariants:** `find_exact()` is hash-authoritative; both entries
  remain in `list()`.
- **Test plan:** Unit test in `tests/unit/maploader/`.
- **Verification:** `pwsh ./scripts/test.ps1 -Path
  tests/unit/maploader/test_map_repository_queries.gd`, then
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

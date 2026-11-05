# Tests

Tests use [gdUnit4](../docs/testing.md) and mirror the architecture boundaries.
Suite files are named `test_*.gd` and extend `GdUnitTestSuite`.

```text
tests/
  unit/         # Pure logic and contracts; no scene tree, no I/O
  integration/  # Scenes, signals, lifecycle, UI wiring
  content/      # Map manifests, catalogs, export filters
  fixtures/     # Shared scenes, resources, and small data fixtures
  tools/        # Test tooling invoked by scripts/ (excluded from exports)
```

Run everything with:

```powershell
.\scripts\verify.ps1
```

Run a tier while iterating:

```powershell
.\scripts\test.ps1 -Tier unit
.\scripts\test.ps1 -Tier integration
.\scripts\test.ps1 -Path tests/unit/smoke/test_framework_smoke.gd
```

See [docs/testing.md](../docs/testing.md) for the policy, determinism rules, and
the manual-test escape hatch.

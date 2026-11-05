# Fixtures

Shared test scenes, resources, and small data files. Keep fixtures minimal and
deterministic; do not copy large production assets here.

Test maps live under `tests/fixtures/maps/` and stay excluded from exports.

`tests/fixtures/maps/catalog.tres` is the canonical test catalog that content
fixtures extend. Repository unit tests use the catalog and manifest variants
under `tests/fixtures/maps/repository/`; they are intentionally isolated from
the map content fixtures.

## Summary

<!-- What changed and why. Link the Trello card: https://trello.com/c/<id> -->

## Release gate checklist

- [ ] Targeted tests for the touched modules pass locally (`python scripts/ci/guardrails.py pr-gate`, `flutter analyze`)
- [ ] New / changed business logic has unit tests under `tests/unit/` (and Flutter tests where relevant)
- [ ] Schema changes go through a new Alembic migration (single head)
- [ ] `history/YYYY-MM-DD.md` entry appended (append-only)
- [ ] No database files, build output, `.env` or secrets committed
- [ ] External integrations (Nafeza / CargoX / PKI): no simulated result is presented as real (`is_simulated` flag kept, mock guard untouched or tested)

## Tests

<!-- Commands run and results. Full suites run pre-build (label `full-tests`). -->

## Follow-ups / risks

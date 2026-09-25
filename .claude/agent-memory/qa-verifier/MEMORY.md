# qa-verifier memory

- pytest console summary ("N passed in Xs") and `--collect-only` output are suppressed once a test imports
  `main`. Always use `--junitxml` + exit code. Exit code 3 + INTERNALERROR = pytest crashed; rerun once.
- Full backend suite: 930 tests/~8 min (2026-09-23); 1067 tests after router-auth change (2026-09-24), took 33 min (22 min on a rerun alongside 2 flutter runs)
  (cargox 870 s, new auth test files ~410 s). Run pytest with --junitxml into scratchpad, not the repo. A one-off run hung ~2.5 h and ended in MemoryError
  while formatting a traceback; it did not reproduce on rerun — treat as environmental, rerun before blaming code.
- Environment-dependent tests (since 2026-09-23 they skip themselves when the environment is missing):
  - `tests/unit/test_arabic_ocr_engine.py` — needs the OCR engine installed.
  - `tests/unit/test_md09_ports_tariff_exchange_audit.py` — needs seeded reference data (100+ ports, 50+ tariffs).
  - `tests/unit/test_version_and_updates_api.py::test_uat_environment_staging_integrity` — needs `sorour_logistics_uat.db`.
- 2026-09-24 update-system change: backend 1725 tests, 21 min. Running `flutter test -j 4` at the same time as pytest made BOTH
  run out of memory: flutter crashed with 'Could not start thread', and the cargox tests failed with MemoryError plus a follow-on LT001 != LTVNO. Run them one after the other.
- Slow tests: `tests/unit/test_cargox_standard_invoice.py` takes ~4.5 min alone (several tests 17-60 s).
- Tests write into the repo (`dist/`, `logs/`, `backups/`); these are gitignored.
- [Flutter test baseline](flutter_test_baseline.md) — 3.44.6 port: 1420 pass/94 perf skip; never run flutter test alongside build
- Boot/uvicorn probes: set DATABASE_PATH to a scratch copy. As of 2026-09-25 the auto_pre_upgrade_*.db snapshot lands in `backups/` next to DATABASE_PATH (scratch), not the repo.
- 2026-09-25 cleanup-pass gate: backend 2006 tests (7 env skips, incl. POSIX-perm skip in test_release_manifest_tools), 39 min; flutter 393 files/1531 pass/94 perf skip, 18 min.
  Production-sync tests (test_production_sync, test_db_safety_production_sync) sandbox DEV/PROD DBs in tmp - no exclusion needed; hash the real DB before/after to prove it.
- 2026-09-25 launcher/no-VBScript gate: backend 2011 tests/7 env skips, 21 min; flutter -j 4 1531 pass/94 skip, 9.6 min (run after pytest, no OOM);
  `flutter analyze` baseline 0 errors / 18 warnings / 1885 infos (count via `grep -oE '^ *(error|warning|info) - '`).

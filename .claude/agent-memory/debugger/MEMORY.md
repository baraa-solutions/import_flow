# debugger memory — known failure modes

- Backend boot NameError on Python 3.12 (works on 3.14 due to lazy annotations): a name used in a signature
  without import. Seen in customs_consultation, financial_approval, import_files, import_documentation (2026-09).
  Sweep with pyflakes; see backend-developer memory.
- pytest looks "silent" (no summary line) after `import main` — not a hang. Use `--junitxml`.
- CI failure step is "Run Backend Pytest Suite"; logs need a browser, so reproduce locally on Python 3.12.
- Order-dependent failures: run the suspect test alone, then with the files collected before it
  (collect order via a tiny `pytest_collection_finish` plugin that writes `session.items` to a file).
- [Flutter suite hang = OOM](flutter_suite_hang_oom.md) — -j 4 "hang" was commit-memory exhaustion; [DIO] 400/403 lines are mocks; live_agent test hits :28080
- [Desktop close crash](desktop_close_crash.md) — flutter_windows.dll+0x1d7b0 c0000005 then c000041d = windowManager.destroy(); use close()
- [Row field focus loss](flutter_row_key_focus_loss.md) — identityHashCode row keys + setState/copyWith = focus lost per keystroke; repro via testTextInput
- [Single-language stale tests](single_language_stale_tests.md) — Arabic/legacy fixtures after phases A/B/C; OpenBLAS OOM in corrupt-DB subprocess test
- [Legacy NULL list 500](legacy_null_list_500.md) — ResponseValidationError on None: startup ADD COLUMN NULLs (real) vs raw-SQL seed (artifact)
- [Smart Extract heuristics](smart_extract_heuristics.md) — PO extract is regex-only (no LLM); 3-decimal EU kg, legal-text EUR, dialog HS prefix match
- [Flutter gate flakes](flutter_gate_flakes.md) — KPI-finder/Form46 test data patterns, concurrent flutter test runs cause 'did not complete'

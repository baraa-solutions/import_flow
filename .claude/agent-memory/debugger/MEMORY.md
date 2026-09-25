# debugger memory — known failure modes

- Backend boot NameError on Python 3.12 (works on 3.14 due to lazy annotations): a name used in a signature
  without import. Seen in customs_consultation, financial_approval, import_files, import_documentation (2026-09).
  Sweep with pyflakes; see backend-developer memory.
- pytest looks "silent" (no summary line) after `import main` — not a hang. Use `--junitxml`.
- CI failure step is "Run Backend Pytest Suite"; logs need a browser, so reproduce locally on Python 3.12.
- Order-dependent failures: run the suspect test alone, then with the files collected before it
  (collect order via a tiny `pytest_collection_finish` plugin that writes `session.items` to a file).

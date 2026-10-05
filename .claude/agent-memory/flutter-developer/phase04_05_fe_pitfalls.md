---
name: phase04-05-fe-pitfalls
description: Pitfalls from the phase 4/5 FE quality pass (CRLF files, scripted edits, l10n block, test mocks, flaky multi-file test runs)
metadata:
  type: feedback
---

- Source and l10n files are CRLF. Python text-mode read/write keeps CRLF on Windows, but `cat >>` / `newline=''` inserts add LF-only lines: normalize inserted blocks to CRLF.
- Bash heredocs in this tool eat backslashes: write Python edit scripts with the Write tool, not `<<EOF`. Scratchpad is shared with other agents: prefix your file names.
- Test package name is `frontend` (`package:frontend/...`). Mock notifiers using `implements XNotifier` need every new getter the screen reads (e.g. `hasMore`).
- Running many test files in one `flutter test` call can give "did not complete" or compile failures when another agent is mid-edit in app_localizations*.dart: re-run the failing file alone before blaming your change.
- Backend structured error detail -> `ApiErrorText.of(l10n, e)`; DemurrageState carries `errorObject` so screens can render it.

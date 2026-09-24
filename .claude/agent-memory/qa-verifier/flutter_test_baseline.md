---
name: flutter-test-baseline
description: Flutter test gate facts on this machine - 3.44.6 port baseline counts, perf tag, concurrency crashes, how to compare runs
metadata:
  type: project
---

Before the Flutter 3.44.6 port (commit 406dba5 and earlier), `app_theme.dart` used `CardTheme(`/`DialogTheme(`, so
269 of ~385 suites failed to *load*. On 2026-09-24 the uncommitted port fixed that. Its first clean full run gave:
386 files, 1420 passed, 0 failed, 94 skipped (all skips = `perf` tag, 85 files in test/perf), exit 0, ~7 min alone.
`frontend/dart_test.yaml` skips tag `perf` by default. A serial perf run (`--run-skipped -t perf -j 1 test/perf`) took ~6 min.
It gave 97 passed and 1 failed. The failure was a RenderFlex overflow of 8236 px in `import_file_details_dialog_perf_test`, not a timing miss.

**Why:** these numbers are the new reference, and pre-port numbers are no longer comparable.
**How to apply:**
- Run `flutter test` ALONE. Running it at the same time as `flutter build web` crashed the flutter tool with "Could not start thread ... 22"
  (thread/commit-memory exhaustion). That produced false "Connection closed before test suite loaded" failures, and the tool then hung
  without writing `done`. Kill only your own process tree (check the command line and start time), then rerun.
- Other sessions leave `flutter test` processes and orphaned `flutter_tester.exe` processes running for hours. Don't kill them. They eat memory.
- Parse `--reporter json`: count `testDone` with hidden=false; a hidden non-success = load failure.
- In Python, set PYTHONIOENCODING=utf-8 before printing test messages; cp1252 crashes on box-drawing characters.
- `flutter build web --debug` takes ~3 min. A wasm dry-run crash under memory pressure is only a warning and does not change the exit code.
- Other sessions may prune scratch worktrees mid-run. Check `git worktree list` if a run stalls.

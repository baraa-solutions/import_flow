---
name: flutter-test-baseline
description: Flutter test gate facts on this machine - app_theme compile error masks ~270 suites, how to compare baseline vs current, runtime and pitfalls
metadata:
  type: project
---

As of 2026-09-24, on Flutter 3.44.6 (stable), `lib/core/theme/app_theme.dart` uses `CardTheme(`/`DialogTheme(` where
`CardThemeData`/`DialogThemeData` are required. That makes 269 of ~385 test suites fail to *load* on HEAD, so it is
pre-existing and not caused by feature diffs. CI (`subosito/flutter-action@v2`, channel stable, no version pin) will hit the same error.
Temporarily patching those 4 lines in a scratch worktree reveals ~80-93 more hidden failures, many of them `*_perf_test` timing tests that are flaky under load.

**Why:** unpatched runs only show load failures, so a regression inside those 269 suites is invisible.
**How to apply:**
- Compare with `--reporter json`. Normalize "loading <abs path>" test names to the basename, because they embed the worktree path.
- Patch the theme in a scratch worktree only, never in the task worktree.
- Windows rejects `flutter test` with ~269 file args ("command line is too long"). Run the full suite instead.
- A full run takes ~12-15 min alone and ~40-55 min when two run concurrently (plus pytest running alongside).
- A HEAD baseline worktree needs `flutter pub get` first. It re-resolves 16 deps, like the task tree's modified pubspec.lock.
- A one-off "The Dart compiler exited unexpectedly" can be attached to a hidden "loading" test that still ends in success.
  That is tool noise, not a failure. Count results from `testDone`, not from `error` events.
- The "failing suites" affected by auth work (auth_gate, login_screen_widget, email_settings_widget) are among the 269 masked
  load failures. An unpatched run cannot prove those suites have no regression.
- Other sessions may remove or prune scratch worktrees mid-run. One vanished on 2026-09-24 and killed a run. Check `git worktree list` if a run stalls.

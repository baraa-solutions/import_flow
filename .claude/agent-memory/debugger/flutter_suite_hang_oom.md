---
name: flutter-suite-hang-oom
description: Full Flutter suite "hangs" / dies at -j 4 on the CTO machine from Windows commit-memory exhaustion, not from a test; plus how to read [DIO] log lines and the live_agent_acceptance_test hazard
metadata:
  type: project
---

On 2026-09-29, `flutter test -j 4` for v2.1.2 (263298f) "hung" for 1h40 at low CPU. Reproduced with `--timeout 60s`: no test
timed out. The run instead died at ~05:45 with `zone.cc: Out of memory`, a JIT `Crash occurred when compiling`, and
`Could not start thread DartWorker`. Free commit memory (Win32_OperatingSystem.FreeVirtualMemory) was only ~2 GB, because
Brave, several claude sessions, mysqld and vmmem were running. At -j 2 the remaining 185 files passed (941/0) in 5.5 min.

**Why:** a flutter_tester that crashes from OOM can leave the runner waiting forever. It looks exactly like a hung test.

**How to apply:**
- A Flutter suite "hang": check free commit memory first and grep the output for `Out of memory` / `Could not start thread`.
  Rerun with `--reporter expanded --timeout 60s` and `-j 2`.
- `[DIO] uri: http://127.0.0.1:28080/...` lines in test output are usually NOT real traffic. A 400 comes from
  flutter_test's mock HttpClient. A 403 with a content-type header can be a test's fake HttpClientAdapter; the
  LogInterceptor prints the resolved baseUrl.
- Real traffic only comes from plain `test()` files that never initialise the test binding. The main one is
  `test/live_agent_acceptance_test.dart`. It skips when /health is not 200. When the installed app is listening on 28080,
  it runs real write calls and fails with 401 because it has no token. It needs an explicit opt-in gate. Related:
  [[order-dependent-failures]].

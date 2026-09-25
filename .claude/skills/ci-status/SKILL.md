---
name: ci-status
description: Show the GitHub Actions CI status for this repository (recent runs, which job and step failed, last green run) using the public GitHub API - no token, gh CLI, or MCP connector needed. Use when asked whether CI is green, why a build failed, or before merging or releasing.
---

# CI Status

The repository is public, so CI status is readable without authentication.

```bash
python .claude/skills/ci-status/ci_status.py              # last 10 runs on main
python .claude/skills/ci-status/ci_status.py --branch <b> # another branch
```

The script prints each run (time, result, commit, title), and for a failed latest run
the failing job and step, plus the last green run in the window.

## Interpreting results

- The only workflow is `.github/workflows/build_and_release.yml`; it runs on every push to `main`
  and publishes a GitHub Release. A failure at **Run Backend Pytest Suite** means the release
  was not published from that commit.
- Step logs require a signed-in browser. To reproduce a pytest failure locally, run
  `python -m pytest tests -q -W ignore --junitxml=.pytest-report.xml` and read the counts from
  the XML (the console summary line is suppressed after `import main`).
- Tests that depend on local machine state (OCR engine installed, seeded reference data,
  `sorour_logistics_uat.db`) also fail in CI.

Report in Egyptian Arabic: current state (green / red), since when it has been red,
the failing step, and the likely cause if a local run confirms it.

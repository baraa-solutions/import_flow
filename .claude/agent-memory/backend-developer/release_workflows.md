---
name: release-workflows
description: Signed update manifest tooling (build/sign/verify scripts), GitHub release/publish/re-sign workflows on the private repo, and /release-check internals
metadata:
  type: project
---

## Release tooling / publish job (Phase 6, 2026-09-24)
- Security rule (lead decision): ALL private-key code lives in `scripts/release/sign_manifest.py` (stdlib + cryptography,
  AST test forbids app imports), run with `-I` from a `--require-hashes` venv (`requirements-sign.txt`, hashes from
  the PyPI JSON API). `build_manifest.py` / `verify_manifest.py` (no secrets) may import the app.
- Manifest contract: `expires_at` REQUIRED (default released_at + 90 d; re-sign = now + 90 d via
  `.github/workflows/resign_update_manifest.yml`), `previous` optional nested `{version, installer{path,size_bytes,sha256}}`.
- `verify_manifest.main(argv, transport=)` takes an httpx transport for tests; hash with `iter_bytes` (MockTransport +
  `iter_raw` -> StreamConsumed). Build job is read-only; only the `release` job (tags only) has `contents: write`.
- Repo is PRIVATE `baraa-solutions/import_flow` (remote `company`; Free/Team = no environment required reviewers).
  publish_update.yml runs from main only, in 3 jobs: `sign` (env, hashed venv only) -> `verify` (no env/secrets, checks
  out refs/tags/<tag>, pip requirements.txt) -> `upload` (env, shell/sftp/curl only). Rule: no secret on a runner with
  unhashed pip installs. Workflow-level concurrency group = resign's job-level group.
  So publishing is the manual `publish_update.yml` (dispatch input `tag`, downloads `update-payload` from the latest green
  `build_and_release.yml` run via run-id); `build_and_release.yml` holds no publish secrets. actionlint: `pip install
  --target <scratch>/al actionlint-py`, run `<scratch>/al/bin/actionlint.exe -shellcheck= .github/workflows/*.yml`.
- Workflow rule: no `python` in any step from "Prepare SSH Credentials" on (tests enforce it). First step of publish/resign is a ref guard (v* tag / refs/heads/main).
- `test_bundle_guard.py` hard-codes job id `build-and-release`. Action SHAs: `gh api repos/<o>/<r>/git/ref/tags/<tag>`
  (gh is logged in here); tests enforce SHA pins + `# vX.Y.Z` comments on every `uses:`.
- Release notes required at `docs/release_notes/<version>.{ar,en}.txt`. CI always signs as `k2026a`. Keep
  `docs/UPDATE_DISTRIBUTION_RUNBOOK.md` + `docs/plans/cto_first_release_checklist.md` in step with the workflows.

## /release-check (2026-09-25)
- `check_release.py` checks take `(report, project_dir, ...)`; `main(argv, project_dir=, transport=)`. Tooling (bundle_guard,
  verify_manifest) always loads from the real checkout; the signing key is read by AST from `modules/app_update/service.py`.
  Tests: `tests/unit/test_release_check.py` (tmp git repo fixture, build_manifest-signed manifest, MockTransport, `no_boot` stub).

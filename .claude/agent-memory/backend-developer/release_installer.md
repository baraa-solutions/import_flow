---
name: release-installer
description: Inno Setup installer, packaging guard, rehearsal builds, production-laptop layout quirks and the old-install DB migration (R2m) for ImportFlow releases
metadata:
  type: project
---

## Release / installer (Phase 0b, 2026-09-24)
- The bash guard hook blocks ANY Bash command whose text contains `package_production.py` (even `cat`/`grep`). Read it
  with the Read/Grep tools; to hand the CTO a diff, build it with a scratchpad script + `difflib`, then
  `git apply --check <patch>` (read-only). It is CRLF; LF patches apply fine (autocrlf).
- `installer/importflow_setup.iss` is UTF-8 **with BOM** + CRLF (BOM needed for Arabic strings in `[Code]`).
  `version_manager.py` regex-rewrites `#define MyAppVersion "..."` and the whole `OutputBaseFilename=` line on bumps,
  so keep both as literal single lines. `tests/unit/test_installer_safety.py` pins the R1-R3 invariants.
- `scripts/release/bundle_guard.py` (`--iss/--dir/--zip`) is the one place that lists forbidden bundle content;
  CI and `/release-check` call it. `dist/Sorour_Logistics_Standalone/` in the worktree holds a stale `sorour_logistics.db`
  from old packaging, so release-check's bundle guard FAILs locally until the CTO removes it.
- ISCC 6.7.3 per-user at `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`. Compile/run-test in a scratch copy with a
  test AppId GUID and `/VERYSILENT /NOICONS /DIR=<scratch>`. Never run the real-AppId setup on this machine.
  Git Bash path-converts `/Q`-style flags: prefix `MSYS_NO_PATHCONV=1`.
- This dev machine has an old ADMIN install in `C:\Program Files (x86)\Sorour Logistics` (with a DB). The per-user
  installer therefore aborts here by design (the "DB in another install folder" check).
- Production laptop (Q1, 2026-09-24): per-user install at `C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\` with
  the live DB (+ -wal/-shm), `backups\`, `data\` (= Flutter runtime: app.so, icudtl.dat, flutter_assets - [Files]
  must overwrite these on update) and `dist\` (unknown, never touch). Legacy scripts incl. `seed.py` are removed by
  exact-name `[InstallDelete]`.
- Inno `Excludes`: a leading backslash anchors to the source root (`\dist\*` skips `<root>\dist\` but keeps
  `data\...\dist\`), verified by compiling. `sed -i` in the Bash tool rewrites CRLF files to LF - re-normalize.
- `backend_runner.py` has no import-time side effects: `run()` takes the single-instance lock (frozen: mutex `Local\SorourLogisticsBackend`; dev: lock file in %TEMP%) BEFORE `from main import app`; watchdog waits for `startup_done`. Tests inject `lock_factory/import_app/serve`.
- Launch target = `{app}\frontend.exe`, never .vbs (VBScript leaving Windows). Upgrades overwrite same-named shortcuts; silent upgrade keeps desktopicon task. Rehearse with test AppId+MyAppName, dummy taskkill names, `csc /target:winexe` marker exe.
- Inno Pascal: `{...{app}...}` comments end at the first `}`: use `//`. Use `CopyFile`, not deprecated `FileCopy`.
- `.github/workflows/build_and_release.yml` is owned by the release-tooling dev (separate `release`/`publish` jobs that
  `needs: build-and-release`); keep workflow tests structural, not tied to one job layout.

## Building installers outside the repo (rehearsal kit, 2026-09-25)
- No global PyInstaller: `pip install --target <scratch>/pyi pyinstaller` + `PYTHONPATH=<scratch>/pyi python build_backend_exe.py`.
  Scratchpad paths break MSBuild (MAX_PATH): PowerShell `subst R: '<path>'`, build from R:, `subst R: /D`; `Path.resolve()` undoes subst.
- Frozen backend with a `backups\pre_migration_*.db` path > ~255 chars fails that backup -> maintenance: smoke-test from a
  short dir. Dev-box `C:\Program Files (x86)\Sorour Logistics` is v1.0.58. stage-local checks sha/size only, not exe name.
- Inherited `_PYI_*`/`_MEIPASS*` made the new onefile backend.exe (via Setup -> frontend.exe) reuse the old _MEI dir (old
  alembic/versions, no migration). Fixed at the source: frozen `backend_runner.run()` calls
  `db_safety.reset_pyinstaller_environment()` first; the installer Popen also passes `env=clean_child_environment()`.
- `backend_runner.run()` builds its startup Event itself (no `started=` param, no module global); tests capture it via a
  `start_watchdog` stub. Defaults come from `db_safety.is_frozen_build()/app_base_dir()` (resolved exe dir).
- Heredocs in the Bash tool turn `\\x00` in embedded Python into real NUL bytes: put test/edit scripts in scratchpad files.

## R2m migration from an old install folder (v2.1.1, 2026-09-26, after review round 2)
- PrepareToInstall: {app} has DB -> pre_install backup (other DB folders only logged); none + exactly 1 other folder ->
  migrate ONLY if interactive (WizardSilent aborts), the folder is still registered (App Path + unins###.exe) and the
  HKCU marker `Software\<Publisher>\<AppName>\InstallerMigration` SourceSha256 differs; else WrongFolderAbortMessage.
  Copy read-only to `backups\pre_migrate_<tag>_<ts>\` + `\staging\` (size+SHA-256), RenameFile .db LAST, undo = move back.
- The old uninstaller runs in CurStepChanged(ssPostInstall) (after re-stop + source re-fingerprint), never in PrepareToInstall:
  a cancel after migration leaves old install registered + data in {app}. Same-AppId HKCU old install: key is rewritten by
  the new install, so post-install lookup fails -> notice only (running it would unregister the new install).
- bundle_guard allows exactly this: CopyFile(...,True) into pre_migrate_, RenameFile staging<->live with literal `+ Stamp +`.
- Rehearsal defines (ISCC /D, `#ifdef` only): RehearsalOldInstallDir(2), RehearsalOldUninstallKey, RehearsalElevateVerb,
  RehearsalAllowSilentMigration, RehearsalAbortAfterPrepare (Abort in ssInstall -> exit 3).
  Kit: `D:/importflow_rehearsal/build/migrate_rehearsal/rehearse.py <repo>` (10 scenarios, cleans HKCU keys/markers).
- Rehearsal copies MUST change MyAppName too: `{commonpf32}\{#MyAppName}` otherwise finds this box's real Program Files DB.
  "[Code]" also appears in the .iss header comment: anchor `^\[Code\]`; `#define ... "x"$` fails on CRLF (match with a negated class that excludes the quote, CR and LF).
- Inno uninstaller launched with wait returns in <1 s with its uninstall key already gone; unins000.exe disappears a
  few seconds later. Poll the key, not the exe. A lowest-priv fake "old" .iss gives a real HKCU key + uninstaller;
  whoami.exe copied as unins000.exe = an uninstaller that "fails" (key stays).
- Pascal: `GetSHA256OfFile` raises on a locked file (wrap try/except); `FileExists` is False for a folder; records
  (`type T = record`) work in [Code]. Installer tests import strip_pascal_comments/_call_arguments from bundle_guard.

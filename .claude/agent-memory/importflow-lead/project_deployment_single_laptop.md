---
name: project-deployment-single-laptop
description: Production runs standalone on ONE laptop (backend.exe + SQLite locally), user needs offsite/external backup; frontend strategy decided accordingly
metadata:
  type: project
---

As of 2026-09-24 the ERP runs in production on a single laptop (standalone: local backend + SQLite), not a LAN server.
The CTO needs backups copied to external storage (USB drive / cloud) because losing the laptop means losing all data.

**Why:** answered while comparing frontend strategies (keep Flutter desktop vs Flutter Web vs React rewrite).
Offline single-laptop use removes the main benefit of a web frontend (no installer), so the decision is: keep Flutter
desktop, do the "must" fixes (pin SDK, port app_theme to new SDK, CI, updater SHA-256/signing). React rewrite rejected
(~135 dev-weeks likely estimate).

**How to apply:**
- Treat the laptop's `sorour_logistics.db` as the only copy of real data; always remind about
  `python scripts/daily_backup.py --test` before write-path changes.
- `scripts/daily_backup.py` already supports offsite copy to any folder (`--offsite-dir` or env
  `GOOGLE_DRIVE_BACKUP_DIR`), AES-256-GCM encrypted. The key `BACKUP_ENCRYPTION_KEY` is auto-generated into the
  laptop's `.env`: if it is not stored elsewhere, encrypted offsite backups are useless after laptop loss.
- Revisit Flutter Web only if a second office/LAN user appears. See [[frontend-strategy]].

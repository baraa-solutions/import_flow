---
name: project-production-laptop-layout
description: Where the production laptop keeps the app, DB and backups (per-user Inno install) and what else sits in {app}
metadata:
  type: project
---

Production laptop (checked 2026-09-24 by the operator's screenshots): per-user Inno install at
`C:\Users\Hp\AppData\Local\Programs\Sorour Logistics\`. Live DB `sorour_logistics.db` (~8.7 MB) + `-wal`/`-shm` next to
`backend.exe`. `{app}` also holds `backups\` (only `sorour_logistics_manual_dev_*.db` from production_sync — no
`auto_pre_upgrade_*`, confirming startup snapshots were lost in the PyInstaller temp dir), `data\`, `dist\` (unknown
content), and leftover dev scripts `seed.py`, `clean_and_isolate_databases.py`, `reset_clean_production_db.py`.
A USB copy of db/-wal/-shm was taken 2026-09-24 20:40.

**Why:** installer and updater design depend on the install mode and on never touching data folders.
**How to apply:** keep the installer per-user; never delete/overwrite anything in `{app}\backups|data|dist` or `*.db*`;
the CTO confirmed (2026-09-24) that someone also ran the app from source with `python` on this laptop, so a second
dev checkout DB may exist there and hold real data — find and back it up before any update; production must run the
installed app only.
Related: [[single-laptop-deployment]]

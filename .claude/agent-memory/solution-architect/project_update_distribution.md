---
name: project-update-distribution
description: Production topology and update-distribution constraints from the CTO (private repo, single laptop, Hostinger static hosting, Ed25519-signed manifest)
metadata:
  type: project
---

Production is ONE standalone Windows laptop (backend.exe + frontend.exe from one Inno Setup installer), not the LAN server described in
docs/UPDATE_DISTRIBUTION_RUNBOOK.md (that runbook is outdated). The GitHub repo is PRIVATE (CTO-confirmed 2026-09-24), so the app can't
download from GitHub anonymously and a token must never ship in the app.

The CTO chose the distribution direction on 2026-09-24: static HTTPS files on his Hostinger shared hosting (kamal-sroor.online), a signed manifest
(Ed25519 public key embedded in the app, SHA-256 of installer inside), CI publishes via SFTP (port 65002) with a dedicated SSH key in Actions
secrets, installer first and manifest last. Full plan: docs/plans/update-system-plan.md.

The CTO approved the plan on 2026-09-24 with an overriding priority: the production DB on the laptop must never lose or overwrite data. Section 0 of the plan
(rules R1-R12) overrides everything else, and DB-safety work is Phase 0, ahead of any updater work.

**Why:** CI was red for weeks, version.json advertised unpublished installers (404), and the old auto-updater ran installers with no verification.

**How to apply:** Any update/release/installer work must keep integrity independent of transport (signature + hash). Never put credentials,
usernames or hosts in repo files except that plan. Treat installer contents as public, so no DB or .env can be in the bundle.
Related: [[bash-guard-package-production]].

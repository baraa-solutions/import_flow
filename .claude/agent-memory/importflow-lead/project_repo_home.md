---
name: project-repo-home
description: The source-of-truth GitHub repo moved to the private org repo baraa-solutions/import_flow (remote "company")
metadata:
  type: project
---

Since 2026-09-25 the source of truth is the PRIVATE repo https://github.com/baraa-solutions/import_flow (git remote `company`).
The old public repo ahmedsalahsorour88/import_flow (remote `origin`) is legacy; the CTO (GitHub `kamalsroor1`) only had write
there, so he could not create environments/secrets. He is admin of the `baraa-solutions` org.

**Why:** releases need the `production-updates` environment + signing-key secret, which require repo admin.
**How to apply:** push/PR/CI checks go to `company`, not `origin` (still only when the CTO asks). `/ci-status` and any
hard-coded `ahmedsalahsorour88` URLs (legacy installer_url, docs) point at the old repo and need updating.

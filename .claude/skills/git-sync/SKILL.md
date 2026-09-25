---
name: git-sync
description: Safely pull the latest origin/main into the current branch with plain git - checks divergence, protects uncommitted work without git stash, resolves history/*.md conflicts append-only, and verifies the backend still boots afterwards.
disable-model-invocation: true
---

# Git Sync

Bring the current branch up to date with `origin/main` using plain `git` (no gh CLI or connector).

## Steps

1. **Inspect**
   ```bash
   git fetch origin
   git status -sb
   git rev-list --left-right --count origin/main...HEAD   # "<behind> <ahead>"
   git log --format="%h | %ad | %an | %s" --date=format:"%Y-%m-%d %H:%M" HEAD..origin/main
   ```
   If behind is 0, report "already up to date" with the latest `origin/main` commit and stop.

2. **Protect local work.** If the working tree has changes, do **not** use `git stash` — the stash
   stack is shared with every worktree of this repo. Instead list the changed files, tell the user,
   and make a local commit of only the files that belong to the current task
   (never `.env`, `*.db`, `backups/`, `dist/`, `logs/`, or scratch folders). Do not push.

3. **Integrate**
   - No local commits and a clean tree: `git merge --ff-only origin/main`
   - Otherwise: `git merge --no-edit origin/main`

4. **Resolve conflicts**
   - `history/*.md` (add/add or content): keep the `origin/main` version in full and append the
     local entries after a `---` separator — history is append-only (AGENTS.md section 18).
     `{ git show origin/main:<f>; printf '\n\n---\n\n'; git show <local-commit>:<f>; } > <f>`
   - `version.json`, `frontend/pubspec.yaml`, `installer/*.iss`: take `origin/main` unless the user
     is intentionally cutting a release from this branch.
   - Code conflicts: resolve by reading both sides; ask the user when intent is unclear.
   Then `git add` the resolved files and `git commit --no-edit`.

5. **Verify**
   ```bash
   python .claude/skills/release-check/check_release.py
   ```
   The backend-boot line must be PASS. If upstream introduced an import error, report the file and line.

## Report (Egyptian Arabic)

New upstream commits (hash, date, author, subject), whether a local commit was made, conflicts and
how each was resolved, the boot check result, and the final ahead/behind count. Never push unless asked.

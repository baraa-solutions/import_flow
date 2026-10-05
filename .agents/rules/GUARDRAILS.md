# 🛡️ Guardrails — hard limits for every AI agent (Antigravity, Gemini, Copilot, Claude)

> These are not suggestions. The owner merges only PRs whose `PR Checks` are green and whose diff respects these
> rules; breaking them only gets the PR sent back.
> Full workflow: `AI_WORKFLOW.md`. Rules: `CORE_RULES.md`, `DOMAIN_RULES.md`.

## 1. Never (stop and ask the user instead)

- Push to `main`, merge a PR, force-push, `git reset --hard`, `git clean`, `git stash`, delete branches or tags.
- Edit `.env`, any `*.db` / `*.sqlite`, `version.json`, `package_production.py`, `installer/`, `scripts/release/`,
  `.github/`, `.githooks/`, `scripts/ci/`, `.claude/`, `.agents/rules/`.
- Run the app or any script against `sorour_logistics.db`. Always `set DATABASE_PATH=%TEMP%\dev_copy.db` first.
- Click or call Production Sync (`modules/production_sync`): it writes the real databases.
- Run destructive SQL (`DROP`, `DELETE` without a business reason, `UPDATE` without `WHERE`).
- Change the database schema without an Alembic migration in `alembic/versions/`.
- Hard-code a tax / duty / VAT rate, exchange rate, fee or price. Rates come from the tariff (HS code), currency
  tables or `system_parameters`.
- Add a route without `Depends(require_permission("<module>.<action>"))`, or a permission code that is not in
  `modules/auth/seed_rbac.py`.
- Delete or rewrite old lines in `history/*.md` (append-only).
- Weaken, skip or delete a failing test to make it green. Fix the code, or ask.
- Commit with `--no-verify`.

## 2. Ask the user before you

- Touch money math (customs, tariff, landed cost, settlement, demurrage, currencies), auth (`modules/auth/`),
  shared registries (`modules/common/`), `main.py`, `settings.py` or `requirements.txt`. These need the owner's review.
- Delete a file, rename a public API field, or change a response shape the Flutter app reads.
- Change more than the task needs ("while I'm here" refactors are not allowed).

## 3. One-time setup per clone (enables the local guards)

```cmd
git config core.hooksPath .githooks
```
- `pre-commit` blocks secrets, databases, release files, history rewrites and backend modules that no longer import.
- `pre-push` runs the same gate as GitHub (boot check, single Alembic head, auth/catalog guard tests, tests of the
  modules you touched). It takes minutes; let it finish. If it prints "FULL SUITE NEEDED BEFORE MERGE", say so in
  the PR: the owner runs the full suites (label `full-tests`) before merging.
- The hooks use `.venv` when it exists. A commit blocked with "does not have the project's packages" means the
  wrong Python: create the venv and `pip install -r requirements.txt`.

## 4. Before saying "done" or opening a PR

```cmd
python scripts/ci/guardrails.py pr-gate
cd frontend && flutter analyze lib/features/<feature>
```
Both must pass. Report the real numbers they print. Then open a PR to `main` on the company repo; the owner reviews
and merges. GitHub runs the same checks on the PR (`PR Checks` workflow: "Backend gate", "Flutter analyze").
Changing `scripts/ci/`, `.github/` or a guard test to turn a check green is treated as breaking the rules.

Remote names: on a fresh clone the company repo is `origin`. Where `AI_WORKFLOW.md` says `company`, use `origin`
(or the remote that points to `baraa-solutions/import_flow`, or to your fork if you work from one).

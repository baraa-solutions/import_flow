@AGENTS.md
@.agents/rules/CORE_RULES.md

# Claude Code setup

The main session runs as the `importflow-lead` agent (`"agent"` in `.claude/settings.json`); it plans and
delegates to the subagents in `.claude/agents/`. All agents run on Opus 5.5 at medium effort.

- Subagents: `solution-architect`, `backend-developer`, `flutter-developer`, `debugger`, `diff-reviewer`,
  `customs-rules-reviewer`, `security-reviewer`, `qa-verifier`. Their persistent memory lives in
  `.claude/agent-memory/<name>/MEMORY.md` (committed, shared).
- Path-scoped rules in `.claude/rules/` load with backend, Flutter, and customs/landed-cost files.
- Skills: `/spec`, `/release-check`, `/ci-status`, `/git-sync`, `history-logger`, plus the domain skills.
- Saved workflows (many agents, high token cost - run on request): `/review-branch [base]`, `/audit-endpoints`.
- Hooks: backup-safe smoke import after each backend edit; the turn cannot end while `import main` fails;
  `history/*.md` append-only; `.env` / `*.db` never edited; destructive git (`stash`, force-push,
  `reset --hard`, `clean -f`) and `package_production.py` blocked.

## Gotchas

- Python 3.12 evaluates annotations eagerly: a missing `typing` import breaks the boot even if it works on 3.14.
- After `import main`, pytest's final "N passed" line is suppressed: read `--junitxml` and the exit code.
- Daily work is Track 1 (`docs/DEV_WORKFLOW.md`): no version bumps, no `version.json` edits, no packaging.

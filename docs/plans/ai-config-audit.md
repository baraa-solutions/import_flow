# AI / agent configuration audit — 2026-10-05

Read-only audit by `solution-architect`. No audited file was changed. Line numbers refer to the worktree
`project-feedback-e6bfde` (including uncommitted edits to CORE_RULES.md, importflow-lead.md, .claude/rules/backend.md).

## 1. Summary

The configuration works, but it has drifted since 2026-09-23, when AGENTS.md went from ~1,300 lines to 128
(commit 83f71fc). The main problems:

- **Dangling references.** Every "AGENTS.md section N" pointer (5, 6, 7.1-7.3, 10-21, 18, 19) now points at
  nothing. The customs worked example (FOB 623,000 -> 165,801.50 EGP) exists only in reviewer memory.
- **A money-rule contradiction.** DOMAIN_RULES and the customs skill say `VAT base = CIF + duty + Freight + fees`.
  That counts freight twice. The customs ruling and the worked example use `CIF + duty`.
- **The UI standard can't be invoked as a skill.** `UI_SCREEN_STANDARDS.md` is a stub that points to a skill that
  exists only under `.agents/skills`, so Claude can't call it as a Skill.
- **Duplication.** The same rules appear 3-5 times (AGENTS.md ≈ a summary of CORE_RULES; skills copied
  byte-for-byte in two trees; the heredoc/sed lesson appears 6+ times in memories).
- **Session cost.** About 15.3 KB of Arabic and emoji-heavy rules loads every session (CLAUDE.md 1.6 KB +
  AGENTS.md 5.1 KB + CORE_RULES 8.7 KB). The lead's own definition and memory add another ~13 KB.
- **Missing lessons.** The 2026-10-05 wave lessons live only in lead memory and history. They are not yet in
  the agent briefs: no commits by agents, Edit tool only, foreground per-file tests, the shared-needs registry,
  and taking the actor from the login. backend-developer still says "add a new code to seed_rbac" and its
  memory still says "start the full suite in the background and wait". Both contradict the wave rules.

## 2. Inventory (bytes / lines)

| Loaded | File | Bytes | Lines |
|---|---|---|---|
| every session | CLAUDE.md (+ @AGENTS.md + @CORE_RULES.md) | 1,576 + 5,058 + 8,737 | 24 + 128 + 208 |
| main session | .claude/agents/importflow-lead.md / lead MEMORY.md | 8,629 / 4,620 | 124 / 44 |
| on path match | .claude/rules/backend.md, customs-domain.md, flutter.md | 1,952 / 1,175 / 1,080 | 30 / 25 / 18 |
| on read | .agents/rules/DOMAIN_RULES.md, UI_SCREEN_STANDARDS.md (stub) | 5,220 / 1,136 | 173 / 21 |
| per subagent | 8 agent files, 2.3-3.8 KB each | 24 KB total | |
| per subagent | backend MEMORY.md (biggest) | 14,740 | 146 |
| skills | .agents/skills (8) and .claude/skills (11): 7 shared copies are byte-identical; ui-screen-standards 23.7 KB only in .agents | | |
| hooks | boot_gate, guard_bash, protect_files, session_context, smoke_import | 12 KB | |
| workflows | review-branch.js, audit-endpoints.js | 10.7 KB | |
| memory | 76 files under .claude/agent-memory; security baseline 214 lines | | |
| stray | frontend/.claude/agent-memory (5 files, untracked); .gemini/antigravity/.../insert_warning.py (tracked) | | |
| other | docs/prompts/app-review.md 9.4 KB; settings.local.json absent | | |

## 3. Findings

| id | file:line | type | problem | proposed change | risk |
|---|---|---|---|---|---|
| F01 | backend-developer.md:13, flutter-developer.md:14, customs-rules-reviewer.md:19,33, lead.md:54, protect_files.py:4,48, customs MEMORY.md:3 | stale | Cites AGENTS.md sections 3-21 / 7.2 / 18 / 19, which no longer exist | Point at the real owners: CORE_RULES §3/§5, DOMAIN_RULES §2-3, `.claude/rules/*`. In the hook message, say "history is append-only" with no section number | low |
| F02 | DOMAIN_RULES.md:42; customs-landed-cost-engine SKILL.md:33; customs-domain.md:15 | contradiction | VAT base includes "+ Freight" although CIF already has freight. The ruling `ruling_vat_base_and_phase03.md` and the worked example (95,942 = 14% × 685,300) use CIF + duty | One formula in DOMAIN_RULES only. Wording: "VAT base = CIF + import duty (+ fees the HS code marks VAT-able)". Others link to it. **The customs-rules-reviewer must confirm before the edit** | high (money) |
| F03 | DOMAIN_RULES.md:138 | contradiction | `Volumetric Weight = CBM × 167` is hard-coded. The code reads `system_parameters.AIR_VOLUMETRIC_KG_PER_CBM` | Use "factor from system parameter AIR_VOLUMETRIC_KG_PER_CBM (default 167)" | low |
| F04 | AGENTS.md:9-16 | contradiction | The table says DOMAIN_RULES and UI_SCREEN_STANDARDS load automatically. Only CORE_RULES is imported (CLAUDE.md:2), and the UI file is a stub | Fix the table: auto = CORE_RULES; path-scoped = .claude/rules; on demand = skills | low |
| F05 | flutter.md:9, flutter-developer.md:3,14, docs/prompts/app-review.md:11 | stale | "Read UI_SCREEN_STANDARDS.md" leads to a 21-line stub. The real 474-line skill is only in `.agents/skills`, which the Skill tool can't reach | Copy `ui-screen-standards` to `.claude/skills/`, add it to flutter-developer `skills:`, and point the references at the skill | low |
| F06 | AGENTS.md (whole) vs CORE_RULES.md | duplicate | Language, stack, architecture, UI quick reference, mandatory rules and the completion protocol are repeated nearly word for word. Both load every session (~5 KB wasted) | Cut AGENTS.md to about 25 lines (system context + index of rule files + skills table). CORE_RULES becomes the only rule body | low |
| F07 | .agents/skills/* vs .claude/skills/* | duplicate | 7 skills are byte-identical in both trees. They will drift on the next edit | Decision: keep `.claude/skills` as the source (Claude-native). Keep `.agents/skills` only if Antigravity/Gemini still uses it (`.gemini/` exists), with a parity check in release-check | med |
| F08 | CORE_RULES.md:124-150 | unnecessary | "Task G / Task I / Step 0" labels and web File System Access API details (~1.6 KB) load every session. The app is Windows desktop | Move the file-save details to the ui-screen-standards skill. Keep one line in CORE_RULES: "all exports via FileSaveHelper.exportAndSaveFile, no silent save" | low |
| F09 | AGENTS.md:117, CORE_RULES.md:96-99,195-199 | contradiction | "100% green tests / 100% passing" vs qa-verifier's expected skips, the CTO's "full gate only at the end" (feedback_speed_parallel) and known flaky runs (exit 127, flutter "did not complete") | Rephrase: "the tests you touched pass; the full gate runs before a release; env skips are listed in qa-verifier" | low |
| F10 | backend-developer.md:23 | contradiction | "add a new code there [seed_rbac] if none fits" vs the wave rule: devs never edit seed_rbac; the lead registers codes | "Use an existing code. If none fits, put the new code in your report or review-shared-needs.md. The lead registers it" | med |
| F11 | backend MEMORY.md:29 | contradiction | "Full tests/unit: start with run_in_background and wait for the notification" vs feedback_large_parallel_waves (never wait on background runs; agents stalled ~3 h) | Delete the line. Replace it with "run one test file at a time in the foreground; the full suite is qa-verifier's job" | low |
| F12 | qa-verifier.md:28 | stale | "Full suite takes about 8 minutes". The real numbers are 3,512 tests (history 2026-10-05:42) and 21-45 min. No mention of `scripts/release/run_release_tests.py` | Update the duration. Add a per-file fallback (aggregate the per-file XMLs) for exit-127 kills. Mention run_release_tests for release gates | low |
| F13 | qa-verifier MEMORY.md:5,12,18,20; lead MEMORY.md:31 | stale | Dated count logs (930 / 1067 / 1725 / 2006 / 2011 tests) are task history, not memory | Keep one "latest baseline" line (date, counts, duration). History holds the rest | low |
| F14 | lead MEMORY.md:3-8,15 | stale | The "CI red since 2026-08-28" section and the "Locale bug: no supportedLocales" note are now fixed (RTL work, releases v2.1-v2.2) | Remove or mark them resolved | low |
| F15 | lead MEMORY.md:21-23 | duplicate | The DATABASE_PATH / stamping warning appears twice in a row and also in backend memory (:53) and qa memory (:17) | One line in lead memory. Move the rule to `.claude/rules/backend.md` ("every `import main` probe uses a scratch DATABASE_PATH") | low |
| F16 | backend MEMORY.md:25-26,69,79-81,108; phase03b file; flutter 344/phase04_05/idoc/l10n files | duplicate | Six or more copies of "heredoc / sed / CRLF mangles code" | Make it one rule in the agent definitions (see M03). Delete the memory copies | low |
| F17 | backend MEMORY.md (146 lines, 14.7 KB) | improvement | Right at its 150-line budget and the costliest auto-loaded memory. Most phase sections are module quirks | Move the phase sections into topic files (phase01/03b/08_10 files already exist). Keep MEMORY.md as an index of ≤60 lines | low |
| F18 | security-reviewer project_security_baseline.md (214 lines); its MEMORY.md (one 574-char line) | stale | Over budget. The "Fixed (in that diff, uncommitted 2026-09-24)" sections are now history. The index line is a change log | Rewrite as "open issues only + inventory command". Index ≤150 chars per entry | low |
| F19 | customs MEMORY.md:11,13 | duplicate | Two index entries point to the same `ruling_phase09_settlement.md` | Merge them into one line | low |
| F20 | customs MEMORY.md:3 | missing | The worked example is the reference fixture for money math, yet it exists only in memory | Put it in DOMAIN_RULES §2 (or the customs skill) as the canonical example. Memory just links to it | med |
| F21 | DOMAIN_RULES.md:119-129 | stale | `integrations/{cargox,nafeza,shipping}` doesn't exist | Describe the real location, or call it "target structure" | low |
| F22 | DOMAIN_RULES.md:10-13 | stale | The 9-stage lifecycle text doesn't match the 6-phase / 25-step board (`modules/lifecycle_board`) and the 10 business phases (docs/phase_01..10) | Replace with "10 business phases (docs/phase_XX) mapped onto the 6-phase / 25-step board" | low |
| F23 | frontend/.claude/agent-memory/ (untracked) | unnecessary | Created when an agent ran with cwd=frontend. 4 files duplicate solution-architect memory. `debugger/flutter_gate_flakes.md` exists only here | Move flutter_gate_flakes.md to root debugger memory and add an index line. Delete the folder. Add `frontend/.claude/` to .gitignore | low |
| F24 | .gemini/antigravity/brain/.../insert_warning.py (tracked) | unnecessary | An Antigravity scratch file committed to the repo | Remove it from git; ignore `.gemini/` | low |
| F25 | lead.md:83-93 (brief template) | missing | The brief lacks the wave rules: no commit, Edit tool only, foreground per-file tests, shared-file registry, turn checkpoint | Add a "Standing rules" line plus "Shared needs: append to docs/plans/review-shared-needs.md" (see M01-M06) | low |
| F26 | backend-developer.md, flutter-developer.md, debugger.md | missing | No "do not commit" rule. One agent committed 4d22473 on its own (history 10-05:33) | Add "Never commit, push or tag; the lead commits" to every editing agent | low |
| F27 | flutter.md:11, flutter-developer.md:21 | missing | The l10n rule names 3 files only. New codes also need `system_message_catalog_{ar,en}.dart` and `domain_enum_labels.dart` (parity tests fail otherwise). The marker-block pattern for parallel l10n edits isn't written down | Add both to `.claude/rules/flutter.md` | low |
| F28 | lead.md:32-35; CLAUDE.md:8; lead MEMORY.md:29 | contradiction (minor) | The lead memory says "Opus 5.5 medium for agents", while flutter-developer and qa-verifier run Sonnet | Keep the model policy in CLAUDE.md only. Drop the memory clause | low |
| F29 | maxTurns: reviewers 40, qa 30, security 50, debugger 60, devs 80 | improvement | Agents hit 40/60/80 turns on big diffs. qa at 30 turns can't do per-file reruns of 3.5k tests | qa 30→50. Add the turn-budget rule (M07) to every agent: inventory and report at ~75% of turns. Lead: split reviews by file subset when the diff is over 3k lines | low |
| F30 | diff-reviewer.md:16; customs-rules-reviewer.md:27 | improvement | Default scope `git diff HEAD` mixes in foreign-session edits (feedback_parallel_sessions) | "Review only the files the lead lists. Without a list, use git diff HEAD and flag files outside the plan" | low |
| F31 | solution-architect.md:25-42 | improvement | The plan format has no "shared files / registry needs" or "production DB safety" section, though the lead cites "plan section 0" (lead.md:72) | Add §0 "DB safety / live-data impact" and §7b "Shared-file needs (seed_rbac, modules/common, docs/*.json, l10n)" | low |
| F32 | settings.json:5-20 | improvement | No allow rule for `python -m pytest` with env-prefix forms, `git worktree list`, or the Workflow tool. `history-logger` and `release-check` exist in both skill trees | Minor. Add `Bash(git worktree list)`. Settings otherwise fit the rules | low |
| F33 | boot_gate.py:19 | improvement | `alembic/` is outside BACKEND_PATHS, so a broken revision file passes the gate (smoke_import also skips alembic) | Add "alembic" to both hooks' roots | low |
| F34 | history-logger SKILL.md | improvement | The template doesn't ask for test counts or commit SHAs, which the lead report needs | Add "Verification: counts + junit source; Commits: sha or 'uncommitted'" | low |
| F35 | erp-module-generator SKILL.md (24 lines) | unnecessary | Repeats CORE_RULES §3 and adds nothing (no template code) | Either enrich it with a real module skeleton (auth dep, coded errors, legacy-tolerant schemas) or delete it (decision) | low |
| F36 | docs/prompts/app-review.md:3,15 | stale | Hard-codes this worktree path and refers to the old "router auth uncommitted" state | Make the path generic. Drop the stale Phase-0 note | low |

## 4. Missing rules from the 2026-10-05 wave (where each one should live)

| id | rule | target file |
|---|---|---|
| M01 | No fabricated data: no fallback FX (48.5…), rates, ACID/company/quantity defaults. Missing → null + 409 coded error | CORE_RULES §6 (already uncommitted at :164), backend.md, flutter.md (no sample defaults in forms) |
| M02 | Response schemas tolerate legacy rows; new columns need server_default or a backfill | backend.md:16-22 (present, uncommitted). Remove the duplicate from CORE_RULES:162-163 and keep one line there |
| M03 | Edit/Write tools for code. Never heredoc, `sed -i` or `python -c` writes (they mangle `\n` and CRLF) | every editing agent definition (backend, flutter, debugger) |
| M04 | Tests: one file per pytest/flutter call, in the foreground. Never wait on background runs. Never run pytest and flutter test together | backend-developer, flutter-developer, debugger, qa-verifier |
| M05 | Agents never commit, push or tag | the 3 editing agents + lead brief template |
| M06 | Shared-file ownership: devs don't edit seed_rbac, modules/common registries, docs/*.json, or l10n outside their marker block. They append to `docs/plans/review-shared-needs.md`; the lead registers RBAC codes | lead.md step 4 + brief template; backend/flutter "Rules" |
| M07 | Turn budget: at ~75% of maxTurns, stop and report done / remaining / files touched, so a fresh agent can finish | all agents |
| M08 | Permission codes must exist in `PERMISSIONS_CATALOG`. `test_route_auth_coverage.py` guards routes | backend.md:9-10 (present). Add "unknown code = 403 for everyone" |
| M09 | Acting user comes from the token (`current_user`) only. Never from body fields (approved_by, reviewer_name) or X-User headers | backend.md, security-reviewer checklist item 1 |
| M10 | Every `import main` probe uses a scratch DATABASE_PATH (it stamps and backs up the DB it points at) | backend.md, debugger.md:22 (present), qa-verifier |
| M11 | New coded errors are registered in the same change, or `test_review_wave_codes.py` fails | backend.md (now only in backend memory) |
| M12 | A stalled agent (no file mtime change for over 30 min): launch a fresh agent with "re-read files, inventory, finish" | lead.md Operating loop step 4 |

## 5. Target structure (one owner per topic)

| Topic | Single owner | Others |
|---|---|---|
| Model / effort policy, Track 1, gotchas | CLAUDE.md | nobody repeats |
| Project rules (language, stack, layering, forbidden, completion) | CORE_RULES.md (≤6 KB) | AGENTS.md = index only |
| Customs / landed cost / CBM formulas + worked example | DOMAIN_RULES.md | customs skill and customs-domain.md link to it; no restated formula |
| Backend coding rules | .claude/rules/backend.md | backend-developer.md keeps only role, workflow and report |
| Flutter coding rules | .claude/rules/flutter.md + ui-screen-standards skill (in .claude/skills) | flutter-developer.md keeps only role, workflow and report |
| Agent workflow rules (commit, Edit tool, tests, turns, shared files) | each agent's "Standing rules" block (identical 6 lines) | lead brief template repeats only the per-task parts |
| Shared-needs registry | docs/plans/review-shared-needs.md | |
| Durable pitfalls | agent memory (index ≤60 lines, topic files ≤80) | no counts, no task logs |
| Task history, test counts | history/YYYY-MM-DD.md | |

## 6. Prioritised change list

### Safe to apply now (no deletions, wording only)

1. F01 — replace the dangling AGENTS.md section references in 4 agent files, protect_files.py and customs memory.
2. F10 + F11 + F26 + M03-M07 — add a 6-line "Standing rules" block to backend-developer, flutter-developer and
   debugger. Fix the seed_rbac sentence. Delete the background-run line in backend memory.
3. F25 + F31 + M06 + M12 — extend the lead brief template and the architect plan format (DB-safety section, shared needs).
4. F12 + F29 — qa-verifier: real durations, per-file fallback, maxTurns 50. Add the turn-budget line everywhere.
5. F27 + M09 + M10 + M11 — add the missing lines to `.claude/rules/flutter.md` and `.claude/rules/backend.md`.
6. F04 + F09 + F03 + F21 + F22 — correct the AGENTS.md table, the "100%" wording, the 167 factor, and the
   integrations and lifecycle text.
7. F13-F19 — memory hygiene: prune count logs and fixed items, merge duplicate entries, split backend memory
   into topic files, rewrite the security baseline as open issues only.
8. F23 (move flutter_gate_flakes.md into root debugger memory; the deletion part is in the next list), F30, F33, F34, F36.

### Needs CTO decision

1. **F02 VAT base formula**: confirm "CIF + import duty (+ VAT-able fees)" with customs-rules-reviewer, then
   edit DOMAIN_RULES and the customs skill. This is a money rule, so the change must not be cosmetic.
2. **F06** cut AGENTS.md to an index (other tools, e.g. Antigravity, may read it directly).
3. **F07** choose one skills tree: delete `.agents/skills` copies, or keep both with a parity check.
4. **F05** move `ui-screen-standards` into `.claude/skills` and delete or keep the `UI_SCREEN_STANDARDS.md` stub.
5. **F08** move the file-save and security "Task G/I" detail out of CORE_RULES.
6. **F23 / F24** delete `frontend/.claude/` and the tracked `.gemini/` scratch file. Add both to .gitignore.
7. **F35** delete or enrich `erp-module-generator`.
8. **F20** move the worked example into DOMAIN_RULES (it becomes binding for every agent).

## 7. Risks

- F02 changes the stated rule for VAT. If the code follows the old text anywhere, editing the doc exposes a
  real calculation bug. Run customs-rules-reviewer over `calc_*` VAT bases before the doc change.
- Removing `.agents/` content may break a colleague's Antigravity/Gemini workflow (commit 83f71fc was authored
  outside Claude Code). Ask before deleting.
- Agent-definition edits take effect for new sessions only. Running sessions keep the old text.

## Applied 2026-10-05 (lead)

- F02: VAT base = CIF + import duty only in DOMAIN_RULES, both customs-landed-cost-engine skills, .claude/rules/customs-domain.md, customs-rules-reviewer rule 3.
- F01: dangling "AGENTS.md section N" references repointed (backend/flutter/customs agents, lead, customs-domain rule, protect_files.py strings, git-sync skill, customs memory).
- F26 / M03-M07: "Standing rules" block in backend-developer, flutter-developer, debugger (no commit, Edit tool only, per-file foreground tests, scratch DATABASE_PATH, shared-needs registry, no fabricated data, 75% turn checkpoint).
- F10 / F11: backend-developer proposes permission codes (lead registers); backend memory "run full suite in background" line replaced.
- F25 / F31 / M12: lead brief template (standing rules, shared needs), shared-registry ownership + stalled-agent rule; architect plan sections 0 (DB safety) and 7b (shared-file needs).
- F12 / F29: qa-verifier maxTurns 50, real timings, chunk fallback, flutter -j 2, run_release_tests.py for releases.
- F27 / M09-M11: .claude/rules/backend.md (login-only actor, scratch DATABASE_PATH, register coded errors, no fabricated data, server_default/backfill, legacy-row tolerant responses); flutter.md (skill, RTL guard, catalogs + enum labels, null money "—", stable numeric controllers).
- F05: ui-screen-standards copied to .claude/skills and preloaded (with screen-audit) for flutter-developer.
- F06 / F08: AGENTS.md reduced to an index (5,058 B → ~2 KB); CORE_RULES file-save detail moved into the ui-screen-standards skill (8,737 B → 7,429 B) + new forbidden items (server_default, legacy rows, fabricated data).
- Memory: lead MEMORY.md pruned (stale CI/locale notes, duplicate DATABASE_PATH lines, old test counts); flutter_gate_flakes.md copied into the root debugger memory.

### Still pending (CTO decision or later)
- F07 one skills tree vs two (ui-screen-standards copies now both contain the file-save section).
- F05 remainder: keep or delete the UI_SCREEN_STANDARDS.md stub.
- F23 / F24: delete frontend/.claude/ (content copied) and the tracked .gemini scratch file; add both to .gitignore.
- F35 erp-module-generator; F20 make the 165,801.50 worked example binding; F03, F09, F21, F22, F30, F32-F34, F36.
- Backend MEMORY.md (146 lines) split into topic files; security baseline rewrite as open issues only.

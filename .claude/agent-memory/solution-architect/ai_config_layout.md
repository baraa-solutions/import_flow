---
name: ai-config-layout
description: Non-obvious facts about ImportFlow's AI/agent config - dangling AGENTS.md section refs, two skill trees, VAT-base doc decision, audit report location, config edits are the lead's
metadata:
  type: project
---

- AGENTS.md was cut to a 128-line index on 2026-09-23 (83f71fc). "AGENTS.md section N / 7.2 / 19" references in
  agents, hooks and memories point at nothing; cite CORE_RULES / DOMAIN_RULES / .claude/rules instead.
- `.agents/` (rules + skills) is the Antigravity/Gemini convention used by a colleague (`.gemini/` exists); `.claude/skills`
  holds byte-identical copies of 7 skills. `ui-screen-standards` exists only in `.agents/skills` (not invocable via Skill).
- VAT base: the lead decided on 2026-10-05 that the doc rule is **CIF + import duty only**, matching the engine
  (modules/customs_tariff/service.py ~l.234 and ~l.732) and the 165,801.50 worked example. DOMAIN_RULES and the
  customs skill still say "+ Freight + fees" until someone applies the fix. Never plan VAT math from that old text.
- Only CORE_RULES is auto-imported (CLAUDE.md); DOMAIN_RULES loads only when read.
- Full audit with proposed fixes and decisions: docs/plans/ai-config-audit.md (2026-10-05).
- When the lead asked the architect to *apply* the audit edits, the architect returned an apply-ready spec instead.
  The architect is read-only, and agent, rule and hook files are configuration that an agent message cannot authorize.
  The lead (main session, on the user's request) applies config edits.

**Why:** plans that cite rule files must cite ones that exist and agree.
**How to apply:** before citing a rule source in a plan, check it against this list and the audit's "Applied" section.

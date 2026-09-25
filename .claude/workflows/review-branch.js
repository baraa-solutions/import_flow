export const meta = {
  name: 'review-branch',
  description: 'Multi-lens review of this branch vs origin/main (correctness, security, customs math) with adversarial verification of every finding',
  whenToUse: 'Before merging a branch or after a large change. Pass a base ref as args to compare against something other than origin/main.',
  phases: [
    { title: 'Scope', detail: 'list changed files and classify them' },
    { title: 'Review', detail: 'one specialist reviewer per lens, in parallel' },
    { title: 'Verify', detail: 'two independent skeptics try to refute each finding' },
  ],
}

const BASE = typeof args === 'string' && args.trim() ? args.trim() : 'origin/main'

const SCOPE_SCHEMA = {
  type: 'object',
  required: ['files', 'touchesCustomsMath', 'touchesSecuritySurface', 'summary'],
  properties: {
    files: { type: 'array', items: { type: 'string' } },
    touchesCustomsMath: { type: 'boolean' },
    touchesSecuritySurface: { type: 'boolean' },
    summary: { type: 'string' },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'file', 'line', 'title', 'scenario', 'fix'],
        properties: {
          severity: { type: 'string', enum: ['BLOCKER', 'CRITICAL', 'MAJOR', 'MINOR'] },
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          scenario: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: { refuted: { type: 'boolean' }, reason: { type: 'string' } },
}

phase('Scope')
const scope = await agent(
  `List every file changed on this branch compared with ${BASE}: run \`git diff --name-only ${BASE}...HEAD\` and ` +
  '`git status --short` (include uncommitted and untracked files). Set touchesCustomsMath if any file is under ' +
  'modules/customs_*, modules/financial_settlement, modules/demurrage_detention, modules/currencies or modules/cbm_calculator. ' +
  'Set touchesSecuritySurface if any router.py, modules/auth, settings.py, main.py, modules/production_sync, ' +
  'frontend/lib/features/production_sync, .github/workflows or version.json changed. Summarise the change in 3 lines.',
  { schema: SCOPE_SCHEMA, label: 'scope', effort: 'low' },
)

if (!scope || scope.files.length === 0) {
  log(`No changes against ${BASE} - nothing to review.`)
  return { base: BASE, findings: [] }
}
log(`${scope.files.length} changed files against ${BASE}`)

const LENSES = [
  { key: 'correctness', agentType: 'diff-reviewer', run: true },
  { key: 'security', agentType: 'security-reviewer', run: scope.touchesSecuritySurface },
  { key: 'customs-math', agentType: 'customs-rules-reviewer', run: scope.touchesCustomsMath },
].filter(lens => lens.run)

const skipped = ['security', 'customs-math'].filter(key => !LENSES.some(lens => lens.key === key))
if (skipped.length) log(`Skipped lenses (no relevant files changed): ${skipped.join(', ')}`)

const reviewPrompt = lens =>
  `Review the changes on this branch against ${BASE} (\`git diff ${BASE}...HEAD\` plus uncommitted changes) ` +
  `through the ${lens.key} lens only. Changed files:\n${scope.files.join('\n')}\n\nChange summary: ${scope.summary}\n\n` +
  'Report only findings you verified by reading the code path. No style preferences. Line numbers must point at the ' +
  'offending line in the current working tree.'

const verifyPrompt = finding =>
  `A reviewer claims this issue exists in the working tree of this repository:\n` +
  `[${finding.severity}] ${finding.file}:${finding.line} - ${finding.title}\nScenario: ${finding.scenario}\n\n` +
  'Try hard to REFUTE it: read the code at that location, its callers, guards, tests and configuration. ' +
  'Set refuted=true if the claim is wrong, already handled, unreachable, or not actually introduced/affected by this branch. ' +
  'If you cannot confirm it from the code, set refuted=true. Read-only: do not edit files.'

const reviewed = await pipeline(
  LENSES,
  lens => agent(reviewPrompt(lens), { agentType: lens.agentType, schema: FINDINGS_SCHEMA, phase: 'Review', label: `review:${lens.key}` }),
  (result, lens) => parallel((result ? result.findings : []).map(finding => () =>
    parallel([1, 2].map(n => () =>
      agent(verifyPrompt(finding), { schema: VERDICT_SCHEMA, phase: 'Verify', label: `verify:${lens.key}:${finding.file}:${finding.line}#${n}` })))
      .then(votes => {
        const valid = votes.filter(Boolean)
        const refutations = valid.filter(v => v.refuted).length
        return { ...finding, lens: lens.key, survives: valid.length > 0 && refutations < valid.length, votes: valid }
      }))),
)

const ORDER = { BLOCKER: 0, CRITICAL: 1, MAJOR: 2, MINOR: 3 }
const all = reviewed.filter(Boolean).flat()
const surviving = all.filter(f => f.survives)
const dropped = all.length - surviving.length

// Several lenses can flag the same line: keep one entry per file:line, highest severity, all lenses listed.
const byLocation = new Map()
for (const { votes, survives, ...finding } of surviving) {
  const key = `${finding.file}:${finding.line}`
  const existing = byLocation.get(key)
  if (!existing) {
    byLocation.set(key, { ...finding, lenses: [finding.lens] })
    continue
  }
  existing.lenses.push(finding.lens)
  if (ORDER[finding.severity] < ORDER[existing.severity]) {
    Object.assign(existing, { severity: finding.severity, title: finding.title, scenario: finding.scenario, fix: finding.fix })
  }
}
const confirmed = [...byLocation.values()].sort((a, b) => ORDER[a.severity] - ORDER[b.severity])
log(`${confirmed.length} distinct finding(s) survived verification, ${dropped} refuted`)

return {
  base: BASE,
  changedFiles: scope.files.length,
  lenses: LENSES.map(l => l.key),
  confirmed: confirmed.map(({ lens, ...f }) => f),
  refutedCount: dropped,
}

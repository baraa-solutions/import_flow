export const meta = {
  name: 'audit-endpoints',
  description: 'Audit every FastAPI route in modules/*/router.py for missing or wrong auth dependencies, verify each gap, and return a prioritised fix list',
  whenToUse: 'To measure and plan closing the authentication gap across all routers, or after adding many routes.',
  phases: [
    { title: 'Discover', detail: 'list router files and batch them' },
    { title: 'Audit', detail: 'security-reviewer per batch of routers' },
    { title: 'Verify', detail: 'independent check of every CRITICAL/HIGH gap' },
  ],
}

const BATCH_SIZE = 6

const DISCOVER_SCHEMA = {
  type: 'object',
  required: ['routerFiles', 'globalAuth'],
  properties: {
    routerFiles: { type: 'array', items: { type: 'string' } },
    globalAuth: { type: 'string' },
  },
}

const AUDIT_SCHEMA = {
  type: 'object',
  required: ['routes'],
  properties: {
    routes: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'method', 'path', 'auth', 'risk', 'suggestedDependency'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          method: { type: 'string' },
          path: { type: 'string' },
          auth: { type: 'string', description: 'dependency found, or NONE' },
          risk: { type: 'string', enum: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'OK'] },
          suggestedDependency: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object',
  required: ['confirmed', 'reason'],
  properties: { confirmed: { type: 'boolean' }, reason: { type: 'string' } },
}

phase('Discover')
const discovered = await agent(
  'List every Python file that defines FastAPI routes: all modules/*/router.py plus any other file under modules/ ' +
  'or main.py that declares @router.<method> or @app.<method>. Also report, in globalAuth, whether main.py applies any ' +
  'authentication globally (middleware, FastAPI(dependencies=...), or include_router(..., dependencies=...)) and how.',
  { schema: DISCOVER_SCHEMA, label: 'discover', effort: 'low' },
)
const files = discovered ? discovered.routerFiles : []
const batches = []
for (let i = 0; i < files.length; i += BATCH_SIZE) batches.push(files.slice(i, i + BATCH_SIZE))
log(`${files.length} route files in ${batches.length} batches; global auth: ${discovered ? discovered.globalAuth : 'unknown'}`)

const auditPrompt = batch =>
  'Audit mode. For EVERY route in these files, record method, full path (router prefix + route path), the auth ' +
  'dependency that applies (route-level or router-level) or NONE, the risk, and the dependency to add ' +
  '(an existing permission code from modules/auth/seed_rbac.py PERMISSIONS_CATALOG where one fits, else require_admin, ' +
  `or a new code to add). Mark protected routes with risk OK.\nGlobal auth in main.py: ${discovered.globalAuth}\nFiles:\n${batch.join('\n')}`

const verifyPrompt = route =>
  `Check this claim by reading the code: the route ${route.method} ${route.path} defined at ${route.file}:${route.line} ` +
  'can be called without authentication (no get_current_user / require_admin / require_permission on the route, its ' +
  'APIRouter, its include_router call, or globally in main.py). confirmed=true only if you verified it is unprotected.'

const audited = await pipeline(
  batches,
  (batch, _item, index) => agent(auditPrompt(batch), { agentType: 'security-reviewer', schema: AUDIT_SCHEMA, phase: 'Audit', label: `audit:batch-${index + 1}` }),
  result => parallel((result ? result.routes : []).map(route => () => {
    if (route.risk !== 'CRITICAL' && route.risk !== 'HIGH') return Promise.resolve({ ...route, verified: null })
    return agent(verifyPrompt(route), { schema: VERDICT_SCHEMA, phase: 'Verify', label: `verify:${route.method} ${route.path}`, effort: 'low' })
      .then(v => ({ ...route, verified: v ? v.confirmed : null }))
  })),
)

const routes = audited.filter(Boolean).flat()
const missingBatches = audited.filter(r => !r).length
if (missingBatches) log(`${missingBatches} batch(es) failed and are NOT covered in this report`)

const RANK = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3, OK: 4 }
const gaps = routes
  .filter(r => r.risk !== 'OK' && r.verified !== false)
  .sort((a, b) => RANK[a.risk] - RANK[b.risk] || a.file.localeCompare(b.file))

const count = risk => routes.filter(r => r.risk === risk).length
return {
  totals: {
    routes: routes.length,
    protected: count('OK'),
    critical: count('CRITICAL'),
    high: count('HIGH'),
    medium: count('MEDIUM'),
    low: count('LOW'),
    refutedByVerification: routes.filter(r => r.verified === false).length,
    uncoveredBatches: missingBatches,
  },
  gaps,
}

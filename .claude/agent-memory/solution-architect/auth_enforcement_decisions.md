---
name: auth-enforcement-decisions
description: 2026-09-23 decisions for API-wide authentication (router-level deps, test seam, WS auth protocol, docs flag) and non-obvious facts found while planning it
metadata:
  type: project
---

Decisions (2026-09-23, auth phase 1 plan):
- Auth is enforced with `APIRouter(..., dependencies=[Depends(get_current_user)])` in each router.py, not in
  main.py `include_router`. Exceptions: `modules/auth/router.py` stays per-route (login/refresh public);
  notifications WebSocket lives on a separate `ws_router` with no router deps; main.py inline routes are per-route.
  **Why:** tests mount routers directly on `FastAPI()`; router-level deps protect them too.
  **How to apply:** new routers must declare router-level auth; routers import helpers from `modules.auth.router`
  (existing pattern, no circular import found).
- `ALLOW_DEV_AUTH_BYPASS` is bound at import time into `modules.auth.permissions` (a module global read per call):
  toggle it in tests with `monkeypatch.setattr(modules.auth.permissions, "ALLOW_DEV_AUTH_BYPASS", False)`.
- Test seam: the bypass fallback in `resolve_user` goes through a module-level helper that `tests/conftest.py`
  patches to return a transient ADMIN when the test DB has no users. Many tests override `get_db` with an
  empty in-memory DB, so seeding a single session admin is not enough.
- WebSocket auth uses the first message `{"type":"auth","token":...}` (no token in the URL, which would end up in logs; also works on Flutter web).
  At that time no Flutter WebSocket client existed at all.
- `/docs`, `/redoc`, `/openapi.json` are served only when `ENABLE_API_DOCS=true`. The Flutter liveness probe uses `/health`.
- `.env.example` shipped `ALLOW_DEV_AUTH_BYPASS=true`; with the bypass on, a request with no token resolves to the first ADMIN,
  so it cancels every auth fix. Always check the production `.env` value in auth work.

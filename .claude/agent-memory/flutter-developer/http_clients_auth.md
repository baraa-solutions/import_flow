---
name: http-clients-auth
description: Which Dio clients carry the JWT, the /api/v1 path-doubling trap, and the no_bare_dio guard test
metadata:
  type: project
---

Backend requires `Authorization: Bearer` on all routes except `/`, `/health`, `/api/v1/health`, auth login/refresh,
system version / version-check / download-installer (decided 2026-09, auth enforcement task).

- Only authenticated clients: `dioProvider` / `uploadDioProvider` in `core/network/api_client.dart`.
  `core/network/dio_client.dart` just delegates to them (keep it that way).
- `test/no_bare_dio_test.dart` fails on any `Dio(` in lib/ outside an allow-list (api_client, auth_provider
  login/refresh, main.dart /health probe; the old updater clients were removed 2026-09-24). Add to the
  allow-list only for public routes or non-backend hosts.
- PATH TRAP: dioProvider baseUrl is `$serverUrl/api/v1`; Dio 5 concatenates, so a relative `'/api/v1/x'` becomes
  `/api/v1/api/v1/x`. Use `ApiConstants.xxx` absolute URLs or paths relative to /api/v1.
- Converting a StatefulWidget to ConsumerStatefulWidget to reach `ref` breaks widget tests that pump it without
  `ProviderScope`: wrap them.
- In ConsumerState, `late final Dio _dio = ref.read(dioProvider);` works for field-style clients. Never
  `close()` a shared client in dispose; use a CancelToken.
- Notifier mocks in tests call `super(Dio())` because notifiers take the Dio in the constructor.

**Why:** the auth rollout broke every bare `Dio()` call (401).
**How to apply:** any new HTTP call uses `ref.read(dioProvider)` (JSON) or `ref.read(uploadDioProvider)` (FormData).

Related pitfalls:
- `core/network/api_error.dart` `ApiError.message(e)` / `ApiError.isForbidden(e)`: use them to surface the backend
  `detail` (403 on admin-only routes) in SnackBars instead of `$e`.
- The role comes from the JWT on the backend. Never send `x-user-role` overrides from features.
- SDK / test pitfalls moved to [[flutter-344-pitfalls]].
- No go_router in lib/: auth routing is `AuthGate` (main.dart: Login vs HomeScreen) plus a guard at the top of
  `HomeScreen.build` (`requiresPasswordChange` -> `ForceChangePasswordScreen`, 2026-09-29). New shell-level gates
  go there (or into AuthGate if main.dart edits are allowed), not into a router.
- `403 {"detail": {"code": "PASSWORD_CHANGE_REQUIRED"}}` is caught in both Dio clients
  (`ApiError.isPasswordChangeRequired`) -> `authNotifier.markPasswordChangeRequired()`. Structured
  `{code, message}` details: use `ApiError.message` (returns `message`).

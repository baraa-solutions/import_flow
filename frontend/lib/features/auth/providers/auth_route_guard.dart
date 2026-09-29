import 'auth_provider.dart';

/// Where the signed-in shell must send the user.
enum AuthDestination { login, forcePasswordChange, home }

/// Route guard for the authenticated shell. An account flagged
/// `must_change_password` may only see the password-change screen (and log
/// out) until the backend clears the flag.
AuthDestination resolveAuthDestination(AuthState state) {
  if (!state.isAuthenticated) return AuthDestination.login;
  if (state.user?.mustChangePassword ?? false) return AuthDestination.forcePasswordChange;
  return AuthDestination.home;
}

bool requiresPasswordChange(AuthState state) =>
    resolveAuthDestination(state) == AuthDestination.forcePasswordChange;

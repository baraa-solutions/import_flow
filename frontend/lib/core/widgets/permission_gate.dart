import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/current_permissions_provider.dart';

/// A UI widget that selectively renders its [child] only if the logged-in user
/// possesses the required permission [code] (or matches [anyOf] / [allOf]).
///
/// If permission is denied, it renders the [fallback] widget (defaults to [SizedBox.shrink]).
///
/// Behavior during loading/errors:
/// - "View" actions (ending in `.view`) remain visible while loading/error so read-only screens stay usable.
/// - Mutation actions (edit/manage/delete) are denied by default until permissions are loaded.
class PermissionGate extends ConsumerWidget {
  /// Single permission code required (e.g. `'purchase_orders.manage'`).
  final String? code;

  /// User must have at least one of these permissions.
  final List<String>? anyOf;

  /// User must have all of these permissions.
  final List<String>? allOf;

  /// The widget to display if permitted.
  final Widget child;

  /// The widget to display if not permitted. Defaults to [SizedBox.shrink].
  final Widget? fallback;

  const PermissionGate({
    super.key,
    this.code,
    this.anyOf,
    this.allOf,
    required this.child,
    this.fallback,
  }) : assert(
          code != null || anyOf != null || allOf != null,
          'At least one of code, anyOf, or allOf must be specified.',
        );

  const PermissionGate.any({
    super.key,
    required List<String> codes,
    required this.child,
    this.fallback,
  })  : code = null,
        anyOf = codes,
        allOf = null;

  const PermissionGate.all({
    super.key,
    required List<String> codes,
    required this.child,
    this.fallback,
  })  : code = null,
        anyOf = null,
        allOf = codes;

  bool _isViewAction() {
    if (code != null) return code!.endsWith('.view');
    if (anyOf != null) return anyOf!.every((c) => c.endsWith('.view'));
    if (allOf != null) return allOf!.every((c) => c.endsWith('.view'));
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsAsync = ref.watch(currentPermissionsProvider);

    return permissionsAsync.when(
      data: (permSet) {
        final isAllowed = _evaluatePermission(permSet);
        if (isAllowed) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      loading: () {
        // While loading, view actions stay visible; mutation actions are hidden
        if (_isViewAction()) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
      error: (_, __) {
        // On error, view actions stay visible; mutation actions are hidden
        if (_isViewAction()) {
          return child;
        }
        return fallback ?? const SizedBox.shrink();
      },
    );
  }

  bool _evaluatePermission(PermissionSet permSet) {
    if (code != null && !permSet.can(code!)) {
      return false;
    }
    if (anyOf != null && anyOf!.isNotEmpty && !permSet.canAny(anyOf!)) {
      return false;
    }
    if (allOf != null && allOf!.isNotEmpty && !permSet.canAll(allOf!)) {
      return false;
    }
    return true;
  }
}

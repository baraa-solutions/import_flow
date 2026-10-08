import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'auth_provider.dart';

/// An immutable set of permissions granted to the currently signed-in user.
///
/// If [codes] contains `'*'` or the user is an admin, all permission checks succeed.
@immutable
class PermissionSet {
  final Set<String> codes;

  const PermissionSet([Set<String>? codes]) : codes = codes ?? const <String>{};

  /// Whether the current permission set grants the specified [code].
  ///
  /// Returns `true` if the set contains `'*'` or the exact [code].
  bool can(String code) {
    if (codes.contains('*')) return true;
    return codes.contains(code);
  }

  /// Whether the permission set grants at least one of the specified [codesToCheck].
  bool canAny(Iterable<String> codesToCheck) {
    if (codes.contains('*')) return true;
    return codesToCheck.any(codes.contains);
  }

  /// Whether the permission set grants all of the specified [codesToCheck].
  bool canAll(Iterable<String> codesToCheck) {
    if (codes.contains('*')) return true;
    return codesToCheck.every(codes.contains);
  }

  bool get isEmpty => codes.isEmpty;
  bool get isNotEmpty => codes.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PermissionSet && setEquals(other.codes, codes);
  }

  @override
  int get hashCode => Object.hashAll(codes);

  @override
  String toString() => 'PermissionSet(${codes.toList()})';
}

/// Provider of the signed-in user's effective permissions.
///
/// Fetches `GET /api/v1/auth/me/permissions` and parses `effective_permissions`.
/// Returns an empty [PermissionSet] (deny by default) if not logged in, while loading, or on error.
final currentPermissionsProvider = FutureProvider<PermissionSet>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated || authState.token == null || authState.token!.isEmpty) {
    return const PermissionSet();
  }

  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get(
      ApiConstants.myPermissions,
      options: Options(
        headers: {'Authorization': 'Bearer ${authState.token}'},
      ),
    );

    final data = response.data;
    if (data == null) {
      return const PermissionSet();
    }

    final Map<String, dynamic> jsonMap;
    if (data is Map<String, dynamic>) {
      jsonMap = data;
    } else if (data is Map) {
      jsonMap = Map<String, dynamic>.from(data);
    } else {
      return const PermissionSet();
    }

    final rawList = jsonMap['effective_permissions'];
    if (rawList is List) {
      final set = rawList
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet();

      // If user has ADMIN role, grant wildcard '*' as well
      final roleCode = jsonMap['role_code']?.toString();
      if (roleCode == 'ADMIN') {
        set.add('*');
      }

      return PermissionSet(set);
    }

    return const PermissionSet();
  } catch (e) {
    // Return empty set on network or parse failure (safe deny by default)
    return const PermissionSet();
  }
});

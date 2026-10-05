import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/api_error_text.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Shared feedback helpers for the import-documentation tabs.

/// Full name of the signed-in user (empty when nobody is signed in). The
/// backend derives the audit identity from the login (C3); this value is only
/// sent where a request schema still requires a non-empty name.
String idocCurrentUserName(WidgetRef ref) {
  final user = ref.read(authProvider).user;
  return (user?.fullName ?? '').trim();
}

/// Shows a backend error as a floating red SnackBar. Structured `detail`
/// objects (403/409/400 with `message`) are rendered by [ApiErrorText.of].
void showIdocError(BuildContext context, Object error, {String? title}) {
  if (!context.mounted) return;
  final text = ApiErrorText.of(context.l10n, error);
  final message = (title == null || title.isEmpty) ? text : '$title: $text';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.crimson,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
}

/// Shows a floating success/info SnackBar.
void showIdocMessage(BuildContext context, String message, {Color? color}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color ?? AppTheme.emerald,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Same as [idocCurrentUserName] for code that only has a [BuildContext]
/// (dialogs that are plain `StatefulWidget`s).
String idocCurrentUserNameOf(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  return (container.read(authProvider).user?.fullName ?? '').trim();
}

/// True only for the optimistic-concurrency 409 (`detail.current_version`).
/// Other 409s (final session locked, same user approving twice, duplicate
/// certified session) are plain business errors shown as a message.
bool isIdocVersionConflict(Object? error) {
  if (error is! DioException || error.response?.statusCode != 409) return false;
  final data = error.response?.data;
  if (data is! Map) return false;
  final detail = data['detail'];
  final source = detail is Map ? detail : data;
  return source.containsKey('current_version');
}

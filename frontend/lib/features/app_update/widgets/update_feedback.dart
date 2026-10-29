import 'package:frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_error.dart';

/// User-facing text for an update API error.
///
/// 403 comes from the shared permission check with an English detail, so it
/// is replaced by a localized "no permission" message. Every other error shows
/// the backend `detail` (Arabic, e.g. 409 / 422 / 501 "غير متاح بعد").
String updateErrorText(AppLocalizations l, Object? error) {
  if (ApiError.isForbidden(error)) return l.updateNoPermission;
  final text = ApiError.message(error, fallback: l.updateFailed);
  return text.isEmpty ? l.updateFailed : text;
}

void showUpdateSnackBar(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.showSnackBar(
    AppTheme.snackBar(context, message, severity: AppSeverity.danger),
  );
}

void showUpdateErrorSnackBar(BuildContext context, Object? error) {
  showUpdateSnackBar(context, updateErrorText(context.l10n, error), isError: true);
}

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/po_system_message.dart';

/// Warning SnackBar listing coded backend messages (e.g. OVER_SHIPPED after an allocation).
/// Does nothing when [messages] is empty.
void showPoMessagesSnack(BuildContext context, List<POSystemMessage> messages) {
  if (messages.isEmpty) return;
  final l10n = context.l10n;
  final text = messages.map((m) => m.text(l10n, fallback: m.code)).join('\n');
  ScaffoldMessenger.of(context).showSnackBar(
    AppTheme.snackBar(
      context,
      text,
      severity: AppSeverity.warning,
      duration: const Duration(seconds: 8),
    ),
  );
}

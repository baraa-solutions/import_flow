import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// SnackBar for a coded 409 "a record already exists" (IR_ASSESSMENT_EXISTS,
/// SCENARIO_SESSION_EXISTS): the readable [message] plus an action that opens the
/// existing record. Shared so every module behaves the same.
void showExistingRecordSnack(
  BuildContext context, {
  required String message,
  required String actionLabel,
  required VoidCallback onOpen,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.orange,
      duration: const Duration(seconds: 10),
      action: SnackBarAction(label: actionLabel, textColor: AppTheme.white, onPressed: onOpen),
    ),
  );
}

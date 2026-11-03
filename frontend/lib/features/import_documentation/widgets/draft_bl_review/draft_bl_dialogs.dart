import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// Modal dialog helpers for Draft B/L confirmation prompts.
class DraftBlDialogs {
  static Future<bool> confirmBlockingMismatchSave(
    BuildContext context,
    int discrepanciesCount,
  ) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.idocADraftBlConfirmTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            l.idocADraftBlConfirmBody(discrepanciesCount),
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            AppButton(
              label: l.cancel,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            AppButton(
              label: l.idocADraftBlConfirmAction,
              variant: AppButtonVariant.danger,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    return confirmed == true;
  }
}

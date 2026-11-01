import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';

/// Confirmation dialog for gap percentage when extracting clearance quotes
class ExtractorGapDialog {
  static Future<bool> confirmGapIfRequired(
    BuildContext context,
    AppLocalizations l10n,
    Map<String, dynamic>? result,
  ) async {
    final valReport = result?['validation_report'] as Map<String, dynamic>?;
    if (valReport?['requires_modal_confirmation'] != true) return true;
    final expCount = valReport?['expected_item_count'] ?? valReport?['expected_count'] ?? 0;
    final extCount = valReport?['extracted_item_count'] ?? valReport?['extracted_count'] ?? 0;
    final gap = (valReport?['gap_percentage'] as num?)?.toDouble() ?? 0.0;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (modalCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.crimson, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.quotationValidationConfirmTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.crimson),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.quotationValidationConfirmMessage(expCount, extCount, gap.toStringAsFixed(1)),
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          AppButton(
            label: l10n.quotationValidationReviewBtn,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(modalCtx, false),
          ),
          AppButton(
            label: l10n.quotationValidationProceedBtn,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.small,
            onPressed: () => Navigator.pop(modalCtx, true),
          ),
        ],
      ),
    );
    return proceed == true;
  }
}

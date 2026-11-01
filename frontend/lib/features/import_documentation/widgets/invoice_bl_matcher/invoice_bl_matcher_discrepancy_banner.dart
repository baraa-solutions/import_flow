import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../idoc_ui.dart';

/// Discrepancy banner component for Screen 22: Invoice vs B/L Matcher.
///
/// Displays tolerance checks, critical variance warnings, mismatch alerts,
/// and the carrier amendment / correction letter generator card.
class InvoiceBlMatcherDiscrepancyBanner extends StatelessWidget {
  final Map<String, dynamic> matchResult;
  final VoidCallback? onRequestCarrierAmendment;

  const InvoiceBlMatcherDiscrepancyBanner({
    super.key,
    required this.matchResult,
    this.onRequestCarrierAmendment,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final criticalCount = (matchResult['critical_discrepancies_count'] as num?)?.toInt() ?? 0;
    final warningCount = (matchResult['warning_discrepancies_count'] as num?)?.toInt() ?? 0;
    final isSafe = matchResult['is_safe_for_certification'] == true;
    final correctionLetter = (matchResult['correction_letter'] ?? '').toString().trim();

    final hasDiscrepancies = criticalCount > 0 || warningCount > 0 || !isSafe;

    if (!hasDiscrepancies && correctionLetter.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasDiscrepancies) ...[
          _buildDiscrepancyAlertBanner(context, criticalCount, warningCount, isSafe),
          const SizedBox(height: 14),
        ],
        if (correctionLetter.isNotEmpty) ...[
          _buildCorrectionLetterCard(context, correctionLetter, l),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildDiscrepancyAlertBanner(BuildContext context, int criticalCount, int warningCount, bool isSafe) {
    final l = context.l10n;
    final Color bannerColor = criticalCount > 0 ? AppTheme.crimson : AppTheme.orange;
    final IconData icon = criticalCount > 0 ? Icons.error_outline : Icons.warning_amber_rounded;

    final String title = criticalCount > 0
        ? l.invoiceBlMatcherStatusCriticalTitle
        : l.invoiceBlMatcherStatusSafeTitle;

    final String message = criticalCount > 0
        ? l.invoiceBlMatcherStatusCriticalDesc(criticalCount)
        : l.invoiceBlMatcherStatusSafeDesc;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: bannerColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: bannerColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          if (onRequestCarrierAmendment != null && criticalCount > 0) ...[
            const SizedBox(width: 12),
            IdocUi.fit(AppButton(
              label: l.invoiceBlMatcherCorrectionLetterTitle,
              icon: Icons.mark_email_unread_outlined,
              variant: AppButtonVariant.warning,
              size: AppButtonSize.small,
              onPressed: onRequestCarrierAmendment,
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrectionLetterCard(BuildContext context, String letter, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.severityBackgroundOf(context, AppSeverity.warning),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_outlined, color: AppTheme.orange, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.invoiceBlMatcherCorrectionLetterTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                ),
              ),
              IdocUi.fit(AppButton(
                label: l.invoiceBlMatcherCopyLetterButton,
                icon: Icons.copy,
                variant: AppButtonVariant.warning,
                size: AppButtonSize.small,
                onPressed: () {
                  CopyHelper.copy(
                    context,
                    letter,
                    customMessage: l.invoiceBlMatcherLetterCopiedSuccess,
                  );
                },
              )),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.severityForegroundOf(context, AppSeverity.warning)
                    : AppTheme.orange,
              ),
            ),
            child: SelectableText(
              letter,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

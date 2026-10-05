import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../customs_clearance/widgets/customs_ui.dart';

/// Banner under the smart extractor result: expected / extracted counts, gap
/// percentage and the coded / range / multi-value / outside-table badges.
/// Severity (safe / warning / critical) comes from the backend report.
class QuotationValidationBanner extends StatelessWidget {
  const QuotationValidationBanner({
    super.key,
    required this.valReport,
    required this.expensesCatalog,
  });

  final Map<String, dynamic>? valReport;
  final List<dynamic>? expensesCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final report = valReport;
    final catalog = expensesCatalog;
    if (report == null && (catalog == null || catalog.isEmpty)) {
      return const SizedBox.shrink();
    }

    final bannerStatus = report?['banner_status']?.toString() ?? 'safe';
    final expectedCount = report?['expected_item_count'] ?? report?['expected_count'] ?? catalog?.length ?? 0;
    final extractedCount = report?['extracted_item_count'] ?? report?['extracted_count'] ?? catalog?.length ?? 0;
    final codedCount = (report?['coded_items_count'] as num?)?.toInt() ?? 0;
    final uncodedCount = (report?['uncoded_items_count'] as num?)?.toInt() ?? 0;
    final gapPct = (report?['gap_percentage'] as num?)?.toDouble() ?? 0.0;
    final multiSplitCount = (report?['multi_value_items_count'] as num?)?.toInt() ?? 0;
    final rangeCount = (report?['range_items_count'] as num?)?.toInt() ?? 0;
    final outsideCount = (report?['outside_table_items_count'] as num?)?.toInt() ?? 0;

    final isCritical = bannerStatus == 'critical';
    final isWarning = bannerStatus == 'warning';
    final severity = isCritical
        ? AppSeverity.danger
        : (isWarning ? AppSeverity.warning : AppSeverity.success);
    final fg = AppTheme.severityForegroundOf(context, severity);
    final bg = AppTheme.severityBackgroundOf(context, severity);

    final IconData icon = isCritical
        ? Icons.error_outline_rounded
        : (isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded);
    final String title = isCritical
        ? l10n.quotationValidationBannerCriticalTitle
        : (isWarning ? l10n.quotationValidationBannerWarningTitle : l10n.quotationValidationBannerSafeTitle);
    final message = l10n.isArabic
        ? (report?['message_ar']?.toString() ?? title)
        : (report?['message_en']?.toString() ?? title);

    void copyReport() {
      final buffer = StringBuffer();
      buffer.writeln('=== ${l10n.quotationValidationCopyReportBtn} ===');
      buffer.writeln(l10n.quotationValidationExpectedCount(expectedCount));
      buffer.writeln(l10n.quotationValidationExtractedCount(extractedCount));
      buffer.writeln(l10n.quotationValidationGapPercentage(gapPct.toStringAsFixed(1)));
      buffer.writeln('$title: $message');
      if (multiSplitCount > 0) {
        buffer.writeln('- $multiSplitCount ${l10n.quotationValidationMultiValueBadge}');
      }
      if (rangeCount > 0) {
        buffer.writeln('- $rangeCount ${l10n.quotationValidationRangeBadge}');
      }
      if (outsideCount > 0) {
        buffer.writeln('- $outsideCount ${l10n.quotationValidationOutsideTableBadge}');
      }
      CopyHelper.copy(context, buffer.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          l10n.quotationValidationReportCopiedToast,
          severity: AppSeverity.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12),
      padding: const EdgeInsetsDirectional.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: fg, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: fg),
                ),
              ),
              AppButton(
                label: l10n.quotationValidationCopyReportBtn,
                icon: Icons.copy_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: copyReport,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(fontSize: 11.5, color: fg.withValues(alpha: 0.9))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CcStatusChip(
                label: l10n.quotationValidationExpectedCount(expectedCount),
                severity: AppSeverity.info,
              ),
              CcStatusChip(
                label: l10n.quotationValidationExtractedCount(extractedCount),
                severity: AppSeverity.info,
              ),
              CcStatusChip(
                label: l10n.quotationValidationGapPercentage(gapPct.toStringAsFixed(1)),
                severity: severity,
              ),
              if (codedCount > 0)
                CcStatusChip(label: l10n.ccqCodedItemsBadge(codedCount), severity: AppSeverity.info),
              if (uncodedCount > 0)
                CcStatusChip(label: l10n.ccqUncodedItemsBadge(uncodedCount), severity: AppSeverity.danger),
              if (multiSplitCount > 0)
                CcStatusChip(
                  label: '$multiSplitCount ${l10n.quotationValidationMultiValueBadge}',
                  severity: AppSeverity.warning,
                ),
              if (rangeCount > 0)
                CcStatusChip(
                  label: '$rangeCount ${l10n.quotationValidationRangeBadge}',
                  severity: AppSeverity.info,
                  icon: Icons.bolt,
                ),
              if (outsideCount > 0)
                CcStatusChip(
                  label: '$outsideCount ${l10n.quotationValidationOutsideTableBadge}',
                  severity: AppSeverity.info,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

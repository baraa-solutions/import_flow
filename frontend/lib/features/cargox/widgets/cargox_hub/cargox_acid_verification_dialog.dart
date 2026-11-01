import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../models/cargox_model.dart';

/// Modal dialog presenting ACID consistency validation results.
class CargoXAcidVerificationDialog extends StatelessWidget {
  final CargoXAcidVerificationReportModel report;

  const CargoXAcidVerificationDialog({
    super.key,
    required this.report,
  });

  static Future<void> show(BuildContext context, CargoXAcidVerificationReportModel report) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CargoXAcidVerificationDialog(report: report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return SelectionArea(
      child: Dialog(
        backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      report.allMatched ? Icons.verified : Icons.warning_amber,
                      color: report.allMatched ? AppTheme.emerald : AppTheme.crimson,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.cargoxAcidReportDialogTitle(report.envelopeCode),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.cargoxTargetAcidLabel(report.targetAcidNumber),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.cargoxMatchRatioLabel(report.verifiedCount, report.totalDocuments),
                  style: const TextStyle(fontSize: 12),
                ),
                const Divider(),
                ...report.items.map((item) => ListTile(
                      dense: true,
                      leading: Icon(
                        item.isMatched ? Icons.check_circle : Icons.cancel,
                        color: item.isMatched ? AppTheme.emerald : AppTheme.crimson,
                        size: 18,
                      ),
                      title: Text(
                        item.docType,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      subtitle: Text(item.notes ?? '', style: const TextStyle(fontSize: 11)),
                    )),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AppButton(
                    label: context.l10n.close,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

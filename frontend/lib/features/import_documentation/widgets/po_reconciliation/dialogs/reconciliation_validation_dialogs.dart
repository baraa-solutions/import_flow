import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/display_name_resolver.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/buttons/app_button.dart';
import '../../../../import_files/models/import_file_model.dart';
import '../../../models/po_reconciliation_session_model.dart';
import '../../idoc_ui.dart';

/// Validation and success confirmation dialogs for PO reconciliation.
class ReconciliationValidationDialogs {
  static void showInputValidationDialog(
    BuildContext context, {
    required String title,
    required List<String> issues,
    required List<String> recommendations,
  }) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.poRecInputValidationDesc,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.danger),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.crimsonBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: issues
                        .map((issue) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.cancel, color: AppTheme.crimson, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(issue, style: const TextStyle(fontSize: 12.5, color: AppTheme.crimson)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Text(l.poRecInputValidationRecHeader, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recommendations
                        .map((rec) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.check_circle, color: AppTheme.emerald, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(rec, style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary)),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.poRecInputValidationGotIt,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx),
            )),
          ],
        ),
      ),
    );
  }

  static void showSaveSuccessReportDialog(
    BuildContext context,
    POReconciliationSessionModel sess, {
    required List<ImportFileModel> importFiles,
    required VoidCallback onPrintReport,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final rawFileCode = sess.importFileCode ?? 'IMP-${sess.importFileId}';
    final shipmentTitle = rawFileCode.isNotEmpty
        ? DisplayNameResolver.resolveShipmentTitleByCode(rawFileCode, shipments: importFiles, isArabic: isAr)
        : '';
    final fileDisplay = shipmentTitle.isNotEmpty && shipmentTitle != rawFileCode
        ? '$shipmentTitle ($rawFileCode)'
        : (rawFileCode.isNotEmpty ? rawFileCode : 'N/A');

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.emerald, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.poRecHistorySavedDialogTitle(sess.sessionCode),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${l.poRecImportFileLabel}: $fileDisplay - ${sess.importerName ?? "N/A"}'),
                const SizedBox(height: 6),
                Text(
                  '${l.poRecFinalInvoiceNoLabel}: ${sess.finalInvoiceNumber ?? "N/A"} | ${l.poRecFinalPackingListNoLabel}: ${sess.finalPackingListNumber ?? "N/A"}',
                ),
                const SizedBox(height: 6),
                Text(
                  '${l.poRecKpiTotalInvoice}: ${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency} | ${l.poRecKpiTotalPackages}: ${sess.totalPackages.toStringAsFixed(0)} | ${l.poRecKpiTotalCbm}: ${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.severityBackgroundOf(context, AppSeverity.success),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.emeraldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: AppTheme.emerald, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.poRecHistorySavedUniqueNotice,
                          style: const TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.close,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(dialogCtx),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecHistoryCopyReportButton,
              icon: Icons.print_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () {
                Navigator.pop(dialogCtx);
                onPrintReport();
              },
            )),
          ],
        ),
      ),
    );
  }

  static Future<bool?> showVarianceAlertConfirmDialog(BuildContext context) {
    final l = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 24),
              const SizedBox(width: 8),
              Text(l.poRecVarianceAlertTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            l.poRecVarianceAlertContent,
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
          actions: [
            IdocUi.fit(AppButton(
              label: l.poRecCancelAndReview,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.pop(ctx, false),
            )),
            IdocUi.fit(AppButton(
              label: l.poRecConfirmCertifyButton,
              icon: Icons.verified,
              variant: AppButtonVariant.success,
              onPressed: () => Navigator.pop(ctx, true),
            )),
          ],
        ),
      ),
    );
  }
}

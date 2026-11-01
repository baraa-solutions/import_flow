import 'package:flutter/material.dart';

import '../../../../../core/widgets/widgets.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/display_name_resolver.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../import_files/models/import_file_model.dart';
import '../../../../purchase_orders/utils/po_packing_matcher.dart';
import '../../../models/po_reconciliation_session_model.dart';
import '../../idoc_ui.dart';

/// Print and export preview dialog for PO reconciliation reports.
class ReconciliationPrintReportDialog {
  static void show(
    BuildContext context,
    POReconciliationSessionModel sess, {
    required List<ImportFileModel> importFiles,
    required String Function(BuildContext context, String status) getLocalizedSessionStatus,
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

    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln(l.poRecReportTitle);
    buffer.writeln('${l.poRecReportSessionCode}: ${sess.sessionCode}');
    buffer.writeln('${l.poRecReportImportFile}: $fileDisplay | ${l.poRecReportImporter}: ${sess.importerName ?? "N/A"}');
    buffer.writeln('${l.poRecReportShipper}: ${sess.shipperName ?? "N/A"} | ${l.poRecReportAcid}: ${sess.acidNumber ?? "N/A"}');
    buffer.writeln(
      '${l.poRecReportInvoiceNo}: ${sess.finalInvoiceNumber ?? "N/A"} | ${l.poRecReportPackingNo}: ${sess.finalPackingListNumber ?? "N/A"}',
    );
    buffer.writeln('${l.poRecReportTotalValue}: ${sess.totalInvoiceAmount.toStringAsFixed(2)} ${sess.currency}');
    buffer.writeln(
      '${l.poRecReportPackages}: ${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit} | ${l.poRecReportGrossWeight}: ${PoPackingMatcher.formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit} | ${l.poRecReportNetWeight}: ${PoPackingMatcher.formatWeight(sess.totalNetWeightKg)} ${l.poRecKgUnit}',
    );
    buffer.writeln('${l.poRecReportTotalCbm}: ${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}');
    buffer.writeln(
      '${l.poRecReportOverallStatus}: ${getLocalizedSessionStatus(context, sess.overallStatus)} | ${l.poRecReportCertifiedBy}: ${sess.certifiedBy ?? "N/A"}',
    );
    buffer.writeln('================================================================\n');
    buffer.writeln(l.poRecReportCsvHeader);

    if (sess.reconciledInvoiceItems != null) {
      for (var itm in sess.reconciledInvoiceItems!) {
        final map = itm as Map<String, dynamic>;
        buffer.writeln(
          '"${map['item_code']}","${map['description']}","${map['hs_code'] ?? ''}",${map['final_quantity']},${map['final_unit_price']},${map['total_amount'] ?? 0.0},${map['final_packages_count'] ?? 1.0},${map['final_gross_weight_kg'] ?? 0.0},${map['final_net_weight_kg'] ?? 0.0},${map['final_cbm'] ?? 0.0}',
        );
      }
    }

    if (sess.reconciledPackingItems != null && sess.reconciledPackingItems!.isNotEmpty) {
      buffer.writeln('\n================================================================');
      buffer.writeln(l.poRecHistoryDetailsCertifiedPackingTitle);
      buffer.writeln('"Item Code","Package Type","Packages","Gross Wt (kg)","Net Wt (kg)","CBM (m³)"');
      for (var itm in sess.reconciledPackingItems!) {
        final map = itm as Map<String, dynamic>;
        buffer.writeln(
          '"${map['item_code']}","${map['package_type'] ?? ''}",${map['final_packages_count'] ?? 0},${map['final_gross_weight_kg'] ?? 0},${map['final_net_weight_kg'] ?? 0},${map['final_cbm'] ?? 0}',
        );
      }
      buffer.writeln('----------------------------------------------------------------');
      buffer.writeln(
        'TOTAL PACKAGES: ${sess.totalPackages.toStringAsFixed(0)} ${l.poRecPackagesUnit} | TOTAL GROSS WT: ${PoPackingMatcher.formatWeight(sess.totalGrossWeightKg)} ${l.poRecKgUnit} | TOTAL NET WT: ${PoPackingMatcher.formatWeight(sess.totalNetWeightKg)} ${l.poRecKgUnit} | TOTAL CBM: ${sess.totalCbm.toStringAsFixed(3)} ${l.poRecCbmUnit}',
      );
    }

    final reportText = buffer.toString();

    showDialog(
      context: context,
      builder: (dialogCtx) => SelectionArea(
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.print_rounded, color: AppTheme.cobalt, size: 24),
              const SizedBox(width: 8),
              Text(l.poRecReportPreviewTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 400,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderOf(context)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  reportText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
                ),
              ),
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
              icon: Icons.copy_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () {
                CopyHelper.copy(context, reportText, customMessage: l.poRecHistoryPrintCopiedSuccess);
                Navigator.pop(dialogCtx);
              },
            )),
          ],
        ),
      ),
    );
  }
}

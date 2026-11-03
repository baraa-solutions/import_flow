import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/widgets/widgets.dart';
import '../idoc_ui.dart';

/// Bottom actions bar for PO Reconciliation.
/// Contains Save Session / Draft, Certify / Approve, and Export Discrepancy Report via FileSaveHelper.
class PoReconciliationActionsBar extends StatelessWidget {
  final bool isSavingSession;
  final bool isSubmitting;
  final bool hasActiveSession;
  final VoidCallback onSaveSession;
  final VoidCallback onCertify;
  final VoidCallback? onReset;
  final String? importFileNameOrCode;
  final Map<String, dynamic>? discrepancyData;

  const PoReconciliationActionsBar({
    super.key,
    required this.isSavingSession,
    required this.isSubmitting,
    required this.hasActiveSession,
    required this.onSaveSession,
    required this.onCertify,
    this.onReset,
    this.importFileNameOrCode,
    this.discrepancyData,
  });

  Future<void> _exportDiscrepancyReport(BuildContext context) async {
    final l = context.l10n;
    final buffer = StringBuffer();
    buffer.writeln('================================================================');
    buffer.writeln(l.poRecReportTitle);
    buffer.writeln('${l.poRecImportFileLabel}: ${importFileNameOrCode ?? "N/A"}');

    if (discrepancyData != null) {
      final overallStatus = discrepancyData!['overall_status']?.toString() ?? 'N/A';
      final crit = discrepancyData!['critical_discrepancies_count']?.toString() ?? '0';
      final warn = discrepancyData!['warning_discrepancies_count']?.toString() ?? '0';
      buffer.writeln('${l.status}: $overallStatus');
      buffer.writeln('Critical Discrepancies: $crit | Warnings: $warn');
      buffer.writeln('================================================================\n');

      final headers = [
        l.poRecColCheckItem,
        context.l10n.idocAColSystemValueInvoice,
        context.l10n.idocAColSystemValuePacking,
        context.l10n.idocAColUploadedValueInvoice,
        context.l10n.idocAColUploadedValuePacking,
        l.poRecColMatchStatus,
        l.poRecColDetails,
      ];
      buffer.writeln(headers.map((h) => '"$h"').join(','));

      final list = discrepancyData!['header_discrepancies'] as List<dynamic>? ?? [];
      for (var d in list) {
        if (d is Map) {
          final row = [
            d['field_name'] ?? '',
            d['system_invoice_value'] ?? d['system_value'] ?? '',
            d['system_packing_value'] ?? d['system_value'] ?? '',
            d['uploaded_invoice_value'] ?? d['extracted_value'] ?? '',
            d['uploaded_packing_value'] ?? d['extracted_value'] ?? '',
            d['status'] ?? '',
            d['details'] ?? d['message'] ?? '',
          ];
          buffer.writeln(row.map((c) => '"$c"').join(','));
        }
      }
    }

    final bytes = utf8.encode(buffer.toString());
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: 'PO_Reconciliation_Discrepancy_Report',
      importFileNameOrCode: importFileNameOrCode ?? 'Report',
      extension: 'csv',
      showNotification: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onReset != null)
          IdocUi.fit(AppButton(
            label: l.poRecResetToOriginalValuesButton,
            icon: Icons.restart_alt,
            variant: AppButtonVariant.secondary,
            onPressed: onReset,
          )),
        if (discrepancyData != null)
          IdocUi.fit(AppButton(
            label: l.tableExportCsv,
            icon: Icons.file_download_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => _exportDiscrepancyReport(context),
          )),
        IdocUi.fit(AppButton(
          label: hasActiveSession ? l.poRecUpdateSessionButton : l.poRecSaveSessionButton,
          icon: Icons.save_rounded,
          variant: AppButtonVariant.success,
          isLoading: isSavingSession,
          onPressed: isSavingSession ? null : onSaveSession,
        )),
        IdocUi.fit(AppButton(
          label: l.poRecCertifyFinalDataButton,
          icon: Icons.verified,
          variant: AppButtonVariant.primary,
          isLoading: isSubmitting,
          onPressed: isSubmitting ? null : onCertify,
        )),
      ],
    );
  }
}

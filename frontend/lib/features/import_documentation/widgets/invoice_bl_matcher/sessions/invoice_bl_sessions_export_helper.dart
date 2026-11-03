import 'package:flutter/material.dart';
import '../../../../../core/helpers/table_copy_helper.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/table_export_service.dart';
import '../../../models/invoice_bl_match_session_model.dart';

class InvoiceBlSessionsExportHelper {
  const InvoiceBlSessionsExportHelper._();

  static void copySessionsTable(BuildContext context, List<InvoiceBLMatchSessionModel> sessions) {
    final headers = [
      context.l10n.idocASessionCode,
      context.l10n.idocAImportFile,
      context.l10n.idocATitle,
      context.l10n.status,
      context.l10n.idocAMatchScore,
      context.l10n.idocADiscrepancies,
      context.l10n.idocACreatedAt,
      context.l10n.idocABy,
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
      s.createdBy ?? '—',
    ]).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: context.l10n.idocAMatchingSessionsTableCopiedToThe,
    );
  }

  static Future<void> exportSessionsToExcel(
    BuildContext context,
    List<InvoiceBLMatchSessionModel> sessions, {
    int? activeFileId,
  }) async {
    final headers = [
      context.l10n.idocASessionCode,
      context.l10n.idocAImportFile,
      context.l10n.idocATitle,
      context.l10n.status,
      context.l10n.idocAMatchScore,
      context.l10n.idocADiscrepancies,
      context.l10n.idocACreatedAt,
      context.l10n.idocABy,
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
      s.createdBy ?? '—',
    ]).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      headers: headers,
      rows: rows,
      stageName: 'Invoice BL Match Sessions',
      importFileNameOrCode: activeFileId != null ? 'IMP-$activeFileId' : 'All-Files',
    );
  }

  static Future<void> exportSessionsToPdf(
    BuildContext context,
    List<InvoiceBLMatchSessionModel> sessions, {
    int? activeFileId,
  }) async {
    final headers = [
      context.l10n.idocASessionCode,
      context.l10n.idocAImportFile,
      context.l10n.idocATitle,
      context.l10n.status,
      context.l10n.idocAMatchScore,
      context.l10n.idocADiscrepancies,
      context.l10n.idocACreatedAt,
    ];
    final rows = sessions.map((s) => [
      s.sessionCode,
      s.importFileCode ?? 'IMP-${s.importFileId}',
      s.sessionTitle ?? s.sessionNotes ?? '—',
      s.isDraft ? context.l10n.idocADraft : context.l10n.idocACertified,
      '${s.matchScore.toStringAsFixed(1)}%',
      s.discrepancyCount.toString(),
      s.createdAt,
    ]).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      headers: headers,
      rows: rows,
      stageName: context.l10n.idocAInvoiceAndBLMatchingSessions,
      importFileNameOrCode: activeFileId != null ? 'IMP-$activeFileId' : 'All-Files',
      headerContext: TableExportHeaderContext(
        title: context.l10n.idocACommercialInvoiceAndBillOfLading,
        subtitle: context.l10n.idocAFooterMatchingBrand,
      ),
    );
  }
}

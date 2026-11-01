import 'package:flutter/material.dart';

import '../../../../core/widgets/copyable_data_helper.dart';
import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/table_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../import_files/models/import_file_model.dart';
import '../../models/file_closure_model.dart';

/// Export, copy TSV and report helpers for File Closure Screen
class ClosureExportHelper {
  static void copyClosureRowTsv(
    BuildContext context,
    ImportFileClosureModel r,
    ImportFileModel? file,
    AppLocalizations l10n,
  ) {
    final fileTitle = file != null ? file.primaryNameWithCode : '#${r.importFileId}';
    final chk = r.closureChecklist;
    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
      l10n.fileClosureColNotes,
    ];
    final values = [
      r.closureCode,
      fileTitle,
      r.archiveLocation,
      r.auditorName,
      r.closedAt,
      chk.docsVerified ? '100%' : '0%',
      chk.customsCleared ? '100%' : '0%',
      chk.warehouseReceived ? '100%' : '0%',
      chk.landedCostSettled ? '100%' : '0%',
      chk.tasksClosed ? '100%' : '0%',
      r.archivalNotes ?? '',
    ];

    TableCopyHelper.copyRow(
      context,
      values,
      headers: headers,
      customMessage: l10n.copyFileClosureRowSuccess,
    );
  }

  static void copyArchivedFilesTsv(
    BuildContext context,
    List<ImportFileClosureModel> records,
    Map<int, ImportFileModel> filesMap,
  ) {
    final l10n = context.l10n;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.fileClosureEmptyRecords, severity: AppSeverity.warning),
      );
      return;
    }

    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
      l10n.fileClosureColNotes,
    ];

    final rows = records.map((r) {
      final matchingFile = filesMap[r.importFileId];
      final fileTitle = matchingFile != null ? matchingFile.primaryNameWithCode : '#${r.importFileId}';
      final chk = r.closureChecklist;
      return [
        r.closureCode,
        fileTitle,
        r.archiveLocation,
        r.auditorName,
        r.closedAt,
        chk.docsVerified ? '100%' : '0%',
        chk.customsCleared ? '100%' : '0%',
        chk.warehouseReceived ? '100%' : '0%',
        chk.landedCostSettled ? '100%' : '0%',
        chk.tasksClosed ? '100%' : '0%',
        r.archivalNotes ?? '',
      ];
    }).toList();

    TableCopyHelper.copyTable(
      context,
      headers,
      rows,
      customMessage: l10n.copyFileClosureTableSuccess,
    );
  }

  static Future<void> exportClosuresExcel(
    BuildContext context,
    List<ImportFileClosureModel> records,
    Map<int, ImportFileModel> filesMap,
  ) async {
    final l10n = context.l10n;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.fileClosureEmptyRecords, severity: AppSeverity.warning),
      );
      return;
    }

    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
      l10n.fileClosureColNotes,
    ];

    final rows = records.map((r) {
      final matchingFile = filesMap[r.importFileId];
      final fileTitle = matchingFile != null ? matchingFile.primaryNameWithCode : '#${r.importFileId}';
      final chk = r.closureChecklist;
      return [
        r.closureCode,
        fileTitle,
        r.archiveLocation,
        r.auditorName,
        r.closedAt,
        chk.docsVerified ? '100%' : '0%',
        chk.customsCleared ? '100%' : '0%',
        chk.warehouseReceived ? '100%' : '0%',
        chk.landedCostSettled ? '100%' : '0%',
        chk.tasksClosed ? '100%' : '0%',
        r.archivalNotes ?? '',
      ];
    }).toList();

    await TableExportService.exportTableToExcel(
      context: context,
      stageName: 'File Closure & Archival',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  static Future<void> exportClosuresPdf(
    BuildContext context,
    List<ImportFileClosureModel> records,
    Map<int, ImportFileModel> filesMap,
  ) async {
    final l10n = context.l10n;
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(context, l10n.fileClosureEmptyRecords, severity: AppSeverity.warning),
      );
      return;
    }

    final headers = [
      l10n.fileClosureColClosureCode,
      l10n.fileClosureColImportFile,
      l10n.fileClosureColArchiveVault,
      l10n.fileClosureColAuditor,
      l10n.fileClosureColClosedDate,
      l10n.fileClosureColDocsVerified,
      l10n.fileClosureColCustomsCleared,
      l10n.fileClosureColWarehouseReceived,
      l10n.fileClosureColLandedCostSettled,
      l10n.fileClosureColTasksClosed,
    ];

    final rows = records.map((r) {
      final matchingFile = filesMap[r.importFileId];
      final fileTitle = matchingFile != null ? matchingFile.primaryNameWithCode : '#${r.importFileId}';
      final chk = r.closureChecklist;
      return [
        r.closureCode,
        fileTitle,
        r.archiveLocation,
        r.auditorName,
        r.closedAt,
        chk.docsVerified ? '100%' : '0%',
        chk.customsCleared ? '100%' : '0%',
        chk.warehouseReceived ? '100%' : '0%',
        chk.landedCostSettled ? '100%' : '0%',
        chk.tasksClosed ? '100%' : '0%',
      ];
    }).toList();

    await TableExportService.exportTableToPdf(
      context: context,
      stageName: 'File Closure & Archival',
      importFileNameOrCode: 'Registry',
      headers: headers,
      rows: rows,
    );
  }

  static void copySingleCertificateSummary(
    BuildContext context,
    ImportFileClosureModel r,
    ImportFileModel? file,
  ) {
    final l10n = context.l10n;
    final fileTitle = file != null ? file.primaryNameWithCode : '#${r.importFileId}';
    final chk = r.closureChecklist;

    final buffer = StringBuffer();
    buffer.writeln('=== ${l10n.fileClosureCertificateDialogTitle(r.closureCode)} ===');
    buffer.writeln('${l10n.fileClosureColClosureCode}: ${r.closureCode}');
    buffer.writeln('${l10n.fileClosureColImportFile}: $fileTitle');
    buffer.writeln('${l10n.fileClosureColArchiveVault}: ${r.archiveLocation}');
    buffer.writeln('${l10n.fileClosureColAuditor}: ${r.auditorName}');
    buffer.writeln('${l10n.fileClosureColClosedDate}: ${r.closedAt}');
    buffer.writeln('--- ${l10n.fileClosureChecklistHeader} ---');
    buffer.writeln('• ${l10n.fileClosureChecklistDocsOriginals}: ${chk.docsVerified ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistCustomsCleared}: ${chk.customsCleared ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistWarehouseGrn}: ${chk.warehouseReceived ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistLandedCost}: ${chk.landedCostSettled ? "100%" : "0%"}');
    buffer.writeln('• ${l10n.fileClosureChecklistTasksClosed}: ${chk.tasksClosed ? "100%" : "0%"}');
    if (r.archivalNotes != null && r.archivalNotes!.isNotEmpty) {
      buffer.writeln('${l10n.fileClosureColNotes}: ${r.archivalNotes!}');
    }

    CopyHelper.copy(
      context,
      buffer.toString().trimRight(),
      customMessage: l10n.fileClosurePrintSuccess(r.closureCode),
    );
  }
}

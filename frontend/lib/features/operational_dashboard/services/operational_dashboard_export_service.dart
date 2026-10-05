import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';

/// Row representation of a shipment for dashboard reports (Task D integrated)
class OperationalDashboardReportRow {
  final String shipmentName;
  final String shipmentTitle;
  final String importFileCode;
  final String customFileNumber;
  final String companyName;
  final String supplierName;
  final String priority;
  final String currentPhase;
  final String operationalStep;
  final String brokerName;
  final String poNumber;
  final double progressPercent;
  final String nextAction;
  final String status;

  const OperationalDashboardReportRow({
    required this.shipmentName,
    required this.shipmentTitle,
    required this.importFileCode,
    required this.customFileNumber,
    required this.companyName,
    required this.supplierName,
    required this.priority,
    required this.currentPhase,
    required this.operationalStep,
    required this.brokerName,
    required this.poNumber,
    required this.progressPercent,
    required this.nextAction,
    required this.status,
  });

  static OperationalDashboardReportRow fromImportFile(
    ImportFileModel file,
    AppLocalizations l,
    bool isArabic,
  ) {
    String priorityText;
    switch (file.priority) {
      case 'Low':
        priorityText = l.priorityLow;
        break;
      case 'Medium':
        priorityText = l.priorityMedium;
        break;
      case 'High':
        priorityText = l.priorityHigh;
        break;
      case 'Critical':
        priorityText = l.priorityCritical;
        break;
      default:
        priorityText = file.priority;
    }

    final resolvedShipmentName = DisplayNameResolver.resolveShipmentName(file, isArabic: isArabic);
    final resolvedShipmentTitle = DisplayNameResolver.resolveShipmentTitle(file, isArabic: isArabic, includeCodeSecondary: true);
    final resolvedPhase =
        file.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: isArabic);
    final resolvedStep = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isArabic);
    final resolvedNextAction =
        (file.nextActionCode != null || file.nextAction.isNotEmpty) ? file.displayNextAction(l, forExport: true) : '-';

    return OperationalDashboardReportRow(
      shipmentName: resolvedShipmentName,
      shipmentTitle: resolvedShipmentTitle,
      importFileCode: file.importFileCode,
      customFileNumber: file.customFileNumber ?? '-',
      companyName: file.companyName,
      supplierName: file.supplierName,
      priority: priorityText,
      currentPhase: resolvedPhase,
      operationalStep: resolvedStep,
      brokerName: file.brokerName ?? l.unassigned,
      poNumber: file.poNumber ?? '-',
      progressPercent: file.progressPercent,
      nextAction: resolvedNextAction,
      status: file.status == 'Closed' ? l.statusClosed : l.statusOpen,
    );
  }
}

/// Unified Export & Dossier Service for Operational Workspace Dashboard (Screen 0)
class OperationalDashboardExportService {
  static String _clean(String val) {
    return val.replaceAll('\t', ' ').replaceAll('\r', '').replaceAll('\n', ' ').trim();
  }

  static String _escapeCsv(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// 1. Export as TSV with UTF-8 BOM
  static Future<void> exportTsv({
    required BuildContext context,
    required List<ImportFileModel> shipments,
    String? filterSummary,
  }) async {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();

    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Header
    buffer.writeln([
      _clean(l.operationalTsvHeaderShipmentName),
      _clean(l.operationalTsvHeaderFileCode),
      _clean(l.operationalTsvHeaderImporter),
      _clean(l.operationalTsvHeaderSupplier),
      _clean(l.operationalTsvHeaderPriority),
      _clean(l.operationalTsvHeaderCurrentPhase),
      _clean(l.operationalTsvHeaderOperationalStep),
      _clean(l.operationalTsvHeaderBroker),
      _clean(l.operationalTsvHeaderPoNumber),
      _clean(l.operationalTsvHeaderProgress),
      _clean(l.operationalTsvHeaderNextAction),
      _clean(l.operationalTsvHeaderStatus),
    ].join('\t'));

    // Rows
    for (final s in shipments) {
      final row = OperationalDashboardReportRow.fromImportFile(s, l, isArabic);
      buffer.writeln([
        _clean(row.shipmentName),
        _clean(row.importFileCode),
        _clean(row.companyName),
        _clean(row.supplierName),
        _clean(row.priority),
        _clean(row.currentPhase),
        _clean(row.operationalStep),
        _clean(row.brokerName),
        _clean(row.poNumber),
        '${row.progressPercent.toStringAsFixed(0)}%',
        _clean(row.nextAction),
        _clean(row.status),
      ].join('\t'));
    }

    final bytes = utf8.encode(buffer.toString());
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: 'operational_workspace_${DateTime.now().millisecondsSinceEpoch}.tsv',
      dialogTitle: l.operationalExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
    );
  }

  /// 2. Export as CSV with RFC-4180 Escaping & UTF-8 BOM
  static Future<void> exportCsv({
    required BuildContext context,
    required List<ImportFileModel> shipments,
    String? filterSummary,
  }) async {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();

    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Header
    buffer.writeln([
      _escapeCsv(l.operationalTsvHeaderShipmentName),
      _escapeCsv(l.operationalTsvHeaderFileCode),
      _escapeCsv(l.operationalTsvHeaderImporter),
      _escapeCsv(l.operationalTsvHeaderSupplier),
      _escapeCsv(l.operationalTsvHeaderPriority),
      _escapeCsv(l.operationalTsvHeaderCurrentPhase),
      _escapeCsv(l.operationalTsvHeaderOperationalStep),
      _escapeCsv(l.operationalTsvHeaderBroker),
      _escapeCsv(l.operationalTsvHeaderPoNumber),
      _escapeCsv(l.operationalTsvHeaderProgress),
      _escapeCsv(l.operationalTsvHeaderNextAction),
      _escapeCsv(l.operationalTsvHeaderStatus),
    ].join(','));

    // Rows
    for (final s in shipments) {
      final row = OperationalDashboardReportRow.fromImportFile(s, l, isArabic);
      buffer.writeln([
        _escapeCsv(row.shipmentName),
        _escapeCsv(row.importFileCode),
        _escapeCsv(row.companyName),
        _escapeCsv(row.supplierName),
        _escapeCsv(row.priority),
        _escapeCsv(row.currentPhase),
        _escapeCsv(row.operationalStep),
        _escapeCsv(row.brokerName),
        _escapeCsv(row.poNumber),
        '${row.progressPercent.toStringAsFixed(0)}%',
        _escapeCsv(row.nextAction),
        _escapeCsv(row.status),
      ].join(','));
    }

    final bytes = utf8.encode(buffer.toString());
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: bytes,
      defaultFileName: 'operational_workspace_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: l.operationalExportExcelDialogTitle,
      allowedExtensions: ['csv'],
    );
  }

  /// 3. Print / PDF View: Vector A4 Landscape with Cairo Font
  static Future<void> printPdf({
    required BuildContext context,
    required List<ImportFileModel> shipments,
    required String filterSummary,
    required String username,
  }) async {
    final l = context.l10n;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';
    final doc = pw.Document();

    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();

    final totalCount = shipments.length;
    final now = DateTime.now();
    final nowFormatted =
        '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} - ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final rows = shipments.map((s) => OperationalDashboardReportRow.fromImportFile(s, l, isRtl)).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        l.operationalReportTitle,
                        style: pw.TextStyle(
                          font: cairoBold,
                          fontSize: 16,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        l.operationalPdfSystemBranding,
                        style: pw.TextStyle(
                          font: cairoRegular,
                          fontSize: 8.5,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.Text(
                      l.operationalPdfOfficialBadge,
                      style: pw.TextStyle(font: cairoBold, fontSize: 9, color: PdfColors.blue900),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400, thickness: 0.8),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${l.operationalReportGeneratedAt}: $nowFormatted',
                    style: pw.TextStyle(font: cairoRegular, fontSize: 8, color: PdfColors.grey700),
                  ),
                  if (username.isNotEmpty)
                    pw.Text(
                      '${l.operationalReportGeneratedBy}: $username',
                      style: pw.TextStyle(font: cairoRegular, fontSize: 8, color: PdfColors.grey700),
                    ),
                ],
              ),
              if (filterSummary.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.amber50,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.amber200, width: 0.5),
                  ),
                  child: pw.Text(
                    '${l.operationalPdfFilterCriteria}$filterSummary',
                    style: pw.TextStyle(font: cairoRegular, fontSize: 8, color: PdfColors.brown800),
                  ),
                ),
              ],
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context ctx) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    l.operationalPdfSystemBranding,
                    style: pw.TextStyle(font: cairoRegular, fontSize: 7, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    l.operationalPdfPageOf(ctx.pageNumber, ctx.pagesCount),
                    style: pw.TextStyle(font: cairoRegular, fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context ctx) {
          return [
            // KPI Summary Block
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(l.matchingShipments, style: pw.TextStyle(font: cairoRegular, fontSize: 8)),
                      pw.Text('$totalCount ${l.shipmentCountUnit}', style: pw.TextStyle(font: cairoBold, fontSize: 11, color: PdfColors.blue900)),
                    ],
                  ),
                ],
              ),
            ),

            // Table of Shipments (Task D integrated: Human-readable names primary)
            pw.TableHelper.fromTextArray(
              headers: [
                l.operationalTsvHeaderShipmentName,
                l.operationalTsvHeaderImporter,
                l.operationalTsvHeaderSupplier,
                l.operationalTsvHeaderPriority,
                l.operationalTsvHeaderCurrentPhase,
                l.operationalTsvHeaderBroker,
                l.operationalTsvHeaderPoNumber,
                l.operationalTsvHeaderProgress,
                l.operationalTsvHeaderNextAction,
              ],
              data: rows.map((r) {
                return [
                  r.shipmentTitle,
                  r.companyName,
                  r.supplierName,
                  r.priority,
                  '${r.currentPhase}\n${r.operationalStep}',
                  r.brokerName,
                  r.poNumber,
                  '${r.progressPercent.toStringAsFixed(0)}%',
                  r.nextAction,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(font: cairoBold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2C3E50)),
              headerHeight: 22,
              cellStyle: pw.TextStyle(font: cairoRegular, fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF9FAFB),
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'operational_workspace_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// 4. Copy Dossier to Clipboard (Task D integrated)
  static void copyDossier({
    required BuildContext context,
    required List<ImportFileModel> shipments,
    required String filterSummary,
  }) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();

    buffer.writeln('📋 ${l.operationalReportTitle}');
    buffer.writeln('═══════════════════════════════════════════════');
    if (filterSummary.isNotEmpty) {
      buffer.writeln('🔍 ${l.operationalDossierCriteria}$filterSummary');
    }
    buffer.writeln('📊 ${l.matchingShipments}: ${shipments.length} ${l.shipmentCountUnit}');
    buffer.writeln('───────────────────────────────────────────────');

    for (int i = 0; i < shipments.length; i++) {
      final r = OperationalDashboardReportRow.fromImportFile(shipments[i], l, isArabic);
      buffer.writeln('[${i + 1}] ${r.shipmentTitle}');
      buffer.writeln('    - ${l.operationalTsvHeaderImporter}: ${r.companyName} | ${l.operationalTsvHeaderSupplier}: ${r.supplierName}');
      buffer.writeln('    - ${l.operationalTsvHeaderPriority}: ${r.priority} | ${l.operationalTsvHeaderProgress}: ${r.progressPercent.toStringAsFixed(0)}%');
      buffer.writeln('    - ${l.operationalTsvHeaderCurrentPhase}: ${r.currentPhase} (${r.operationalStep})');
      buffer.writeln('    - ${l.operationalTsvHeaderBroker}: ${r.brokerName} | ${l.operationalTsvHeaderPoNumber}: ${r.poNumber}');
      buffer.writeln('    - ${l.operationalTsvHeaderNextAction}: ${r.nextAction}');
      buffer.writeln('');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l.operationalCopiedDossierSuccess,
    );
  }
}

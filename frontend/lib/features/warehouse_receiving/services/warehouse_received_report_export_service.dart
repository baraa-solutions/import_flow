import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/warehouse_receiving_model.dart';

/// Item Model for Screen 64: Warehouse Received Shipments Detailed Report
class WarehouseReceivedReportItem {
  final String importFileCode;
  final String poNumber;
  final String containerInfo;
  final String itemCode;
  final String itemName;
  final int invoicedQty;
  final int shortageQty;
  final int damagedQty;
  final int samplesQty;
  final int receivedQty;
  final int varianceQty;
  final String warehouseName;
  final String arrivalDate;
  final String status;
  final String grnCode;

  const WarehouseReceivedReportItem({
    required this.importFileCode,
    required this.poNumber,
    required this.containerInfo,
    required this.itemCode,
    required this.itemName,
    required this.invoicedQty,
    required this.shortageQty,
    required this.damagedQty,
    this.samplesQty = 0,
    required this.receivedQty,
    required this.varianceQty,
    required this.warehouseName,
    required this.arrivalDate,
    required this.status,
    this.grnCode = '',
  });

  static List<WarehouseReceivedReportItem> fromReceivingRecords(
      List<WarehouseReceivingModel> records) {
    final List<WarehouseReceivedReportItem> list = [];
    for (final r in records) {
      for (final item in r.grnItems) {
        final arrival = r.arrivalDatetime.length >= 10
            ? r.arrivalDatetime.substring(0, 10)
            : r.arrivalDatetime;
        list.add(WarehouseReceivedReportItem(
          importFileCode: 'IMP-${r.importFileId}',
          poNumber: 'PO-MAIN-${r.importFileId}',
          containerInfo: '1 × 40ft HQ (${r.truckPlateNumber ?? "N/A"})',
          itemCode: item.itemCode,
          itemName: item.itemName,
          invoicedQty: item.invoicedQty,
          shortageQty: item.shortageQty,
          damagedQty: item.damagedQty,
          samplesQty: 0,
          receivedQty: item.acceptedQty,
          varianceQty: item.acceptedQty - item.invoicedQty,
          warehouseName: r.warehouseName,
          arrivalDate: arrival,
          status: r.status,
          grnCode: r.grnCode,
        ));
      }
    }
    return list;
  }

  String toRowSummary(AppLocalizations l) {
    return [
      '${l.whReportColImportFile}: $importFileCode',
      '${l.whReportColPoNumber}: $poNumber',
      '${l.whReportColItemAndDescription}: $itemCode - $itemName',
      '${l.whReportColInvoicedQty}: $invoicedQty',
      '${l.whReportColReceivedQty}: $receivedQty',
      '${l.whReportColShortageQty}: $shortageQty',
      '${l.whReportColDamagedQty}: $damagedQty',
      '${l.whReportColSamplesQty}: $samplesQty',
      '${l.whReportColVarianceQty}: ${varianceQty >= 0 ? "+$varianceQty" : "$varianceQty"}',
      '${l.whReportColWarehouse}: $warehouseName',
      '${l.whReportColArrivalDate}: $arrivalDate',
      '${l.whReportColReceiptStatus}: $status',
    ].join(' | ');
  }
}

/// Dedicated Export & Dossier Service for Screen 64:
/// Inbound Logistics - Warehouse Received Shipments Detailed Report.
class WarehouseReceivedReportExportService {
  static String _cleanTsv(String val) {
    return val.replaceAll('\t', ' ').replaceAll('\r', '').replaceAll('\n', ' ').trim();
  }

  static String _csvQuote(String val) {
    final cleaned = val.replaceAll('\r', '').trim();
    if (cleaned.contains(',') || cleaned.contains('"') || cleaned.contains('\n')) {
      return '"${cleaned.replaceAll('"', '""')}"';
    }
    return cleaned;
  }

  /// Exports received shipments report as TSV string with UTF-8 BOM
  static String exportReportToTsv(BuildContext context, List<WarehouseReceivedReportItem> items) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      l.whReportColImportFile,
      l.whReportColPoNumber,
      l.whReportColContainerAndTruck,
      l.whReportColItemAndDescription,
      l.whReportColInvoicedQty,
      l.whReportColShortageQty,
      l.whReportColDamagedQty,
      l.whReportColSamplesQty,
      l.whReportColReceivedQty,
      l.whReportColVarianceQty,
      l.whReportColWarehouse,
      l.whReportColArrivalDate,
      l.whReportColReceiptStatus,
    ].join('\t'));

    for (final it in items) {
      buf.writeln([
        _cleanTsv(it.importFileCode),
        _cleanTsv(it.poNumber),
        _cleanTsv(it.containerInfo),
        _cleanTsv('${it.itemCode} - ${it.itemName}'),
        _cleanTsv(it.invoicedQty.toString()),
        _cleanTsv(it.shortageQty.toString()),
        _cleanTsv(it.damagedQty.toString()),
        _cleanTsv(it.samplesQty.toString()),
        _cleanTsv(it.receivedQty.toString()),
        _cleanTsv('${it.varianceQty >= 0 ? "+" : ""}${it.varianceQty}'),
        _cleanTsv(it.warehouseName),
        _cleanTsv(it.arrivalDate),
        _cleanTsv(it.status),
      ].join('\t'));
    }

    return buf.toString();
  }

  /// Exports received shipments report as CSV string with UTF-8 BOM
  static String exportReportToCsv(BuildContext context, List<WarehouseReceivedReportItem> items) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      _csvQuote(l.whReportColImportFile),
      _csvQuote(l.whReportColPoNumber),
      _csvQuote(l.whReportColContainerAndTruck),
      _csvQuote(l.whReportColItemAndDescription),
      _csvQuote(l.whReportColInvoicedQty),
      _csvQuote(l.whReportColShortageQty),
      _csvQuote(l.whReportColDamagedQty),
      _csvQuote(l.whReportColSamplesQty),
      _csvQuote(l.whReportColReceivedQty),
      _csvQuote(l.whReportColVarianceQty),
      _csvQuote(l.whReportColWarehouse),
      _csvQuote(l.whReportColArrivalDate),
      _csvQuote(l.whReportColReceiptStatus),
    ].join(','));

    for (final it in items) {
      buf.writeln([
        _csvQuote(it.importFileCode),
        _csvQuote(it.poNumber),
        _csvQuote(it.containerInfo),
        _csvQuote('${it.itemCode} - ${it.itemName}'),
        _csvQuote(it.invoicedQty.toString()),
        _csvQuote(it.shortageQty.toString()),
        _csvQuote(it.damagedQty.toString()),
        _csvQuote(it.samplesQty.toString()),
        _csvQuote(it.receivedQty.toString()),
        _csvQuote('${it.varianceQty >= 0 ? "+" : ""}${it.varianceQty}'),
        _csvQuote(it.warehouseName),
        _csvQuote(it.arrivalDate),
        _csvQuote(it.status),
      ].join(','));
    }

    return buf.toString();
  }

  /// Saves report TSV to file and copies content to clipboard
  static Future<void> saveReportTsvToFile(
      BuildContext context, List<WarehouseReceivedReportItem> items) async {
    final l = context.l10n;
    final tsvContent = exportReportToTsv(context, items);
    await CopyHelper.copy(context, tsvContent, customMessage: l.whReportCopiedTsvSuccess);
    if (!context.mounted) return;

    final filename =
        'Warehouse_Received_Detailed_Report_${DateTime.now().millisecondsSinceEpoch}.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.whReportExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Saves report CSV to file and copies content to clipboard
  static Future<void> saveReportCsvToFile(
      BuildContext context, List<WarehouseReceivedReportItem> items) async {
    final l = context.l10n;
    final csvContent = exportReportToCsv(context, items);
    await CopyHelper.copy(context, csvContent, customMessage: l.whReportCopiedExcelSuccess);
    if (!context.mounted) return;

    final filename =
        'Warehouse_Received_Detailed_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: filename,
      dialogTitle: l.whReportExportExcelBtn,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: true,
    );
  }

  /// Builds a complete formatted text dossier for quick copying
  static String buildReportDossier({
    required BuildContext context,
    required List<WarehouseReceivedReportItem> items,
  }) {
    final l = context.l10n;
    final buf = StringBuffer();

    buf.writeln('================================================================');
    buf.writeln(l.whReportDossierHeader);
    buf.writeln('================================================================');
    buf.writeln(l.whReportInfoBannerTitle);
    buf.writeln('Timestamp: ${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('----------------------------------------------------------------');

    final totalInvoiced = items.fold<int>(0, (s, i) => s + i.invoicedQty);
    final totalReceived = items.fold<int>(0, (s, i) => s + i.receivedQty);
    final totalDamaged = items.fold<int>(0, (s, i) => s + i.damagedQty);
    final totalShortage = items.fold<int>(0, (s, i) => s + i.shortageQty);
    final totalSamples = items.fold<int>(0, (s, i) => s + i.samplesQty);
    final totalVariance = items.fold<int>(0, (s, i) => s + i.varianceQty);

    buf.writeln(l.whReportDossierKpiSummary);
    buf.writeln('• ${l.whReportKpiInvoicedQty}: ${l.whReportUnitsValue(totalInvoiced)}');
    buf.writeln('• ${l.whReportKpiReceivedQty}: ${l.whReportUnitsValue(totalReceived)}');
    buf.writeln('• ${l.whReportKpiDamagedQty}: ${l.whReportUnitsValue(totalDamaged)}');
    buf.writeln('• ${l.whReportKpiShortageQty}: ${l.whReportUnitsValue(totalShortage)}');
    buf.writeln('• ${l.whReportKpiSamplesQty}: ${l.whReportUnitsValue(totalSamples)}');
    buf.writeln(
        '• ${l.whReportKpiVarianceQty}: ${totalVariance >= 0 ? "+" : ""}${l.whReportUnitsValue(totalVariance)}');
    buf.writeln('----------------------------------------------------------------');
    buf.writeln(l.whReportDossierRecordsDetails);
    buf.writeln('----------------------------------------------------------------');

    if (items.isEmpty) {
      buf.writeln(l.whReportNoDataFound);
    } else {
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        buf.writeln('[${i + 1}] ${l.whReportColImportFile}: ${it.importFileCode}');
        buf.writeln('    • ${l.whReportColPoNumber}: ${it.poNumber}');
        buf.writeln('    • ${l.whReportColContainerAndTruck}: ${it.containerInfo}');
        buf.writeln('    • ${l.whReportColItemAndDescription}: ${it.itemCode} - ${it.itemName}');
        buf.writeln('    • ${l.whReportColInvoicedQty}: ${it.invoicedQty}');
        buf.writeln('    • ${l.whReportColReceivedQty}: ${it.receivedQty}');
        buf.writeln('    • ${l.whReportColShortageQty}: ${it.shortageQty}');
        buf.writeln('    • ${l.whReportColDamagedQty}: ${it.damagedQty}');
        buf.writeln('    • ${l.whReportColSamplesQty}: ${it.samplesQty}');
        buf.writeln(
            '    • ${l.whReportColVarianceQty}: ${it.varianceQty >= 0 ? "+" : ""}${it.varianceQty}');
        buf.writeln('    • ${l.whReportColWarehouse}: ${it.warehouseName}');
        buf.writeln('    • ${l.whReportColArrivalDate}: ${it.arrivalDate}');
        buf.writeln('    • ${l.whReportColReceiptStatus}: ${it.status}');
        buf.writeln();
      }
    }

    buf.writeln('================================================================');
    buf.writeln(l.whReportDossierFooter);
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies full plain text dossier to system clipboard
  static Future<void> copyDossierToClipboard(
    BuildContext context,
    List<WarehouseReceivedReportItem> items,
  ) async {
    final l = context.l10n;
    final dossier = buildReportDossier(context: context, items: items);
    await CopyHelper.copy(context, dossier, customMessage: l.whReportCopiedDossierSuccess);
  }

  /// Generates and previews a Vector A4 Landscape PDF using Cairo font
  static Future<void> printOrSaveReportPdf(
    BuildContext context,
    List<WarehouseReceivedReportItem> items,
  ) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final doc = pw.Document();

    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();
    final pageTheme = pw.PageTheme(
      pageFormat: PdfPageFormat.a4.landscape,
      textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      theme: pw.ThemeData.withFont(
        base: cairoRegular,
        bold: cairoBold,
      ),
      margin: const pw.EdgeInsets.all(24),
    );

    final totalInvoiced = items.fold<int>(0, (s, i) => s + i.invoicedQty);
    final totalReceived = items.fold<int>(0, (s, i) => s + i.receivedQty);
    final totalDamaged = items.fold<int>(0, (s, i) => s + i.damagedQty);
    final totalShortage = items.fold<int>(0, (s, i) => s + i.shortageQty);
    final totalSamples = items.fold<int>(0, (s, i) => s + i.samplesQty);
    final totalVariance = items.fold<int>(0, (s, i) => s + i.varianceQty);

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        header: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IMPORTFLOW ERP — ${l.whReportPdfTitle}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      l.whReportPdfSubtitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateTime.now().toString().substring(0, 10),
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'Phase 06 — Warehouse Inbound Operations',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ImportFlow ERP System • Official Warehouse Received Shipments Audit Report',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            // KPI Summary Cards
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiCard(l.whReportKpiInvoicedQty, totalInvoiced.toString(), PdfColors.blue800),
                  _buildPdfKpiCard(l.whReportKpiReceivedQty, totalReceived.toString(), PdfColors.green800),
                  _buildPdfKpiCard(l.whReportKpiDamagedQty, totalDamaged.toString(), PdfColors.red800),
                  _buildPdfKpiCard(l.whReportKpiShortageQty, totalShortage.toString(), PdfColors.orange800),
                  _buildPdfKpiCard(l.whReportKpiSamplesQty, totalSamples.toString(), PdfColors.purple800),
                  _buildPdfKpiCard(
                    l.whReportKpiVarianceQty,
                    '${totalVariance >= 0 ? "+" : ""}$totalVariance',
                    totalVariance == 0 ? PdfColors.green800 : PdfColors.red800,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Detailed Data Table
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.center,
              headerAlignment: pw.Alignment.center,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              headers: [
                l.whReportColImportFile,
                l.whReportColPoNumber,
                l.whReportColItemAndDescription,
                l.whReportColInvoicedQty,
                l.whReportColReceivedQty,
                l.whReportColShortageQty,
                l.whReportColDamagedQty,
                l.whReportColSamplesQty,
                l.whReportColVarianceQty,
                l.whReportColWarehouse,
                l.whReportColArrivalDate,
                l.whReportColReceiptStatus,
              ],
              data: items.map((it) {
                return [
                  it.importFileCode,
                  it.poNumber,
                  '${it.itemCode}\n${it.itemName}',
                  it.invoicedQty.toString(),
                  it.receivedQty.toString(),
                  it.shortageQty.toString(),
                  it.damagedQty.toString(),
                  it.samplesQty.toString(),
                  '${it.varianceQty >= 0 ? "+" : ""}${it.varianceQty}',
                  it.warehouseName,
                  it.arrivalDate,
                  it.status,
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    if (!context.mounted) return;
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: 'Warehouse Received Report',
      importFileNameOrCode: 'Detailed Report',
      extension: 'pdf',
    );
  }

  static pw.Widget _buildPdfKpiCard(String label, String value, PdfColor color) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      ],
    );
  }
}

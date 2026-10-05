import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/goods_in_transit_model.dart';

/// Dedicated Export & Dossier Service for Screen 63:
/// Inbound Logistics - Goods In Transit (GIT) Ledger.
class GoodsInTransitExportService {
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

  /// Exports goods in transit ledger as TSV string with UTF-8 BOM
  static String exportGitToTsv(BuildContext context, List<GitLineItemModel> items) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      l.gitColFileCode,
      l.gitColPoNumber,
      l.gitColItemCode,
      l.gitColItemName,
      l.gitColInvoicedQty,
      l.gitColPackagesCount,
      l.gitPackageTypeCol,
      l.gitColContainers,
      l.gitContainerTypeCol,
      l.gitColCertifiedDate,
      l.gitColLedgerStatus,
    ].join('\t'));

    for (final it in items) {
      final statusStr = it.isDeliveredToWarehouse
          ? l.gitStatusDeliveredToWarehouse
          : l.gitStatusInTransit;

      buf.writeln([
        _cleanTsv(it.importFileCode),
        _cleanTsv(it.poNumber),
        _cleanTsv(it.itemCode),
        _cleanTsv(it.itemName),
        _cleanTsv(it.invoicedQty.toStringAsFixed(0)),
        _cleanTsv(it.packagesCount.toString()),
        _cleanTsv(it.packageType),
        _cleanTsv(it.containersCount.toString()),
        _cleanTsv(it.containerType),
        _cleanTsv(it.certifiedDate),
        _cleanTsv(statusStr),
      ].join('\t'));
    }

    return buf.toString();
  }

  /// Exports goods in transit ledger as CSV string with UTF-8 BOM
  static String exportGitToCsv(BuildContext context, List<GitLineItemModel> items) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      _csvQuote(l.gitColFileCode),
      _csvQuote(l.gitColPoNumber),
      _csvQuote(l.gitColItemCode),
      _csvQuote(l.gitColItemName),
      _csvQuote(l.gitColInvoicedQty),
      _csvQuote(l.gitColPackagesCount),
      _csvQuote(l.gitPackageTypeCol),
      _csvQuote(l.gitColContainers),
      _csvQuote(l.gitContainerTypeCol),
      _csvQuote(l.gitColCertifiedDate),
      _csvQuote(l.gitColLedgerStatus),
    ].join(','));

    for (final it in items) {
      final statusStr = it.isDeliveredToWarehouse
          ? l.gitStatusDeliveredToWarehouse
          : l.gitStatusInTransit;

      buf.writeln([
        _csvQuote(it.importFileCode),
        _csvQuote(it.poNumber),
        _csvQuote(it.itemCode),
        _csvQuote(it.itemName),
        _csvQuote(it.invoicedQty.toStringAsFixed(0)),
        _csvQuote(it.packagesCount.toString()),
        _csvQuote(it.packageType),
        _csvQuote(it.containersCount.toString()),
        _csvQuote(it.containerType),
        _csvQuote(it.certifiedDate),
        _csvQuote(statusStr),
      ].join(','));
    }

    return buf.toString();
  }

  /// Saves goods in transit ledger TSV to file and copies content to clipboard
  static Future<void> saveGitTsvToFile(BuildContext context, List<GitLineItemModel> items) async {
    final l = context.l10n;
    final tsvContent = exportGitToTsv(context, items);
    await CopyHelper.copy(context, tsvContent, customMessage: l.gitCopiedTsvSuccess);
    if (!context.mounted) return;

    final filename = 'Goods_In_Transit_Ledger_${DateTime.now().millisecondsSinceEpoch}.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.gitExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Saves goods in transit ledger CSV to file and copies content to clipboard
  static Future<void> saveGitCsvToFile(BuildContext context, List<GitLineItemModel> items) async {
    final l = context.l10n;
    final csvContent = exportGitToCsv(context, items);
    await CopyHelper.copy(context, csvContent, customMessage: l.gitCopiedExcelSuccess);
    if (!context.mounted) return;

    final filename = 'Goods_In_Transit_Ledger_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: filename,
      dialogTitle: l.gitExportExcelBtn,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: true,
    );
  }

  /// Builds a complete formatted text dossier for quick copying
  static String buildGitDossier({
    required BuildContext context,
    required List<GitLineItemModel> items,
  }) {
    final l = context.l10n;
    final buf = StringBuffer();

    buf.writeln('================================================================');
    buf.writeln(l.gitDossierHeader);
    buf.writeln('================================================================');
    buf.writeln(l.gitInfoBannerTitle);
    buf.writeln('Timestamp: ${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('----------------------------------------------------------------');

    final activeItems = items.where((i) => !i.isDeliveredToWarehouse).toList();
    final uniqueFiles = activeItems.map((i) => i.importFileCode).toSet().length;
    final uniquePos = activeItems.map((i) => i.poNumber).toSet().length;
    final totalQty = activeItems.fold<double>(0.0, (s, i) => s + i.invoicedQty);
    final totalPkgs = activeItems.fold<int>(0, (s, i) => s + i.packagesCount);
    final totalContainers = activeItems.fold<int>(0, (s, i) => s + i.containersCount);

    buf.writeln(l.gitDossierKpiSummary);
    buf.writeln('• ${l.gitKpiInTransitShipments}: ${l.gitKpiShipmentsValue(uniqueFiles)}');
    buf.writeln('• ${l.gitKpiPurchaseOrders}: ${l.gitKpiPurchaseOrdersValue(uniquePos)}');
    buf.writeln('• ${l.gitKpiInvoicedQuantity}: ${l.gitKpiQuantityValue(totalQty.toStringAsFixed(0))}');
    buf.writeln('• ${l.gitKpiPackagesCount}: ${l.gitKpiPackagesValue(totalPkgs)}');
    buf.writeln('• ${l.gitKpiActiveContainers}: ${l.gitKpiContainersValue(totalContainers)}');
    buf.writeln('----------------------------------------------------------------');
    buf.writeln(l.gitDossierRecordsDetails);
    buf.writeln('----------------------------------------------------------------');

    if (items.isEmpty) {
      buf.writeln(l.gitNoDataFound);
    } else {
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        final statusStr = it.isDeliveredToWarehouse
            ? l.gitStatusDeliveredToWarehouse
            : l.gitStatusInTransit;

        buf.writeln('[${i + 1}] ${l.gitColFileCode}: ${it.importFileCode}');
        buf.writeln('    • ${l.gitColPoNumber}: ${it.poNumber}');
        buf.writeln('    • ${l.gitColItemCode}: ${it.itemCode}');
        buf.writeln('    • ${l.gitColItemName}: ${it.itemName}');
        buf.writeln('    • ${l.gitColInvoicedQty}: ${it.invoicedQty.toStringAsFixed(0)}');
        buf.writeln('    • ${l.gitColPackagesCount}: ${it.packagesCount} (${it.packageType})');
        buf.writeln('    • ${l.gitColContainers}: ${it.containersCount} × ${it.containerType}');
        buf.writeln('    • ${l.gitColCertifiedDate}: ${it.certifiedDate}');
        buf.writeln('    • ${l.gitColLedgerStatus}: $statusStr');
        buf.writeln();
      }
    }

    buf.writeln('================================================================');
    buf.writeln(l.gitDossierFooter);
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies full plain text dossier to system clipboard
  static Future<void> copyDossierToClipboard(
    BuildContext context,
    List<GitLineItemModel> items,
  ) async {
    final l = context.l10n;
    final dossier = buildGitDossier(context: context, items: items);
    await CopyHelper.copy(context, dossier, customMessage: l.gitCopiedDossierSuccess);
  }

  /// Generates and previews a Vector A4 Landscape PDF using Cairo font
  static Future<void> printOrSaveGitPdf(
    BuildContext context,
    List<GitLineItemModel> items,
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

    final activeItems = items.where((i) => !i.isDeliveredToWarehouse).toList();
    final uniqueFiles = activeItems.map((i) => i.importFileCode).toSet().length;
    final uniquePos = activeItems.map((i) => i.poNumber).toSet().length;
    final totalQty = activeItems.fold<double>(0.0, (s, i) => s + i.invoicedQty);
    final totalPkgs = activeItems.fold<int>(0, (s, i) => s + i.packagesCount);
    final totalContainers = activeItems.fold<int>(0, (s, i) => s + i.containersCount);

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
                      'IMPORTFLOW ERP — ${l.gitPdfTitle}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      l.gitPdfSubtitle,
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
                      'Phase 06 — Inbound Warehouse Logistics Hub',
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
                  'ImportFlow ERP System • Official Goods In Transit Inventory Ledger',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            pw.SizedBox(height: 10),

            // KPI Summary Cards in PDF
            pw.Row(
              children: [
                _buildPdfKpiCard(
                  title: l.gitKpiInTransitShipments,
                  value: l.gitKpiShipmentsValue(uniqueFiles),
                  color: PdfColors.blue900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.gitKpiPurchaseOrders,
                  value: l.gitKpiPurchaseOrdersValue(uniquePos),
                  color: PdfColors.purple900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.gitKpiInvoicedQuantity,
                  value: l.gitKpiQuantityValue(totalQty.toStringAsFixed(0)),
                  color: PdfColors.indigo900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.gitKpiPackagesCount,
                  value: l.gitKpiPackagesValue(totalPkgs),
                  color: PdfColors.teal900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.gitKpiActiveContainers,
                  value: l.gitKpiContainersValue(totalContainers),
                  color: PdfColors.green900,
                  isAr: isAr,
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Section Header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: PdfColors.grey200,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    l.gitTableSectionHeader,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.Text(
                    '${items.length} ${l.gitColLedgerStatus}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Goods In Transit Table
            if (items.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  l.gitNoDataFound,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // File Code
                  1: const pw.FlexColumnWidth(1.2), // PO Number
                  2: const pw.FlexColumnWidth(1.1), // Item Code
                  3: const pw.FlexColumnWidth(2.0), // Item Description
                  4: const pw.FlexColumnWidth(1.0), // Invoiced Qty
                  5: const pw.FlexColumnWidth(1.2), // Packages
                  6: const pw.FlexColumnWidth(1.3), // Containers
                  7: const pw.FlexColumnWidth(1.0), // Date
                  8: const pw.FlexColumnWidth(1.1), // Status
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildPdfTableCell(l.gitColFileCode, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColPoNumber, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColItemCode, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColItemName, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColInvoicedQty, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColPackagesCount, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColContainers, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColCertifiedDate, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.gitColLedgerStatus, isHeader: true, isAr: isAr),
                    ],
                  ),
                  // Data Rows
                  ...items.map((it) {
                    final statusStr = it.isDeliveredToWarehouse
                        ? l.gitStatusDeliveredToWarehouse
                        : l.gitStatusInTransit;

                    return pw.TableRow(
                      children: [
                        _buildPdfTableCell(it.importFileCode, isAr: isAr, bold: true),
                        _buildPdfTableCell(it.poNumber, isAr: isAr),
                        _buildPdfTableCell(it.itemCode, isAr: isAr),
                        _buildPdfTableCell(it.itemName, isAr: isAr),
                        _buildPdfTableCell(it.invoicedQty.toStringAsFixed(0), isAr: isAr, alignEnd: true),
                        _buildPdfTableCell('${it.packagesCount} ${it.packageType}', isAr: isAr),
                        _buildPdfTableCell('${it.containersCount} × ${it.containerType}', isAr: isAr),
                        _buildPdfTableCell(it.certifiedDate, isAr: isAr),
                        _buildPdfTableCell(
                          statusStr,
                          isAr: isAr,
                          color: it.isDeliveredToWarehouse ? PdfColors.green800 : PdfColors.teal800,
                          bold: true,
                        ),
                      ],
                    );
                  }),
                ],
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
      stageName: 'Goods In Transit Ledger',
      importFileNameOrCode: 'Ledger',
      extension: 'pdf',
    );
  }

  static pw.Widget _buildPdfKpiCard({
    required String title,
    required String value,
    required PdfColor color,
    required bool isAr,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              maxLines: 1,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    bool isAr = false,
    bool bold = false,
    bool alignEnd = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Align(
        alignment: alignEnd
            ? (isAr ? pw.Alignment.centerLeft : pw.Alignment.centerRight)
            : (isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isHeader ? 8 : 7.5,
            fontWeight: (isHeader || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? (isHeader ? PdfColors.blueGrey900 : PdfColors.black),
          ),
          maxLines: 2,
        ),
      ),
    );
  }
}

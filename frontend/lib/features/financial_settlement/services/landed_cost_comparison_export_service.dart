import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/localization/domain_enum_labels.dart';

/// Service responsible for exporting Landed Cost Comparison data across TSV, Excel (CSV), vector PDF, and clipboard dossier.
class LandedCostComparisonExportService {
  final BuildContext context;
  final String fileCode;
  final String incoterm;
  final double estimatedCost;
  final Map<String, dynamic>? settlementRecord;

  LandedCostComparisonExportService({
    required this.context,
    required this.fileCode,
    required this.incoterm,
    required this.estimatedCost,
    required this.settlementRecord,
  });

  AppLocalizations get _l10n => context.l10n;

  double get _totalFob => (settlementRecord?['total_fob_egp'] ?? 0.0).toDouble();
  double get _totalExpenses => (settlementRecord?['total_expenses_egp'] ?? 0.0).toDouble();
  double get _totalLanded => (settlementRecord?['total_landed_cost_egp'] ?? 0.0).toDouble();
  double get _fobVariance => estimatedCost > 0 ? ((_totalFob - estimatedCost) / estimatedCost) * 100 : 0.0;
  double get _landedVariance => estimatedCost > 0 ? ((_totalLanded - estimatedCost) / estimatedCost) * 100 : 0.0;
  List<dynamic> get _expenses => (settlementRecord?['expense_invoices'] as List?) ?? [];
  List<dynamic> get _items => (settlementRecord?['item_landed_costs'] as List?) ?? [];

  /// Builds a clean plain-text dossier for quick clipboard copy.
  String buildDossierText() {
    final buffer = StringBuffer();
    final l10n = _l10n;

    buffer.writeln('================================================================');
    buffer.writeln('${l10n.landedCostDossierHeader} — [$fileCode]');
    buffer.writeln('================================================================');
    buffer.writeln('');
    buffer.writeln('${l10n.colItemCode}: $fileCode');
    buffer.writeln('Incoterm: ${incoterm.toUpperCase()}');
    buffer.writeln('');
    buffer.writeln('--- ${l10n.estimatedCostHeader} vs ${l10n.actualCostHeader} ---');
    buffer.writeln('${l10n.estimatedCostHeader}: ${estimatedCost.toStringAsFixed(2)} EGP');
    buffer.writeln('${l10n.fobValueCardTitle}: ${_totalFob.toStringAsFixed(2)} EGP (${_fobVariance >= 0 ? "+" : ""}${_fobVariance.toStringAsFixed(2)}%)');
    buffer.writeln('${l10n.totalExpensesCardTitle}: ${_totalExpenses.toStringAsFixed(2)} EGP');
    buffer.writeln('${l10n.totalLandedCostCardTitle}: ${_totalLanded.toStringAsFixed(2)} EGP (${_landedVariance >= 0 ? "+" : ""}${_landedVariance.toStringAsFixed(2)}%)');
    buffer.writeln('');

    if (_expenses.isNotEmpty) {
      buffer.writeln('--- ${l10n.expenseBreakdownHeader} (${_expenses.length}) ---');
      for (var i = 0; i < _expenses.length; i++) {
        final exp = _expenses[i];
        final catRaw = exp['category']?.toString() ?? 'other';
        final cat = (DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, catRaw) ?? l10n.expenseCategoryName(catRaw));
        final provider = exp['provider_name']?.toString() ?? '-';
        final cur = exp['currency']?.toString() ?? 'EGP';
        final fx = (exp['amount_fx'] ?? 0).toString();
        final rate = (exp['exchange_rate'] ?? 1).toString();
        final egp = (exp['amount_egp'] ?? 0).toString();
        buffer.writeln('${i + 1}. [$cat] $provider | $fx $cur @ $rate = $egp EGP');
      }
      buffer.writeln('');
    }

    if (_items.isNotEmpty) {
      buffer.writeln('--- ${l10n.itemLandedCostHeader} (${_items.length}) ---');
      for (var i = 0; i < _items.length; i++) {
        final itm = _items[i];
        final code = itm['item_code']?.toString() ?? '-';
        final name = itm['item_name']?.toString() ?? '-';
        final qty = (itm['qty'] ?? 0).toString();
        final fobUnit = ((itm['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2);
        final landedUnit = ((itm['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2);
        final markup = (((itm['markup_factor'] ?? 1.0) as num)).toStringAsFixed(2);
        buffer.writeln('${i + 1}. [$code] $name | Qty: $qty | FOB: $fobUnit EGP | Landed: $landedUnit EGP | Markup: ${markup}x');
      }
      buffer.writeln('');
    }

    buffer.writeln('================================================================');
    buffer.writeln('Sorour Logistics ERP — Automated Landed Cost Comparison Engine');
    buffer.writeln('================================================================');

    return buffer.toString();
  }

  /// Copies dossier to clipboard and shows SnackBar notification.
  Future<void> copyDossierToClipboard() async {
    final text = buildDossierText();
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.landedCostCopyDossierSuccess),
          backgroundColor: const Color(0xFF27AE60),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Exports Landed Cost comparison to TSV format with UTF-8 BOM.
  Future<void> exportToTsv() async {
    final buffer = StringBuffer();
    final l10n = _l10n;

    // Headers
    buffer.writeln([
      l10n.landedCostTsvHeaderSection,
      l10n.landedCostTsvHeaderCodeOrCategory,
      l10n.landedCostTsvHeaderNameOrProvider,
      l10n.landedCostTsvHeaderQtyOrCurrency,
      l10n.landedCostTsvHeaderUnitPriceOrFx,
      l10n.landedCostTsvHeaderExchangeRate,
      l10n.landedCostTsvHeaderTotalCostEgp,
      l10n.landedCostTsvHeaderMarkupOrVariance,
    ].join('\t'));

    // Summary Rows
    buffer.writeln([
      l10n.estimatedCostHeader,
      fileCode,
      incoterm.toUpperCase(),
      '1',
      estimatedCost.toStringAsFixed(2),
      '1.00',
      estimatedCost.toStringAsFixed(2),
      '0.00%',
    ].join('\t'));

    buffer.writeln([
      l10n.fobValueCardTitle,
      fileCode,
      l10n.fobValueCardTitle,
      '1',
      _totalFob.toStringAsFixed(2),
      '1.00',
      _totalFob.toStringAsFixed(2),
      '${_fobVariance >= 0 ? "+" : ""}${_fobVariance.toStringAsFixed(2)}%',
    ].join('\t'));

    buffer.writeln([
      l10n.totalExpensesCardTitle,
      fileCode,
      l10n.totalExpensesCardTitle,
      '1',
      _totalExpenses.toStringAsFixed(2),
      '1.00',
      _totalExpenses.toStringAsFixed(2),
      '-',
    ].join('\t'));

    buffer.writeln([
      l10n.totalLandedCostCardTitle,
      fileCode,
      l10n.totalLandedCostCardTitle,
      '1',
      _totalLanded.toStringAsFixed(2),
      '1.00',
      _totalLanded.toStringAsFixed(2),
      '${_landedVariance >= 0 ? "+" : ""}${_landedVariance.toStringAsFixed(2)}%',
    ].join('\t'));

    // Expenses Breakdown
    for (final exp in _expenses) {
      final catRaw = exp['category']?.toString() ?? 'other';
      final cat = (DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, catRaw) ?? l10n.expenseCategoryName(catRaw));
      final provider = exp['provider_name']?.toString() ?? '-';
      final cur = exp['currency']?.toString() ?? 'EGP';
      final fx = (exp['amount_fx'] ?? 0).toString();
      final rate = (exp['exchange_rate'] ?? 1).toString();
      final egp = (exp['amount_egp'] ?? 0).toString();

      buffer.writeln([
        l10n.expenseBreakdownHeader,
        cat,
        provider,
        cur,
        fx,
        rate,
        egp,
        '-',
      ].join('\t'));
    }

    // Items Breakdown
    for (final itm in _items) {
      final code = itm['item_code']?.toString() ?? '-';
      final name = itm['item_name']?.toString() ?? '-';
      final qty = (itm['qty'] ?? 0).toString();
      final fobUnit = ((itm['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2);
      final landedUnit = ((itm['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2);
      final markup = (((itm['markup_factor'] ?? 1.0) as num)).toStringAsFixed(2);

      buffer.writeln([
        l10n.itemLandedCostHeader,
        code,
        name,
        qty,
        fobUnit,
        '1.00',
        landedUnit,
        '${markup}x',
      ].join('\t'));
    }

    final safeCode = fileCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = 'landed_cost_comparison_${safeCode.isNotEmpty ? safeCode : "shipment"}.tsv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l10n.landedCostExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports Landed Cost comparison to clean unmerged CSV (Excel compatible) with UTF-8 BOM.
  Future<void> exportToExcel() async {
    final buffer = StringBuffer();
    final l10n = _l10n;

    // Headers
    buffer.writeln([
      _csvCell(l10n.landedCostTsvHeaderSection),
      _csvCell(l10n.landedCostTsvHeaderCodeOrCategory),
      _csvCell(l10n.landedCostTsvHeaderNameOrProvider),
      _csvCell(l10n.landedCostTsvHeaderQtyOrCurrency),
      _csvCell(l10n.landedCostTsvHeaderUnitPriceOrFx),
      _csvCell(l10n.landedCostTsvHeaderExchangeRate),
      _csvCell(l10n.landedCostTsvHeaderTotalCostEgp),
      _csvCell(l10n.landedCostTsvHeaderMarkupOrVariance),
    ].join(','));

    // Summary Rows
    buffer.writeln([
      _csvCell(l10n.estimatedCostHeader),
      _csvCell(fileCode),
      _csvCell(incoterm.toUpperCase()),
      _csvCell('1'),
      _csvCell(estimatedCost.toStringAsFixed(2)),
      _csvCell('1.00'),
      _csvCell(estimatedCost.toStringAsFixed(2)),
      _csvCell('0.00%'),
    ].join(','));

    buffer.writeln([
      _csvCell(l10n.fobValueCardTitle),
      _csvCell(fileCode),
      _csvCell(l10n.fobValueCardTitle),
      _csvCell('1'),
      _csvCell(_totalFob.toStringAsFixed(2)),
      _csvCell('1.00'),
      _csvCell(_totalFob.toStringAsFixed(2)),
      _csvCell('${_fobVariance >= 0 ? "+" : ""}${_fobVariance.toStringAsFixed(2)}%'),
    ].join(','));

    buffer.writeln([
      _csvCell(l10n.totalExpensesCardTitle),
      _csvCell(fileCode),
      _csvCell(l10n.totalExpensesCardTitle),
      _csvCell('1'),
      _csvCell(_totalExpenses.toStringAsFixed(2)),
      _csvCell('1.00'),
      _csvCell(_totalExpenses.toStringAsFixed(2)),
      _csvCell('-'),
    ].join(','));

    buffer.writeln([
      _csvCell(l10n.totalLandedCostCardTitle),
      _csvCell(fileCode),
      _csvCell(l10n.totalLandedCostCardTitle),
      _csvCell('1'),
      _csvCell(_totalLanded.toStringAsFixed(2)),
      _csvCell('1.00'),
      _csvCell(_totalLanded.toStringAsFixed(2)),
      _csvCell('${_landedVariance >= 0 ? "+" : ""}${_landedVariance.toStringAsFixed(2)}%'),
    ].join(','));

    // Expenses Breakdown
    for (final exp in _expenses) {
      final catRaw = exp['category']?.toString() ?? 'other';
      final cat = (DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, catRaw) ?? l10n.expenseCategoryName(catRaw));
      final provider = exp['provider_name']?.toString() ?? '-';
      final cur = exp['currency']?.toString() ?? 'EGP';
      final fx = (exp['amount_fx'] ?? 0).toString();
      final rate = (exp['exchange_rate'] ?? 1).toString();
      final egp = (exp['amount_egp'] ?? 0).toString();

      buffer.writeln([
        _csvCell(l10n.expenseBreakdownHeader),
        _csvCell(cat),
        _csvCell(provider),
        _csvCell(cur),
        _csvCell(fx),
        _csvCell(rate),
        _csvCell(egp),
        _csvCell('-'),
      ].join(','));
    }

    // Items Breakdown
    for (final itm in _items) {
      final code = itm['item_code']?.toString() ?? '-';
      final name = itm['item_name']?.toString() ?? '-';
      final qty = (itm['qty'] ?? 0).toString();
      final fobUnit = ((itm['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2);
      final landedUnit = ((itm['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2);
      final markup = (((itm['markup_factor'] ?? 1.0) as num)).toStringAsFixed(2);

      buffer.writeln([
        _csvCell(l10n.itemLandedCostHeader),
        _csvCell(code),
        _csvCell(name),
        _csvCell(qty),
        _csvCell(fobUnit),
        _csvCell('1.00'),
        _csvCell(landedUnit),
        _csvCell('${markup}x'),
      ].join(','));
    }

    final safeCode = fileCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = 'landed_cost_comparison_${safeCode.isNotEmpty ? safeCode : "shipment"}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l10n.landedCostExportExcelDialogTitle,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  static String _csvCell(dynamic value) {
    if (value == null) return '""';
    final str = value.toString().replaceAll('"', '""');
    return '"$str"';
  }

  /// Generates vector A4 landscape Cairo PDF and opens the system print/save dialog.
  Future<void> printOrSavePdf() async {
    final pdf = pw.Document();
    final l10n = _l10n;
    final isRtl = Localizations.localeOf(context).languageCode == 'ar';

    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();

    const charcoal = PdfColor.fromInt(0xFF2C3E50);
    const cobalt = PdfColor.fromInt(0xFF3498DB);
    const emerald = PdfColor.fromInt(0xFF27AE60);
    const crimson = PdfColor.fromInt(0xFFC0392B);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context pdfContext) => [
          // Header Bar
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: charcoal,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${l10n.landedCostDossierHeader} — $fileCode',
                  style: pw.TextStyle(color: PdfColors.white, font: cairoBold, fontSize: 16),
                ),
                pw.Text(
                  'Incoterm: ${incoterm.toUpperCase()}',
                  style: pw.TextStyle(color: PdfColors.white, font: cairoBold, fontSize: 13),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Executive Summary Cards
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildPdfSummaryBox(
                  title: l10n.estimatedCostHeader,
                  value: '${estimatedCost.toStringAsFixed(2)} EGP',
                  badge: null,
                  color: cobalt,
                  font: cairoBold,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildPdfSummaryBox(
                  title: l10n.fobValueCardTitle,
                  value: '${_totalFob.toStringAsFixed(2)} EGP',
                  badge: '${_fobVariance >= 0 ? "+" : ""}${_fobVariance.toStringAsFixed(2)}%',
                  color: charcoal,
                  font: cairoBold,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildPdfSummaryBox(
                  title: l10n.totalExpensesCardTitle,
                  value: '${_totalExpenses.toStringAsFixed(2)} EGP',
                  badge: '${_expenses.length} invoices',
                  color: charcoal,
                  font: cairoBold,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildPdfSummaryBox(
                  title: l10n.totalLandedCostCardTitle,
                  value: '${_totalLanded.toStringAsFixed(2)} EGP',
                  badge: '${_landedVariance >= 0 ? "+" : ""}${_landedVariance.toStringAsFixed(2)}%',
                  color: _landedVariance > 0 ? crimson : emerald,
                  font: cairoBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // Expenses Breakdown Table
          if (_expenses.isNotEmpty) ...[
            pw.Text(
              '${l10n.expenseBreakdownHeader} (${_expenses.length})',
              style: pw.TextStyle(font: cairoBold, fontSize: 13, color: charcoal),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(font: cairoBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: charcoal),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              headers: [
                l10n.colExpenseCategory,
                l10n.colExpenseProvider,
                l10n.colExpenseCurrency,
                l10n.colExpenseAmountFx,
                l10n.colExpenseExchangeRate,
                l10n.colExpenseAmountEgp,
              ],
              data: _expenses.map((exp) {
                final catRaw = exp['category']?.toString() ?? 'other';
                return [
                  (DomainEnums.labelIfKnown(l10n, DomainEnumType.clearanceExpenseCategory, catRaw) ?? l10n.expenseCategoryName(catRaw)),
                  exp['provider_name']?.toString() ?? '-',
                  exp['currency']?.toString() ?? 'EGP',
                  (exp['amount_fx'] ?? 0).toString(),
                  (exp['exchange_rate'] ?? 1).toString(),
                  '${(exp['amount_egp'] ?? 0)} EGP',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
          ],

          // Items Landed Cost Table
          if (_items.isNotEmpty) ...[
            pw.Text(
              '${l10n.itemLandedCostHeader} (${_items.length})',
              style: pw.TextStyle(font: cairoBold, fontSize: 13, color: charcoal),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(font: cairoBold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: cobalt),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              headers: [
                l10n.colItemCode,
                l10n.colItemName,
                l10n.colItemQty,
                l10n.colFobUnitPrice,
                l10n.colLandedUnitPrice,
                l10n.colCostMarkupFactor,
              ],
              data: _items.map((itm) {
                final fobUnit = ((itm['fob_unit_egp'] ?? 0) as num).toStringAsFixed(2);
                final landedUnit = ((itm['unit_landed_cost_egp'] ?? 0) as num).toStringAsFixed(2);
                final markup = (((itm['markup_factor'] ?? 1.0) as num)).toStringAsFixed(2);
                return [
                  itm['item_code']?.toString() ?? '-',
                  itm['item_name']?.toString() ?? '-',
                  (itm['qty'] ?? 0).toString(),
                  '$fobUnit EGP',
                  '$landedUnit EGP',
                  '${markup}x',
                ];
              }).toList(),
            ),
          ],
        ],
        footer: (pw.Context pdfContext) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Sorour Logistics ERP — Landed Cost Engine — Page ${pdfContext.pageNumber} of ${pdfContext.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
          ),
        ),
      ),
    );

    final safeCode = fileCode.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'landed_cost_comparison_${safeCode.isNotEmpty ? safeCode : "shipment"}.pdf',
    );
  }

  pw.Widget _buildPdfSummaryBox({
    required String title,
    required String value,
    required String? badge,
    required PdfColor color,
    required pw.Font font,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: color, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.grey800)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 13, color: color)),
          if (badge != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(badge, style: pw.TextStyle(font: font, fontSize: 8.5, color: color)),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_consultation_model.dart';

/// Service providing multi-channel export capabilities for the Master Clearance Expense Types Catalog:
/// 1. PDF Report (A4 Landscape, Cairo Arabic font, Printing.layoutPdf)
/// 2. Excel / CSV (UTF-8 BOM for Arabic compatibility)
/// 3. TSV (Tab-separated values)
/// 4. Clipboard Dossier (Formatted plaintext)
class ClearanceExpenseTypesExportService {
  ClearanceExpenseTypesExportService._();

  static String toRowSummary(
    ClearanceExpenseTypeModel exp,
    AppLocalizations l, {
    required bool isArabic,
  }) {
    final statusStr = exp.isActive
        ? (isArabic ? 'سارٍ' : 'Active')
        : (isArabic ? 'معطل' : 'Inactive');
    return [
      '${l.expenseCodeCol}: ${exp.expenseCode}',
      '${l.expenseNameArCol}: ${exp.nameAr}',
      if (exp.nameEn != null && exp.nameEn!.isNotEmpty) '${l.expenseNameEnCol}: ${exp.nameEn}',
      '${l.expenseCategoryCol}: ${exp.category}',
      '${l.calculationUnitCol}: ${exp.defaultUnit}',
      '${l.defaultCurrencyCol}: ${exp.defaultCurrency}',
      '${isArabic ? 'الحالة' : 'Status'}: $statusStr',
    ].join(' | ');
  }

  // ===========================================================================
  // 1. CSV / EXCEL EXPORT
  // ===========================================================================
  static String generateCsvContent(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();
    // UTF-8 BOM for instant Microsoft Excel compatibility
    buffer.write('\uFEFF');

    buffer.writeln('"${l.expenseCatalogPdfReportTitle}"');
    buffer.writeln('"${l.expenseCatalogPdfReportSubtitle}"');
    buffer.writeln('"${l.expenseCatalogTotalCountLabel(expenses.length)}"');
    buffer.writeln('"${isArabic ? 'تاريخ التصدير' : 'Export Date'}: ${DateTime.now().toLocal().toString().split('.').first}"');
    buffer.writeln('');

    final headers = [
      l.expenseCodeCol,
      l.expenseNameArCol,
      l.expenseNameEnCol,
      l.expenseCategoryCol,
      l.calculationUnitCol,
      l.defaultCurrencyCol,
      isArabic ? 'الحالة' : 'Status',
    ];
    buffer.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));

    for (final exp in expenses) {
      final statusStr = exp.isActive
          ? (isArabic ? 'سارٍ' : 'Active')
          : (isArabic ? 'معطل' : 'Inactive');
      final row = [
        exp.expenseCode,
        exp.nameAr,
        exp.nameEn ?? '-',
        exp.category,
        exp.defaultUnit,
        exp.defaultCurrency,
        statusStr,
      ];
      buffer.writeln(row.map((r) => '"${(r ?? '').replaceAll('"', '""')}"').join(','));
    }

    return buffer.toString();
  }

  static Future<String?> exportExcel(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) async {
    final l = context.l10n;
    final content = generateCsvContent(context, expenses);
    final defaultFileName = 'clearance_expense_types_${DateTime.now().millisecondsSinceEpoch}.csv';

    return FileSaveHelper.saveText(
      context: context,
      textContent: content,
      defaultFileName: defaultFileName,
      dialogTitle: l.expenseCatalogExportExcelBtn,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: true,
    );
  }

  // ===========================================================================
  // 2. TSV EXPORT
  // ===========================================================================
  static String generateTsvContent(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();
    buffer.write('\uFEFF');

    final headers = [
      l.expenseCodeCol,
      l.expenseNameArCol,
      l.expenseNameEnCol,
      l.expenseCategoryCol,
      l.calculationUnitCol,
      l.defaultCurrencyCol,
      isArabic ? 'الحالة' : 'Status',
    ];
    buffer.writeln(headers.join('\t'));

    for (final exp in expenses) {
      final statusStr = exp.isActive
          ? (isArabic ? 'سارٍ' : 'Active')
          : (isArabic ? 'معطل' : 'Inactive');
      final row = [
        exp.expenseCode,
        exp.nameAr,
        exp.nameEn ?? '-',
        exp.category,
        exp.defaultUnit,
        exp.defaultCurrency,
        statusStr,
      ];
      buffer.writeln(row.join('\t'));
    }

    return buffer.toString();
  }

  static Future<String?> exportTsv(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) async {
    final l = context.l10n;
    final content = generateTsvContent(context, expenses);
    final defaultFileName = 'clearance_expense_types_${DateTime.now().millisecondsSinceEpoch}.tsv';

    return FileSaveHelper.saveText(
      context: context,
      textContent: content,
      defaultFileName: defaultFileName,
      dialogTitle: l.expenseCatalogExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  // ===========================================================================
  // 3. CLIPBOARD DOSSIER EXPORT
  // ===========================================================================
  static String buildDossier(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final buffer = StringBuffer();
    final now = DateTime.now().toLocal().toString().split('.').first;
    final activeCount = expenses.where((e) => e.isActive).length;

    buffer.writeln('====================================================');
    buffer.writeln('📋 ${l.expenseCatalogPdfReportTitle}');
    buffer.writeln('====================================================');
    buffer.writeln('ℹ️  ${l.expenseCatalogPdfReportSubtitle}');
    buffer.writeln('📅 ${isArabic ? 'تاريخ الاستخراج' : 'Export Date'}: $now');
    buffer.writeln('📊 ${l.expenseCatalogTotalCountLabel(expenses.length)} | ${l.expenseCatalogActiveCountLabel(activeCount)}');
    buffer.writeln('----------------------------------------------------');

    for (var i = 0; i < expenses.length; i++) {
      final exp = expenses[i];
      final statusStr = exp.isActive
          ? (isArabic ? 'سارٍ' : 'Active')
          : (isArabic ? 'معطل' : 'Inactive');
      buffer.writeln('[${i + 1}] [${exp.expenseCode}] ${exp.nameAr}${exp.nameEn != null ? ' (${exp.nameEn})' : ''}');
      buffer.writeln('    • ${l.expenseCategoryCol}: ${exp.category}');
      buffer.writeln('    • ${l.calculationUnitCol}: ${exp.defaultUnit} | ${l.defaultCurrencyCol}: ${exp.defaultCurrency} | ${isArabic ? 'الحالة' : 'Status'}: $statusStr');
    }
    buffer.writeln('====================================================');

    return buffer.toString();
  }

  static Future<void> copyDossier(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) async {
    final l = context.l10n;
    final dossier = buildDossier(context, expenses);
    await CopyHelper.copy(context, dossier, customMessage: l.expenseCatalogDossierCopiedToast);
  }

  // ===========================================================================
  // 4. PDF GENERATION & PRINTING
  // ===========================================================================
  static Future<void> printOrSavePdf(
    BuildContext context,
    List<ClearanceExpenseTypeModel> expenses,
  ) async {
    final l = context.l10n;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();
    final activeCount = expenses.where((e) => e.isActive).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        header: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey700, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l.expenseCatalogPdfReportTitle,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.Text(
                      l.expenseCatalogPdfReportSubtitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isArabic ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ImportFlow ERP System',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                    ),
                    pw.Text(
                      DateTime.now().toString().split('.')[0],
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
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'ImportFlow Enterprise - Customs Clearance & Tariff Engine',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            pw.SizedBox(height: 8),

            // Summary Metrics Card
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpi(l.expenseCatalogTotalCountLabel(expenses.length), '${expenses.length}'),
                  _buildPdfKpi(l.expenseCatalogActiveCountLabel(activeCount), '$activeCount'),
                  _buildPdfKpi(isArabic ? 'تاريخ التقرير' : 'Report Date', DateTime.now().toLocal().toString().split(' ').first),
                ],
              ),
            ),

            pw.SizedBox(height: 12),

            // Expenses Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2), // Code
                1: const pw.FlexColumnWidth(2.5), // Arabic Name
                2: const pw.FlexColumnWidth(2.5), // English Name
                3: const pw.FlexColumnWidth(2.2), // Category
                4: const pw.FlexColumnWidth(1.6), // Unit
                5: const pw.FlexColumnWidth(1.0), // Currency
                6: const pw.FlexColumnWidth(1.0), // Status
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _buildPdfTableCell(l.expenseCodeCol, isHeader: true),
                    _buildPdfTableCell(l.expenseNameArCol, isHeader: true),
                    _buildPdfTableCell(l.expenseNameEnCol, isHeader: true),
                    _buildPdfTableCell(l.expenseCategoryCol, isHeader: true),
                    _buildPdfTableCell(l.calculationUnitCol, isHeader: true),
                    _buildPdfTableCell(l.defaultCurrencyCol, isHeader: true),
                    _buildPdfTableCell(isArabic ? 'الحالة' : 'Status', isHeader: true),
                  ],
                ),
                // Rows
                ...expenses.map((exp) {
                  final statusStr = exp.isActive
                      ? (isArabic ? 'سارٍ' : 'Active')
                      : (isArabic ? 'معطل' : 'Inactive');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: exp.isActive ? PdfColors.white : PdfColors.grey100,
                    ),
                    children: [
                      _buildPdfTableCell(exp.expenseCode, isBold: true),
                      _buildPdfTableCell(exp.nameAr, isBold: true),
                      _buildPdfTableCell(exp.nameEn ?? '-'),
                      _buildPdfTableCell(exp.category),
                      _buildPdfTableCell(exp.defaultUnit),
                      _buildPdfTableCell(exp.defaultCurrency ?? '-'),
                      _buildPdfTableCell(statusStr),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'clearance_expense_types_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildPdfKpi(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
      ],
    );
  }

  static pw.Widget _buildPdfTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.start,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 8,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
      ),
    );
  }
}

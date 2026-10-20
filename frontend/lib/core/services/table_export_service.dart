import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../export/export_language.dart';
import '../export/export_language_resolver.dart';
import '../export/widgets/export_language_dialog.dart';
import '../helpers/table_copy_helper.dart';
import 'file_save_helper.dart';
import '../utils/bidi_text.dart';

/// Optional section for additional summary tables in PDF and Excel exports.
class TableExportSection {
  final String title;
  final List<String> headers;
  final List<List<dynamic>> rows;

  const TableExportSection({
    required this.title,
    required this.headers,
    required this.rows,
  });
}

/// Optional context parameters for PDF export header banner and metadata card.
class TableExportHeaderContext {
  final String? title;
  final String? subtitle;
  final Map<String, String>? metadata;

  const TableExportHeaderContext({
    this.title,
    this.subtitle,
    this.metadata,
  });
}

/// Central unified service for generic tabular data export across Sorour Logistics ERP.
///
/// Converts any on-screen table into:
/// 1. Excel/TSV/CSV file with UTF-8 BOM, fully compatible with Arabic text in Microsoft Excel.
/// 2. Formatted PDF with Arabic Cairo font support, RTL alignment, and ERP branding.
class TableExportService {
  /// Cleans and quotes a CSV/TSV cell value.
  static String _formatCsvCell(dynamic value) {
    if (value == null) return '';
    final cleaned = stripBidiIsolates(value.toString()).replaceAll('\r', '').trim();
    if (cleaned.contains(',') || cleaned.contains('"') || cleaned.contains('\n') || cleaned.contains('\t')) {
      return '"${cleaned.replaceAll('"', '""')}"';
    }
    return cleaned;
  }

  /// Builds a clean CSV string with UTF-8 BOM from headers and rows, plus optional additional sections.
  static String buildCsvContent(
    List<String> headers,
    List<List<dynamic>> rows, {
    List<TableExportSection>? additionalSections,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM for Excel Arabic support
    buffer.writeln(headers.map(_formatCsvCell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_formatCsvCell).join(','));
    }

    if (additionalSections != null && additionalSections.isNotEmpty) {
      for (final section in additionalSections) {
        buffer.writeln(); // Empty row separator
        buffer.writeln(_formatCsvCell(section.title));
        buffer.writeln(section.headers.map(_formatCsvCell).join(','));
        for (final row in section.rows) {
          buffer.writeln(row.map(_formatCsvCell).join(','));
        }
      }
    }

    return buffer.toString();
  }

  /// Builds a clean TSV string with UTF-8 BOM from headers and rows, plus optional additional sections.
  static String buildTsvContent(
    List<String> headers,
    List<List<dynamic>> rows, {
    List<TableExportSection>? additionalSections,
  }) {
    final buffer = StringBuffer();
    buffer.write('\uFEFF'); // UTF-8 BOM
    buffer.writeln(headers.map((h) => TableCopyHelper.cleanCell(h)).join('\t'));
    for (final row in rows) {
      buffer.writeln(row.map((c) => TableCopyHelper.cleanCell(c)).join('\t'));
    }

    if (additionalSections != null && additionalSections.isNotEmpty) {
      for (final section in additionalSections) {
        buffer.writeln(); // Empty row separator
        buffer.writeln(TableCopyHelper.cleanCell(section.title));
        buffer.writeln(section.headers.map((h) => TableCopyHelper.cleanCell(h)).join('\t'));
        for (final row in section.rows) {
          buffer.writeln(row.map((c) => TableCopyHelper.cleanCell(c)).join('\t'));
        }
      }
    }

    return buffer.toString();
  }

  /// Exports any generic tabular data to CSV with UTF-8 BOM.
  /// Automatically prompts [ExportLanguageDialog] if [lang] is null.
  static Future<String?> exportTableToCsv({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    required String importFileNameOrCode,
    List<TableExportSection>? additionalSections,
    String? customFileName,
    ExportLanguage? lang,
  }) async {
    ExportLanguage? selectedLang = lang;
    selectedLang ??= await ExportLanguageDialog.show(context);
    if (selectedLang == null) return null;

    final content = buildCsvContent(headers, rows, additionalSections: additionalSections);
    final bytes = utf8.encode(content);

    return FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      extension: 'csv',
      customDialogTitle: selectedLang.isArabic ? 'تصدير جدول البيانات (CSV)' : 'Export Data Table (CSV)',
      showNotification: true,
    );
  }

  /// Exports any generic tabular data to Excel (CSV/TSV with UTF-8 BOM)
  /// using the unified Save As dialog and standard file naming.
  /// Automatically prompts [ExportLanguageDialog] if [lang] is null.
  static Future<String?> exportTableToExcel({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    required String importFileNameOrCode,
    List<TableExportSection>? additionalSections,
    String? customFileName,
    bool asTsv = false,
    ExportLanguage? lang,
  }) async {
    ExportLanguage? selectedLang = lang;
    selectedLang ??= await ExportLanguageDialog.show(context);
    if (selectedLang == null) return null;

    final content = asTsv
        ? buildTsvContent(headers, rows, additionalSections: additionalSections)
        : buildCsvContent(headers, rows, additionalSections: additionalSections);
    final bytes = utf8.encode(content);
    final extension = asTsv ? 'tsv' : 'csv';

    return FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: bytes,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      extension: extension,
      customDialogTitle: selectedLang.isArabic
          ? 'تصدير جدول البيانات (Excel)'
          : 'Export Data Table (Excel)',
      showNotification: true,
    );
  }

  /// Generates a formatted, multi-page PDF document for generic tabular data
  /// with Cairo Arabic font, RTL/LTR layout based on language, ERP banner, and clean Key-Value Grid metadata card.
  static Future<pw.Document> generatePdfDocument({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    String? importFileNameOrCode,
    TableExportHeaderContext? headerContext,
    List<TableExportSection>? additionalSections,
    PdfPageFormat? pageFormat,
    ExportLanguage? lang = ExportLanguage.ar,
  }) async {
    final pdf = pw.Document();
    final isAr = lang?.isArabic ?? true;

    // 1. Load Arabic Cairo fonts and Sorour brand assets
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();
    final watermarkImage = await ExportLanguageResolver.loadWatermarkImage();
    final headerLogoImage = await ExportLanguageResolver.loadHeaderLogoImage();

    // 2. Select landscape if table has > 5 columns for readability
    final effectiveFormat = pageFormat ?? (headers.length > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4);

    final title = headerContext?.title ?? stageName;
    final subtitle = headerContext?.subtitle ??
        (isAr ? 'Sorour Logistics ERP — تقرير بيانات الجدول' : 'Sorour Logistics ERP — Official Table Data Report');
    final metadata = headerContext?.metadata ?? {};

    // Clean data cells for PDF display
    final cleanHeaders = headers.map((h) => TableCopyHelper.cleanCell(h)).toList();
    final cleanData = rows.map((r) => r.map((c) => TableCopyHelper.cleanCell(c)).toList()).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: effectiveFormat,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        pageTheme: pw.PageTheme(
          pageFormat: effectiveFormat,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
          textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          buildBackground: (pw.Context ctx) {
            if (watermarkImage == null) return pw.SizedBox();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.045,
                  child: pw.Image(
                    watermarkImage,
                    width: (effectiveFormat.width > effectiveFormat.height) ? 340 : 260,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0F386A'), // Sorour Navy
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (headerLogoImage != null) ...[
                          pw.Image(headerLogoImage, height: 28, fit: pw.BoxFit.contain),
                          pw.SizedBox(width: 10),
                        ],
                        pw.Column(
                          crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              title,
                              style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              subtitle,
                              style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if ((importFileNameOrCode ?? '').isNotEmpty)
                      pw.Text(
                        importFileNameOrCode!,
                        style: pw.TextStyle(color: PdfColor.fromHex('#88B6D2'), fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                  ],
                ),
              ),
              if (metadata.isNotEmpty && ctx.pageNumber == 1) ...[
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(2.0),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(2.0),
                  },
                  children: () {
                    final entries = metadata.entries.toList();
                    final gridRows = <pw.TableRow>[];
                    for (int i = 0; i < entries.length; i += 2) {
                      final e1 = entries[i];
                      final hasSecond = i + 1 < entries.length;
                      final e2 = hasSecond ? entries[i + 1] : null;

                      gridRows.add(
                        pw.TableRow(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              color: PdfColor.fromHex('#F1F5F9'),
                              child: pw.Text(
                                '${e1.key}:',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8.5,
                                  color: PdfColor.fromHex('#1E293B'),
                                ),
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              color: PdfColors.white,
                              child: pw.Text(
                                e1.value,
                                style: const pw.TextStyle(
                                  fontSize: 8.5,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ),
                            if (e2 != null) ...[
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                color: PdfColor.fromHex('#F1F5F9'),
                                child: pw.Text(
                                  '${e2.key}:',
                                  style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 8.5,
                                    color: PdfColor.fromHex('#1E293B'),
                                  ),
                                ),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                color: PdfColors.white,
                                child: pw.Text(
                                  e2.value,
                                  style: const pw.TextStyle(
                                    fontSize: 8.5,
                                    color: PdfColors.grey800,
                                  ),
                                ),
                              ),
                            ] else ...[
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                color: PdfColor.fromHex('#F8FAFC'),
                                child: pw.Text(''),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                color: PdfColors.white,
                                child: pw.Text(''),
                              ),
                            ],
                          ],
                        ),
                      );
                    }
                    return gridRows;
                  }(),
                ),
              ],
              pw.SizedBox(height: 10),
            ],
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
                  isAr
                      ? 'تاريخ الإنشاء: ${DateTime.now().toString().substring(0, 19)}'
                      : 'Generated: ${DateTime.now().toString().substring(0, 19)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  isAr
                      ? 'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}'
                      : 'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          final widgets = <pw.Widget>[
            pw.TableHelper.fromTextArray(
              headers: cleanHeaders,
              data: cleanData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#074E8C'), // Sorour Deep Ocean Blue
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              headerAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
              ),
            ),
          ];

          if (additionalSections != null && additionalSections.isNotEmpty) {
            for (final section in additionalSections) {
              final secHeaders = section.headers.map((h) => TableCopyHelper.cleanCell(h)).toList();
              final secData = section.rows.map((r) => r.map((c) => TableCopyHelper.cleanCell(c)).toList()).toList();

              widgets.add(pw.SizedBox(height: 14));
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#2C3E50'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    section.title,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
              widgets.add(
                pw.TableHelper.fromTextArray(
                  headers: secHeaders,
                  data: secData,
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.5,
                    color: PdfColors.white,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#475569'),
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                  headerAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                  rowDecoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                    ),
                  ),
                  oddRowDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                  ),
                ),
              );
            }
          }

          return widgets;
        },
      ),
    );

    return pdf;
  }

  /// Exports any generic tabular data to a formatted, multi-page PDF document
  /// with Cairo Arabic font, RTL layout, ERP banner, and clean Key-Value Grid metadata card.
  /// Automatically prompts [ExportLanguageDialog] if [lang] is null.
  static Future<String?> exportTableToPdf({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    required String importFileNameOrCode,
    TableExportHeaderContext? headerContext,
    List<TableExportSection>? additionalSections,
    PdfPageFormat? pageFormat,
    ExportLanguage? lang,
  }) async {
    ExportLanguage? selectedLang = lang;
    selectedLang ??= await ExportLanguageDialog.show(context);
    if (selectedLang == null) return null;

    final pdf = await generatePdfDocument(
      headers: headers,
      rows: rows,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      headerContext: headerContext,
      additionalSections: additionalSections,
      pageFormat: pageFormat,
      lang: selectedLang,
    );

    final pdfBytes = await pdf.save();
    if (!context.mounted) return null;

    return FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: pdfBytes,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      extension: 'pdf',
      customDialogTitle: selectedLang.isArabic ? 'تصدير جدول البيانات (PDF)' : 'Export Data Table (PDF)',
      showNotification: true,
    );
  }

  /// Direct print or print-preview for any generic tabular data via Printing.layoutPdf.
  /// Automatically prompts [ExportLanguageDialog] if [lang] is null.
  static Future<void> printTable({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    String? importFileNameOrCode,
    TableExportHeaderContext? headerContext,
    List<TableExportSection>? additionalSections,
    PdfPageFormat? pageFormat,
    ExportLanguage? lang,
  }) async {
    ExportLanguage? selectedLang = lang;
    selectedLang ??= await ExportLanguageDialog.show(context);
    if (selectedLang == null) return;

    final pdf = await generatePdfDocument(
      headers: headers,
      rows: rows,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      headerContext: headerContext,
      additionalSections: additionalSections,
      pageFormat: pageFormat,
      lang: selectedLang,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: stageName,
    );
  }
}


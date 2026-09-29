import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  /// Exports any generic tabular data to Excel (CSV/TSV with UTF-8 BOM)
  /// using the unified Save As dialog and standard file naming.
  static Future<String?> exportTableToExcel({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    required String importFileNameOrCode,
    List<TableExportSection>? additionalSections,
    String? customFileName,
    bool asTsv = false,
  }) async {
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
      customDialogTitle: 'تصدير جدول البيانات ($extension)',
      showNotification: true,
    );
  }

  /// Exports any generic tabular data to a formatted, multi-page PDF document
  /// with Cairo Arabic font, RTL layout, ERP banner, and clean Key-Value Grid metadata card.
  static Future<String?> exportTableToPdf({
    required BuildContext context,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String stageName,
    required String importFileNameOrCode,
    TableExportHeaderContext? headerContext,
    List<TableExportSection>? additionalSections,
    PdfPageFormat? pageFormat,
  }) async {
    final pdf = pw.Document();

    // 1. Load Arabic Cairo fonts
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    // 2. Select landscape if table has > 5 columns for readability
    final effectiveFormat = pageFormat ?? (headers.length > 5 ? PdfPageFormat.a4.landscape : PdfPageFormat.a4);

    final title = headerContext?.title ?? stageName;
    final subtitle = headerContext?.subtitle ?? 'Sorour Logistics ERP — تقرير بيانات الجدول';
    final metadata = headerContext?.metadata ?? {};

    // Clean data cells for PDF display
    final cleanHeaders = headers.map((h) => TableCopyHelper.cleanCell(h)).toList();
    final cleanData = rows.map((r) => r.map((c) => TableCopyHelper.cleanCell(c)).toList()).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: effectiveFormat,
        theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2C3E50'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                    pw.Text(
                      importFileNameOrCode,
                      style: pw.TextStyle(color: PdfColor.fromHex('#3498DB'), fontSize: 11, fontWeight: pw.FontWeight.bold),
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
                  'تاريخ الإنشاء: ${DateTime.now().toString().substring(0, 19)}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'صفحة ${ctx.pageNumber} من ${ctx.pagesCount}',
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
                color: PdfColor.fromHex('#34495E'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              cellAlignment: pw.Alignment.centerRight,
              headerAlignment: pw.Alignment.centerRight,
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
                  cellAlignment: pw.Alignment.centerRight,
                  headerAlignment: pw.Alignment.centerRight,
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

    final pdfBytes = await pdf.save();
    if (!context.mounted) return null;

    return FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: pdfBytes,
      stageName: stageName,
      importFileNameOrCode: importFileNameOrCode,
      extension: 'pdf',
      customDialogTitle: 'تصدير جدول البيانات (PDF)',
      showNotification: true,
    );
  }
}


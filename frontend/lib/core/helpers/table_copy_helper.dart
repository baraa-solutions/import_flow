import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/bidi_text.dart';

/// Central helper for selective table data copy in Sorour Logistics ERP.
///
/// Converts table rows and cells into clean, tab-separated values (TSV)
/// that paste directly and perfectly into Microsoft Excel and Google Sheets.
class TableCopyHelper {
  /// Cleans a single cell string value for TSV compatibility.
  /// Replaces tabs with spaces, strips carriage returns and newlines.
  static String cleanCell(dynamic value) {
    if (value == null) return '';
    final str = stripBidiIsolates(value.toString());
    return str
        .replaceAll('\t', ' ')
        .replaceAll('\r', '')
        .replaceAll('\n', ' ')
        .trim();
  }

  /// Formats a single row of cell values as a tab-separated string.
  static String formatRowAsTsv(List<dynamic> cellValues) {
    return cellValues.map(cleanCell).join('\t');
  }

  /// Formats a single row with its headers as a two-line TSV string.
  static String formatRowWithHeadersAsTsv(List<String> headers, List<dynamic> cellValues) {
    final headerLine = headers.map(cleanCell).join('\t');
    final dataLine = cellValues.map(cleanCell).join('\t');
    return '$headerLine\n$dataLine';
  }

  /// Formats multiple rows with headers into a full TSV table string.
  static String formatTableAsTsv(List<String> headers, List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(cleanCell).join('\t'));
    for (final row in rows) {
      buffer.writeln(row.map(cleanCell).join('\t'));
    }
    return buffer.toString().trimRight();
  }

  /// Copies a single row's cell values to the system clipboard as TSV.
  /// Displays a localized confirmation SnackBar.
  static Future<void> copyRow(
    BuildContext context,
    List<dynamic> cellValues, {
    List<String>? headers,
    bool includeHeaders = false,
    String? customMessage,
  }) async {
    final tsv = (includeHeaders && headers != null && headers.isNotEmpty)
        ? formatRowWithHeadersAsTsv(headers, cellValues)
        : formatRowAsTsv(cellValues);

    if (tsv.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: stripBidiIsolates(tsv)));
    if (!context.mounted) return;

    final message = customMessage ?? (Localizations.localeOf(context).languageCode == 'ar'
        ? 'تم نسخ بيانات السطر بنجاح (جاهزة للصق في إكسيل)'
        : 'Row data copied to clipboard (Excel paste ready)');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 380,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppTheme.flatCharcoal,
        duration: const Duration(milliseconds: 1800),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_rows_rounded, color: AppTheme.flatEmerald, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Copies an entire table (headers + all rows) to clipboard as TSV.
  static Future<void> copyTable(
    BuildContext context,
    List<String> headers,
    List<List<dynamic>> rows, {
    String? customMessage,
  }) async {
    final tsv = formatTableAsTsv(headers, rows);
    if (tsv.trim().isEmpty) return;

    await Clipboard.setData(ClipboardData(text: stripBidiIsolates(tsv)));
    if (!context.mounted) return;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final message = customMessage ?? (isAr
        ? 'تم نسخ جدول البيانات بالكامل (${rows.length} سطر) إلى الحافظة'
        : 'Table copied to clipboard (${rows.length} rows)');

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: 400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppTheme.flatCharcoal,
        duration: const Duration(milliseconds: 2000),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.flatEmerald, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

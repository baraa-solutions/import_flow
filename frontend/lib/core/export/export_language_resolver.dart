import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'export_language.dart';
import 'export_translations.dart';

/// Central resolver for language-specific export behavior across Sorour Logistics ERP.
/// Encapsulates text direction, PDF fonts, bidi isolation, number/date formatting,
/// bilingual field fallback, and localized file naming.
class ExportLanguageResolver {
  final ExportLanguage lang;

  const ExportLanguageResolver({this.lang = ExportLanguage.ar});

  bool get isArabic => lang.isArabic;
  bool get isEnglish => lang.isEnglish;

  TextDirection get textDirection => isArabic ? TextDirection.rtl : TextDirection.ltr;
  pw.TextDirection get pdfTextDirection => isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  pw.Alignment get pdfAlignStart => isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft;
  pw.CrossAxisAlignment get pdfCrossAlignStart =>
      isArabic ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.start;

  /// Translates a key using the central dictionary.
  String tr(String key) => ExportTranslations.tr(key, lang: lang);

  /// Isolates embedded Latin / digit / code strings in Arabic PDF documents.
  /// Uses Unicode Left-to-Right Isolate (\u2066) and Pop Directional Isolate (\u2069).
  /// This prevents Arabic RTL text from scrambling English street names, postal codes,
  /// SWIFT codes, emails, URLs, or registration IDs.
  String bidiIsolate(String? value) {
    if (value == null || value.trim().isEmpty) return '-';
    final clean = value.trim();
    if (isArabic) {
      // If the string contains ASCII letters or digits, wrap in LRI/PDI
      return '\u2066$clean\u2069';
    }
    return clean;
  }

  /// Formats date uniformly (YYYY-MM-DD).
  String formatDate(DateTime? date) {
    if (date == null) return '-';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Resolves bilingual database fields (e.g. name_ar vs name_en).
  /// Respects user's chosen language, falling back to the alternate language
  /// if the preferred field is empty, never auto-translating free-form user input.
  String resolveBilingual({String? ar, String? en}) {
    if (isArabic) {
      if (ar != null && ar.trim().isNotEmpty) return ar.trim();
      return (en != null && en.trim().isNotEmpty) ? en.trim() : '-';
    } else {
      if (en != null && en.trim().isNotEmpty) return en.trim();
      return (ar != null && ar.trim().isNotEmpty) ? ar.trim() : '-';
    }
  }

  /// Asynchronously loads appropriate PDF fonts based on language.
  /// Arabic uses Cairo (with complete shaping for Arabic ligatures and letters).
  /// English uses Roboto (clean, international typography).
  Future<pw.ThemeData> getPdfTheme() async {
    if (isArabic) {
      final arabicRegular = await PdfGoogleFonts.cairoRegular();
      final arabicBold = await PdfGoogleFonts.cairoBold();
      return pw.ThemeData.withFont(base: arabicRegular, bold: arabicBold);
    } else {
      final englishRegular = await PdfGoogleFonts.robotoRegular();
      final englishBold = await PdfGoogleFonts.robotoBold();
      return pw.ThemeData.withFont(base: englishRegular, bold: englishBold);
    }
  }

  /// Builds a sanitized, language-specific file name.
  /// E.g.
  /// Arabic: بطاقة_بيانات_الشركة_IMP-123456_2026-10-18.pdf
  /// English: Company_Data_Card_IMP-123456_2026-10-18.pdf
  String buildFileName({
    required String prefixKey,
    required String identifier,
    required String extension,
  }) {
    final prefix = tr(prefixKey);
    final cleanId = identifier
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .trim();
    final date = formatDate(DateTime.now());
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '${prefix}_${cleanId}_$date.$ext';
  }

  /// Cleans strings for Excel / CSV export.
  /// Strips Unicode isolates from exported CSV to prevent CSV corruption.
  static String cleanExcelCell(dynamic value) {
    if (value == null) return '';
    final text = value.toString().replaceAll(RegExp(r'[\u2066-\u2069]'), '').trim();
    if (text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}

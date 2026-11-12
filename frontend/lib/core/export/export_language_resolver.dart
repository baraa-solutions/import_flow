import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
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

  static pw.MemoryImage? _cachedWatermark;
  static pw.MemoryImage? _cachedHeaderLogo;

  /// Loads the official Sorour brand watermark image for subtle PDF page backgrounds.
  static Future<pw.MemoryImage?> loadWatermarkImage() async {
    if (_cachedWatermark != null) return _cachedWatermark;
    try {
      final bytes = await rootBundle.load('assets/brand/sorour_logo_watermark.png');
      _cachedWatermark = pw.MemoryImage(bytes.buffer.asUint8List());
      return _cachedWatermark;
    } catch (_) {
      return null;
    }
  }

  /// Loads the official Sorour brand logo image for PDF headers.
  static Future<pw.MemoryImage?> loadHeaderLogoImage() async {
    if (_cachedHeaderLogo != null) return _cachedHeaderLogo;
    try {
      final bytes = await rootBundle.load('assets/brand/sorour_logo_dark.png');
      _cachedHeaderLogo = pw.MemoryImage(bytes.buffer.asUint8List());
      return _cachedHeaderLogo;
    } catch (_) {
      return null;
    }
  }

  /// Builds a unified PageTheme with Cairo/Roboto typography and the Sorour background watermark.
  Future<pw.PageTheme> getPdfPageTheme({
    PdfPageFormat? pageFormat,
    pw.MemoryImage? watermarkImage,
  }) async {
    final theme = await getPdfTheme();
    final watermark = watermarkImage ?? await loadWatermarkImage();
    final format = pageFormat ?? PdfPageFormat.a4;
    return pw.PageTheme(
      pageFormat: format,
      theme: theme,
      textDirection: pdfTextDirection,
      buildBackground: (pw.Context ctx) {
        if (watermark == null) return pw.SizedBox();
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Center(
            child: pw.Opacity(
              opacity: 0.045,
              child: pw.Image(
                watermark,
                width: (format.width > format.height) ? 320 : 250,
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the official Sorour brand header banner for PDF reports.
  pw.Widget buildPdfHeaderBanner({
    required String title,
    String? subtitle,
    pw.MemoryImage? logo,
    pw.Widget? trailing,
  }) {
    return pw.Container(
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
              if (logo != null) ...[
                pw.Image(logo, height: 28, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pdfCrossAlignStart,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      subtitle,
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Export file name: `[<entity name>_]<localized type>_<identifier>_<yyyy-MM-dd>.<ext>`.
  /// [entityName] (company / supplier / partner name) leads the name so a shared file is recognisable
  /// without opening it; every part is made filesystem-safe.
  /// E.g. `Archi_Brands_Company_Data_Card_IMP-123456_2026-10-18.pdf`.
  String buildFileName({
    required String prefixKey,
    required String identifier,
    required String extension,
    String? entityName,
  }) {
    final parts = [
      if (entityName != null && sanitizeFileNamePart(entityName).isNotEmpty) sanitizeFileNamePart(entityName),
      tr(prefixKey),
      sanitizeFileNamePart(identifier),
      formatDate(DateTime.now()),
    ].where((p) => p.isNotEmpty);
    final ext = extension.startsWith('.') ? extension.substring(1) : extension;
    return '${parts.join('_')}.$ext';
  }

  /// One file-name segment: no characters illegal on Windows / macOS, no whitespace runs, no repeated or
  /// edge underscores / dots, at most [maxLength] characters.
  static String sanitizeFileNamePart(String value, {int maxLength = 60}) {
    var clean = value
        .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_.]+|[_.]+$'), '');
    if (clean.length > maxLength) clean = clean.substring(0, maxLength).replaceAll(RegExp(r'[_.]+$'), '');
    return clean;
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

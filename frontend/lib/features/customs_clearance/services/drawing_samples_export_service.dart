import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_clearance_model.dart';

/// Dedicated Export & Dossier Service for Screen 60:
/// Customs Clearance - Drawing Samples & Shortage Tracking.
class DrawingSamplesExportService {
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

  static String getSampleStatusLabel(BuildContext context, String? status) {
    final l = context.l10n;
    if (status == 'Approved' || status == 'PASSED' || status == 'CONFORMING') {
      return l.customsClearanceSamplePassed;
    }
    if (status == 'Rejected' || status == 'NON_CONFORMING') {
      return l.ccInsStatusRejected;
    }
    return l.customsClearanceSamplePending;
  }

  static String getShortageActionLabel(BuildContext context, String? action) {
    final l = context.l10n;
    switch (action) {
      case 'DEDUCT_DUTY':
        return l.drawingSamplesShortageActionDeductDuty;
      case 'CARRIER_CLAIM':
        return l.drawingSamplesShortageActionCarrierClaim;
      case 'SURVEY_ENDORSED':
        return l.drawingSamplesShortageActionSurveyEndorsement;
      default:
        return action ?? '-';
    }
  }

  /// Exports drawn samples as TSV string with UTF-8 BOM
  static String exportSamplesToTsv(
    BuildContext context,
    List<CustomsClearanceModel> samples, {
    String Function(int id)? fileCodeResolver,
  }) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      l.drawingSamplesColSampleCode,
      l.drawingSamplesColFileCode,
      l.drawingSamplesColSampledBodies,
      l.drawingSamplesColSamplingDate,
      l.drawingSamplesColGoeicCert,
      l.drawingSamplesColTestStatus,
      l.drawingSamplesColLabResult,
      l.drawingSamplesFieldNotes,
    ].join('\t'));

    for (final s in samples) {
      final bodies = s.sampledRegulatoryBodies.map((b) => DomainEnums.label(l, DomainEnumType.regulatoryBody, b)).join(', ');
      final fileCode = fileCodeResolver != null ? fileCodeResolver(s.importFileId) : '—';
      final statusStr = getSampleStatusLabel(context, s.sampleTestStatus);
      buf.writeln([
        _cleanTsv(s.samplingRecordNo ?? '—'),
        _cleanTsv(fileCode),
        _cleanTsv(bodies.isNotEmpty ? bodies : '—'),
        _cleanTsv(s.samplingDate ?? '—'),
        _cleanTsv(s.goeicCertificateNo ?? '—'),
        _cleanTsv(statusStr),
        _cleanTsv(s.labTestResult),
        _cleanTsv(s.inspectionNotes ?? '—'),
      ].join('\t'));
    }

    return buf.toString();
  }

  /// Exports shortage reconciliation entries as TSV string with UTF-8 BOM
  static String exportShortagesToTsv(BuildContext context, List<Map<String, dynamic>> shortages) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      l.drawingSamplesColShortageCode,
      l.drawingSamplesColContainerPkg,
      l.drawingSamplesColItemDesc,
      l.drawingSamplesColManifestQty,
      l.drawingSamplesColLandedQty,
      l.drawingSamplesColShortageQty,
      l.drawingSamplesColShortagePct,
      l.drawingSamplesColShortageAction,
      l.drawingSamplesColShortageNotes,
    ].join('\t'));

    for (final item in shortages) {
      final actionLabel = getShortageActionLabel(context, item['action'] as String?);
      buf.writeln([
        _cleanTsv((item['shortage_id'] ?? '').toString()),
        _cleanTsv((item['container_no'] ?? '').toString()),
        _cleanTsv((item['item_desc'] ?? '').toString()),
        _cleanTsv((item['manifest_qty'] ?? '0').toString()),
        _cleanTsv((item['landed_qty'] ?? '0').toString()),
        _cleanTsv((item['shortage_qty'] ?? '0').toString()),
        _cleanTsv('${item['shortage_pct'] ?? '0'}%'),
        _cleanTsv(actionLabel),
        _cleanTsv((item['notes'] ?? '-').toString()),
      ].join('\t'));
    }

    return buf.toString();
  }

  /// Exports drawn samples as CSV string with UTF-8 BOM
  static String exportSamplesToCsv(
    BuildContext context,
    List<CustomsClearanceModel> samples, {
    String Function(int id)? fileCodeResolver,
  }) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      _csvQuote(l.drawingSamplesColSampleCode),
      _csvQuote(l.drawingSamplesColFileCode),
      _csvQuote(l.drawingSamplesColSampledBodies),
      _csvQuote(l.drawingSamplesColSamplingDate),
      _csvQuote(l.drawingSamplesColGoeicCert),
      _csvQuote(l.drawingSamplesColTestStatus),
      _csvQuote(l.drawingSamplesColLabResult),
      _csvQuote(l.drawingSamplesFieldNotes),
    ].join(','));

    for (final s in samples) {
      final bodies = s.sampledRegulatoryBodies.map((b) => DomainEnums.label(l, DomainEnumType.regulatoryBody, b)).join(', ');
      final fileCode = fileCodeResolver != null ? fileCodeResolver(s.importFileId) : '—';
      final statusStr = getSampleStatusLabel(context, s.sampleTestStatus);
      buf.writeln([
        _csvQuote(s.samplingRecordNo ?? '—'),
        _csvQuote(fileCode),
        _csvQuote(bodies.isNotEmpty ? bodies : '—'),
        _csvQuote(s.samplingDate ?? '—'),
        _csvQuote(s.goeicCertificateNo ?? '—'),
        _csvQuote(statusStr),
        _csvQuote(s.labTestResult),
        _csvQuote(s.inspectionNotes ?? '—'),
      ].join(','));
    }

    return buf.toString();
  }

  /// Exports shortage reconciliation entries as CSV string with UTF-8 BOM
  static String exportShortagesToCsv(BuildContext context, List<Map<String, dynamic>> shortages) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      _csvQuote(l.drawingSamplesColShortageCode),
      _csvQuote(l.drawingSamplesColContainerPkg),
      _csvQuote(l.drawingSamplesColItemDesc),
      _csvQuote(l.drawingSamplesColManifestQty),
      _csvQuote(l.drawingSamplesColLandedQty),
      _csvQuote(l.drawingSamplesColShortageQty),
      _csvQuote(l.drawingSamplesColShortagePct),
      _csvQuote(l.drawingSamplesColShortageAction),
      _csvQuote(l.drawingSamplesColShortageNotes),
    ].join(','));

    for (final item in shortages) {
      final actionLabel = getShortageActionLabel(context, item['action'] as String?);
      buf.writeln([
        _csvQuote((item['shortage_id'] ?? '').toString()),
        _csvQuote((item['container_no'] ?? '').toString()),
        _csvQuote((item['item_desc'] ?? '').toString()),
        _csvQuote((item['manifest_qty'] ?? '0').toString()),
        _csvQuote((item['landed_qty'] ?? '0').toString()),
        _csvQuote((item['shortage_qty'] ?? '0').toString()),
        _csvQuote('${item['shortage_pct'] ?? '0'}%'),
        _csvQuote(actionLabel),
        _csvQuote((item['notes'] ?? '-').toString()),
      ].join(','));
    }

    return buf.toString();
  }

  /// Saves drawn samples TSV to file
  static Future<void> saveSamplesTsvToFile(
    BuildContext context,
    List<CustomsClearanceModel> samples, {
    String Function(int id)? fileCodeResolver,
  }) async {
    final l = context.l10n;
    final tsvContent = exportSamplesToTsv(context, samples, fileCodeResolver: fileCodeResolver);
    await CopyHelper.copy(context, tsvContent, customMessage: l.drawingSamplesCopiedTsvSuccess);
    if (!context.mounted) return;

    final filename = 'Drawing_Samples_${DateTime.now().millisecondsSinceEpoch}.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.drawingSamplesExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Saves drawn samples CSV to file
  static Future<void> saveSamplesCsvToFile(
    BuildContext context,
    List<CustomsClearanceModel> samples, {
    String Function(int id)? fileCodeResolver,
  }) async {
    final l = context.l10n;
    final csvContent = exportSamplesToCsv(context, samples, fileCodeResolver: fileCodeResolver);
    await CopyHelper.copy(context, csvContent, customMessage: l.drawingSamplesCopiedExcelSuccess);
    if (!context.mounted) return;

    final filename = 'Drawing_Samples_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: filename,
      dialogTitle: l.drawingSamplesExportExcelBtn,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Saves shortage reconciliation TSV to file
  static Future<void> saveShortagesTsvToFile(BuildContext context, List<Map<String, dynamic>> shortages) async {
    final l = context.l10n;
    final tsvContent = exportShortagesToTsv(context, shortages);
    await CopyHelper.copy(context, tsvContent, customMessage: l.drawingSamplesCopiedTsvSuccess);
    if (!context.mounted) return;

    final filename = 'Cargo_Shortage_Reconciliation_${DateTime.now().millisecondsSinceEpoch}.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.drawingSamplesExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Builds a complete text dossier summarizing both Drawn Samples and Shortage Reconciliation
  static String buildDrawingSamplesDossier({
    required BuildContext context,
    required List<CustomsClearanceModel> samples,
    List<Map<String, dynamic>> shortages = const [],
    String Function(int id)? fileCodeResolver,
  }) {
    final l = context.l10n;
    final buf = StringBuffer();

    buf.writeln('================================================================');
    buf.writeln('IMPORTFLOW ERP — ${l.drawingSamplesScreenTitle}');
    buf.writeln('================================================================');
    buf.writeln(l.drawingSamplesScreenSubtitle);
    buf.writeln('Timestamp: ${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('');

    // Summary KPIs
    final totalSamples = samples.length;
    final passedSamples = samples.where((s) => s.sampleTestStatus == 'Approved' || s.labTestResult == 'CONFORMING').length;
    final pendingSamples = samples.where((s) => s.sampleTestStatus == 'Samples Under Testing' || s.labTestResult == 'PENDING').length;

    buf.writeln('--- ${l.drawingSamplesSummaryHeader} ---');
    buf.writeln('• ${l.drawingSamplesKpiTotalSamples}: $totalSamples');
    buf.writeln('• ${l.drawingSamplesKpiPassedSamples}: $passedSamples');
    buf.writeln('• ${l.drawingSamplesKpiPendingSamples}: $pendingSamples');
    buf.writeln('');

    // Section 1: Laboratory Drawn Samples
    buf.writeln('----------------------------------------------------------------');
    buf.writeln('1. ${l.drawingSamplesTabDrawnSamples} (${samples.length})');
    buf.writeln('----------------------------------------------------------------');
    if (samples.isEmpty) {
      buf.writeln(l.drawingSamplesEmptySamples);
    } else {
      for (int i = 0; i < samples.length; i++) {
        final s = samples[i];
        final fileCode = fileCodeResolver != null ? fileCodeResolver(s.importFileId) : '—';
        final bodies = s.sampledRegulatoryBodies.map((b) => DomainEnums.label(l, DomainEnumType.regulatoryBody, b)).join(', ');
        final statusStr = getSampleStatusLabel(context, s.sampleTestStatus);
        buf.writeln('[${i + 1}] ${s.samplingRecordNo ?? '—'} | $fileCode');
        buf.writeln('   • ${l.drawingSamplesColSampledBodies}: ${bodies.isNotEmpty ? bodies : '—'}');
        buf.writeln('   • ${l.drawingSamplesColSamplingDate}: ${s.samplingDate ?? '—'} | ${l.drawingSamplesColGoeicCert}: ${s.goeicCertificateNo ?? '—'}');
        buf.writeln('   • ${l.drawingSamplesColTestStatus}: $statusStr | ${l.drawingSamplesColLabResult}: ${s.labTestResult}');
        if (s.inspectionNotes != null && s.inspectionNotes!.trim().isNotEmpty) {
          buf.writeln('   • ${l.drawingSamplesFieldNotes}: ${s.inspectionNotes}');
        }
      }
    }
    buf.writeln('');

    // Section 2: Cargo Examination & Shortage Reconciliation
    buf.writeln('----------------------------------------------------------------');
    buf.writeln('2. ${l.drawingSamplesShortageSectionTitle}');
    buf.writeln('----------------------------------------------------------------');
    if (shortages.isEmpty) {
      buf.writeln(l.ccShortageNotAvailable);
    } else {
      for (int i = 0; i < shortages.length; i++) {
        final item = shortages[i];
        final actionLabel = getShortageActionLabel(context, item['action'] as String?);
        buf.writeln('[${i + 1}] ${item['shortage_id']} | ${item['container_no']} — ${item['item_desc']}');
        buf.writeln('   • ${l.drawingSamplesColManifestQty}: ${item['manifest_qty']} | ${l.drawingSamplesColLandedQty}: ${item['landed_qty']}');
        buf.writeln('   • ${l.drawingSamplesColShortageQty}: ${item['shortage_qty']} (${item['shortage_pct']}%)');
        buf.writeln('   • ${l.drawingSamplesColShortageAction}: $actionLabel');
        if (item['notes'] != null && item['notes'].toString().isNotEmpty && item['notes'] != '-') {
          buf.writeln('   • ${l.drawingSamplesColShortageNotes}: ${item['notes']}');
        }
      }
    }
    buf.writeln('');
    buf.writeln('================================================================');
    buf.writeln('IMPORTFLOW ERP — Customs Clearance & Examination Subsystem');
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies full plain-text dossier to clipboard
  static Future<void> copyDossierToClipboard({
    required BuildContext context,
    required List<CustomsClearanceModel> samples,
    List<Map<String, dynamic>> shortages = const [],
    String Function(int id)? fileCodeResolver,
  }) async {
    final l = context.l10n;
    final dossier = buildDrawingSamplesDossier(
      context: context,
      samples: samples,
      shortages: shortages,
      fileCodeResolver: fileCodeResolver,
    );
    await CopyHelper.copy(context, dossier, customMessage: l.drawingSamplesCopiedDossierSuccess);
  }

  /// Helper for PDF table cells
  static pw.Widget _pdfCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor? color,
    PdfColor? headerColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: isHeader || isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: headerColor ?? (isHeader ? PdfColors.white : (color ?? PdfColors.black)),
        ),
      ),
    );
  }

  /// Generates Vector A4 Landscape PDF with Cairo font and launches print dialog
  static Future<void> printOrSaveDrawingSamplesPdf({
    required BuildContext context,
    required List<CustomsClearanceModel> samples,
    List<Map<String, dynamic>> shortages = const [],
    String Function(int id)? fileCodeResolver,
  }) async {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final textDir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final totalSamples = samples.length;
    final passedSamples = samples.where((s) => s.sampleTestStatus == 'Approved' || s.labTestResult == 'CONFORMING').length;
    final pendingSamples = samples.where((s) => s.sampleTestStatus == 'Samples Under Testing' || s.labTestResult == 'PENDING').length;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context ctx) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IMPORTFLOW ERP — SOROUR LOGISTICS',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      l.drawingSamplesScreenTitle,
                      style: pw.TextStyle(color: PdfColors.amber300, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateTime.now().toString().substring(0, 16),
                      style: const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                    ),
                    pw.Text(
                      'Stage 7: Customs Clearance',
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // KPI Cards Box
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(children: [
                  pw.Text(l.drawingSamplesKpiTotalSamples, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('$totalSamples', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                ]),
                pw.Column(children: [
                  pw.Text(l.drawingSamplesKpiPassedSamples, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('$passedSamples', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                ]),
                pw.Column(children: [
                  pw.Text(l.drawingSamplesKpiPendingSamples, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text('$pendingSamples', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Section 1: Laboratory Drawn Samples
          pw.Text(
            l.drawingSamplesTabDrawnSamples,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(3.5),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(2.5),
              5: const pw.FlexColumnWidth(2.5),
              6: const pw.FlexColumnWidth(2.5),
              7: const pw.FlexColumnWidth(3.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                children: [
                  _pdfCell(l.drawingSamplesColSampleCode, isHeader: true),
                  _pdfCell(l.drawingSamplesColFileCode, isHeader: true),
                  _pdfCell(l.drawingSamplesColSampledBodies, isHeader: true),
                  _pdfCell(l.drawingSamplesColSamplingDate, isHeader: true),
                  _pdfCell(l.drawingSamplesColGoeicCert, isHeader: true),
                  _pdfCell(l.drawingSamplesColTestStatus, isHeader: true),
                  _pdfCell(l.drawingSamplesColLabResult, isHeader: true),
                  _pdfCell(l.drawingSamplesFieldNotes, isHeader: true),
                ],
              ),
              if (samples.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(l.drawingSamplesEmptySamples, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ),
                    _pdfCell(''),
                    _pdfCell(''),
                    _pdfCell(''),
                    _pdfCell(''),
                    _pdfCell(''),
                    _pdfCell(''),
                    _pdfCell(''),
                  ],
                )
              else
                ...samples.map((s) {
                  final isPassed = s.sampleTestStatus == 'Approved' || s.labTestResult == 'CONFORMING';
                  final statusStr = getSampleStatusLabel(context, s.sampleTestStatus);
                  final fileCode = fileCodeResolver != null ? fileCodeResolver(s.importFileId) : '—';
                  final bodies = s.sampledRegulatoryBodies.map((b) => DomainEnums.label(l, DomainEnumType.regulatoryBody, b)).join(', ');
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isPassed ? PdfColors.green50 : PdfColors.white,
                    ),
                    children: [
                      _pdfCell(s.samplingRecordNo ?? '—', isBold: true),
                      _pdfCell(fileCode),
                      _pdfCell(bodies.isNotEmpty ? bodies : '—'),
                      _pdfCell(s.samplingDate ?? '—'),
                      _pdfCell(s.goeicCertificateNo ?? '—'),
                      _pdfCell(statusStr, color: isPassed ? PdfColors.green900 : PdfColors.orange900, isBold: true),
                      _pdfCell(s.labTestResult),
                      _pdfCell(s.inspectionNotes ?? '—'),
                    ],
                  );
                }),
            ],
          ),
          pw.SizedBox(height: 16),

          // Section 2: Cargo Examination Shortage Protocols
          pw.Text(
            l.drawingSamplesShortageSectionTitle,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 4),
          if (shortages.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Text(
                l.ccShortageNotAvailable,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(4),
                3: const pw.FlexColumnWidth(2),
                4: const pw.FlexColumnWidth(2),
                5: const pw.FlexColumnWidth(2),
                6: const pw.FlexColumnWidth(2),
                7: const pw.FlexColumnWidth(3.5),
                8: const pw.FlexColumnWidth(3.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                  children: [
                    _pdfCell(l.drawingSamplesColShortageCode, isHeader: true),
                    _pdfCell(l.drawingSamplesColContainerPkg, isHeader: true),
                    _pdfCell(l.drawingSamplesColItemDesc, isHeader: true),
                    _pdfCell(l.drawingSamplesColManifestQty, isHeader: true),
                    _pdfCell(l.drawingSamplesColLandedQty, isHeader: true),
                    _pdfCell(l.drawingSamplesColShortageQty, isHeader: true),
                    _pdfCell(l.drawingSamplesColShortagePct, isHeader: true),
                    _pdfCell(l.drawingSamplesColShortageAction, isHeader: true),
                    _pdfCell(l.drawingSamplesColShortageNotes, isHeader: true),
                  ],
                ),
                ...shortages.map((item) {
                  final actionLabel = getShortageActionLabel(context, item['action'] as String?);
                  return pw.TableRow(
                    children: [
                      _pdfCell((item['shortage_id'] ?? '').toString(), isBold: true),
                      _pdfCell((item['container_no'] ?? '').toString()),
                      _pdfCell((item['item_desc'] ?? '').toString()),
                      _pdfCell((item['manifest_qty'] ?? '0').toString()),
                      _pdfCell((item['landed_qty'] ?? '0').toString()),
                      _pdfCell((item['shortage_qty'] ?? '0').toString(), color: PdfColors.red800, isBold: true),
                      _pdfCell('${item['shortage_pct'] ?? '0'}%', isBold: true),
                      _pdfCell(actionLabel),
                      _pdfCell((item['notes'] ?? '-').toString()),
                    ],
                  );
                }),
              ],
            ),
          pw.SizedBox(height: 12),

          // Footer
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Sorour Logistics ImportFlow ERP — Confidential & Official Examination Record',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Customs_Examination_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}

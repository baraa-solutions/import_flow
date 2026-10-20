import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';

/// Export service for Central Shipment Documents & Rectifications Archive (Screen 51).
/// Supports TSV export, clean Excel (CSV) export, vector A4 landscape Cairo PDF, and clipboard dossier.
class CentralDocsArchiveExportService {
  final BuildContext context;
  final Map<String, dynamic> data;

  CentralDocsArchiveExportService({
    required this.context,
    required this.data,
  });

  AppLocalizations get _l10n => context.l10n;

  String get fileCode => data['import_file_code']?.toString() ?? '';
  String get customFileNum => data['custom_file_number']?.toString() ?? '';
  String get importer => data['importer_name']?.toString() ?? 'N/A';
  String get supplier => data['supplier_name']?.toString() ?? 'N/A';
  String get acid => data['acid_number']?.toString() ?? 'N/A';
  String get pol => data['port_of_loading']?.toString() ?? 'N/A';
  String get pod => data['port_of_discharge']?.toString() ?? 'N/A';
  String get readiness => data['readiness_status']?.toString() ?? 'IN_REVIEW';
  double get score => (data['readiness_score'] as num?)?.toDouble() ?? 0.0;
  int get totalCritical => data['total_critical_discrepancies'] as int? ?? 0;
  int get totalWarning => data['total_warning_discrepancies'] as int? ?? 0;
  int get pkgsCount => data['total_packages'] as int? ?? 0;
  String get weightCount => (data['total_gross_weight_kg'] as num?)?.toStringAsFixed(2) ?? '0.00';
  String get totalValueFormatted =>
      '${(data['fob_or_cif_amount'] as num?)?.toStringAsFixed(2) ?? '0.00'} ${data['currency'] ?? 'EUR'}';

  Map<String, dynamic> get reqSummary => data['import_requirements_summary'] as Map<String, dynamic>? ?? {};
  String get hsCode => reqSummary['hs_code']?.toString() ?? 'N/A';
  String get commodity => reqSummary['commodity_description']?.toString() ?? '';
  String get origin => reqSummary['country_of_origin']?.toString() ?? '';
  bool get cooRequired => reqSummary['coo_required'] as bool? ?? false;
  String get cooType => reqSummary['coo_type']?.toString() ?? 'Standard COO';
  bool get inspRequired => reqSummary['inspection_required'] as bool? ?? false;
  String get inspAgency => reqSummary['inspection_body']?.toString() ?? 'COTECNA / SGS';
  bool get decree43 => reqSummary['decree_43_applicable'] as bool? ?? false;
  bool get whiteList => reqSummary['white_list_verified'] as bool? ?? false;

  List<dynamic> get checklist => data['all_rectifications_checklist'] as List<dynamic>? ?? [];

  List<Map<String, dynamic>> _extractCoreDocs() {
    final l10n = _l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    final rawDocs = [
      {
        'doc': data['final_invoice'] as Map<String, dynamic>? ?? {},
        'defaultTitle': l10n.docTitleCommercialInvoice,
        'isMandatory': true,
      },
      {
        'doc': data['final_packing_list'] as Map<String, dynamic>? ?? {},
        'defaultTitle': l10n.docTitlePackingList,
        'isMandatory': true,
      },
      {
        'doc': data['draft_bl'] as Map<String, dynamic>? ?? {},
        'defaultTitle': l10n.docTitleBillOfLading,
        'isMandatory': true,
      },
      {
        'doc': data['certificate_of_origin'] as Map<String, dynamic>? ?? {},
        'defaultTitle': l10n.docTitleCertificateOfOrigin,
        'isMandatory': false,
      },
      {
        'doc': data['inspection_certificate'] as Map<String, dynamic>? ?? {},
        'defaultTitle': l10n.docTitleInspectionCertificate,
        'isMandatory': false,
      },
    ];

    return rawDocs.map((item) {
      final docMap = item['doc'] as Map<String, dynamic>;
      final title = (isAr ? docMap['title_ar'] : docMap['title_en'])?.toString() ??
          (item['defaultTitle'] as String);
      final ref = docMap['document_reference']?.toString() ?? 'N/A';
      final status = docMap['status']?.toString() ?? 'NOT_STARTED';
      final isWaived = docMap['is_waived'] as bool? ?? false;
      final legalNote = docMap['legal_requirement_note']?.toString() ?? '';
      final discrepancies = (docMap['discrepancies'] as List<dynamic>?) ?? [];

      String statusDisplay;
      if (isWaived || status == 'WAIVED') {
        statusDisplay = l10n.docStatusWaived;
      } else if (status == 'APPROVED') {
        statusDisplay = l10n.docStatusApproved;
      } else if (status == 'MODIFICATIONS_REQUESTED') {
        statusDisplay = l10n.docStatusModificationsRequested;
      } else if (status == 'REVIEW_PENDING') {
        statusDisplay = l10n.docStatusReviewPending;
      } else {
        statusDisplay = l10n.docStatusNotStarted;
      }

      return {
        'title': title,
        'ref': ref,
        'status': statusDisplay,
        'rawStatus': status,
        'isMandatory': item['isMandatory'] as bool,
        'isWaived': isWaived,
        'legalNote': legalNote,
        'discrepancies': discrepancies,
        'discrepanciesCount': discrepancies.length,
      };
    }).toList();
  }

  String _getReadinessText() {
    if (readiness == 'READY_FOR_RELEASE') {
      return _l10n.readinessReadyForRelease;
    } else if (readiness == 'ACTION_REQUIRED') {
      return _l10n.readinessActionRequired;
    } else {
      return _l10n.readinessInReview;
    }
  }

  /// Builds a clean plain-text dossier for quick clipboard copy.
  String buildDossierText() {
    final buffer = StringBuffer();
    final l10n = _l10n;

    buffer.writeln('================================================================');
    buffer.writeln('${l10n.centralDocsDossierHeader} — [$fileCode]');
    buffer.writeln('================================================================');
    buffer.writeln('');
    buffer.writeln('${l10n.fileCodeLabel(fileCode)} | ${l10n.customsFileNumberLabel(customFileNum)}');
    buffer.writeln('${l10n.importerCompanyLabel} $importer');
    buffer.writeln('${l10n.exporterSupplierLabel} $supplier');
    buffer.writeln('${l10n.acidNumberLabel} $acid');
    buffer.writeln('${l10n.shippingRouteLabel} $pol ➔ $pod');
    buffer.writeln('${l10n.totalPackagesAndWeightLabel} ${l10n.packagesCountText(pkgsCount, weightCount)}');
    buffer.writeln('${l10n.totalInvoiceValueLabel} $totalValueFormatted');
    buffer.writeln('Status: ${_getReadinessText()} (${score.toStringAsFixed(0)}%)');
    buffer.writeln('');

    // Compliance specs
    buffer.writeln('--- ${l10n.centralDocsDossierComplianceTitle} ---');
    buffer.writeln('HS Code: $hsCode | Origin: $origin | $commodity');
    buffer.writeln('${l10n.chipCooLabel}: ${cooRequired ? l10n.cooRequiredText(cooType) : l10n.cooNotRequiredText}');
    buffer.writeln('${l10n.chipVocLabel}: ${inspRequired ? l10n.inspRequiredText(inspAgency) : l10n.inspNotRequiredText}');
    buffer.writeln('${l10n.chipDecree43Label}: ${decree43 ? (whiteList ? l10n.decree43WhiteListed : l10n.decree43RegistrationRequired) : l10n.decree43NotApplicable}');
    buffer.writeln('');

    // Five Core Documents
    final docs = _extractCoreDocs();
    buffer.writeln('--- ${l10n.centralDocsDossierCoreDocsTitle} (${docs.length}) ---');
    for (var i = 0; i < docs.length; i++) {
      final d = docs[i];
      final reqType = (d['isMandatory'] as bool) ? l10n.docMandatoryCore : l10n.docConditional;
      buffer.writeln('${i + 1}. ${d['title']} [$reqType]');
      buffer.writeln('   ${l10n.docReferenceLabel(d['ref'])} | ${d['status']}');
      final note = d['legalNote']?.toString() ?? '';
      if (note.isNotEmpty) {
        buffer.writeln('   Note: $note');
      }
      final discList = d['discrepancies'] as List;
      if (discList.isNotEmpty) {
        for (final item in discList) {
          buffer.writeln('   - [${item['field']}]: ${item['issue']} ➔ ${item['rectification']}');
        }
      }
    }
    buffer.writeln('');

    // Master Rectifications Log
    if (checklist.isNotEmpty) {
      buffer.writeln('--- ${l10n.centralDocsDossierDiscrepanciesTitle} (${checklist.length}) ---');
      for (var i = 0; i < checklist.length; i++) {
        final item = checklist[i];
        final isCrit = item['severity']?.toString() == 'CRITICAL';
        final sevText = isCrit ? l10n.severityCritical : l10n.severityWarning;
        buffer.writeln('${i + 1}. [${item['document']}] [${item['field']}] ($sevText)');
        buffer.writeln('   ${l10n.discrepancyIssueLabel(item['issue'] ?? '')}');
        buffer.writeln('   ${l10n.discrepancyRectificationLabel(item['rectification'] ?? '')}');
      }
      buffer.writeln('');
    } else {
      buffer.writeln('--- ${l10n.noDiscrepanciesSuccessMessage} ---');
      buffer.writeln('');
    }

    buffer.writeln('================================================================');
    buffer.writeln('Sorour Logistics ERP — Central Shipment Documents Archive');
    buffer.writeln('================================================================');

    return buffer.toString();
  }

  /// Copies dossier to clipboard and shows SnackBar notification.
  Future<void> copyDossierToClipboard() async {
    final text = buildDossierText();
    await CopyHelper.copy(
      context,
      text,
      customMessage: _l10n.centralDocsCopyDossierSuccess,
    );
  }

  /// Exports central archive documents and rectifications as TSV with UTF-8 BOM.
  Future<void> exportToTsv() async {
    final l10n = _l10n;
    final buffer = StringBuffer();

    // TSV Header Row
    buffer.writeln([
      l10n.centralDocsTsvHeaderDocName,
      l10n.centralDocsTsvHeaderDocType,
      l10n.centralDocsTsvHeaderRefNo,
      l10n.centralDocsTsvHeaderStatus,
      l10n.centralDocsTsvHeaderDiscrepanciesCount,
      l10n.centralDocsTsvHeaderIssues,
      l10n.centralDocsTsvHeaderRectifications,
      l10n.centralDocsTsvHeaderLegalNote,
    ].join('\t'));

    // Core Documents Rows
    final docs = _extractCoreDocs();
    for (final doc in docs) {
      final reqType = (doc['isMandatory'] as bool) ? l10n.docMandatoryCore : l10n.docConditional;
      final discList = doc['discrepancies'] as List;
      final issues = discList.map((d) => '[${d['field']}]: ${d['issue']}').join(' ; ');
      final rects = discList.map((d) => '[${d['field']}]: ${d['rectification']}').join(' ; ');

      buffer.writeln([
        _cleanTsv(doc['title']?.toString() ?? ''),
        _cleanTsv(reqType),
        _cleanTsv(doc['ref']?.toString() ?? ''),
        _cleanTsv(doc['status']?.toString() ?? ''),
        doc['discrepanciesCount'].toString(),
        _cleanTsv(issues),
        _cleanTsv(rects),
        _cleanTsv(doc['legalNote']?.toString() ?? ''),
      ].join('\t'));
    }

    final safeCode = fileCode.replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'Central_Docs_Archive_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.tsv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l10n.centralDocsExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports central archive documents and rectifications as clean Excel (CSV) with UTF-8 BOM.
  Future<void> exportToExcel() async {
    final l10n = _l10n;
    final buffer = StringBuffer();

    // CSV Header Row
    buffer.writeln([
      _csvQuote(l10n.centralDocsTsvHeaderDocName),
      _csvQuote(l10n.centralDocsTsvHeaderDocType),
      _csvQuote(l10n.centralDocsTsvHeaderRefNo),
      _csvQuote(l10n.centralDocsTsvHeaderStatus),
      _csvQuote(l10n.centralDocsTsvHeaderDiscrepanciesCount),
      _csvQuote(l10n.centralDocsTsvHeaderIssues),
      _csvQuote(l10n.centralDocsTsvHeaderRectifications),
      _csvQuote(l10n.centralDocsTsvHeaderLegalNote),
    ].join(','));

    // Core Documents Rows
    final docs = _extractCoreDocs();
    for (final doc in docs) {
      final reqType = (doc['isMandatory'] as bool) ? l10n.docMandatoryCore : l10n.docConditional;
      final discList = doc['discrepancies'] as List;
      final issues = discList.map((d) => '[${d['field']}]: ${d['issue']}').join(' ; ');
      final rects = discList.map((d) => '[${d['field']}]: ${d['rectification']}').join(' ; ');

      buffer.writeln([
        _csvQuote(doc['title']?.toString() ?? ''),
        _csvQuote(reqType),
        _csvQuote(doc['ref']?.toString() ?? ''),
        _csvQuote(doc['status']?.toString() ?? ''),
        doc['discrepanciesCount'].toString(),
        _csvQuote(issues),
        _csvQuote(rects),
        _csvQuote(doc['legalNote']?.toString() ?? ''),
      ].join(','));
    }

    final safeCode = fileCode.replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'Central_Docs_Archive_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l10n.centralDocsExportExcelDialogTitle,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Generates vector A4 Landscape PDF with Cairo typography and executive summary.
  Future<void> printOrSavePdf() async {
    final l10n = _l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final textDir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();
    final docs = _extractCoreDocs();
    final readinessTitle = _getReadinessText();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => [
          // Header
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
                      l10n.centralDocsDossierHeader,
                      style: pw.TextStyle(color: PdfColors.amber300, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      l10n.fileCodeLabel(fileCode),
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    if (customFileNum.isNotEmpty)
                      pw.Text(
                        l10n.customsFileNumberLabel(customFileNum),
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Overview Information Row
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${l10n.importerCompanyLabel} $importer', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('${l10n.exporterSupplierLabel} $supplier', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('${l10n.acidNumberLabel} $acid', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey800)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${l10n.shippingRouteLabel} $pol ➔ $pod', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text('${l10n.totalPackagesAndWeightLabel} ${l10n.packagesCountText(pkgsCount, weightCount)}', style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(height: 2),
                      pw.Text('${l10n.totalInvoiceValueLabel} $totalValueFormatted', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: readiness == 'READY_FOR_RELEASE'
                        ? PdfColors.green50
                        : (readiness == 'ACTION_REQUIRED' ? PdfColors.red50 : PdfColors.amber50),
                    border: pw.Border.all(
                      color: readiness == 'READY_FOR_RELEASE'
                          ? PdfColors.green700
                          : (readiness == 'ACTION_REQUIRED' ? PdfColors.red700 : PdfColors.amber700),
                    ),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '$readinessTitle (${score.toStringAsFixed(0)}%)',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: readiness == 'READY_FOR_RELEASE'
                          ? PdfColors.green900
                          : (readiness == 'ACTION_REQUIRED' ? PdfColors.red900 : PdfColors.amber900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Core Documents Table
          pw.Text(
            l10n.centralDocsDossierCoreDocsTitle,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              l10n.centralDocsTsvHeaderDocName,
              l10n.centralDocsTsvHeaderDocType,
              l10n.centralDocsTsvHeaderRefNo,
              l10n.centralDocsTsvHeaderStatus,
              l10n.centralDocsTsvHeaderDiscrepanciesCount,
              l10n.centralDocsTsvHeaderLegalNote,
            ],
            data: docs.map((d) {
              final reqType = (d['isMandatory'] as bool) ? l10n.docMandatoryCore : l10n.docConditional;
              return [
                d['title']?.toString() ?? '',
                reqType,
                d['ref']?.toString() ?? '',
                d['status']?.toString() ?? '',
                d['discrepanciesCount'].toString(),
                d['legalNote']?.toString() ?? '',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
          pw.SizedBox(height: 12),

          // Master Rectifications Checklist (if any)
          if (checklist.isNotEmpty) ...[
            pw.Text(
              l10n.centralDocsDossierDiscrepanciesTitle,
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                l10n.centralDocsTsvHeaderDocName,
                'Field',
                'Severity',
                l10n.centralDocsTsvHeaderIssues,
                l10n.centralDocsTsvHeaderRectifications,
              ],
              data: checklist.map((item) {
                final isCrit = item['severity']?.toString() == 'CRITICAL';
                return [
                  item['document']?.toString() ?? '',
                  item['field']?.toString() ?? '',
                  isCrit ? l10n.severityCritical : l10n.severityWarning,
                  item['issue']?.toString() ?? '',
                  item['rectification']?.toString() ?? '',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.red900),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Central_Docs_Archive_${fileCode.replaceAll(RegExp(r"[^\w\-]"), "_")}.pdf',
    );
  }

  String _cleanTsv(String value) {
    return value.replaceAll('\t', ' ').replaceAll('\r', '').replaceAll('\n', ' ');
  }

  String _csvQuote(String value) {
    final sanitized = value.replaceAll('"', '""');
    return '"$sanitized"';
  }
}

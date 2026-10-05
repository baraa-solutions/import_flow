import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/cargo_insurance_model.dart';

/// Dedicated Export & Dossier Service for Screen 65:
/// Cargo & Marine Insurance Hub (Certificates Registry, Valuation & Policies).
class CargoInsuranceExportService {
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

  /// Converts single certificate to a clean single-line summary string for clipboard copy
  static String toRowSummary(
    CargoInsuranceModel cert,
    AppLocalizations l, {
    List<ImportFileModel>? shipments,
    bool isArabic = true,
  }) {
    final date = cert.issuedAt != null && cert.issuedAt!.length >= 10
        ? cert.issuedAt!.substring(0, 10)
        : (cert.createdAt.length >= 10 ? cert.createdAt.substring(0, 10) : cert.createdAt);
    final route = '${cert.portOfLoading} -> ${cert.portOfDischarge}';
    final shipmentCode = cert.importFileId != null ? 'IMP-${cert.importFileId}' : null;
    final fileStr = shipmentCode != null
        ? DisplayNameResolver.resolveShipmentTitleByCode(shipmentCode, shipments: shipments, isArabic: isArabic)
        : 'N/A';
    return [
      '${l.insuranceColCertCode}: ${cert.certificateCode}',
      '${l.insuranceColIssueDate}: $date',
      '${l.insuranceColPolicyFile}: ${cert.policyNumber ?? "N/A"} ($fileStr)',
      '${l.insuranceColInsuredEntity}: ${cert.insuredEntityName}',
      '${l.insuranceColInsuranceCo}: ${cert.insuranceCompanyName ?? "N/A"}',
      '${l.insuranceColTransportRoute}: ${cert.transportMode} - $route',
      '${l.insuranceColInsuredValue}: ${cert.insuredValue.toStringAsFixed(2)} ${cert.currency}',
      '${l.insuranceColCoverageClause}: ${cert.coverageClause}',
      '${l.insuranceColGrossPremium}: ${cert.totalPayablePremium.toStringAsFixed(2)} ${cert.currency}',
      '${l.insuranceColStatus}: ${cert.status}',
    ].join(' | ');
  }

  /// Exports certificates registry as TSV string with UTF-8 BOM
  static String exportCertificatesToTsv(
    BuildContext context,
    List<CargoInsuranceModel> certs, {
    List<ImportFileModel>? shipments,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      l.insuranceColCertCode,
      l.insuranceColIssueDate,
      l.insuranceColPolicyFile,
      l.insuranceFieldLinkImportFile,
      l.insuranceColInsuredEntity,
      l.insuranceColInsuranceCo,
      l.insuranceFieldTransportMode,
      l.insuranceFieldPol,
      l.insuranceFieldPod,
      l.insuranceFieldCarrier,
      l.insuranceFieldCurrency,
      l.insuranceBreakdownCifBase,
      l.insuranceColInsuredValue,
      l.insuranceColCoverageClause,
      l.insuranceWarAndStrikesTitle,
      l.insuranceColGrossPremium,
      l.insuranceColStatus,
    ].join('\t'));

    for (final c in certs) {
      final date = c.issuedAt != null && c.issuedAt!.length >= 10
          ? c.issuedAt!.substring(0, 10)
          : (c.createdAt.length >= 10 ? c.createdAt.substring(0, 10) : c.createdAt);
      final shipmentCode = c.importFileId != null ? 'IMP-${c.importFileId}' : null;
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        shipmentCode,
        shipments: shipments,
        isArabic: isAr,
      );
      buf.writeln([
        _cleanTsv(c.certificateCode),
        _cleanTsv(date),
        _cleanTsv(c.policyNumber ?? '-'),
        _cleanTsv(shipmentCode != null ? shipmentTitle : '-'),
        _cleanTsv(c.insuredEntityName),
        _cleanTsv(c.insuranceCompanyName ?? '-'),
        _cleanTsv(c.transportMode),
        _cleanTsv(c.portOfLoading),
        _cleanTsv(c.portOfDischarge),
        _cleanTsv(c.carrierName ?? c.vesselOrFlightNo ?? '-'),
        _cleanTsv(c.currency),
        _cleanTsv(c.cifValue.toStringAsFixed(2)),
        _cleanTsv(c.insuredValue.toStringAsFixed(2)),
        _cleanTsv(c.coverageClause),
        _cleanTsv(c.includeWarAndStrikes ? 'YES' : 'NO'),
        _cleanTsv(c.totalPayablePremium.toStringAsFixed(2)),
        _cleanTsv(c.status),
      ].join('\t'));
    }

    return buf.toString();
  }

  /// Exports certificates registry as RFC 4180 unmerged CSV string with UTF-8 BOM
  static String exportCertificatesToCsv(
    BuildContext context,
    List<CargoInsuranceModel> certs, {
    List<ImportFileModel>? shipments,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      _csvQuote(l.insuranceColCertCode),
      _csvQuote(l.insuranceColIssueDate),
      _csvQuote(l.insuranceColPolicyFile),
      _csvQuote(l.insuranceFieldLinkImportFile),
      _csvQuote(l.insuranceColInsuredEntity),
      _csvQuote(l.insuranceColInsuranceCo),
      _csvQuote(l.insuranceFieldTransportMode),
      _csvQuote(l.insuranceFieldPol),
      _csvQuote(l.insuranceFieldPod),
      _csvQuote(l.insuranceFieldCarrier),
      _csvQuote(l.insuranceFieldCurrency),
      _csvQuote(l.insuranceBreakdownCifBase),
      _csvQuote(l.insuranceColInsuredValue),
      _csvQuote(l.insuranceColCoverageClause),
      _csvQuote(l.insuranceWarAndStrikesTitle),
      _csvQuote(l.insuranceColGrossPremium),
      _csvQuote(l.insuranceColStatus),
    ].join(','));

    for (final c in certs) {
      final date = c.issuedAt != null && c.issuedAt!.length >= 10
          ? c.issuedAt!.substring(0, 10)
          : (c.createdAt.length >= 10 ? c.createdAt.substring(0, 10) : c.createdAt);
      final shipmentCode = c.importFileId != null ? 'IMP-${c.importFileId}' : null;
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        shipmentCode,
        shipments: shipments,
        isArabic: isAr,
      );
      buf.writeln([
        _csvQuote(c.certificateCode),
        _csvQuote(date),
        _csvQuote(c.policyNumber ?? '-'),
        _csvQuote(shipmentCode != null ? shipmentTitle : '-'),
        _csvQuote(c.insuredEntityName),
        _csvQuote(c.insuranceCompanyName ?? '-'),
        _csvQuote(c.transportMode),
        _csvQuote(c.portOfLoading),
        _csvQuote(c.portOfDischarge),
        _csvQuote(c.carrierName ?? c.vesselOrFlightNo ?? '-'),
        _csvQuote(c.currency),
        _csvQuote(c.cifValue.toStringAsFixed(2)),
        _csvQuote(c.insuredValue.toStringAsFixed(2)),
        _csvQuote(c.coverageClause),
        _csvQuote(c.includeWarAndStrikes ? 'YES' : 'NO'),
        _csvQuote(c.totalPayablePremium.toStringAsFixed(2)),
        _csvQuote(c.status),
      ].join(','));
    }

    return buf.toString();
  }

  /// Saves TSV export file and copies TSV to clipboard
  static Future<void> saveCertificatesTsvToFile(
    BuildContext context,
    List<CargoInsuranceModel> certs, {
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final tsv = exportCertificatesToTsv(context, certs, shipments: shipments);
    await CopyHelper.copy(context, tsv, customMessage: l.insuranceCopiedTsvSuccess);
    if (!context.mounted) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final fileName = 'cargo_insurance_registry_$timestamp.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: tsv,
      defaultFileName: fileName,
      dialogTitle: l.insuranceExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: false,
    );
  }

  /// Saves unmerged CSV export file and copies CSV to clipboard
  static Future<void> saveCertificatesCsvToFile(
    BuildContext context,
    List<CargoInsuranceModel> certs, {
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final csv = exportCertificatesToCsv(context, certs, shipments: shipments);
    await CopyHelper.copy(context, csv, customMessage: l.insuranceCopiedExcelSuccess);
    if (!context.mounted) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final fileName = 'cargo_insurance_registry_$timestamp.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: csv,
      defaultFileName: fileName,
      dialogTitle: l.insuranceExportExcelBtn,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: false,
    );
  }

  /// Builds plain-text comprehensive dossier with headers, KPIs, and itemized records
  static String buildCertificatesDossier({
    required BuildContext context,
    required List<CargoInsuranceModel> certs,
    List<ImportFileModel>? shipments,
  }) {
    final l = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final buf = StringBuffer();

    buf.writeln('================================================================');
    buf.writeln(l.insuranceDossierHeader);
    buf.writeln('================================================================');
    buf.writeln('Timestamp: ${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('----------------------------------------------------------------');

    final totalCount = certs.length;
    final issuedCount = certs.where((c) => c.status == 'ISSUED').length;
    final totalInsuredUSD = certs.fold<double>(
      0.0,
      (sum, c) => sum + (c.currency == 'USD' ? c.insuredValue : c.insuredValue * c.exchangeRate),
    );
    final totalPremiumsUSD = certs.fold<double>(
      0.0,
      (sum, c) => sum + (c.currency == 'USD' ? c.totalPayablePremium : c.totalPayablePremium * c.exchangeRate),
    );

    buf.writeln(l.insuranceDossierKpiSummary);
    buf.writeln('• ${l.insuranceKpiTotalPolicies}: $totalCount');
    buf.writeln('• ${l.insuranceKpiIssuedValid}: $issuedCount');
    buf.writeln('• ${l.insuranceKpiTotalInsured}: \$${totalInsuredUSD.toStringAsFixed(2)} USD eq');
    buf.writeln('• ${l.insuranceKpiTotalPremiums}: \$${totalPremiumsUSD.toStringAsFixed(2)} USD eq');
    buf.writeln('----------------------------------------------------------------');
    buf.writeln(l.insuranceDossierRecordsDetails);
    buf.writeln('----------------------------------------------------------------');

    if (certs.isEmpty) {
      buf.writeln(l.insuranceNoDataFound);
    } else {
      for (int i = 0; i < certs.length; i++) {
        final c = certs[i];
        final date = c.issuedAt != null && c.issuedAt!.length >= 10
            ? c.issuedAt!.substring(0, 10)
            : (c.createdAt.length >= 10 ? c.createdAt.substring(0, 10) : c.createdAt);
        final shipmentCode = c.importFileId != null ? 'IMP-${c.importFileId}' : null;
        final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
          shipmentCode,
          shipments: shipments,
          isArabic: isAr,
        );
        final polFileStr = shipmentCode != null
            ? '${c.policyNumber ?? "N/A"} ($shipmentTitle [$shipmentCode])'
            : '${c.policyNumber ?? "N/A"} (N/A)';
        buf.writeln('[${i + 1}] ${l.insuranceColCertCode}: ${c.certificateCode} (${c.status})');
        buf.writeln('    • ${l.insuranceColIssueDate}: $date');
        buf.writeln('    • ${l.insuranceColPolicyFile}: $polFileStr');
        buf.writeln('    • ${l.insuranceColInsuredEntity}: ${c.insuredEntityName}');
        buf.writeln('    • ${l.insuranceColInsuranceCo}: ${c.insuranceCompanyName ?? "N/A"}');
        buf.writeln('    • ${l.insuranceColTransportRoute}: ${c.transportMode} (${c.portOfLoading} -> ${c.portOfDischarge})');
        if (c.carrierName != null || c.vesselOrFlightNo != null) {
          buf.writeln('    • ${l.insuranceFieldCarrier}: ${c.carrierName ?? c.vesselOrFlightNo}');
        }
        buf.writeln('    • ${l.insuranceBreakdownCifBase}: ${c.cifValue.toStringAsFixed(2)} ${c.currency}');
        buf.writeln('    • ${l.insuranceColInsuredValue}: ${c.insuredValue.toStringAsFixed(2)} ${c.currency}');
        buf.writeln('    • ${l.insuranceColCoverageClause}: ${c.coverageClause} (War & Strikes: ${c.includeWarAndStrikes ? "Yes" : "No"})');
        buf.writeln('    • ${l.insuranceColGrossPremium}: ${c.totalPayablePremium.toStringAsFixed(2)} ${c.currency}');
        if (c.goodsDescription != null && c.goodsDescription!.isNotEmpty) {
          buf.writeln('    • ${l.insuranceFieldGoodsDesc}: ${c.goodsDescription}');
        }
        buf.writeln();
      }
    }

    buf.writeln('================================================================');
    buf.writeln(l.insuranceDossierFooter);
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies full plain-text dossier to system clipboard
  static Future<void> copyDossierToClipboard(
    BuildContext context,
    List<CargoInsuranceModel> certs, {
    List<ImportFileModel>? shipments,
  }) async {
    final l = context.l10n;
    final dossier = buildCertificatesDossier(context: context, certs: certs, shipments: shipments);
    await CopyHelper.copy(context, dossier, customMessage: l.insuranceCopiedDossierSuccess);
  }

  /// Generates and previews a Vector A4 Landscape PDF using Cairo font
  static Future<void> printOrSaveCertificatesPdf(
    BuildContext context,
    List<CargoInsuranceModel> certs, {
    List<ImportFileModel>? shipments,
    bool save = false,
  }) async {
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

    final totalCount = certs.length;
    final issuedCount = certs.where((c) => c.status == 'ISSUED').length;
    final totalInsuredUSD = certs.fold<double>(
      0.0,
      (sum, c) => sum + (c.currency == 'USD' ? c.insuredValue : c.insuredValue * c.exchangeRate),
    );
    final totalPremiumsUSD = certs.fold<double>(
      0.0,
      (sum, c) => sum + (c.currency == 'USD' ? c.totalPayablePremium : c.totalPayablePremium * c.exchangeRate),
    );

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
                      'IMPORTFLOW ERP — ${l.insurancePdfTitle}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      l.insurancePdfSubtitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateTime.now().toString().substring(0, 19),
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${certs.length} ${isAr ? "وثائق مسجلة" : "Policies"}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context ctx) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  l.insuranceDossierFooter,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  '${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            // KPI Summary Cards
            pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpiItem(l.insuranceKpiTotalPolicies, '$totalCount', PdfColors.blueGrey800),
                  _buildPdfKpiItem(l.insuranceKpiIssuedValid, '$issuedCount', PdfColors.teal700),
                  _buildPdfKpiItem(l.insuranceKpiTotalInsured, '\$${totalInsuredUSD.toStringAsFixed(0)}', PdfColors.indigo700),
                  _buildPdfKpiItem(l.insuranceKpiTotalPremiums, '\$${totalPremiumsUSD.toStringAsFixed(2)}', PdfColors.green800),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Vector Table
            pw.TableHelper.fromTextArray(
              headers: [
                l.insuranceColCertCode,
                l.insuranceColIssueDate,
                l.insuranceColPolicyFile,
                l.insuranceColInsuredEntity,
                l.insuranceColInsuranceCo,
                l.insuranceColTransportRoute,
                l.insuranceColInsuredValue,
                l.insuranceColCoverageClause,
                l.insuranceColGrossPremium,
                l.insuranceColStatus,
              ],
              data: certs.map((c) {
                final date = c.issuedAt != null && c.issuedAt!.length >= 10
                    ? c.issuedAt!.substring(0, 10)
                    : (c.createdAt.length >= 10 ? c.createdAt.substring(0, 10) : c.createdAt);
                final shipmentCode = c.importFileId != null ? 'IMP-${c.importFileId}' : null;
                final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
                  shipmentCode,
                  shipments: shipments,
                  isArabic: isAr,
                );
                final polFile = shipmentCode != null
                    ? '${c.policyNumber ?? "-"}\n$shipmentTitle\n[$shipmentCode]'
                    : (c.policyNumber ?? "-");
                final route = '${c.transportMode}\n${c.portOfLoading} -> ${c.portOfDischarge}';
                return [
                  c.certificateCode,
                  date,
                  polFile,
                  c.insuredEntityName,
                  c.insuranceCompanyName ?? '-',
                  route,
                  '${c.insuredValue.toStringAsFixed(2)}\n${c.currency}',
                  c.coverageClause,
                  '${c.totalPayablePremium.toStringAsFixed(2)}\n${c.currency}',
                  c.status,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    if (save) {
      final bytes = await doc.save();
      if (!context.mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: l.insuranceExportStageName,
        importFileNameOrCode: l.insuranceExportRegistryTag,
        extension: 'pdf',
      );
      return;
    }
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'cargo_insurance_registry.pdf',
    );
  }

  static pw.Widget _buildPdfKpiItem(String title, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

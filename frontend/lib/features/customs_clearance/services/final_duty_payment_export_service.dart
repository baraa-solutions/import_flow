import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_clearance_model.dart';
import '../widgets/customs_ui.dart';

/// Dedicated Export & Dossier Service for Screen 62:
/// Customs Clearance - Final Duty Payment & Release.
class FinalDutyPaymentExportService {
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

  /// Exports clearance duty payment ledger as TSV string with UTF-8 BOM
  static String exportFinalDutyToTsv(BuildContext context, List<CustomsClearanceModel> records) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      l.customsClearanceColClearanceCode,
      l.customsClearanceColDecl46,
      l.customsClearanceColCustomsOffice,
      l.customsClearanceChannelLabel,
      l.customsClearanceColActualDuty,
      l.customsClearanceColEstimatedDuty,
      l.customsClearanceColDutyVariance,
      l.customsClearanceColPaymentStatus,
      l.finalDutyColBankReceipt,
      l.finalDutyColReleasePermit,
      l.status,
    ].join('\t'));

    for (final r in records) {
      final isPaid = CcStatus.isPaid(r);
      final actual = CcFormat.fixed(r.effectiveDutyTotal);
      final est = CcFormat.fixed(r.estimatedDutyTotal);
      final variance = '${CcFormat.signedFixed(r.dutyVarianceAmount)} (${CcFormat.percent(r.dutyVariancePercentage)})';
      final paymentStatusStr = isPaid ? l.finalDutyStatusPaidVerified : l.finalDutyStatusPendingPayment;
      final releasePermitStr = r.releasePermitNo ?? '-';
      final bankReceiptStr = r.bankReceiptNo ?? '-';

      buf.writeln([
        _cleanTsv(r.clearanceCode),
        _cleanTsv(r.declaration46No ?? '-'),
        _cleanTsv(r.customsOfficeName),
        _cleanTsv(CcUi.channelStyle(l, r.channelType).label),
        _cleanTsv('$actual ${l.finalDutyCurrencyEgp}'),
        _cleanTsv('$est ${l.finalDutyCurrencyEgp}'),
        _cleanTsv(variance),
        _cleanTsv(paymentStatusStr),
        _cleanTsv(bankReceiptStr),
        _cleanTsv(releasePermitStr),
        _cleanTsv(CcUi.statusStyle(l, r.status).label),
      ].join('\t'));
    }

    return buf.toString();
  }

  /// Exports clearance duty payment ledger as CSV string with UTF-8 BOM
  static String exportFinalDutyToCsv(BuildContext context, List<CustomsClearanceModel> records) {
    final l = context.l10n;
    final buf = StringBuffer();
    buf.write('\uFEFF'); // UTF-8 BOM

    buf.writeln([
      _csvQuote(l.customsClearanceColClearanceCode),
      _csvQuote(l.customsClearanceColDecl46),
      _csvQuote(l.customsClearanceColCustomsOffice),
      _csvQuote(l.customsClearanceChannelLabel),
      _csvQuote(l.customsClearanceColActualDuty),
      _csvQuote(l.customsClearanceColEstimatedDuty),
      _csvQuote(l.customsClearanceColDutyVariance),
      _csvQuote(l.customsClearanceColPaymentStatus),
      _csvQuote(l.finalDutyColBankReceipt),
      _csvQuote(l.finalDutyColReleasePermit),
      _csvQuote(l.status),
    ].join(','));

    for (final r in records) {
      final isPaid = CcStatus.isPaid(r);
      final actual = CcFormat.fixed(r.effectiveDutyTotal);
      final est = CcFormat.fixed(r.estimatedDutyTotal);
      final variance = '${CcFormat.signedFixed(r.dutyVarianceAmount)} (${CcFormat.percent(r.dutyVariancePercentage)})';
      final paymentStatusStr = isPaid ? l.finalDutyStatusPaidVerified : l.finalDutyStatusPendingPayment;
      final releasePermitStr = r.releasePermitNo ?? '-';
      final bankReceiptStr = r.bankReceiptNo ?? '-';

      buf.writeln([
        _csvQuote(r.clearanceCode),
        _csvQuote(r.declaration46No ?? '-'),
        _csvQuote(r.customsOfficeName),
        _csvQuote(CcUi.channelStyle(l, r.channelType).label),
        _csvQuote('$actual ${l.finalDutyCurrencyEgp}'),
        _csvQuote('$est ${l.finalDutyCurrencyEgp}'),
        _csvQuote(variance),
        _csvQuote(paymentStatusStr),
        _csvQuote(bankReceiptStr),
        _csvQuote(releasePermitStr),
        _csvQuote(CcUi.statusStyle(l, r.status).label),
      ].join(','));
    }

    return buf.toString();
  }

  /// Saves duty ledger TSV to file
  static Future<void> saveFinalDutyTsvToFile(BuildContext context, List<CustomsClearanceModel> records) async {
    final l = context.l10n;
    final tsvContent = exportFinalDutyToTsv(context, records);
    await CopyHelper.copy(context, tsvContent, customMessage: l.finalDutyCopiedTsvSuccess);
    if (!context.mounted) return;

    final filename = 'Customs_Final_Duty_Payment_${DateTime.now().millisecondsSinceEpoch}.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: tsvContent,
      defaultFileName: filename,
      dialogTitle: l.finalDutyExportTsvBtn,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Saves duty ledger CSV to file
  static Future<void> saveFinalDutyCsvToFile(BuildContext context, List<CustomsClearanceModel> records) async {
    final l = context.l10n;
    final csvContent = exportFinalDutyToCsv(context, records);
    await CopyHelper.copy(context, csvContent, customMessage: l.finalDutyCopiedExcelSuccess);
    if (!context.mounted) return;

    final filename = 'Customs_Final_Duty_Payment_${DateTime.now().millisecondsSinceEpoch}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: csvContent,
      defaultFileName: filename,
      dialogTitle: l.finalDutyExportExcelBtn,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Builds a complete formatted text dossier for quick copying
  static String buildFinalDutyDossier({
    required BuildContext context,
    required List<CustomsClearanceModel> records,
  }) {
    final l = context.l10n;
    final buf = StringBuffer();

    buf.writeln('================================================================');
    buf.writeln(l.finalDutyDossierHeader);
    buf.writeln('================================================================');
    buf.writeln(l.finalDutyScreenSubtitle);
    buf.writeln('Timestamp: ${DateTime.now().toString().substring(0, 19)}');
    buf.writeln('----------------------------------------------------------------');

    final kpis = FinalDutyKpis.from(records);

    buf.writeln(l.finalDutyDossierKpiSummary);
    buf.writeln('• ${l.finalDutyKpiOutstanding}: ${kpis.outstanding.toStringAsFixed(2)} ${l.finalDutyCurrencyEgp}');
    buf.writeln('• ${l.finalDutyKpiTotalPaid}: ${kpis.totalPaid.toStringAsFixed(2)} ${l.finalDutyCurrencyEgp}');
    buf.writeln('• ${l.finalDutyKpiPendingPayment}: ${kpis.pendingCount}');
    buf.writeln('• ${l.finalDutyKpiNetVariance}: ${kpis.netVariance >= 0 ? "+" : ""}${kpis.netVariance.toStringAsFixed(2)} ${l.finalDutyCurrencyEgp}');
    buf.writeln('----------------------------------------------------------------');
    buf.writeln(l.finalDutyDossierRecordsDetails);
    buf.writeln('----------------------------------------------------------------');

    if (records.isEmpty) {
      buf.writeln(l.finalDutyEmptyRecords);
    } else {
      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        final isPaid = CcStatus.isPaid(r);
        final actual = CcFormat.fixed(r.effectiveDutyTotal);
        final est = CcFormat.fixed(r.estimatedDutyTotal);
        final variance = '${CcFormat.signedFixed(r.dutyVarianceAmount)} (${CcFormat.percent(r.dutyVariancePercentage)})';
        final paymentStatusStr = isPaid ? l.finalDutyStatusPaidVerified : l.finalDutyStatusPendingPayment;
        final channelLabel = CcUi.channelStyle(l, r.channelType).label;
        final statusLabel = CcUi.statusStyle(l, r.status).label;

        buf.writeln('[${i + 1}] ${l.customsClearanceColClearanceCode}: ${r.clearanceCode}');
        buf.writeln('    • ${l.customsClearanceColDecl46}: ${r.declaration46No ?? '-'}');
        buf.writeln('    • ${l.customsClearanceColCustomsOffice}: ${r.customsOfficeName}');
        buf.writeln('    • ${l.customsClearanceChannelLabel}: $channelLabel');
        buf.writeln('    • ${l.customsClearanceColActualDuty}: $actual ${l.finalDutyCurrencyEgp}');
        buf.writeln('    • ${l.customsClearanceColEstimatedDuty}: $est ${l.finalDutyCurrencyEgp}');
        buf.writeln('    • ${l.customsClearanceColDutyVariance}: $variance');
        buf.writeln('    • ${l.customsClearanceColPaymentStatus}: $paymentStatusStr');
        if (r.bankReceiptNo != null && r.bankReceiptNo!.isNotEmpty) {
          buf.writeln('    • ${l.finalDutyColBankReceipt}: ${r.bankReceiptNo}');
        }
        if (r.releasePermitNo != null && r.releasePermitNo!.isNotEmpty) {
          buf.writeln('    • ${l.finalDutyColReleasePermit}: ${r.releasePermitNo}');
        }
        buf.writeln('    • ${l.status}: $statusLabel');
        if (r.dutyVarianceReason != null && r.dutyVarianceReason!.isNotEmpty) {
          buf.writeln('    • ${l.customsClearanceVarianceReasonInput}: ${r.dutyVarianceReason}');
        }
        buf.writeln();
      }
    }

    buf.writeln('================================================================');
    buf.writeln('End of Duty Payment & Release Dossier — Verified by ImportFlow ERP');
    buf.writeln('================================================================');

    return buf.toString();
  }

  /// Copies full plain text dossier to system clipboard
  static Future<void> copyDossierToClipboard(
    BuildContext context,
    List<CustomsClearanceModel> records,
  ) async {
    final l = context.l10n;
    final dossier = buildFinalDutyDossier(context: context, records: records);
    await CopyHelper.copy(context, dossier, customMessage: l.finalDutyCopiedDossierSuccess);
  }

  /// Generates and previews a Vector A4 Landscape PDF using Cairo font
  static Future<void> printOrSaveFinalDutyPdf(
    BuildContext context,
    List<CustomsClearanceModel> records,
  ) async {
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

    final kpis = FinalDutyKpis.from(records);

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
                      'IMPORTFLOW ERP — ${l.finalDutyPdfTitle}',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      l.finalDutyPdfSubtitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateTime.now().toString().substring(0, 10),
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                    pw.Text(
                      'Phase 07 — Customs Clearance Hub',
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
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ImportFlow ERP System • Official Customs Release & Duty Settlement Document',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            pw.SizedBox(height: 10),

            // KPI Summary Cards in PDF
            pw.Row(
              children: [
                _buildPdfKpiCard(
                  title: l.finalDutyKpiOutstanding,
                  value: '${kpis.outstanding.toStringAsFixed(2)} ${l.finalDutyCurrencyEgp}',
                  color: PdfColors.blue900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.finalDutyKpiTotalPaid,
                  value: '${kpis.totalPaid.toStringAsFixed(2)} ${l.finalDutyCurrencyEgp}',
                  color: PdfColors.green900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.finalDutyKpiPendingPayment,
                  value: kpis.pendingCount.toString(),
                  color: PdfColors.orange900,
                  isAr: isAr,
                ),
                pw.SizedBox(width: 8),
                _buildPdfKpiCard(
                  title: l.finalDutyKpiNetVariance,
                  value: '${kpis.netVariance >= 0 ? "+" : ""}${kpis.netVariance.toStringAsFixed(2)} ${l.finalDutyCurrencyEgp}',
                  color: kpis.netVariance.abs() > CcUi.varianceWarnThresholdEgp ? PdfColors.red900 : PdfColors.teal900,
                  isAr: isAr,
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Section Header
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: PdfColors.grey200,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    l.customsClearanceDutyLedgerTableTitle,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.Text(
                    '${records.length} ${l.status}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),

            // Duty Ledger Table
            if (records.isEmpty)
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  l.finalDutyEmptyRecords,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2), // Clearance Code
                  1: const pw.FlexColumnWidth(1.1), // Decl 46
                  2: const pw.FlexColumnWidth(1.4), // Office
                  3: const pw.FlexColumnWidth(1.2), // Actual Duty
                  4: const pw.FlexColumnWidth(1.2), // Estimated Duty
                  5: const pw.FlexColumnWidth(1.1), // Variance
                  6: const pw.FlexColumnWidth(1.1), // Payment Status
                  7: const pw.FlexColumnWidth(1.1), // Bank Receipt
                  8: const pw.FlexColumnWidth(1.1), // Release Permit
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildPdfTableCell(l.customsClearanceColClearanceCode, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.customsClearanceColDecl46, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.customsClearanceColCustomsOffice, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.customsClearanceColActualDuty, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.customsClearanceColEstimatedDuty, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.customsClearanceColDutyVariance, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.customsClearanceColPaymentStatus, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.finalDutyColBankReceipt, isHeader: true, isAr: isAr),
                      _buildPdfTableCell(l.finalDutyColReleasePermit, isHeader: true, isAr: isAr),
                    ],
                  ),
                  // Data Rows
                  ...records.map((r) {
                    final isPaid = CcStatus.isPaid(r);
                    final actual = CcFormat.fixed(r.effectiveDutyTotal);
                    final est = CcFormat.fixed(r.estimatedDutyTotal);
                    final variance = CcFormat.signedFixed(r.dutyVarianceAmount);
                    final paymentStatusStr = isPaid ? l.finalDutyStatusPaidVerified : l.finalDutyStatusPendingPayment;
                    final releasePermitStr = r.releasePermitNo ?? '-';
                    final bankReceiptStr = r.bankReceiptNo ?? '-';

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isPaid ? PdfColors.green50 : PdfColors.white,
                      ),
                      children: [
                        _buildPdfTableCell(r.clearanceCode, isAr: isAr, isBold: true, color: PdfColors.blue800),
                        _buildPdfTableCell(r.declaration46No ?? '-', isAr: isAr),
                        _buildPdfTableCell(r.customsOfficeName, isAr: isAr),
                        _buildPdfTableCell('$actual ${l.finalDutyCurrencyEgp}', isAr: isAr, isBold: true, color: PdfColors.green900),
                        _buildPdfTableCell('$est ${l.finalDutyCurrencyEgp}', isAr: isAr),
                        _buildPdfTableCell(variance, isAr: isAr, color: (r.dutyVarianceAmount ?? 0).abs() > 500 ? PdfColors.orange900 : PdfColors.grey800),
                        _buildPdfTableCell(paymentStatusStr, isAr: isAr, isBold: true, color: isPaid ? PdfColors.green900 : PdfColors.orange900),
                        _buildPdfTableCell(bankReceiptStr, isAr: isAr),
                        _buildPdfTableCell(releasePermitStr, isAr: isAr),
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
      onLayout: (format) async => doc.save(),
      name: 'Customs_Final_Duty_Payment_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildPdfKpiCard({
    required String title,
    required String value,
    required PdfColor color,
    required bool isAr,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: color, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
    PdfColor? color,
    required bool isAr,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: isAr ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 7.0,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.grey900 : PdfColors.grey800),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../models/freight_quotation_model.dart';

/// Normalized row representing a carrier freight quotation for export and comparison.
class FreightQuoteExportRow {
  final String carrier;
  final double totalCost;
  final double oceanFreight;
  final double localCharges;
  final double inlandCharges;
  final String currency;
  final int transitDays;
  final String sailingDate;
  final String arrivalDate;
  final int freeDays;
  final bool isAwarded;
  final String remarks;

  const FreightQuoteExportRow({
    required this.carrier,
    required this.totalCost,
    required this.oceanFreight,
    required this.localCharges,
    required this.inlandCharges,
    required this.currency,
    required this.transitDays,
    required this.sailingDate,
    required this.arrivalDate,
    required this.freeDays,
    required this.isAwarded,
    required this.remarks,
  });

  factory FreightQuoteExportRow.from(dynamic item) {
    if (item is FreightQuotationItemModel) {
      return FreightQuoteExportRow(
        carrier: item.providerName.trim().isNotEmpty ? item.providerName.trim() : '-',
        totalCost: item.totalCost,
        oceanFreight: item.oceanFreightCost,
        localCharges: item.localChargesCost,
        inlandCharges: item.inlandCost,
        currency: (item.currencyCode ?? '').trim().isNotEmpty ? item.currencyCode!.trim() : '-',
        transitDays: item.transitDays,
        sailingDate: item.sailingDate.trim().isNotEmpty ? item.sailingDate.trim() : '-',
        arrivalDate: item.estimatedArrivalDate.trim().isNotEmpty ? item.estimatedArrivalDate.trim() : '-',
        freeDays: item.freeDaysAtPod,
        isAwarded: item.isAwarded,
        remarks: (item.remarks != null && item.remarks!.trim().isNotEmpty) ? item.remarks!.trim() : '-',
      );
    } else if (item is Map) {
      final name = (item['provider_name'] ?? item['forwarder_name'])?.toString().trim();
      final total = (item['total_cost'] ?? item['total_price']) as num?;
      final ocean = item['ocean_freight_cost'] as num?;
      final local = item['local_charges_cost'] as num?;
      final inland = item['inland_cost'] as num?;
      final cur = item['currency_code']?.toString().trim();
      final transit = item['transit_days'] as num?;
      final sail = item['sailing_date']?.toString().trim();
      final arr = item['estimated_arrival_date']?.toString().trim();
      final free = (item['free_days_at_pod'] ?? item['free_days_pod']) as num?;
      final awarded = item['is_awarded'] == true || item['is_winner'] == true;
      final rem = item['remarks']?.toString().trim();

      return FreightQuoteExportRow(
        carrier: (name != null && name.isNotEmpty) ? name : '-',
        totalCost: total?.toDouble() ?? 0.0,
        oceanFreight: ocean?.toDouble() ?? 0.0,
        localCharges: local?.toDouble() ?? 0.0,
        inlandCharges: inland?.toDouble() ?? 0.0,
        currency: (cur != null && cur.isNotEmpty) ? cur : 'USD',
        transitDays: transit?.toInt() ?? 0,
        sailingDate: (sail != null && sail.isNotEmpty) ? sail : '-',
        arrivalDate: (arr != null && arr.isNotEmpty) ? arr : '-',
        freeDays: free?.toInt() ?? 14,
        isAwarded: awarded,
        remarks: (rem != null && rem.isNotEmpty) ? rem : '-',
      );
    }

    return const FreightQuoteExportRow(
      carrier: '-',
      totalCost: 0.0,
      oceanFreight: 0.0,
      localCharges: 0.0,
      inlandCharges: 0.0,
      currency: 'USD',
      transitDays: 0,
      sailingDate: '-',
      arrivalDate: '-',
      freeDays: 14,
      isAwarded: false,
      remarks: '-',
    );
  }
}

/// Central export and dossier service for Freight Quotations & Comparison (Screen 49).
/// Supports TSV export (UTF-8 BOM), unmerged CSV/Excel (UTF-8 BOM),
/// vector A4 landscape Cairo PDF print/save, and single-click summary clipboard dossier.
class FreightQuotationsExportService {
  /// Builds a plain-text comparison dossier for clipboard copy.
  static String buildDossierText({
    required BuildContext context,
    required List<dynamic> quotations,
    String? importFileCode,
    String? supplierName,
  }) {
    final l = context.l10n;
    final rows = quotations.map((q) => FreightQuoteExportRow.from(q)).toList();
    final sb = StringBuffer();

    sb.writeln('================================================================');
    sb.writeln(l.freightQuotationsDossierHeader);
    if (importFileCode != null && importFileCode.isNotEmpty) {
      sb.writeln('${l.selectImportFileDropdownLabel}: $importFileCode');
    }
    if (supplierName != null && supplierName.isNotEmpty) {
      sb.writeln('${l.unknownSupplierFallback}: $supplierName');
    }
    sb.writeln('================================================================');

    if (rows.isNotEmpty) {
      // Find cheapest & fastest
      FreightQuoteExportRow cheapest = rows.first;
      FreightQuoteExportRow fastest = rows.first;
      for (final r in rows) {
        if (r.totalCost < cheapest.totalCost && r.totalCost > 0) cheapest = r;
        if (r.transitDays < fastest.transitDays && r.transitDays > 0) fastest = r;
      }

      sb.writeln('${l.metricCheapestQuote}: ${cheapest.carrier} (${cheapest.totalCost.toStringAsFixed(2)} ${cheapest.currency})');
      sb.writeln('${l.metricFastestQuote}: ${fastest.carrier} (${l.transitDaysCount(fastest.transitDays)})');
      sb.writeln();

      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final status = r.isAwarded ? '[${l.quoteAwardedBtn}]' : '';
        sb.writeln('${i + 1}. ${r.carrier} $status');
        sb.writeln('   ${l.freightQuotesTsvHeaderTotalCost}: ${r.totalCost.toStringAsFixed(2)} ${r.currency}');
        sb.writeln('   ${l.freightQuotesTsvHeaderOceanFreight}: ${r.oceanFreight.toStringAsFixed(2)} ${r.currency}');
        sb.writeln('   ${l.freightQuotesTsvHeaderLocalCharges}: ${r.localCharges.toStringAsFixed(2)} ${r.currency}');
        if (r.inlandCharges > 0) {
          sb.writeln('   ${l.freightQuotesTsvHeaderInlandCharges}: ${r.inlandCharges.toStringAsFixed(2)} ${r.currency}');
        }
        sb.writeln('   ${l.freightQuotesTsvHeaderTransitDays}: ${l.transitDaysCount(r.transitDays)}');
        sb.writeln('   ${l.freightQuotesTsvHeaderSailingDate}: ${r.sailingDate} | ${l.freightQuotesTsvHeaderArrivalDate}: ${r.arrivalDate}');
        sb.writeln('   ${l.freightQuotesTsvHeaderFreeDays}: ${l.transitDaysCount(r.freeDays)}');
        if (r.remarks != '-') {
          sb.writeln('   ${l.freightQuotesTsvHeaderRemarks}: ${r.remarks}');
        }
        sb.writeln('----------------------------------------------------------------');
      }
    } else {
      sb.writeln(l.noFreightQuotesForFile);
    }

    return sb.toString();
  }

  /// Exports quotations comparison table to TSV format with UTF-8 BOM.
  static Future<void> exportToTsv({
    required BuildContext context,
    required List<dynamic> quotations,
    String? importFileCode,
  }) async {
    final l = context.l10n;
    final rows = quotations.map((q) => FreightQuoteExportRow.from(q)).toList();
    final sb = StringBuffer();

    // TSV Headers
    sb.writeln([
      l.freightQuotesTsvHeaderCarrier,
      l.freightQuotesTsvHeaderTotalCost,
      l.freightQuotesTsvHeaderOceanFreight,
      l.freightQuotesTsvHeaderLocalCharges,
      l.freightQuotesTsvHeaderInlandCharges,
      l.freightQuotesTsvHeaderTransitDays,
      l.freightQuotesTsvHeaderSailingDate,
      l.freightQuotesTsvHeaderArrivalDate,
      l.freightQuotesTsvHeaderFreeDays,
      l.freightQuotesTsvHeaderStatus,
      l.freightQuotesTsvHeaderRemarks,
    ].join('\t'));

    for (final r in rows) {
      final status = r.isAwarded ? l.quoteAwardedBtn : '-';
      sb.writeln([
        r.carrier,
        '${r.totalCost.toStringAsFixed(2)} ${r.currency}',
        '${r.oceanFreight.toStringAsFixed(2)} ${r.currency}',
        '${r.localCharges.toStringAsFixed(2)} ${r.currency}',
        '${r.inlandCharges.toStringAsFixed(2)} ${r.currency}',
        r.transitDays.toString(),
        r.sailingDate,
        r.arrivalDate,
        r.freeDays.toString(),
        status,
        r.remarks,
      ].join('\t'));
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filePrefix = (importFileCode != null && importFileCode.isNotEmpty) ? importFileCode : 'Comparison';
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: 'Freight_Quotations_${filePrefix}_$dateStr.tsv',
      dialogTitle: l.freightQuotationsExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports quotations comparison table to unmerged CSV/Excel with UTF-8 BOM.
  static Future<void> exportToExcel({
    required BuildContext context,
    required List<dynamic> quotations,
    String? importFileCode,
  }) async {
    final l = context.l10n;
    final rows = quotations.map((q) => FreightQuoteExportRow.from(q)).toList();
    final sb = StringBuffer();

    String escapeCsv(String text) {
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    // CSV Headers
    sb.writeln([
      escapeCsv(l.freightQuotesTsvHeaderCarrier),
      escapeCsv(l.freightQuotesTsvHeaderTotalCost),
      escapeCsv(l.freightQuotesTsvHeaderOceanFreight),
      escapeCsv(l.freightQuotesTsvHeaderLocalCharges),
      escapeCsv(l.freightQuotesTsvHeaderInlandCharges),
      escapeCsv(l.freightQuotesTsvHeaderTransitDays),
      escapeCsv(l.freightQuotesTsvHeaderSailingDate),
      escapeCsv(l.freightQuotesTsvHeaderArrivalDate),
      escapeCsv(l.freightQuotesTsvHeaderFreeDays),
      escapeCsv(l.freightQuotesTsvHeaderStatus),
      escapeCsv(l.freightQuotesTsvHeaderRemarks),
    ].join(','));

    for (final r in rows) {
      final status = r.isAwarded ? l.quoteAwardedBtn : '-';
      sb.writeln([
        escapeCsv(r.carrier),
        escapeCsv('${r.totalCost.toStringAsFixed(2)} ${r.currency}'),
        escapeCsv('${r.oceanFreight.toStringAsFixed(2)} ${r.currency}'),
        escapeCsv('${r.localCharges.toStringAsFixed(2)} ${r.currency}'),
        escapeCsv('${r.inlandCharges.toStringAsFixed(2)} ${r.currency}'),
        escapeCsv(r.transitDays.toString()),
        escapeCsv(r.sailingDate),
        escapeCsv(r.arrivalDate),
        escapeCsv(r.freeDays.toString()),
        escapeCsv(status),
        escapeCsv(r.remarks),
      ].join(','));
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filePrefix = (importFileCode != null && importFileCode.isNotEmpty) ? importFileCode : 'Comparison';
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: 'Freight_Quotations_${filePrefix}_$dateStr.csv',
      dialogTitle: l.freightQuotationsExportExcelDialogTitle,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: true,
    );
  }

  /// Generates vector A4 landscape Cairo PDF and opens the print/save preview.
  static Future<void> printOrSavePdf({
    required BuildContext context,
    required List<dynamic> quotations,
    String? importFileCode,
    String? supplierName,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final rows = quotations.map((q) => FreightQuoteExportRow.from(q)).toList();

    final pdf = pw.Document();
    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (pw.Context pdfContext) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
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
                            l.freightQuotationsDossierHeader,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          if (importFileCode != null && importFileCode.isNotEmpty)
                            pw.Text(
                              '${l.selectImportFileDropdownLabel}: $importFileCode ${supplierName != null ? "($supplierName)" : ""}',
                              style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                            ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#3498DB'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          '${rows.length} ${l.freightQuotationsComparisonTitle}',
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.0), // Carrier
                    1: const pw.FlexColumnWidth(1.2), // Total Cost
                    2: const pw.FlexColumnWidth(1.2), // Ocean Freight
                    3: const pw.FlexColumnWidth(1.1), // Local Charges
                    4: const pw.FlexColumnWidth(1.1), // Inland Charges
                    5: const pw.FlexColumnWidth(0.9), // Transit Days
                    6: const pw.FlexColumnWidth(1.1), // Sailing Date
                    7: const pw.FlexColumnWidth(1.1), // Arrival Date
                    8: const pw.FlexColumnWidth(0.9), // Free Days
                    9: const pw.FlexColumnWidth(1.0), // Status
                    10: const pw.FlexColumnWidth(1.4), // Remarks
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECF0F1')),
                      children: [
                        _pdfHeaderCell(l.freightQuotesTsvHeaderCarrier),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderTotalCost),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderOceanFreight),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderLocalCharges),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderInlandCharges),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderTransitDays),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderSailingDate),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderArrivalDate),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderFreeDays),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderStatus),
                        _pdfHeaderCell(l.freightQuotesTsvHeaderRemarks),
                      ],
                    ),
                    // Data Rows
                    ...rows.map((r) {
                      final status = r.isAwarded ? l.quoteAwardedBtn : '-';
                      final rowColor = r.isAwarded ? PdfColor.fromHex('#E8F8F5') : PdfColors.white;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: rowColor),
                        children: [
                          _pdfDataCell(r.carrier, isBold: r.isAwarded),
                          _pdfDataCell('${r.totalCost.toStringAsFixed(2)} ${r.currency}', isBold: true, color: PdfColor.fromHex('#27AE60')),
                          _pdfDataCell('${r.oceanFreight.toStringAsFixed(2)} ${r.currency}'),
                          _pdfDataCell('${r.localCharges.toStringAsFixed(2)} ${r.currency}'),
                          _pdfDataCell(r.inlandCharges > 0 ? '${r.inlandCharges.toStringAsFixed(2)} ${r.currency}' : '-'),
                          _pdfDataCell(l.transitDaysCount(r.transitDays)),
                          _pdfDataCell(r.sailingDate),
                          _pdfDataCell(r.arrivalDate),
                          _pdfDataCell(l.transitDaysCount(r.freeDays)),
                          _pdfDataCell(status, color: r.isAwarded ? PdfColor.fromHex('#27AE60') : PdfColors.grey700),
                          _pdfDataCell(r.remarks),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 10),

                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Export Date: ${DateTime.now().toString().substring(0, 19)}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                    pw.Text('Sorour Logistics ERP Enterprise Edition', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    final filePrefix = (importFileCode != null && importFileCode.isNotEmpty) ? importFileCode : 'Comparison';
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Freight_Quotations_${filePrefix}_$dateStr.pdf',
    );
  }

  static pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50')),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _pdfDataCell(String text, {bool isBold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}

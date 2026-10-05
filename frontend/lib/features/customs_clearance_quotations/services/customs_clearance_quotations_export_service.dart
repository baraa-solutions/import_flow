import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../models/customs_clearance_quotation_model.dart';
import '../../../core/localization/domain_enum_labels.dart';

class CustomsClearanceQuotationsExportService {
  CustomsClearanceQuotationsExportService._();

  // ===========================================================================
  // 1. TSV EXPORT FOR RFQS & COMPETING QUOTES
  // ===========================================================================

  static Future<void> exportRfqsTsv(
    BuildContext context,
    List<CustomsClearanceRFQModel> rfqs,
  ) async {
    final l10n = context.l10n;
    final buffer = StringBuffer();

    // Header Row
    buffer.writeln([
      l10n.clearanceQuotesTsvHeaderRfqCode,
      l10n.clearanceQuotesTsvHeaderTitle,
      l10n.clearanceQuotesTsvHeaderPort,
      l10n.clearanceQuotesTsvHeaderShipmentType,
      l10n.clearanceQuotesTsvHeaderContainers,
      l10n.clearanceQuotesTsvHeaderWeight,
      l10n.clearanceQuotesTsvHeaderCbm,
      l10n.clearanceQuotesTsvHeaderBroker,
      l10n.clearanceQuotesTsvHeaderClearanceFee,
      l10n.clearanceQuotesTsvHeaderInlandTransport,
      l10n.clearanceQuotesTsvHeaderInspectionFee,
      l10n.clearanceQuotesTsvHeaderPortExpenses,
      l10n.clearanceQuotesTsvHeaderMiscFee,
      l10n.clearanceQuotesTsvHeaderTotal,
      l10n.clearanceQuotesTsvHeaderDays,
      l10n.clearanceQuotesTsvHeaderStatus,
    ].join('\t'));

    // Data Rows
    for (final rfq in rfqs) {
      if (rfq.quotations.isEmpty) {
        buffer.writeln([
          rfq.rfqCode,
          rfq.title,
          rfq.portName,
          rfq.shipmentType,
          rfq.containersCount.toString(),
          '${rfq.grossWeightKg} ${l10n.kgUnit}',
          '${rfq.cbm} ${l10n.cbmUnit}',
          '-',
          '-',
          '-',
          '-',
          '-',
          '-',
          rfq.lowestClearanceCost > 0 ? '${rfq.lowestClearanceCost.toStringAsFixed(2)} ${l10n.egpCurrency}' : '-',
          rfq.fastestTurnaroundDays > 0 ? l10n.clearanceQuotesDaysCount(rfq.fastestTurnaroundDays) : '-',
          rfq.status,
        ].join('\t'));
      } else {
        for (final q in rfq.quotations) {
          buffer.writeln([
            rfq.rfqCode,
            rfq.title,
            rfq.portName,
            rfq.shipmentType,
            rfq.containersCount.toString(),
            '${rfq.grossWeightKg} ${l10n.kgUnit}',
            '${rfq.cbm} ${l10n.cbmUnit}',
            q.providerName,
            '${q.clearanceFee.toStringAsFixed(2)} ${q.currency}',
            '${q.inlandTransportFee.toStringAsFixed(2)} ${q.currency}',
            '${q.inspectionFee.toStringAsFixed(2)} ${q.currency}',
            '${q.portExpenses.toStringAsFixed(2)} ${q.currency}',
            '${q.miscellaneousFee.toStringAsFixed(2)} ${q.currency}',
            '${q.totalCost.toStringAsFixed(2)} ${q.currency}',
            l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays),
            q.isAwarded ? l10n.clearanceQuotesStatusAwardedBadge : rfq.status,
          ].join('\t'));
        }
      }
    }

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: 'clearance_rfqs_${DateTime.now().millisecondsSinceEpoch}.tsv',
      dialogTitle: l10n.clearanceQuotesExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  // ===========================================================================
  // 2. EXCEL / CSV EXPORT FOR RFQS
  // ===========================================================================

  static Future<void> exportRfqsExcel(
    BuildContext context,
    List<CustomsClearanceRFQModel> rfqs,
  ) async {
    final l10n = context.l10n;
    final buffer = StringBuffer();

    String quoteCsv(String val) {
      final sanitized = val.replaceAll('"', '""');
      return '"$sanitized"';
    }

    // Header Row
    buffer.writeln([
      quoteCsv(l10n.clearanceQuotesTsvHeaderRfqCode),
      quoteCsv(l10n.clearanceQuotesTsvHeaderTitle),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPort),
      quoteCsv(l10n.clearanceQuotesTsvHeaderShipmentType),
      quoteCsv(l10n.clearanceQuotesTsvHeaderContainers),
      quoteCsv(l10n.clearanceQuotesTsvHeaderWeight),
      quoteCsv(l10n.clearanceQuotesTsvHeaderCbm),
      quoteCsv(l10n.clearanceQuotesTsvHeaderBroker),
      quoteCsv(l10n.clearanceQuotesTsvHeaderClearanceFee),
      quoteCsv(l10n.clearanceQuotesTsvHeaderInlandTransport),
      quoteCsv(l10n.clearanceQuotesTsvHeaderInspectionFee),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPortExpenses),
      quoteCsv(l10n.clearanceQuotesTsvHeaderMiscFee),
      quoteCsv(l10n.clearanceQuotesTsvHeaderTotal),
      quoteCsv(l10n.clearanceQuotesTsvHeaderDays),
      quoteCsv(l10n.clearanceQuotesTsvHeaderStatus),
    ].join(','));

    // Data Rows
    for (final rfq in rfqs) {
      if (rfq.quotations.isEmpty) {
        buffer.writeln([
          quoteCsv(rfq.rfqCode),
          quoteCsv(rfq.title),
          quoteCsv(rfq.portName),
          quoteCsv(rfq.shipmentType),
          quoteCsv(rfq.containersCount.toString()),
          quoteCsv('${rfq.grossWeightKg} ${l10n.kgUnit}'),
          quoteCsv('${rfq.cbm} ${l10n.cbmUnit}'),
          quoteCsv('-'),
          quoteCsv('-'),
          quoteCsv('-'),
          quoteCsv('-'),
          quoteCsv('-'),
          quoteCsv('-'),
          quoteCsv(rfq.lowestClearanceCost > 0 ? '${rfq.lowestClearanceCost.toStringAsFixed(2)} ${l10n.egpCurrency}' : '-'),
          quoteCsv(rfq.fastestTurnaroundDays > 0 ? l10n.clearanceQuotesDaysCount(rfq.fastestTurnaroundDays) : '-'),
          quoteCsv(rfq.status),
        ].join(','));
      } else {
        for (final q in rfq.quotations) {
          buffer.writeln([
            quoteCsv(rfq.rfqCode),
            quoteCsv(rfq.title),
            quoteCsv(rfq.portName),
            quoteCsv(rfq.shipmentType),
            quoteCsv(rfq.containersCount.toString()),
            quoteCsv('${rfq.grossWeightKg} ${l10n.kgUnit}'),
            quoteCsv('${rfq.cbm} ${l10n.cbmUnit}'),
            quoteCsv(q.providerName),
            quoteCsv('${q.clearanceFee.toStringAsFixed(2)} ${q.currency}'),
            quoteCsv('${q.inlandTransportFee.toStringAsFixed(2)} ${q.currency}'),
            quoteCsv('${q.inspectionFee.toStringAsFixed(2)} ${q.currency}'),
            quoteCsv('${q.portExpenses.toStringAsFixed(2)} ${q.currency}'),
            quoteCsv('${q.miscellaneousFee.toStringAsFixed(2)} ${q.currency}'),
            quoteCsv('${q.totalCost.toStringAsFixed(2)} ${q.currency}'),
            quoteCsv(l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)),
            quoteCsv(q.isAwarded ? l10n.clearanceQuotesStatusAwardedBadge : rfq.status),
          ].join(','));
        }
      }
    }

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: 'clearance_rfqs_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: l10n.clearanceQuotesExportExcelDialogTitle,
      allowedExtensions: ['csv'],
      addUtf8Bom: true,
    );
  }

  // ===========================================================================
  // 3. VECTOR A4 LANDSCAPE PDF FOR RFQS & COMPETING QUOTES
  // ===========================================================================

  static Future<void> printOrSaveRfqsPdf(
    BuildContext context,
    List<CustomsClearanceRFQModel> rfqs,
  ) async {
    final l10n = context.l10n;
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    );

    final totalRfqs = rfqs.length;
    final totalQuotes = rfqs.fold<int>(0, (sum, r) => sum + r.quotations.length);
    final awardedCount = rfqs.where((r) => r.status == 'Awarded').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey700, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.clearanceQuotesScreenTitle,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.Text(
                      l10n.clearanceQuotesScreenSubtitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ImportFlow ERP System',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                    ),
                    pw.Text(
                      DateTime.now().toString().split('.')[0],
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
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.only(top: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'ImportFlow Enterprise - Customs Clearance & Tariff Engine',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            pw.SizedBox(height: 10),

            // Summary Metrics Bar
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpi(l10n.clearanceQuotesTabRfqs, '$totalRfqs'),
                  _buildPdfKpi(l10n.clearanceQuotesReceivedQuotesHeader(totalQuotes), '$totalQuotes'),
                  _buildPdfKpi(l10n.clearanceQuotesStatusAwarded, '$awardedCount'),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // RFQ Sections
            ...rfqs.map((rfq) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // RFQ Title & Parameters
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          '${rfq.rfqCode} - ${rfq.title}',
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: rfq.status == 'Awarded' ? PdfColors.green100 : PdfColors.blueGrey100,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            rfq.status,
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: rfq.status == 'Awarded' ? PdfColors.green900 : PdfColors.blueGrey900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${l10n.clearanceQuotesBadgePort} ${rfq.portName} | ${l10n.clearanceQuotesBadgeShipmentType} ${rfq.shipmentType} (${rfq.containersCount}) | ${l10n.clearanceQuotesBadgeWeight} ${rfq.grossWeightKg} ${l10n.kgUnit} | ${l10n.clearanceQuotesBadgeVolume} ${rfq.cbm} ${l10n.cbmUnit}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 8),

                    // Quotations Table
                    if (rfq.quotations.isEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(
                          l10n.clearanceQuotesNoQuotesYet,
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      )
                    else
                      pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                        children: [
                          // Header
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                            children: [
                              _buildPdfTableCell(l10n.clearanceQuotesColBroker, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColClearanceFee, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColInlandTransport, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColInspectionFee, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColPortExpenses, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColMiscellaneous, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColEstimatedTotal, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesColDuration, isHeader: true),
                              _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderStatus, isHeader: true),
                            ],
                          ),
                          // Data
                          ...rfq.quotations.map((q) {
                            return pw.TableRow(
                              decoration: q.isAwarded ? const pw.BoxDecoration(color: PdfColors.green50) : null,
                              children: [
                                _buildPdfTableCell(q.providerName, isBold: q.isAwarded),
                                _buildPdfTableCell('${q.clearanceFee.toStringAsFixed(0)} ${q.currency}'),
                                _buildPdfTableCell('${q.inlandTransportFee.toStringAsFixed(0)} ${q.currency}'),
                                _buildPdfTableCell('${q.inspectionFee.toStringAsFixed(0)} ${q.currency}'),
                                _buildPdfTableCell('${q.portExpenses.toStringAsFixed(0)} ${q.currency}'),
                                _buildPdfTableCell('${q.miscellaneousFee.toStringAsFixed(0)} ${q.currency}'),
                                _buildPdfTableCell('${q.totalCost.toStringAsFixed(0)} ${q.currency}', isBold: true),
                                _buildPdfTableCell(l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)),
                                _buildPdfTableCell(q.isAwarded ? l10n.clearanceQuotesStatusAwardedBadge : '-'),
                              ],
                            );
                          }),
                        ],
                      ),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'clearance_rfqs_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildPdfKpi(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
      ],
    );
  }

  static pw.Widget _buildPdfTableCell(String text, {bool isHeader = false, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 7.5,
          fontWeight: (isHeader || isBold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blueGrey900 : PdfColors.grey900,
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. PLAIN TEXT CLIPBOARD DOSSIER COPY
  // ===========================================================================

  static void copyRfqDossier(
    BuildContext context,
    List<CustomsClearanceRFQModel> rfqs,
  ) {
    final l10n = context.l10n;
    final buffer = StringBuffer();

    buffer.writeln('====================================================');
    buffer.writeln('📦 ${l10n.clearanceQuotesDossierTitle}');
    buffer.writeln('📅 ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('====================================================\n');

    for (final rfq in rfqs) {
      buffer.writeln('📋 [${rfq.rfqCode}] ${rfq.title}');
      buffer.writeln('   • ${l10n.clearanceQuotesBadgePort} ${rfq.portName}');
      buffer.writeln('   • ${l10n.clearanceQuotesBadgeShipmentType} ${rfq.shipmentType} (${rfq.containersCount})');
      buffer.writeln('   • ${l10n.clearanceQuotesBadgeWeight} ${rfq.grossWeightKg} ${l10n.kgUnit} | ${l10n.clearanceQuotesBadgeVolume} ${rfq.cbm} ${l10n.cbmUnit}');
      buffer.writeln('   • ${l10n.clearanceQuotesTsvHeaderStatus}: ${rfq.status}');

      if (rfq.status == 'Awarded' && rfq.awardedProviderName != null) {
        buffer.writeln('   🏆 ${l10n.clearanceQuotesAwardedBannerPrefix} ${rfq.awardedProviderName}');
      }

      buffer.writeln('   --- ${l10n.clearanceQuotesReceivedQuotesHeader(rfq.quotations.length)} ---');

      if (rfq.quotations.isEmpty) {
        buffer.writeln('   (${l10n.clearanceQuotesNoQuotesYet})');
      } else {
        for (final q in rfq.quotations) {
          final awardTag = q.isAwarded ? ' [${l10n.clearanceQuotesStatusAwardedBadge}]' : '';
          buffer.writeln('   • ${q.providerName}$awardTag:');
          buffer.writeln('     - ${l10n.clearanceQuotesColClearanceFee}: ${q.clearanceFee.toStringAsFixed(0)} ${q.currency}');
          buffer.writeln('     - ${l10n.clearanceQuotesColInlandTransport}: ${q.inlandTransportFee.toStringAsFixed(0)} ${q.currency}');
          buffer.writeln('     - ${l10n.clearanceQuotesColInspectionFee}: ${q.inspectionFee.toStringAsFixed(0)} ${q.currency}');
          buffer.writeln('     - ${l10n.clearanceQuotesColPortExpenses}: ${q.portExpenses.toStringAsFixed(0)} ${q.currency}');
          buffer.writeln('     - ${l10n.clearanceQuotesColMiscellaneous}: ${q.miscellaneousFee.toStringAsFixed(0)} ${q.currency}');
          buffer.writeln('     - ${l10n.clearanceQuotesColEstimatedTotal}: ${q.totalCost.toStringAsFixed(0)} ${q.currency}');
          buffer.writeln('     - ${l10n.clearanceQuotesColDuration}: ${l10n.clearanceQuotesDaysCount(q.estimatedTurnaroundDays)}');
        }
      }
      buffer.writeln('');
    }

    CopyHelper.copy(
      context,
      buffer.toString(),
      customMessage: l10n.clearanceQuotesCopiedDossierSuccess,
    );
  }

  // ===========================================================================
  // 5. PRICE LIST TSV & EXCEL EXPORTS
  // ===========================================================================

  static Future<void> exportPriceListTsv(
    BuildContext context,
    List<ClearancePriceListItemModel> items,
  ) async {
    final l10n = context.l10n;
    final buffer = StringBuffer();

    // Header Row
    buffer.writeln([
      l10n.clearanceQuotesTsvHeaderBroker,
      l10n.clearanceQuotesTsvHeaderPort,
      l10n.clearanceQuotesTsvHeaderPriceServiceType,
      l10n.clearanceQuotesTsvHeaderPriceContainerType,
      l10n.clearanceQuotesTsvHeaderPriceStandardRate,
      l10n.clearanceQuotesTsvHeaderPriceNotes,
    ].join('\t'));

    for (final item in items) {
      buffer.writeln([
        item.providerName,
        item.portName,
        DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory),
        item.containerType,
        '${item.unitPrice.toStringAsFixed(2)} ${item.currency}',
        item.notes ?? '-',
      ].join('\t'));
    }

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: 'clearance_price_list_${DateTime.now().millisecondsSinceEpoch}.tsv',
      dialogTitle: l10n.clearanceQuotesExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  static Future<void> exportPriceListExcel(
    BuildContext context,
    List<ClearancePriceListItemModel> items,
  ) async {
    final l10n = context.l10n;
    final buffer = StringBuffer();

    String quoteCsv(String val) {
      final sanitized = val.replaceAll('"', '""');
      return '"$sanitized"';
    }

    // Header Row
    buffer.writeln([
      quoteCsv(l10n.clearanceQuotesTsvHeaderBroker),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPort),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPriceServiceType),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPriceContainerType),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPriceStandardRate),
      quoteCsv(l10n.clearanceQuotesTsvHeaderPriceNotes),
    ].join(','));

    for (final item in items) {
      buffer.writeln([
        quoteCsv(item.providerName),
        quoteCsv(item.portName),
        quoteCsv(DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory)),
        quoteCsv(item.containerType),
        quoteCsv('${item.unitPrice.toStringAsFixed(2)} ${item.currency}'),
        quoteCsv(item.notes ?? '-'),
      ].join(','));
    }

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: 'clearance_price_list_${DateTime.now().millisecondsSinceEpoch}.csv',
      dialogTitle: l10n.clearanceQuotesExportExcelDialogTitle,
      allowedExtensions: ['csv'],
      addUtf8Bom: true,
    );
  }

  static Future<void> printOrSavePriceListPdf(
    BuildContext context,
    List<ClearancePriceListItemModel> items,
  ) async {
    final l10n = context.l10n;
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey700, width: 1.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      l10n.clearanceQuotesPriceListTitle,
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                    ),
                    pw.Text(
                      l10n.clearanceQuotesPriceListSubtitle,
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Text(
                  DateTime.now().toString().split('.')[0],
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context ctx) {
          return [
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderBroker, isHeader: true),
                    _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderPort, isHeader: true),
                    _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderPriceServiceType, isHeader: true),
                    _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderPriceContainerType, isHeader: true),
                    _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderPriceStandardRate, isHeader: true),
                    _buildPdfTableCell(l10n.clearanceQuotesTsvHeaderPriceNotes, isHeader: true),
                  ],
                ),
                ...items.map((item) {
                  return pw.TableRow(
                    children: [
                      _buildPdfTableCell(item.providerName, isBold: true),
                      _buildPdfTableCell(item.portName),
                      _buildPdfTableCell(DomainEnums.label(l10n, DomainEnumType.clearanceServiceCategory, item.serviceCategory)),
                      _buildPdfTableCell(item.containerType),
                      _buildPdfTableCell('${item.unitPrice.toStringAsFixed(2)} ${item.currency}'),
                      _buildPdfTableCell(item.notes ?? '-'),
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
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'clearance_price_list_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}

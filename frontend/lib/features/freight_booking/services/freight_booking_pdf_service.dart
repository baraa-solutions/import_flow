import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../models/freight_booking_model.dart';

class FreightBookingPdfService {
  FreightBookingPdfService._();

  static Future<Uint8List> build({
    required ShipmentBookingModel booking,
    required AppLocalizations l,
    String? fileCode,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final isAr = l.isArabic;
    final textDir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final b = booking;
    final totalUsd = b.totalFreightCostUsd != null ? '\$${b.totalFreightCostUsd!.toStringAsFixed(2)}' : '—';
    final code = b.bookingCode;
    final displayFileCode = fileCode ?? (b.importFileCode ?? (b.importFileId != null ? 'IMP-${b.importFileId}' : '—'));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey800,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        l.freightBookingPrintSystemHeader,
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        l.freightBookingPrintManifestHeader(code),
                        style: const pw.TextStyle(color: PdfColors.blueGrey100, fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        '${l.freightBookingColImportFile}: $displayFileCode',
                        style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateTime.now().toIso8601String().substring(0, 10),
                        style: const pw.TextStyle(color: PdfColors.blueGrey200, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Route & Carrier Card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${l.freightBookingViewShippingLine} ${b.shippingLineName ?? "—"}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.Text(
                        '${l.freightBookingViewConfirmNo} ${b.bookingConfirmationNo ?? "—"}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                  pw.Divider(color: PdfColors.grey300, height: 16),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${l.freightBookingColRoute}: ${b.polName ?? "—"} → ${b.podName ?? "—"}',
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('${l.freightBookingColVesselVoyage}: ${b.vesselName ?? "—"} / ${b.voyageNumber ?? "—"}',
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(l.freightBookingViewEtd(b.etd != null ? b.etd!.substring(0, 10) : '—'),
                          style: const pw.TextStyle(fontSize: 10)),
                      pw.Text(l.freightBookingViewEta(b.eta != null ? b.eta!.substring(0, 10) : '—'),
                          style: const pw.TextStyle(fontSize: 10)),
                      if (b.atd != null)
                        pw.Text(l.freightBookingViewAtd(b.atd!.substring(0, 10), '+${b.departureDelayDays}d'),
                            style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Containers Section
            if (b.containersData.isNotEmpty) ...[
              pw.Text(
                l.freightBookingPrintContainersHeader,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: [
                  l.freightBookingColContainers,
                  l.cargoShippingContainerNo,
                  l.cargoShippingSealNo,
                ],
                data: b.containersData.expand((c) {
                  if (c.individualContainers.isEmpty) {
                    return [
                      [c.containerType, '—', '—']
                    ];
                  }
                  return c.individualContainers.map((indiv) => [
                        c.containerType,
                        indiv.containerNumber.isEmpty ? '—' : indiv.containerNumber,
                        indiv.sealNumber.isEmpty ? '—' : indiv.sealNumber,
                      ]);
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              ),
              pw.SizedBox(height: 16),
            ],

            // Cost Charges Section
            if (b.costChargesData.isNotEmpty) ...[
              pw.Text(
                l.freightBookingPrintChargesHeader,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: [
                  l.smartTasksColType,
                  l.smartExtractorColUnit,
                  l.smartExtractorColUnitPrice,
                  l.smartExtractorColTotalPrice,
                ],
                data: b.costChargesData.map((ch) {
                  return [
                    ch.chargeType,
                    ch.unit,
                    '${ch.rate.toStringAsFixed(2)} ${ch.currency}',
                    '${ch.total.toStringAsFixed(2)} ${ch.currency}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              ),
              pw.SizedBox(height: 12),
            ],

            // Grand Total
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green700),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    l.freightBookingPrintGrandTotal(totalUsd),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.green900),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}

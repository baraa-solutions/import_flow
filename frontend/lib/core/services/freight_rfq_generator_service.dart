import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../features/import_files/models/import_file_model.dart';
import '../theme/app_theme.dart';
import '../widgets/copyable_data_helper.dart';
import 'file_save_helper.dart';

class FreightRfqGeneratorService {
  /// Generates a professional Freight RFQ Sheet as a PDF document
  static Future<Uint8List> generateFreightRfqPdf({
    required FreightRfqDataModel rfq,
    String? recipientName,
  }) async {
    final pdf = pw.Document();

    pw.Font font;
    pw.Font boldFont;
    try {
      font = await PdfGoogleFonts.cairoRegular();
      boldFont = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      font = await PdfGoogleFonts.amiriRegular();
      boldFont = await PdfGoogleFonts.amiriBold();
    }

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: boldFont,
    );

    const primaryColor = PdfColor.fromInt(0xFF2C3E50); // Charcoal
    const accentColor = PdfColor.fromInt(0xFF3498DB); // Cobalt
    const lightBg = PdfColor.fromInt(0xFFF8F9FA);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        build: (context) => [
          // Header Banner
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'REQUEST FOR FREIGHT QUOTATION (RFQ)',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'International Freight Inquiry & Shipping Specifications',
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFBDC3C7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Ref: ${rfq.customFileNumber ?? rfq.importFileCode}',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Date: ${DateTime.now().toString().substring(0, 10)}',
                      style: const pw.TextStyle(
                        color: PdfColor.fromInt(0xFFBDC3C7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Parties Information Cards
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Importer Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'REQUESTER / IMPORTER',
                        style: pw.TextStyle(color: accentColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        rfq.companyName,
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Logistics & Procurement Dept.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              // Forwarder / Recipient Card
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBg,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'TO / CARRIER & FORWARDER',
                        style: pw.TextStyle(color: accentColor, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        recipientName?.isNotEmpty == true ? recipientName! : 'Shipping Line / Freight Forwarder',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Commercial Freight Rates Team', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // Shipment Key Metrics Table
          pw.Text('1. SHIPMENT SPECIFICATIONS',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFCBD5E1), width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(3),
            },
            children: [
              _buildTableRow('Commodity', rfq.commodity, 'HS Code(s)', rfq.hsCodes.isNotEmpty ? rfq.hsCodes : 'To be declared'),
              _buildTableRow('Incoterm Rule', rfq.incotermCode, 'Shipment Mode', rfq.shipmentMode),
              _buildTableRow('Container / Mode', rfq.recommendedContainers, 'Total Volume', '${rfq.totalCbm.toStringAsFixed(2)} CBM'),
              if (rfq.isAir)
                _buildTableRow('Chargeable Weight', '${rfq.chargeableWeightKg.toStringAsFixed(1)} KG', 'Gross / Net Wt', '${rfq.grossWeightKg.toStringAsFixed(1)} / ${rfq.netWeightKg.toStringAsFixed(1)} KG')
              else
                _buildTableRow('Gross Weight', '${rfq.grossWeightKg.toStringAsFixed(1)} KG', 'Net Weight', '${rfq.netWeightKg.toStringAsFixed(1)} KG'),
              _buildTableRow('Total Packages', '${rfq.totalPackages} Pkgs', 'Stackability', rfq.stackability),
              _buildTableRow('Port / Airport (POL)', rfq.portOfLoading, 'Port / Airport (POD)', rfq.portOfDischarge),
              _buildTableRow('Cargo Ready Date', rfq.cargoReadyDate, 'Required Free Time', '${rfq.targetFreeDays} Days FT at POD'),
            ],
          ),
          pw.SizedBox(height: 16),

          // Pickup Address (for EXW)
          if (rfq.incotermCode.toUpperCase() == 'EXW') ...[
            pw.Text('2. PICKUP & FACTORY LOCATION',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFEF3C7),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFF59E0B)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Shipper: ${rfq.supplierName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text('Factory Address: ${rfq.pickupAddress}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // Packages & Dimensions Breakdown
          if (rfq.packagesBreakdown.isNotEmpty) ...[
            pw.Text('3. PACKAGING & PALLET DIMENSIONS',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: lightBg,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
              ),
              child: pw.Text(
                rfq.packagesBreakdown,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
              ),
            ),
            pw.SizedBox(height: 14),
          ],

          // Required Quotation Inclusions
          pw.Text('4. REQUIRED QUOTATION BREAKDOWN',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: const PdfColor.fromInt(0xFFCBD5E1)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: rfq.isAir
                  ? [
                      _buildBulletPoint('1. Air Freight Rate per KG / All-in in USD.'),
                      if (rfq.incotermCode.toUpperCase() == 'EXW')
                        _buildBulletPoint('2. EXW All-in charges (Trucking from factory + Origin Airport Handling / OTHC + Export Customs Clearance).'),
                      _buildBulletPoint('3. Destination Terminal Handling & D/O fees (DTHC) for ${rfq.portOfDischarge}.'),
                      _buildBulletPoint('4. Flight transit time & flight schedule details.'),
                      _buildBulletPoint('5. Earliest flight departure (ETD date) and booking cutoff.'),
                    ]
                  : [
                      _buildBulletPoint('1. Ocean Freight Rate per container (or LCL w/m rate) in USD.'),
                      if (rfq.incotermCode.toUpperCase() == 'EXW')
                        _buildBulletPoint('2. EXW All-in charges (Trucking from factory + Local Origin Port Terminal / OTHC + Export Customs Clearance).'),
                      _buildBulletPoint('3. Destination Terminal Handling Charges (DTHC for ${rfq.portOfDischarge}).'),
                      _buildBulletPoint('4. Transit time in days & direct vessel schedule details.'),
                      _buildBulletPoint('5. Free time confirmation: Must be at least ${rfq.targetFreeDays} days free time (Demurrage + Detention) at destination.'),
                      _buildBulletPoint('6. Earliest ETD date and booking cutoff date.'),
                    ],
            ),
          ),
          pw.SizedBox(height: 14),

          // Special Instructions
          if (rfq.specialRequirements.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFEFF6FF),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: accentColor),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SPECIAL OPERATIONAL REQUIREMENTS:',
                      style: pw.TextStyle(color: accentColor, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.SizedBox(height: 4),
                  pw.Text(rfq.specialRequirements, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static pw.TableRow _buildTableRow(String label1, String value1, String label2, String value2) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: const PdfColor.fromInt(0xFFF1F5F9),
          child: pw.Text(label1, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value1, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          color: const PdfColor.fromInt(0xFFF1F5F9),
          child: pw.Text(label2, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value2, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  static pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 9.5)),
          ),
        ],
      ),
    );
  }

  /// Copy text to clipboard and show snackbar
  static void copyToClipboard(BuildContext context, String text, String label) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    CopyHelper.copy(
      context,
      text,
      customMessage: isAr ? 'تم نسخ $label إلى الحافظة بنجاح' : '$label copied to clipboard successfully',
    );
  }

  /// Print or Preview PDF
  static Future<void> printOrSavePdf(BuildContext context, Uint8List pdfBytes, String fileCode) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Phase1_Freight_RFQ_$fileCode',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء طباعة الملف: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  /// Exports and Saves Freight RFQ PDF directly with native save dialog
  static Future<String?> savePdfToFile(BuildContext context, Uint8List pdfBytes, String fileCode) async {
    final filename = 'Phase1_Freight_RFQ_${fileCode}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return FileSaveHelper.saveBytes(
      context: context,
      bytes: pdfBytes,
      defaultFileName: filename,
      dialogTitle: 'حفظ طلب عروض أسعار النولون (Freight RFQ) بصيغة PDF',
      allowedExtensions: ['pdf'],
    );
  }
}

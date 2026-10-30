import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/file_save_helper.dart';

class CustomsPdfService {
  /// Generates a PDF byte array for a multi-item customs duty estimation statement.
  static Future<Uint8List> generateMultiItemCustomsPdf({
    required String currency,
    required double exchangeRate,
    required double totalFobFc,
    required double totalFobEgp,
    required double insuranceEgp,
    required double freightEgp,
    required double additionalFeesEgp,
    required double totalCifEgp,
    required String insuranceMode,
    required String freightMode,
    required Map<String, dynamic> result,
  }) async {
    final pdf = pw.Document();

    // Load Arabic Font (Cairo or Amiri from Google Fonts via printing package)
    pw.Font arabicFont;
    pw.Font arabicBoldFont;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBoldFont = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      // Fallback if offline
      arabicFont = await PdfGoogleFonts.amiriRegular();
      arabicBoldFont = await PdfGoogleFonts.amiriBold();
    }

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicBoldFont,
    );

    final String statementNo = result['statement_no']?.toString() ?? 'NAFEZA-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final String dateStr = DateTime.now().toString().split('.').first;

    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    final lines = (result['line_breakdowns'] as List<dynamic>?) ?? (result['lines'] as List<dynamic>?) ?? [];

    final double totalDuty = (result['total_duty_egp'] as num?)?.toDouble() ?? (summary['total_customs_duty_egp'] as num?)?.toDouble() ?? 0.0;
    final double totalVat = (result['total_vat_egp'] as num?)?.toDouble() ?? (summary['total_vat_egp'] as num?)?.toDouble() ?? 0.0;
    final double totalScheduleTax = (result['total_schedule_tax_egp'] as num?)?.toDouble() ?? (summary['total_schedule_tax_egp'] as num?)?.toDouble() ?? 0.0;
    final double totalServiceFee = (result['total_customs_service_fee_egp'] as num?)?.toDouble() ?? (summary['total_customs_service_fee_egp'] as num?)?.toDouble() ?? 0.0;
    final double totalDevFee = (result['total_development_fee_egp'] as num?)?.toDouble() ?? (summary['total_development_fee_egp'] as num?)?.toDouble() ?? 0.0;
    final double totalInspection = (result['total_inspection_fees_egp'] as num?)?.toDouble() ?? (summary['total_inspection_fees_egp'] as num?)?.toDouble() ?? 0.0;
    final double grandTotalDuties = (result['grand_total_payable_egp'] as num?)?.toDouble() ?? (summary['total_duties_and_taxes_egp'] as num?)?.toDouble() ?? 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Header Title Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#2C3E50'),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'بيان تقدير الضرائب والرسوم الجمركية',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Sorour Logistics ERP — Customs Duty Calculation Engine (Nafeza Format)',
                        style: const pw.TextStyle(
                          color: PdfColors.grey300,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'رقم البيان: $statementNo',
                        style: pw.TextStyle(color: PdfColors.amber, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'التاريخ: $dateStr',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Key Financial Parameters Grid
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#ECF0F1'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#BDC3C7')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfMetaItem('عملة الفاتورة:', currency),
                  _pdfMetaItem('سعر الصرف الرسمي:', '$exchangeRate EGP/$currency'),
                  _pdfMetaItem('إجمالي الفاتورة (FOB):', '${totalFobFc.toStringAsFixed(2)} $currency'),
                  _pdfMetaItem('التأمين ($insuranceMode):', '${insuranceEgp.toStringAsFixed(2)} EGP'),
                  _pdfMetaItem('النولون ($freightMode):', '${freightEgp.toStringAsFixed(2)} EGP'),
                  _pdfMetaItem('القيمة الجمركية (CIF):', '${totalCifEgp.toStringAsFixed(2)} EGP', isHighlight: true),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Executive Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#3498DB'), width: 1.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('إجمالي المستحق للجمارك والضرائب:',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfSummaryStat('ضريبة الوارد', '${totalDuty.toStringAsFixed(2)} EGP'),
                      _pdfSummaryStat('ضريبة الجدول', '${totalScheduleTax.toStringAsFixed(2)} EGP'),
                      _pdfSummaryStat('أ.ن.ص (1%)', '${totalServiceFee.toStringAsFixed(2)} EGP'),
                      _pdfSummaryStat('القيمة المضافة (VAT)', '${totalVat.toStringAsFixed(2)} EGP'),
                      _pdfSummaryStat('خدمات ونولون/فحص', '${(totalInspection + additionalFeesEgp + totalDevFee).toStringAsFixed(2)} EGP'),
                    ],
                  ),
                  pw.Divider(color: PdfColor.fromHex('#3498DB')),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي الضرائب والرسوم المستحقة سدادها:',
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
                      pw.Text('${grandTotalDuties.toStringAsFixed(2)} EGP',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#27AE60'))),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Line Items Detailed Table
            pw.Text('جدول تفاصيل البنود والأصناف الجمركية:',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headers: [
                'السطر',
                'HS Code',
                'المنشأ',
                'القيمة ($currency)',
                'CIF (EGP)',
                'ضريبة الوارد',
                'ض.جدول',
                'أ.ن.ص (1%)',
                'القيمة المضافة',
                'فحص/خدمات'
              ],
              data: lines.map((l) {
                final lineMap = l as Map<String, dynamic>;
                final lineNo = lineMap['line_no'] ?? '-';
                final hs = lineMap['hs_code'] ?? '-';
                final origin = lineMap['origin_country'] ?? '-';
                final valFc = (lineMap['value_fc'] as num?)?.toDouble() ?? 0.0;
                final cifEgp = (lineMap['cif_value_egp'] as num?)?.toDouble() ?? (lineMap['cif_allocated_egp'] as num?)?.toDouble() ?? 0.0;
                final dutyEgp = (lineMap['duty_egp'] as num?)?.toDouble() ?? (lineMap['customs_duty_amount'] as num?)?.toDouble() ?? 0.0;
                final dutyRate = (lineMap['customs_duty_rate'] as num?)?.toDouble() ?? 0.0;
                final schedEgp = (lineMap['schedule_tax_egp'] as num?)?.toDouble() ?? 0.0;
                final svcEgp = (lineMap['customs_service_fee_egp'] as num?)?.toDouble() ?? 0.0;
                final vatEgp = (lineMap['vat_egp'] as num?)?.toDouble() ?? (lineMap['vat_amount'] as num?)?.toDouble() ?? 0.0;
                final vatRate = (lineMap['vat_rate'] as num?)?.toDouble() ?? 0.0;
                final inspEgp = (lineMap['inspection_fee_egp'] as num?)?.toDouble() ?? 0.0;

                return [
                  '$lineNo',
                  '$hs',
                  '$origin',
                  valFc.toStringAsFixed(2),
                  cifEgp.toStringAsFixed(2),
                  '${dutyEgp.toStringAsFixed(2)}\n($dutyRate%)',
                  schedEgp.toStringAsFixed(2),
                  svcEgp.toStringAsFixed(2),
                  '${vatEgp.toStringAsFixed(2)}\n($vatRate%)',
                  inspEgp.toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.center,
              border: pw.TableBorder.all(color: PdfColor.fromHex('#BDC3C7'), width: 0.5),
            ),

            pw.SizedBox(height: 20),

            // Footer Signature & Audit
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ملاحظات وإخلاء مسؤولية:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('هذا البيان التقديري تم استخراجه آلياً بواسطة محرك الحسابات الجمركية لشركة Sorour Logistics ERP.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                    pw.Text('تُطبق القواعد والأسعار المعتمدة بجدول التعريفة الجمركية المصرية ومعطيات منصة نافذة.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('توقيع / واعتماد المخلص الجمركي:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 20),
                    pw.Text('_________________________', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfMetaItem(String label, String value, {bool isHighlight = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: isHighlight ? PdfColor.fromHex('#C0392B') : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static pw.Widget _pdfSummaryStat(String title, String amount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(amount, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
      ],
    );
  }

  /// Print directly to printer
  static Future<void> printStatement({
    required String currency,
    required double exchangeRate,
    required double totalFobFc,
    required double totalFobEgp,
    required double insuranceEgp,
    required double freightEgp,
    required double additionalFeesEgp,
    required double totalCifEgp,
    required String insuranceMode,
    required String freightMode,
    required Map<String, dynamic> result,
  }) async {
    final pdfBytes = await generateMultiItemCustomsPdf(
      currency: currency,
      exchangeRate: exchangeRate,
      totalFobFc: totalFobFc,
      totalFobEgp: totalFobEgp,
      insuranceEgp: insuranceEgp,
      freightEgp: freightEgp,
      additionalFeesEgp: additionalFeesEgp,
      totalCifEgp: totalCifEgp,
      insuranceMode: insuranceMode,
      freightMode: freightMode,
      result: result,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Phase1_Nafeza_Customs_Duty_Statement',
    );
  }

  /// Download/Save PDF file to disk
  static Future<String?> downloadPdf({
    BuildContext? context,
    required String currency,
    required double exchangeRate,
    required double totalFobFc,
    required double totalFobEgp,
    required double insuranceEgp,
    required double freightEgp,
    required double additionalFeesEgp,
    required double totalCifEgp,
    required String insuranceMode,
    required String freightMode,
    required Map<String, dynamic> result,
  }) async {
    final pdfBytes = await generateMultiItemCustomsPdf(
      currency: currency,
      exchangeRate: exchangeRate,
      totalFobFc: totalFobFc,
      totalFobEgp: totalFobEgp,
      insuranceEgp: insuranceEgp,
      freightEgp: freightEgp,
      additionalFeesEgp: additionalFeesEgp,
      totalCifEgp: totalCifEgp,
      insuranceMode: insuranceMode,
      freightMode: freightMode,
      result: result,
    );

    final String defaultFileName = 'Phase1_Nafeza_Customs_Statement_${DateTime.now().millisecondsSinceEpoch}.pdf';
    
    if (context == null || !context.mounted) return null;
    return FileSaveHelper.saveBytes(
      context: context,
      bytes: pdfBytes,
      defaultFileName: defaultFileName,
      dialogTitle: 'حفظ بيان التقدير الجمركي بصيغة PDF',
      allowedExtensions: ['pdf'],
    );
  }
}

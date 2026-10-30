import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/file_save_helper.dart';
import '../models/customs_consultation_model.dart';
import 'customs_export_service.dart';

class CustomsConsultationPdfService {
  /// Generates an enterprise-grade Arabic PDF for a Customs Consultation statement, checklist, broker quote, and Nafeza fee breakdown.
  static Future<Uint8List> generateConsultationPdf(CustomsConsultationModel session) async {
    final pdf = pw.Document();

    pw.Font arabicFont;
    pw.Font arabicBoldFont;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBoldFont = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      arabicFont = await PdfGoogleFonts.amiriRegular();
      arabicBoldFont = await PdfGoogleFonts.amiriBold();
    }

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicBoldFont,
    );

    // Compute Nafeza Breakdown
    final nafezaBreakdown = CustomsExportService.computeNafezaFeeBreakdown(
      totalDutyEgp: session.estimatedDutiesEgp * 0.45, // approximate or exact duty component
      totalVatEgp: session.estimatedDutiesEgp * 0.45,
      totalServiceFeeEgp: session.estimatedDutiesEgp * 0.10,
      totalScheduleTaxEgp: 0.0,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          final appliedBrokerQuotes = session.brokerQuoteItems.where((q) => q.isApplicable).toList();

          return [
            // Header Box
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
                        'تقرير دراسة الاستشارة الجمركية والفحص المستندي وبيان نافذة الرسمي',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Sorour Logistics ERP — Customs Duty & Nafeza Statement Calculation Engine',
                        style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 8),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'كود الدراسة: ${session.consultationCode}',
                        style: pw.TextStyle(color: PdfColors.amber, fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'التاريخ: ${session.createdAt.split("T").first.split(" ").first}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Metadata Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'عنوان الدراسة: ${session.title}',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                      ),
                      pw.Text(
                        'الحالة العامة: ${session.overallStatus}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColor.fromHex('#3498DB')),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('ملف الشحنة: ${session.importFileCode ?? "-"}', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('المستخلص الجمركي: ${session.brokerName}', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text(
                        'الرسوم الجمركية والضرائب: ${session.estimatedDutiesEgp.toStringAsFixed(2)} EGP',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C0392B')),
                      ),
                      pw.Text(
                        'أتعاب ومصاريف المخلص: ${session.totalBrokerFeesEgp.toStringAsFixed(2)} EGP',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#27AE60')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Quick Metrics Summary Box
            pw.Row(
              children: [
                _buildPdfMetricBox('نسبة الجاهزية الجمركية', '${session.readinessPercentage.toStringAsFixed(0)}%', PdfColor.fromHex('#3498DB')),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('إجمالي المستندات', '${session.totalDocumentsCount}', PdfColor.fromHex('#2C3E50')),
                _buildPdfMetricBox('المستندات المعتمدة', '${session.approvedDocumentsCount}', PdfColor.fromHex('#27AE60')),
                _buildPdfMetricBox(
                  'عوائق التخليص',
                  '${session.blockingIssuesCount} عائق',
                  session.blockingIssuesCount > 0 ? PdfColor.fromHex('#C0392B') : PdfColor.fromHex('#27AE60'),
                ),
                _buildPdfMetricBox(
                  'إجمالي التكلفة التقديرية',
                  '${(session.estimatedDutiesEgp + session.totalBrokerFeesEgp).toStringAsFixed(2)} EGP',
                  PdfColor.fromHex('#E67E22'),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // 1. Nafeza Statement Fee Breakdown (تفاصيل بنود التحصيل والإقرارات الرسمية)
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#3498DB')),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '🏛️ تفاصيل بنود التحصيل والإقرارات الرسمية:',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50')),
                      ),
                      pw.Text(
                        'إجمالي البيان: ${session.estimatedDutiesEgp > 0 ? session.estimatedDutiesEgp.toStringAsFixed(2) : nafezaBreakdown.grandTotal.toStringAsFixed(2)} ج.م',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#27AE60')),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  ...nafezaBreakdown.groups.map((group) {
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            color: PdfColors.grey200,
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('تحصيل ${group.groupName}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                                pw.Text('${group.totalAmount.toStringAsFixed(2)} ج.م', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                              ],
                            ),
                          ),
                          ...group.items.map((item) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              child: pw.Row(
                                children: [
                                  pw.Container(
                                    width: 30,
                                    child: pw.Text('[${item.code}]', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                                  ),
                                  pw.Expanded(
                                    child: pw.Text(item.nameAr, style: const pw.TextStyle(fontSize: 8)),
                                  ),
                                  pw.Container(
                                    width: 40,
                                    child: pw.Text(
                                      item.calculationType == 'flat' ? 'قطعي' : (item.calculationType == 'reference' ? 'مرجعي' : 'مشتق'),
                                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                                    ),
                                  ),
                                  pw.Text('${item.calculatedAmount.toStringAsFixed(2)} ج.م', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // 2. Broker Quote Section (if items exist)
            if (appliedBrokerQuotes.isNotEmpty) ...[
              pw.Text(
                '💰 بيان تفاصيل عرض أسعار التخليص الجمركي والنقل للمستخلص (${session.brokerName}):',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50')),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.2),
                  1: pw.FlexColumnWidth(1.8),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.6),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECF0F1')),
                    children: [
                      _buildPdfTableHeader('نوع المصروف / الخدمة'),
                      _buildPdfTableHeader('التصنيف'),
                      _buildPdfTableHeader('سعر الوحدة'),
                      _buildPdfTableHeader('الكمية'),
                      _buildPdfTableHeader('الإجمالي'),
                    ],
                  ),
                  ...appliedBrokerQuotes.map((quote) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(quote.expenseName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(quote.category.split('(').first.trim(), style: const pw.TextStyle(fontSize: 7.5)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${quote.unitPrice.toStringAsFixed(2)} ${quote.currency}', style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${quote.qty}', style: const pw.TextStyle(fontSize: 8)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${quote.totalAmount.toStringAsFixed(2)} ${quote.currency}',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#27AE60')),
                          ),
                        ),
                      ],
                    );
                  }),
                  // Total Broker Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5EEF8')),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('إجمالي أتعاب ومصاريف المخلص المطبقة:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Container(),
                      pw.Container(),
                      pw.Container(),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '${session.totalBrokerFeesEgp.toStringAsFixed(2)} EGP',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#8E44AD')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
            ],

            // 3. Checklist Table Header
            pw.Text(
              '📋 قائمة فحص المستندات والاشتراطات الجمركية المعتمدة للشحنة:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#2C3E50')),
            ),
            pw.SizedBox(height: 6),

            // Table of Checklist Items
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.0),
                1: pw.FlexColumnWidth(1.4),
                2: pw.FlexColumnWidth(1.0),
                3: pw.FlexColumnWidth(2.6),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECF0F1')),
                  children: [
                    _buildPdfTableHeader('نوع المستند وبنود التعريفة'),
                    _buildPdfTableHeader('الجهة المسؤولة'),
                    _buildPdfTableHeader('الحالة'),
                    _buildPdfTableHeader('الاشتراطات والملاحظات'),
                  ],
                ),
                ...session.checklistItems.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              item.documentType,
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                            ),
                            if (item.hsCode != null && item.hsCode!.isNotEmpty)
                              pw.Text(
                                'بنود: ${item.hsCode}',
                                style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey700),
                              ),
                            if (item.isBlockingShipment)
                              pw.Text(
                                '⚠️ عائق معطل للشحن/التخليص',
                                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.red900),
                              ),
                          ],
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item.responsibleParty, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          item.status,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: item.status == 'Approved'
                                ? PdfColor.fromHex('#27AE60')
                                : (item.status == 'Rejected' ? PdfColor.fromHex('#C0392B') : PdfColors.black),
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item.remarks ?? '-', style: const pw.TextStyle(fontSize: 7.5)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports and Saves Customs Consultation PDF directly with native save dialog
  static Future<String?> saveConsultationPdfToFile(BuildContext context, CustomsConsultationModel session) async {
    final pdfBytes = await generateConsultationPdf(session);
    final defaultFileName = 'Phase1_Customs_Consultation_${session.consultationCode}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    if (!context.mounted) return null;
    return FileSaveHelper.saveBytes(
      context: context,
      bytes: pdfBytes,
      defaultFileName: defaultFileName,
      dialogTitle: 'حفظ تقرير دراسة الاستشارة الجمركية بصيغة PDF',
      allowedExtensions: ['pdf'],
    );
  }

  /// Prints or previews consultation PDF via Printing.layoutPdf
  static Future<void> printOrPreviewConsultationPdf(BuildContext context, CustomsConsultationModel session) async {
    final pdfBytes = await generateConsultationPdf(session);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Customs_Consultation_${session.consultationCode}',
    );
  }

  /// Generates and prints or previews customs tax calculation report PDF
  static Future<void> printOrPreviewCalculationReportPdf({
    required BuildContext context,
    required String title,
    required String? importFileCode,
    required String brokerName,
    required String currency,
    required double exchangeRate,
    required double totalFreightEgp,
    required double totalInsuranceEgp,
    required List<CustomsItemCalcRow> calcLines,
    required NafezaFeeBreakdownResult nafezaResult,
    required List<CustomsBrokerQuoteItemModel> brokerQuoteItems,
    required List<CustomsChecklistItemModel> checklist,
  }) async {
    final session = CustomsConsultationModel(
      consultationId: 0,
      consultationCode: importFileCode != null ? 'CALC-$importFileCode' : 'CALC-${DateTime.now().millisecondsSinceEpoch}',
      brokerId: 0,
      brokerName: brokerName.isNotEmpty ? brokerName : 'Customs Broker',
      title: title.isNotEmpty ? title : 'Customs Tax & Tariff Assessment',
      overallStatus: 'Pending Review',
      estimatedDutiesEgp: calcLines.fold(0.0, (s, l) => s + l.totalTaxesAndDutiesEgp),
      totalBrokerFeesEgp: brokerQuoteItems.fold(0.0, (s, i) => s + (i.isApplicable ? i.totalAmount : 0.0)),
      checklistItems: checklist,
      brokerQuoteItems: brokerQuoteItems,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    final pdfBytes = await generateConsultationPdf(session);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Customs_Tax_Assessment_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Generates an enterprise-grade Arabic A4 PDF statement for the list of customs consultations / tax reviews
  static Future<Uint8List> generateConsultationsLogPdf(List<CustomsConsultationModel> sessions) async {
    final pdf = pw.Document();

    pw.Font arabicFont;
    pw.Font arabicBoldFont;
    try {
      arabicFont = await PdfGoogleFonts.cairoRegular();
      arabicBoldFont = await PdfGoogleFonts.cairoBold();
    } catch (_) {
      arabicFont = await PdfGoogleFonts.amiriRegular();
      arabicBoldFont = await PdfGoogleFonts.amiriBold();
    }

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicBoldFont,
    );

    final totalEstimatedDuties = sessions.fold(0.0, (sum, s) => sum + s.estimatedDutiesEgp);
    final readyCount = sessions.where((s) => s.overallStatus == 'Clearance Ready').length;
    final blockedCount = sessions.where((s) => s.overallStatus == 'Blocked' || s.hasBlockingIssues).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            // Header Box
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
                        'سجل دراسات الضرائب والرسوم الجمركية وبيان 46',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        'منظومة إدارة الاستيراد والتخليص الجمركي — كشف رسمي',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'إجمالي الدراسات: ${sessions.length}',
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'تاريخ الطباعة: ${DateTime.now().toLocal().toString().split(".").first}',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Summary Metrics Row
            pw.Row(
              children: [
                _buildPdfMetricBox('إجمالي الدراسات', '${sessions.length}', PdfColor.fromHex('#2C3E50')),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('جاهز للتخليص', '$readyCount', PdfColor.fromHex('#27AE60')),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('معطل / عوائق', '$blockedCount', blockedCount > 0 ? PdfColor.fromHex('#C0392B') : PdfColors.grey700),
                pw.SizedBox(width: 8),
                _buildPdfMetricBox('إجمالي الرسوم التقديرية', '${totalEstimatedDuties.toStringAsFixed(2)} ج.م', PdfColor.fromHex('#2980B9')),
              ],
            ),
            pw.SizedBox(height: 12),

            // Consultations Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2), // Code
                1: pw.FlexColumnWidth(1.1), // Import File
                2: pw.FlexColumnWidth(2.8), // Title
                3: pw.FlexColumnWidth(1.8), // Broker
                4: pw.FlexColumnWidth(1.6), // Duties
                5: pw.FlexColumnWidth(1.0), // Readiness
                6: pw.FlexColumnWidth(1.2), // Status
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECF0F1')),
                  children: [
                    _buildPdfTableHeader('كود الدراسة'),
                    _buildPdfTableHeader('ملف الشحنة'),
                    _buildPdfTableHeader('الموضوع / الوصف'),
                    _buildPdfTableHeader('المستخلص الجمركي'),
                    _buildPdfTableHeader('الرسوم التقديرية'),
                    _buildPdfTableHeader('الجاهزية'),
                    _buildPdfTableHeader('الحالة'),
                  ],
                ),
                ...sessions.map((s) {
                  final fileCodeStr = s.importFileCode ?? (s.importFileId != null ? 'IMP-${s.importFileId}' : '—');
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(s.consultationCode, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2980B9'))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(fileCodeStr, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(s.title, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(s.brokerName, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('${s.estimatedDutiesEgp.toStringAsFixed(2)} ج.م', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C0392B'))),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('${s.readinessPercentage.toStringAsFixed(0)}%', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text(
                          s.overallStatus == 'Clearance Ready'
                              ? 'جاهز للتخليص'
                              : (s.overallStatus == 'Blocked'
                                  ? 'معطل'
                                  : (s.overallStatus == 'In Progress'
                                      ? 'قيد الإجراء'
                                      : (s.overallStatus == 'Action Required'
                                          ? 'مطلوب إجراء'
                                          : 'قيد المراجعة'))),
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                }),
                // Total Summary Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F5EEF8')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('الإجمالي', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${sessions.length} استشارة', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        '${totalEstimatedDuties.toStringAsFixed(2)} ج.م',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#C0392B')),
                      ),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
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

  /// Prints or previews consultations log statement via Printing.layoutPdf
  static Future<void> printOrPreviewConsultationsLogPdf(BuildContext context, List<CustomsConsultationModel> sessions) async {
    final pdfBytes = await generateConsultationsLogPdf(sessions);
    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Customs_Tax_Review_Log_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static pw.Widget _buildPdfMetricBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: color, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 7, color: color, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfTableHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('#2C3E50')),
      ),
    );
  }
}


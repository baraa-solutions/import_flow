import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/copyable_data_helper.dart';
import '../../models/shipment_audit_timeline_model.dart';

/// Helper for exporting and printing shipment audit timeline data (CSV, PDF, and Clipboard).
class TimelineExportHelper {
  TimelineExportHelper._();

  static void copyAllTable(BuildContext context, ShipmentAuditTimelineModel data) {
    final sb = StringBuffer();
    sb.writeln('محضر التتبع الزمني للشحنة: ${data.importFileCode} (${data.customFileNumber ?? ""})');
    sb.writeln(
        'أرضيات الميناء تبدأ: ${data.financialRadar.portStorageStartDate} | غرامات الحاوية تبدأ: ${data.financialRadar.demurrageStartDate}');
    sb.writeln(
        'المتوقع للمخزن: ${data.financialRadar.expectedWarehouseDeliveryDate} | الفعلي: ${data.financialRadar.actualWarehouseDeliveryDate ?? "جاري"}');
    sb.writeln('------------------------------------------------------------');
    for (final m in data.milestones) {
      sb.writeln(
          '#${m.seq} | ${m.nameAr} | مخطط: ${m.plannedDate ?? "-"} | فعلي: ${m.actualDate ?? "-"} | فارق: ${m.varianceDays} يوم | مدة: ${m.tatDisplay ?? "-"} | حالة: ${m.status} | ملاحظات: ${m.notes ?? ""}');
    }
    CopyHelper.copy(context, sb.toString());
  }

  static Future<void> exportExcelCsv(
    BuildContext context,
    ShipmentAuditTimelineModel data,
    String directivesText,
  ) async {
    final sb = StringBuffer();

    // UTF-8 BOM
    sb.write('\uFEFF');

    sb.writeln('محضر ورادار التتبع الزمني الشامل للشحنة (36 محطة وسجل تتبع الباخرة)');
    sb.writeln('كود الشحنة,${data.importFileCode},رقم الملف,${data.customFileNumber ?? "-"}');
    sb.writeln('الشركة المستوردة,${data.companyName},المورد الأجنبي,${data.supplierName}');
    sb.writeln('الخط الملاحي,${data.shippingLineName ?? "-"},رقم البوليصة,${data.billOfLadingNo ?? "-"}');
    sb.writeln('ميناء الشحن,${data.portOfLoading ?? "-"},ميناء الوصول,${data.portOfDischarge ?? "-"}');
    sb.writeln(
        'تاريخ بدء أرضيات الميناء,${data.financialRadar.portStorageStartDate ?? "-"},سماح الميناء,${data.financialRadar.portStorageFreeDays} أيام');
    sb.writeln(
        'تاريخ بدء غرامات الحاوية,${data.financialRadar.demurrageStartDate ?? "-"},سماح الخط,${data.financialRadar.demurrageFreeDays} يوما');
    sb.writeln(
        'التاريخ المتوقع لوصول المخزن,${data.financialRadar.expectedWarehouseDeliveryDate ?? "-"},التاريخ الفعلي للمخزن,${data.financialRadar.actualWarehouseDeliveryDate ?? "-"}');
    sb.writeln();

    sb.writeln('--- مصفوفة الـ 36 محطة زمنية والملاحظات التشغيلية ---');
    sb.writeln(
        '#,كود المحطة,اسم المحطة والحدث الزمني,المرحلة,التاريخ المخطط,التاريخ الفعلي,الفارق (أيام),مدة الإنجاز,الحالة,الملاحظات والتوجيهات التشغيلية');

    for (final m in data.milestones) {
      final safeName = m.nameAr.replaceAll(',', ' - ');
      final safeNotes = (m.notes ?? '').replaceAll(',', ' - ').replaceAll('\n', ' ');
      sb.writeln(
          '${m.seq},${m.code},"$safeName",Phase ${m.phaseNumber},${m.plannedDate ?? "-"},${m.actualDate ?? "-"},${m.varianceDays},${m.tatDisplay ?? "-"},${m.status},"$safeNotes"');
    }

    sb.writeln();
    sb.writeln('--- سجل نبضات تتبع الباخرة كل 3 أيام ---');
    sb.writeln('رقم التحديث,تاريخ التحديث,الموقع الجغرافي للباخرة,الـ ETA في هذا اليوم,أيام الانحراف,الملاحظات المكتوبة');

    for (final p in data.vesselTrackingPulse) {
      final safeLoc = p.vesselLocation.replaceAll(',', ' - ');
      final safeRem = (p.remarks ?? '').replaceAll(',', ' - ');
      sb.writeln('تحديث ${p.updateSeq},${p.trackingDate},"$safeLoc",${p.currentEta},+${p.delayDays} يوم,"$safeRem"');
    }

    sb.writeln();
    sb.writeln('--- محضر وتوجيهات الاجتماع التشغيلي ---');
    sb.writeln('"${directivesText.replaceAll('"', '""')}"');

    final csvBytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(sb.toString())];
    await FileSaveHelper.exportAndSaveFile(
      context: context,
      bytes: csvBytes,
      stageName: 'Timeline-Audit-36-Milestones',
      importFileNameOrCode: data.importFileCode,
      extension: 'csv',
    );
  }

  static Future<void> printOrExportPdf(
    BuildContext context,
    ShipmentAuditTimelineModel data,
    String directivesText,
  ) async {
    try {
      final doc = pw.Document();
      final font = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('تقرير ومحضر التتبع الزمني والرقابي الشامل للشحنة',
                      style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.Text('${data.importFileCode} | ${data.customFileNumber ?? ""}',
                      style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.blue900)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المورد: ${data.supplierName}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('الخط الملاحي: ${data.shippingLineName ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('البوليصة: ${data.billOfLadingNo ?? "-"}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('أرضيات الميناء: ${data.financialRadar.portStorageStartDate}',
                      style: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColors.red900)),
                  pw.Text('غرامات الحاوية: ${data.financialRadar.demurrageStartDate}',
                      style: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColors.red900)),
                  pw.Text('المتوقع للمخزن: ${data.financialRadar.expectedWarehouseDeliveryDate}',
                      style: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColors.green900)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('مصفوفة الـ 36 محطة زمنية والملاحظات:', style: pw.TextStyle(font: fontBold, fontSize: 12)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                '#',
                'المحطة والحدث الزمني',
                'المخطط',
                'الفعلي',
                'الفارق',
                'المدة',
                'الحالة',
                'الملاحظات التشغيلية والتوجيهات'
              ],
              data: data.milestones
                  .map((m) => [
                        '${m.seq}',
                        m.nameAr,
                        m.plannedDate ?? '-',
                        m.actualDate ?? '-',
                        '${m.varianceDays}',
                        m.tatDisplay ?? '-',
                        m.status,
                        m.notes ?? '-',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 12),
            pw.Text('توجيهات ومحضر الاجتماع:', style: pw.TextStyle(font: fontBold, fontSize: 11)),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Text(
                  directivesText.isNotEmpty ? directivesText : 'لا توجد ملاحظات إضافية.',
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(context, 'تعذر إنشاء ملف الطباعة: $e', severity: AppSeverity.danger),
        );
      }
    }
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/helpers/table_copy_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/file_save_helper.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../models/import_file_model.dart';

/// Helper service managing export operations (TSV, PNG, Excel, PDF)
/// for the Visual Container Load Planner.
class LoadPlannerExportHelper {
  LoadPlannerExportHelper._();

  static String getScenarioName(bool? mode, AppLocalizations l) {
    if (mode == true) return l.allStackableChip;
    if (mode == false) return l.allNonStackableChip;
    return l.mixedStackingChip;
  }

  static String getPlanStatusText(ContainerPackingResult res, AppLocalizations l) {
    if (res.containerCode == 'FAILED') {
      return l.containerLoadFailed;
    }
    final nonStackCount = res.placedItems.where((p) => !p.item.isStackable).length;
    if (nonStackCount > 0) {
      return '${l.allNonStackableChip}: $nonStackCount';
    }
    final spaceUtil = res.spec.internalVolumeCbm > 0
        ? (res.totalVolume / res.spec.internalVolumeCbm * 100).toStringAsFixed(1)
        : '0.0';
    return '${l.containerGoodUtil} ($spaceUtil%)';
  }

  static Future<Uint8List?> captureContainerRender(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static void copyTableTsv({
    required BuildContext context,
    required AppLocalizations l,
    required List<ContainerPackingResult> plan,
  }) {
    final headers = [
      l.containerSpecType,
      l.packingListItemsCol,
      l.totalGrossWeightFromPl,
      l.spaceUtilizationPercent,
      l.currentPhaseStage,
    ];

    final rows = plan.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final res = entry.value;
      final specText = res.containerCode == 'FAILED'
          ? l.containerLoadFailed
          : '$idx: ${res.spec.code}';
      final placedIds = res.placedItemsSummary;
      final weightText = res.containerCode == 'FAILED'
          ? '-'
          : '${res.totalWeight.toStringAsFixed(0)} kg';
      final spaceUtil = res.spec.internalVolumeCbm > 0
          ? '${((res.totalVolume / res.spec.internalVolumeCbm) * 100).toStringAsFixed(1)}%'
          : '0.0%';
      final statusText = getPlanStatusText(res, l);

      return [
        specText,
        placedIds.isEmpty ? '-' : placedIds,
        weightText,
        spaceUtil,
        statusText,
      ];
    }).toList();

    TableCopyHelper.copyTable(context, headers, rows);
  }

  static Future<void> saveImage({
    required BuildContext context,
    required GlobalKey visualKey,
    required ImportFileModel file,
    required bool? activeStackingMode,
    required AppLocalizations l,
  }) async {
    try {
      final pngBytes = await captureContainerRender(visualKey);
      if (pngBytes == null || pngBytes.isEmpty) {
        throw Exception(l.containerImageCaptureError);
      }

      if (!context.mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: pngBytes,
        stageName: 'Container Load Planner',
        importFileNameOrCode:
            '${file.companyName} (${file.importFileCode}) - ${getScenarioName(activeStackingMode, l)}',
        extension: 'png',
        customDialogTitle: l.saveContainerImageDialogTitle,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${l.containerExportError}$e',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  static Future<void> exportExcel({
    required BuildContext context,
    required ImportFileModel file,
    required bool? activeStackingMode,
    required List<ContainerPackingResult> plan,
    required double totalPlanWeight,
    required double totalPlanVolume,
    required int totalPkgs,
    required int stackableInActive,
    required int nonStackableInActive,
    required String fleetSummaryText,
    required AppLocalizations l,
  }) async {
    try {
      final isAr = l.isArabic;
      final buffer = StringBuffer();
      buffer.writeln(isAr
          ? 'تقرير ومحاكاة رص الحاويات وتوزيع الشحنة'
          : 'Container Load Planner & Simulation Report');
      buffer.writeln('${isAr ? "ملف الاستيراد" : "Import File"},${file.importFileCode}');
      buffer.writeln('${isAr ? "الشركة المستوردة" : "Company"},"${file.companyName.replaceAll('"', '""')}"');
      buffer.writeln('${isAr ? "المورد الأجنبي" : "Supplier"},"${file.supplierName.replaceAll('"', '""')}"');
      buffer.writeln('${isAr ? "سيناريو الرص" : "Stacking Scenario"},"${getScenarioName(activeStackingMode, l)}"');
      buffer.writeln('${isAr ? "ملخص أسطول الحاويات" : "Fleet Summary"},"$fleetSummaryText (${plan.length})"');
      buffer.writeln('${isAr ? "إجمالي الطرود" : "Total Cargo Packages"},$totalPkgs');
      buffer.writeln('${isAr ? "إجمالي الوزن القائم (كجم)" : "Total Cargo Weight (kg)"},${totalPlanWeight.toStringAsFixed(1)}');
      buffer.writeln('${isAr ? "إجمالي الحجم (م3)" : "Total Cargo Volume (m3)"},${totalPlanVolume.toStringAsFixed(3)}');
      buffer.writeln('${isAr ? "البضائع القابلة للرص" : "Stackable Items"},$stackableInActive');
      buffer.writeln('${isAr ? "البضائع غير القابلة للرص" : "Non-Stackable Items"},$nonStackableInActive');
      buffer.writeln('');
      buffer.writeln(isAr
          ? 'نوع ومواصفات الحاوية,أرقام بنود الباكنج ليست المرصوصة,الوزن القائم (كجم),نسبة استغلال المساحة %,الحالة التشغيلية'
          : 'Container Spec,Packing List Numbers / Placed Items,Gross Weight (kg),Space Util %,Operational Status');

      for (int i = 0; i < plan.length; i++) {
        final res = plan[i];
        final placedIds = res.placedItems.map((p) => p.item.itemId).join('; ');
        final spaceUtil = res.spec.internalVolumeCbm > 0
            ? (res.totalVolume / res.spec.internalVolumeCbm * 100).toStringAsFixed(1)
            : '0.0';
        final statusText = getPlanStatusText(res, l);
        buffer.writeln(
            '"${res.spec.name} (${res.spec.code})","$placedIds",${res.totalWeight.toStringAsFixed(1)},$spaceUtil%,"$statusText"');
      }

      final csvString = '\uFEFF${buffer.toString()}';
      final bytes = utf8.encode(csvString);

      if (!context.mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: 'Container Load Planner',
        importFileNameOrCode:
            '${file.companyName} (${file.importFileCode}) - ${getScenarioName(activeStackingMode, l)}',
        extension: 'xlsx',
        customDialogTitle: l.exportContainerExcelDialogTitle,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${l.containerExportError}$e',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }

  static Future<void> exportPdf({
    required BuildContext context,
    required GlobalKey visualKey,
    required ImportFileModel file,
    required bool? activeStackingMode,
    required List<ContainerPackingResult> plan,
    required double totalPlanWeight,
    required double totalPlanVolume,
    required int totalPkgs,
    required String fleetSummaryText,
    required AppLocalizations l,
  }) async {
    try {
      final capturedImageBytes = await captureContainerRender(visualKey);

      final pdf = pw.Document();
      pw.Font arabicFont;
      try {
        arabicFont = await PdfGoogleFonts.cairoRegular();
      } catch (_) {
        arabicFont = pw.Font.helvetica();
      }

      final isAr = l.isArabic;
      final theme = pw.ThemeData.withFont(base: arabicFont, bold: arabicFont);

      pdf.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            final content = <pw.Widget>[
              // Header Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#2C3E50'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      isAr
                          ? 'تقرير ومحاكاة رص الحاويات وتوزيع الشحنة'
                          : 'Container Load Planner & Stacking Simulation Report',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.Text(
                      '${file.importFileCode} | ${isAr ? "الأسطول" : "Fleet"}: $fleetSummaryText',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Shipment Summary Metrics Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "الشركة" : "Company"}: ${file.companyName}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "المورد" : "Supplier"}: ${file.supplierName}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "السيناريو" : "Scenario"}: ${getScenarioName(activeStackingMode, l)}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "إجمالي الطرود" : "Total Packages"}: $totalPkgs',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "إجمالي الوزن" : "Total Gross Wt"}: ${totalPlanWeight.toStringAsFixed(1)} kg',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "إجمالي الحجم" : "Total Volume"}: ${totalPlanVolume.toStringAsFixed(3)} m3',
                            style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Simulation Details Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(1.0),
                  3: const pw.FlexColumnWidth(1.0),
                  4: const pw.FlexColumnWidth(1.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isAr ? 'الحاوية' : 'Container', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isAr ? 'أرقام البنود المرصوصة' : 'Placed Item IDs', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isAr ? 'الوزن (كجم)' : 'Weight (kg)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isAr ? 'استغلال المساحة %' : 'Space Util %', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(isAr ? 'الحالة التشغيلية' : 'Status', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...plan.map((res) {
                    final placedIds = res.placedItemsSummary;
                    final spaceUtil = res.spec.internalVolumeCbm > 0
                        ? (res.totalVolume / res.spec.internalVolumeCbm * 100).toStringAsFixed(1)
                        : '0.0';
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(res.spec.code, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(placedIds.isEmpty ? '-' : placedIds, style: const pw.TextStyle(fontSize: 7))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${res.totalWeight.toStringAsFixed(0)} kg', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$spaceUtil%', style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(getPlanStatusText(res, l), style: const pw.TextStyle(fontSize: 8))),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 14),

              // Embedded Visual Stacking Render Image
              if (capturedImageBytes != null) ...[
                pw.Container(
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                  ),
                  child: pw.Image(
                    pw.MemoryImage(capturedImageBytes),
                    fit: pw.BoxFit.contain,
                    height: 220,
                  ),
                ),
              ],
            ];

            return isAr
                ? [pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: content))]
                : content;
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (!context.mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: pdfBytes,
        stageName: 'Container Load Planner',
        importFileNameOrCode:
            '${file.companyName} (${file.importFileCode}) - ${getScenarioName(activeStackingMode, l)}',
        extension: 'pdf',
        customDialogTitle: l.exportContainerPdfDialogTitle,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.snackBar(
            context,
            '${l.containerExportError}$e',
            severity: AppSeverity.danger,
          ),
        );
      }
    }
  }
}

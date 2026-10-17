// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/widgets/container_load_plan_painter.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/import_file_model.dart';

/// Visual Container Load Planner & Simulation Dialog (Task H / Phase 2)
/// Implements responsive layout (Task A), WCAG AA dark mode contrast (Task B),
/// proper RTL mirroring (Task C), and 3-way export: Image, Excel, PDF (Task H & I).
class VisualContainerLoadPlannerDialog extends StatefulWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final double? fallbackCbm;
  final double? fallbackWeight;

  const VisualContainerLoadPlannerDialog({
    super.key,
    required this.file,
    required this.linkedPOs,
    this.fallbackCbm,
    this.fallbackWeight,
  });

  @override
  State<VisualContainerLoadPlannerDialog> createState() =>
      _VisualContainerLoadPlannerDialogState();
}

class _VisualContainerLoadPlannerDialogState
    extends State<VisualContainerLoadPlannerDialog> {
  final GlobalKey _containerVisualKey = GlobalKey();
  final ScrollController _tableScrollController = ScrollController();

  // Active Stacking Mode: null = Mixed Stacking, true = All Stackable, false = All Non-Stackable
  bool? _activeStackingMode;

  // Export Loading States
  bool _isExportingImage = false;
  bool _isExportingExcel = false;
  bool _isExportingPdf = false;

  late List<CargoItem> _baseCargoItems;

  @override
  void initState() {
    super.initState();
    _baseCargoItems = ImportFilePoLinker.buildCargoItems(
      pos: widget.linkedPOs,
      file: widget.file,
      fallbackCbm: widget.fallbackCbm ?? 0.0,
      fallbackWeight: widget.fallbackWeight ?? 0.0,
    );
    _activeStackingMode =
        _baseCargoItems.any((i) => !i.isStackable) ? null : true;
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  String _getScenarioName(bool? mode, AppLocalizations l) {
    if (mode == true) return l.allStackableChip;
    if (mode == false) return l.allNonStackableChip;
    return l.mixedStackingChip;
  }

  String _getPlanStatusText(ContainerPackingResult res, AppLocalizations l) {
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

  Future<Uint8List?> _captureContainerRender() async {
    try {
      final boundary = _containerVisualKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleSaveImage(AppLocalizations l) async {
    if (_isExportingImage) return;
    setState(() => _isExportingImage = true);

    try {
      final pngBytes = await _captureContainerRender();
      if (pngBytes == null || pngBytes.isEmpty) {
        throw Exception(l.containerImageCaptureError);
      }

      if (!mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: pngBytes,
        stageName: 'Container Load Planner',
        importFileNameOrCode:
            '${widget.file.companyName} (${widget.file.importFileCode}) - ${_getScenarioName(_activeStackingMode, l)}',
        extension: 'png',
        customDialogTitle: l.saveContainerImageDialogTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.containerExportError}$e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingImage = false);
    }
  }

  void _copyLoadPlanTableAsTsv(
      AppLocalizations l, List<ContainerPackingResult> plan) {
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
      final statusText = _getPlanStatusText(res, l);

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

  Future<void> _handleExportExcel(
      AppLocalizations l,
      List<ContainerPackingResult> plan,
      double totalPlanWeight,
      double totalPlanVolume,
      int totalPkgs,
      int stackableInActive,
      int nonStackableInActive,
      String fleetSummaryText) async {
    if (_isExportingExcel) return;
    setState(() => _isExportingExcel = true);

    try {
      final isAr = l.isArabic;
      final buffer = StringBuffer();
      buffer.writeln(isAr
          ? 'تقرير ومحاكاة رص الحاويات وتوزيع الشحنة'
          : 'Container Load Planner & Simulation Report');
      buffer.writeln('${isAr ? "ملف الاستيراد" : "Import File"},${widget.file.importFileCode}');
      buffer.writeln('${isAr ? "الشركة المستوردة" : "Company"},"${widget.file.companyName.replaceAll('"', '""')}"');
      buffer.writeln('${isAr ? "المورد الأجنبي" : "Supplier"},"${widget.file.supplierName.replaceAll('"', '""')}"');
      buffer.writeln('${isAr ? "سيناريو الرص" : "Stacking Scenario"},"${_getScenarioName(_activeStackingMode, l)}"');
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
        final statusText = _getPlanStatusText(res, l);
        buffer.writeln(
            '"${res.spec.name} (${res.spec.code})","$placedIds",${res.totalWeight.toStringAsFixed(1)},$spaceUtil%,"$statusText"');
      }

      final csvString = '\uFEFF${buffer.toString()}';
      final bytes = utf8.encode(csvString);

      if (!mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: 'Container Load Planner',
        importFileNameOrCode:
            '${widget.file.companyName} (${widget.file.importFileCode}) - ${_getScenarioName(_activeStackingMode, l)}',
        extension: 'xlsx',
        customDialogTitle: l.exportContainerExcelDialogTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.containerExportError}$e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingExcel = false);
    }
  }

  Future<void> _handleExportPdf(
      AppLocalizations l,
      List<ContainerPackingResult> plan,
      double totalPlanWeight,
      double totalPlanVolume,
      int totalPkgs,
      String fleetSummaryText) async {
    if (_isExportingPdf) return;
    setState(() => _isExportingPdf = true);

    try {
      final capturedImageBytes = await _captureContainerRender();

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
                      '${widget.file.importFileCode} | ${isAr ? "الأسطول" : "Fleet"}: $fleetSummaryText',
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
                        child: pw.Text('${isAr ? "الشركة" : "Company"}: ${widget.file.companyName}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "المورد" : "Supplier"}: ${widget.file.supplierName}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${isAr ? "السيناريو" : "Scenario"}: ${_getScenarioName(_activeStackingMode, l)}',
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
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_getPlanStatusText(res, l), style: const pw.TextStyle(fontSize: 8))),
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

      if (!mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: pdfBytes,
        stageName: 'Container Load Planner',
        importFileNameOrCode:
            '${widget.file.companyName} (${widget.file.importFileCode}) - ${_getScenarioName(_activeStackingMode, l)}',
        extension: 'pdf',
        customDialogTitle: l.exportContainerPdfDialogTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.containerExportError}$e'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final screenSize = MediaQuery.of(context).size;
    final double screenW = screenSize.width;
    final double screenH = screenSize.height;

    // STEP 1 — Task A: Responsive sizing on Desktop, Tablet & Mobile
    final double dialogWidth;
    final double dialogHeight;

    if (screenW >= AppTheme.desktopBreakpoint) {
      // Desktop (>= 1200px): Generous width up to 1480px, height up to 940px
      dialogWidth = (screenW * 0.95).clamp(1150.0, 1480.0);
      dialogHeight = (screenH * 0.90).clamp(720.0, 940.0);
    } else if (screenW >= AppTheme.tabletBreakpoint) {
      // Tablet (768px - 1199px):
      dialogWidth = (screenW * 0.95).clamp(740.0, 1150.0);
      dialogHeight = (screenH * 0.90).clamp(620.0, 880.0);
    } else {
      // Mobile (< 768px):
      dialogWidth = screenW * 0.96;
      dialogHeight = (screenH * 0.92).clamp(500.0, 800.0);
    }

    // Compute plan dynamically based on active stacking scenario
    final plan = ContainerRequirementEngine.planShipment(
      _baseCargoItems,
      forceStackable: _activeStackingMode,
    );

    // Metrics for active plan
    final totalPkgs = _baseCargoItems.length;
    final stackableInActive = _activeStackingMode == true
        ? totalPkgs
        : (_activeStackingMode == false
            ? 0
            : _baseCargoItems.where((c) => c.isStackable).length);
    final nonStackableInActive = totalPkgs - stackableInActive;

    final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
    final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

    // Fleet Summary
    final Map<String, int> containerCounts = {};
    for (final p in plan) {
      if (p.containerCode != 'FAILED') {
        containerCounts[p.containerCode] =
            (containerCounts[p.containerCode] ?? 0) + 1;
      }
    }
    final fleetSummaryText = containerCounts.entries
        .map((e) => '${e.value} x ${e.key}')
        .join(' + ');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      title: screenW < 768
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${l.visualLoadPlannerTitle} — ${widget.file.importFileCode}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blue.shade900.withOpacity(0.3)
                            : AppTheme.cobalt.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.blue.shade700 : AppTheme.cobalt,
                        ),
                      ),
                      child: Text(
                        '$fleetSummaryText (${plan.length})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const Key('copyTableBtn'),
                          tooltip: l.isArabic ? 'نسخ الجدول' : 'Copy Table',
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy_outlined,
                              color: AppTheme.cobalt, size: 18),
                          onPressed: () => _copyLoadPlanTableAsTsv(l, plan),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('saveImageBtn'),
                          tooltip: l.saveContainerImageTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: _isExportingImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.image_outlined,
                                  color: AppTheme.cobalt, size: 18),
                          onPressed: _isExportingImage ? null : () => _handleSaveImage(l),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('exportExcelBtn'),
                          tooltip: l.exportContainerExcelTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: _isExportingExcel
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.emerald,
                                  ),
                                )
                              : const Icon(Icons.table_chart_outlined,
                                  color: AppTheme.emerald, size: 18),
                          onPressed: _isExportingExcel
                              ? null
                              : () => _handleExportExcel(l, plan, totalPlanWeight,
                                  totalPlanVolume, totalPkgs, stackableInActive, nonStackableInActive, fleetSummaryText),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          key: const Key('exportPdfBtn'),
                          tooltip: l.exportContainerPdfTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: _isExportingPdf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.crimson,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined,
                                  color: AppTheme.crimson, size: 18),
                          onPressed: _isExportingPdf
                              ? null
                              : () => _handleExportPdf(l, plan, totalPlanWeight,
                                  totalPlanVolume, totalPkgs, fleetSummaryText),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${l.visualLoadPlannerTitle} — ${widget.file.importFileCode}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Fleet Summary Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.shade900.withOpacity(0.3)
                        : AppTheme.cobalt.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.blue.shade700 : AppTheme.cobalt,
                    ),
                  ),
                  child: Text(
                    '$fleetSummaryText (${plan.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ── TASK H & J: Export & Copy Actions Strip ─────────────────────────────
                // 0. Copy Table (TSV) Action
                IconButton(
                  key: const Key('copyTableBtn'),
                  tooltip: l.isArabic ? 'نسخ الجدول' : 'Copy Table',
                  icon: const Icon(Icons.copy_outlined,
                      color: AppTheme.cobalt, size: 20),
                  onPressed: () => _copyLoadPlanTableAsTsv(l, plan),
                ),
                const SizedBox(width: 4),

                // 1. Save Image (PNG) Action
                IconButton(
                  key: const Key('saveImageBtn'),
                  tooltip: l.saveContainerImageTooltip,
                  icon: _isExportingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image_outlined,
                          color: AppTheme.cobalt, size: 20),
                  onPressed: _isExportingImage ? null : () => _handleSaveImage(l),
                ),

                // 2. Export Excel (.xlsx) Action
                IconButton(
                  key: const Key('exportExcelBtn'),
                  tooltip: l.exportContainerExcelTooltip,
                  icon: _isExportingExcel
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.emerald,
                          ),
                        )
                      : const Icon(Icons.table_chart_outlined,
                          color: AppTheme.emerald, size: 20),
                  onPressed: _isExportingExcel
                      ? null
                      : () => _handleExportExcel(l, plan, totalPlanWeight,
                          totalPlanVolume, totalPkgs, stackableInActive, nonStackableInActive, fleetSummaryText),
                ),

                // 3. Export PDF Action
                IconButton(
                  key: const Key('exportPdfBtn'),
                  tooltip: l.exportContainerPdfTooltip,
                  icon: _isExportingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.crimson,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined,
                          color: AppTheme.crimson, size: 20),
                  onPressed: _isExportingPdf
                      ? null
                      : () => _handleExportPdf(l, plan, totalPlanWeight,
                          totalPlanVolume, totalPkgs, fleetSummaryText),
                ),
              ],
            ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ── 1. Stacking Scenario Buttons Strip (All 3 required states) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '🔄 ${l.cargoStackingScenariosTitle}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        key: const Key('scenarioChip_1'),
                        label: Text('📦 1. ${l.allStackableChip}'),
                        selected: _activeStackingMode == true,
                        selectedColor: AppTheme.emerald,
                        backgroundColor:
                            isDark ? AppTheme.darkCardBackground : null,
                        labelStyle: TextStyle(
                          color: _activeStackingMode == true
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.charcoal),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _activeStackingMode = true);
                        },
                      ),
                      ChoiceChip(
                        key: const Key('scenarioChip_2'),
                        label: Text('🚫 2. ${l.allNonStackableChip}'),
                        selected: _activeStackingMode == false,
                        selectedColor: Colors.orange.shade800,
                        backgroundColor:
                            isDark ? AppTheme.darkCardBackground : null,
                        labelStyle: TextStyle(
                          color: _activeStackingMode == false
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.charcoal),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _activeStackingMode = false);
                        },
                      ),
                      ChoiceChip(
                        key: const Key('scenarioChip_3'),
                        label: Text('🔀 3. ${l.mixedStackingChip}'),
                        selected: _activeStackingMode == null,
                        selectedColor: AppTheme.cobalt,
                        backgroundColor:
                            isDark ? AppTheme.darkCardBackground : null,
                        labelStyle: TextStyle(
                          color: _activeStackingMode == null
                              ? Colors.white
                              : (isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.charcoal),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _activeStackingMode = null);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── 2. Summary Metrics Strip (Predictable Stacking on Tablet) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkSurface
                    : AppTheme.charcoal.withOpacity(0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildMetricPill(
                    '📦',
                    '$totalPkgs',
                    isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    isDark: isDark,
                  ),
                  _buildMetricPill(
                    '⚖️',
                    '${totalPlanWeight.toStringAsFixed(0)} kg',
                    isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                    isDark: isDark,
                  ),
                  _buildMetricPill(
                    '📐',
                    '${totalPlanVolume.toStringAsFixed(3)} m³',
                    isDark ? const Color(0xFFFDBA74) : const Color(0xFFB45309),
                    isDark: isDark,
                  ),
                  _buildMetricPill(
                    '✅ ${l.allStackableChip}',
                    '$stackableInActive',
                    isDark ? const Color(0xFF6EE7B7) : AppTheme.wcagEmerald,
                    isDark: isDark,
                  ),
                  _buildMetricPill(
                    '🚫 ${l.allNonStackableChip}',
                    '$nonStackableInActive',
                    isDark ? const Color(0xFFFCA5A5) : AppTheme.wcagCrimson,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── 3. Packing List Summary Table with Constrained Height & Sticky Scroll ──
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBackground : Colors.white,
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : Colors.grey.shade300,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectionArea(
                child: Column(
                  children: [
                    // Sticky Header
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkElevatedSurface
                          : AppTheme.charcoal.withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(l.containerSpecType, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Expanded(flex: 3, child: Text(l.packingListItemsCol, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Expanded(flex: 2, child: Text(l.totalGrossWeightFromPl, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Expanded(flex: 2, child: Text(l.spaceUtilizationPercent, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                        Expanded(flex: 3, child: Text(l.currentPhaseStage, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.start, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null))),
                      ],
                    ),
                  ),
                  // Scrollable Body
                  Expanded(
                    child: Scrollbar(
                      controller: _tableScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _tableScrollController,
                        child: Column(
                          children: plan.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final res = entry.value;
                            final placedIds = res.placedItemsSummary;
                            final double spaceUtil = res.spec.internalVolumeCbm > 0
                                ? (res.totalVolume / res.spec.internalVolumeCbm) * 100
                                : 0.0;
                            final statusText = _getPlanStatusText(res, l);

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      res.containerCode == 'FAILED'
                                          ? l.containerLoadFailed
                                          : '$idx: ${res.spec.code}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: res.containerCode == 'FAILED'
                                            ? (isDark ? const Color(0xFFFCA5A5) : AppTheme.wcagCrimson)
                                            : (isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      placedIds.isEmpty ? '-' : placedIds,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      res.containerCode == 'FAILED'
                                          ? '-'
                                          : '${res.totalWeight.toStringAsFixed(0)} kg',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '${spaceUtil.toStringAsFixed(1)}%',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        // WCAG AA Dark/Light contrast
                                        color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      statusText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.start,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: statusText.contains(l.containerLoadFailed) || statusText.contains('فشل') || statusText.contains('Failed')
                                            ? (isDark ? const Color(0xFFFCA5A5) : AppTheme.wcagCrimson)
                                            : (statusText.contains(l.allNonStackableChip) || statusText.contains('غير قابل') || statusText.contains('Non-Stackable')
                                                ? (isDark ? const Color(0xFFFCD34D) : AppTheme.wcagOrange)
                                                : (isDark ? const Color(0xFF6EE7B7) : AppTheme.wcagEmerald)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
            const SizedBox(height: 10),

            // ── 4. Main Container Visual Renderings (Wrapped in RepaintBoundary for Export) ──
            Expanded(
              child: RepaintBoundary(
                key: _containerVisualKey,
                child: ListView.builder(
                  itemCount: plan.length,
                  itemBuilder: (ctx, pIdx) {
                    final res = plan[pIdx];
                    if (res.containerCode == 'FAILED') {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          '${l.oversizedItemsWarning}: ${res.unplacedItems.map((u) => u.itemId).join(', ')}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      color: isDark ? AppTheme.darkCardBackground : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  l.containerLayoutTitle(pIdx + 1, res.spec.name, res.spec.code),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      l.woodenFloorPallets,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.amber.shade200 : Colors.brown,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkSurface : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${l.internalDimensionsPrefix}: ${res.spec.internalLength.toStringAsFixed(0)} x ${res.spec.internalWidth.toStringAsFixed(0)} x ${res.spec.internalHeight.toStringAsFixed(0)} cm',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Side View (Left Wall Removed) - High Fidelity Realistic Container
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: CustomPaint(
                                painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                child: Container(),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Top View (Roof Removed)
                            Container(
                              height: 145,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: CustomPaint(
                                painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                child: Container(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          key: const Key('closePlannerDialogBtn'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          label: Text(l.closePlannerBtn),
        ),
      ],
    );
  }

  static Widget _buildMetricPill(String icon, String value, Color color,
      {bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.08),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(isDark ? 0.6 : 0.25)),
      ),
      child: Text.rich(
        TextSpan(
          text: '$icon ',
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/helpers/table_copy_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/utils/bidi_text.dart';
import '../../../core/widgets/widgets.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/lifecycle_board_model.dart';

/// Central export and dossier generation service for the Lifecycle Board & Live Radar (Screen 48).
/// Supports TSV export (UTF-8 BOM), unmerged Excel/CSV (UTF-8 BOM), vector A4 landscape Cairo PDF,
/// and plain text clipboard dossier for both the 6-Phase Kanban Board and the Live Logistics Radar views.
class LifecycleBoardExportService {
  // ===========================================================================
  // 1. KANBAN PHASES BOARD EXPORTS
  // ===========================================================================

  /// Builds a plain-text dossier of the Kanban shipments table for clipboard copy.
  static String buildKanbanDossierText({
    required BuildContext context,
    required List<ShipmentStageCardModel> shipments,
    required List<PhaseSummaryModel> phases,
    List<ImportFileModel>? allImportFiles,
    String? filterTitle,
  }) {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final sb = StringBuffer();

    sb.writeln('================================================================');
    sb.writeln(l.lifecycleDossierHeader);
    if (filterTitle != null && filterTitle.isNotEmpty) {
      sb.writeln('[$filterTitle]');
    }
    sb.writeln('================================================================');
    sb.writeln(l.totalActiveShipmentsCount(shipments.length, phases.length));
    sb.writeln();

    for (int i = 0; i < shipments.length; i++) {
      final s = shipments[i];
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        s.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
        includeCodeSecondary: true,
      );
      final stepName = DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr);
      sb.writeln('${i + 1}. $shipmentTitle - $stepName');
      sb.writeln('   ${l.colImportCompany}: ${s.companyName} | ${l.colForeignSupplier}: ${s.supplierName}');
      if (s.poNumber != null && s.poNumber!.isNotEmpty) {
        sb.writeln('   ${l.colPurchaseOrder}: ${s.poNumber}');
      }
      sb.writeln('   ${l.colModeAndIncoterm}: ${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}');
      sb.writeln('   ${l.colEstimatedValue}: ${s.estimatedCost != null ? s.estimatedCost!.toStringAsFixed(0) : "-"} ${s.estimatedCostCurrency ?? ""}');
      if (s.status == 'On-Hold') {
        sb.writeln('   ${l.lifecycleTsvHeaderStatus}: ${l.onHoldStatusTag}');
      }
      if (s.previousStepCode != null) {
        final prevStepName = DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr);
        sb.writeln('   ${l.colPreviousStep}: $prevStepName');
      }
      if (s.nextStepCode != null) {
        final nxtStepName = DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr);
        sb.writeln('   ${l.colNextStep}: $nxtStepName');
      }
      if (s.notes != null && s.notes!.isNotEmpty) {
        sb.writeln('   ${l.colNotesAndActivities}: ${s.notes}');
      }
      sb.writeln('----------------------------------------------------------------');
    }

    return stripBidiIsolates(sb.toString());
  }

  /// Copies the Kanban dossier to the system clipboard cleanly using [CopyHelper].
  static Future<void> copyKanbanDossier({
    required BuildContext context,
    required List<ShipmentStageCardModel> shipments,
    required List<PhaseSummaryModel> phases,
    List<ImportFileModel>? allImportFiles,
    String? filterTitle,
  }) async {
    final dossier = buildKanbanDossierText(
      context: context,
      shipments: shipments,
      phases: phases,
      allImportFiles: allImportFiles,
      filterTitle: filterTitle,
    );
    await CopyHelper.copy(
      context,
      dossier,
      customMessage: context.l10n.lifecycleCopyDossierSuccess,
    );
  }

  /// Copies the Kanban table as TSV directly to clipboard using [TableCopyHelper.copyTable].
  static Future<void> copyKanbanTable({
    required BuildContext context,
    required List<ShipmentStageCardModel> shipments,
    List<ImportFileModel>? allImportFiles,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final headers = [
      l.operationalTsvHeaderShipmentName,
      l.lifecycleTsvHeaderFileCode,
      l.lifecycleTsvHeaderPreviousStep,
      l.lifecycleTsvHeaderCurrentStep,
      l.lifecycleTsvHeaderNextStep,
      l.lifecycleTsvHeaderCompany,
      l.lifecycleTsvHeaderSupplier,
      l.lifecycleTsvHeaderPoNumber,
      l.lifecycleTsvHeaderShipmentMode,
      l.lifecycleTsvHeaderEstimatedCost,
      l.lifecycleTsvHeaderStatus,
      l.lifecycleTsvHeaderNotes,
    ];
    final rows = shipments.map((s) {
      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
        s.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
      );
      final prevStep = s.previousStepCode != null
          ? DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr)
          : '-';
      final curStep = DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr);
      final nxtStep = s.nextStepCode != null
          ? DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr)
          : '-';
      final statusStr = s.status == 'On-Hold' ? l.onHoldStatusTag : s.status;

      return [
        shipmentName,
        s.importFileCode,
        prevStep,
        curStep,
        nxtStep,
        s.companyName,
        s.supplierName,
        s.poNumber ?? '-',
        '${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}',
        '${s.estimatedCost != null ? s.estimatedCost!.toStringAsFixed(0) : "-"} ${s.estimatedCostCurrency ?? ""}',
        statusStr,
        s.notes ?? '',
      ];
    }).toList();

    await TableCopyHelper.copyTable(context, headers, rows);
  }

  /// Exports the Kanban shipments table to TSV format with UTF-8 BOM.
  static Future<void> exportKanbanToTsv({
    required BuildContext context,
    required List<ShipmentStageCardModel> shipments,
    List<ImportFileModel>? allImportFiles,
    String? filterTitle,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final sb = StringBuffer();

    // Headers
    sb.writeln([
      l.operationalTsvHeaderShipmentName,
      l.lifecycleTsvHeaderFileCode,
      l.lifecycleTsvHeaderPreviousStep,
      l.lifecycleTsvHeaderCurrentStep,
      l.lifecycleTsvHeaderNextStep,
      l.lifecycleTsvHeaderCompany,
      l.lifecycleTsvHeaderSupplier,
      l.lifecycleTsvHeaderPoNumber,
      l.lifecycleTsvHeaderShipmentMode,
      l.lifecycleTsvHeaderEstimatedCost,
      l.lifecycleTsvHeaderStatus,
      l.lifecycleTsvHeaderNotes,
    ].join('\t'));

    for (final s in shipments) {
      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
        s.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
      );
      final prevStep = s.previousStepCode != null
          ? DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr)
          : '-';
      final curStep = DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr);
      final nxtStep = s.nextStepCode != null
          ? DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr)
          : '-';
      final statusStr = s.status == 'On-Hold' ? l.onHoldStatusTag : s.status;

      sb.writeln([
        shipmentName,
        s.importFileCode,
        prevStep,
        curStep,
        nxtStep,
        s.companyName,
        s.supplierName,
        s.poNumber ?? '-',
        '${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}',
        '${s.estimatedCost != null ? s.estimatedCost!.toStringAsFixed(0) : "-"} ${s.estimatedCostCurrency ?? ""}',
        statusStr,
        s.notes ?? '',
      ].join('\t'));
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: 'Lifecycle_Kanban_$dateStr.tsv',
      dialogTitle: l.lifecycleExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports the Kanban shipments table to unmerged CSV/Excel with UTF-8 BOM.
  static Future<void> exportKanbanToExcel({
    required BuildContext context,
    required List<ShipmentStageCardModel> shipments,
    List<ImportFileModel>? allImportFiles,
    String? filterTitle,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final sb = StringBuffer();

    String escapeCsv(String text) {
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    // Headers
    sb.writeln([
      escapeCsv(l.operationalTsvHeaderShipmentName),
      escapeCsv(l.lifecycleTsvHeaderFileCode),
      escapeCsv(l.lifecycleTsvHeaderPreviousStep),
      escapeCsv(l.lifecycleTsvHeaderCurrentStep),
      escapeCsv(l.lifecycleTsvHeaderNextStep),
      escapeCsv(l.lifecycleTsvHeaderCompany),
      escapeCsv(l.lifecycleTsvHeaderSupplier),
      escapeCsv(l.lifecycleTsvHeaderPoNumber),
      escapeCsv(l.lifecycleTsvHeaderShipmentMode),
      escapeCsv(l.lifecycleTsvHeaderEstimatedCost),
      escapeCsv(l.lifecycleTsvHeaderStatus),
      escapeCsv(l.lifecycleTsvHeaderNotes),
    ].join(','));

    for (final s in shipments) {
      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
        s.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
      );
      final prevStep = s.previousStepCode != null
          ? DisplayNameResolver.resolveStepName(s.previousStepCode!, isArabic: isAr)
          : '-';
      final curStep = DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr);
      final nxtStep = s.nextStepCode != null
          ? DisplayNameResolver.resolveStepName(s.nextStepCode!, isArabic: isAr)
          : '-';
      final statusStr = s.status == 'On-Hold' ? l.onHoldStatusTag : s.status;

      sb.writeln([
        escapeCsv(shipmentName),
        escapeCsv(s.importFileCode),
        escapeCsv(prevStep),
        escapeCsv(curStep),
        escapeCsv(nxtStep),
        escapeCsv(s.companyName),
        escapeCsv(s.supplierName),
        escapeCsv(s.poNumber ?? '-'),
        escapeCsv('${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}'),
        escapeCsv('${s.estimatedCost != null ? s.estimatedCost!.toStringAsFixed(0) : "-"} ${s.estimatedCostCurrency ?? ""}'),
        escapeCsv(statusStr),
        escapeCsv(s.notes ?? ''),
      ].join(','));
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: 'Lifecycle_Kanban_$dateStr.csv',
      dialogTitle: l.lifecycleExportExcelDialogTitle,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: true,
    );
  }

  /// Generates vector A4 landscape Cairo PDF and opens printing / saving dialogue for Kanban board.
  static Future<void> printOrSaveKanbanPdf({
    required BuildContext context,
    required List<ShipmentStageCardModel> shipments,
    required List<PhaseSummaryModel> phases,
    List<ImportFileModel>? allImportFiles,
    String? filterTitle,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;

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
                            l.lifecycleDossierHeader,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          if (filterTitle != null && filterTitle.isNotEmpty)
                            pw.Text(
                              filterTitle,
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
                          l.shipmentsCountFormatted(shipments.length),
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
                    0: const pw.FlexColumnWidth(1.4), // Shipment Name & Code
                    1: const pw.FlexColumnWidth(1.4), // Current Step
                    2: const pw.FlexColumnWidth(1.5), // Importer
                    3: const pw.FlexColumnWidth(1.5), // Supplier
                    4: const pw.FlexColumnWidth(1.0), // PO
                    5: const pw.FlexColumnWidth(1.1), // Mode & Incoterm
                    6: const pw.FlexColumnWidth(1.2), // Estimated Value
                    7: const pw.FlexColumnWidth(0.9), // Status
                    8: const pw.FlexColumnWidth(2.0), // Notes
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECF0F1')),
                      children: [
                        _pdfHeaderCell(l.operationalTsvHeaderShipmentName),
                        _pdfHeaderCell(l.lifecycleTsvHeaderCurrentStep),
                        _pdfHeaderCell(l.lifecycleTsvHeaderCompany),
                        _pdfHeaderCell(l.lifecycleTsvHeaderSupplier),
                        _pdfHeaderCell(l.lifecycleTsvHeaderPoNumber),
                        _pdfHeaderCell(l.lifecycleTsvHeaderShipmentMode),
                        _pdfHeaderCell(l.lifecycleTsvHeaderEstimatedCost),
                        _pdfHeaderCell(l.lifecycleTsvHeaderStatus),
                        _pdfHeaderCell(l.lifecycleTsvHeaderNotes),
                      ],
                    ),
                    // Data Rows
                    ...shipments.map((s) {
                      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                        s.importFileCode,
                        shipments: allImportFiles,
                        isArabic: isAr,
                      );
                      final curStep = DisplayNameResolver.resolveStepName(s.stepCode, isArabic: isAr);
                      final statusStr = s.status == 'On-Hold' ? l.onHoldStatusTag : s.status;

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  shipmentName,
                                  style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#2C3E50'),
                                  ),
                                ),
                                if (shipmentName != s.importFileCode)
                                  pw.Text(
                                    s.importFileCode,
                                    style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                                  ),
                              ],
                            ),
                          ),
                          _pdfDataCell(curStep),
                          _pdfDataCell(s.companyName),
                          _pdfDataCell(s.supplierName),
                          _pdfDataCell(s.poNumber ?? '-'),
                          _pdfDataCell('${s.shipmentMode ?? "-"} | ${s.incotermCode ?? "-"}'),
                          _pdfDataCell('${s.estimatedCost != null ? s.estimatedCost!.toStringAsFixed(0) : "-"} ${s.estimatedCostCurrency ?? ""}'),
                          _pdfDataCell(statusStr, isAlert: s.status == 'On-Hold'),
                          _pdfDataCell(s.notes ?? '-'),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Sign-off footer
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
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Lifecycle_Kanban_$dateStr.pdf',
    );
  }

  // ===========================================================================
  // 2. LIVE LOGISTICS TRACKING RADAR EXPORTS
  // ===========================================================================

  /// Builds a plain-text dossier of the Live Radar tracking items for clipboard copy.
  static String buildRadarDossierText({
    required BuildContext context,
    required List<LiveLogisticsTrackingItemModel> items,
    List<ImportFileModel>? allImportFiles,
  }) {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final sb = StringBuffer();

    sb.writeln('================================================================');
    sb.writeln(l.radarDossierHeader);
    sb.writeln('================================================================');
    sb.writeln(l.shipmentsCountFormatted(items.length));
    sb.writeln();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final shipmentTitle = DisplayNameResolver.resolveShipmentTitleByCode(
        item.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
        includeCodeSecondary: true,
      );
      sb.writeln('${i + 1}. $shipmentTitle - ${item.companyName} → ${item.supplierName}');
      sb.writeln('   ${l.radarTsvHeaderCarrierVessel}: ${item.carrierName ?? l.colCarrierUnderPrep} (${item.vesselName ?? "-"})');
      sb.writeln('   ${l.radarTsvHeaderBlRoute}: ${l.colBillOfLadingPrefix}: ${item.blNumber ?? l.colCarrierUnderPrep} | ${item.polName ?? "-"} → ${item.podName ?? "-"}');
      sb.writeln('   ${l.radarTsvHeaderArrivalStatus}: ${l.colEtaPrefix}: ${item.eta ?? "-"} | ${item.arrivalStatus}');
      if (item.accumulatedDemurrageFx > 0) {
        sb.writeln('   ${l.radarTsvHeaderDemurrageRisk}: ${l.demurrageIncurredBadge} (${l.demurrageFeesFormatted(item.accumulatedDemurrageFx.toStringAsFixed(0), item.accumulatedDemurrageEgp.toStringAsFixed(0))})');
      } else {
        final demRemainingStr = item.freeDaysRemaining != null ? l.freeDaysRemainingBadge(item.freeDaysRemaining) : '-';
        final demConsumedStr = item.freeDaysTotal != null ? l.freeDaysConsumed(item.usedFreeDays, item.freeDaysTotal) : '-';
        sb.writeln('   ${l.radarTsvHeaderDemurrageRisk}: $demRemainingStr ($demConsumedStr)');
      }
      sb.writeln('   ${l.radarTsvHeaderTestingStatus}: ${item.sampleTestStatus}');
      sb.writeln('   ${l.radarTsvHeaderDocReadiness}: ${item.docReadinessPercent.toStringAsFixed(0)}%');
      sb.writeln('----------------------------------------------------------------');
    }

    return stripBidiIsolates(sb.toString());
  }

  /// Copies the Live Logistics Radar dossier to the system clipboard cleanly using [CopyHelper].
  static Future<void> copyRadarDossier({
    required BuildContext context,
    required List<LiveLogisticsTrackingItemModel> items,
    List<ImportFileModel>? allImportFiles,
  }) async {
    final dossier = buildRadarDossierText(
      context: context,
      items: items,
      allImportFiles: allImportFiles,
    );
    await CopyHelper.copy(
      context,
      dossier,
      customMessage: context.l10n.lifecycleCopyDossierSuccess,
    );
  }

  /// Copies the Live Logistics Radar table as TSV directly to clipboard using [TableCopyHelper.copyTable].
  static Future<void> copyRadarTable({
    required BuildContext context,
    required List<LiveLogisticsTrackingItemModel> items,
    List<ImportFileModel>? allImportFiles,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final headers = [
      l.operationalTsvHeaderShipmentName,
      l.radarTsvHeaderFileCode,
      l.radarTsvHeaderCarrierVessel,
      l.radarTsvHeaderBlRoute,
      l.radarTsvHeaderArrivalStatus,
      l.radarTsvHeaderDemurrageRisk,
      l.radarTsvHeaderTestingStatus,
      l.radarTsvHeaderDocReadiness,
    ];
    final rows = items.map((item) {
      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
        item.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
      );
      final carrierVessel = '${item.carrierName ?? l.colCarrierUnderPrep} (${item.vesselName ?? "-"})';
      final blRoute = '${item.blNumber ?? l.colCarrierUnderPrep} | ${item.polName ?? "-"} -> ${item.podName ?? "-"}';
      final arrivalStr = '${item.eta ?? "-"} (${item.arrivalStatus})';
      final demurrageStr = item.accumulatedDemurrageFx > 0
          ? '${l.demurrageIncurredBadge}: \$${item.accumulatedDemurrageFx.toStringAsFixed(0)}'
          : (item.freeDaysRemaining != null ? l.freeDaysRemainingBadge(item.freeDaysRemaining) : '-');

      return [
        shipmentName,
        item.importFileCode,
        carrierVessel,
        blRoute,
        arrivalStr,
        demurrageStr,
        item.sampleTestStatus,
        '${item.docReadinessPercent.toStringAsFixed(0)}%',
      ];
    }).toList();

    await TableCopyHelper.copyTable(context, headers, rows);
  }

  /// Exports the Live Radar table to TSV format with UTF-8 BOM.
  static Future<void> exportRadarToTsv({
    required BuildContext context,
    required List<LiveLogisticsTrackingItemModel> items,
    List<ImportFileModel>? allImportFiles,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final sb = StringBuffer();

    sb.writeln([
      l.operationalTsvHeaderShipmentName,
      l.radarTsvHeaderFileCode,
      l.radarTsvHeaderCarrierVessel,
      l.radarTsvHeaderBlRoute,
      l.radarTsvHeaderArrivalStatus,
      l.radarTsvHeaderDemurrageRisk,
      l.radarTsvHeaderTestingStatus,
      l.radarTsvHeaderDocReadiness,
    ].join('\t'));

    for (final item in items) {
      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
        item.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
      );
      final carrierVessel = '${item.carrierName ?? l.colCarrierUnderPrep} (${item.vesselName ?? "-"})';
      final blRoute = '${item.blNumber ?? l.colCarrierUnderPrep} | ${item.polName ?? "-"} -> ${item.podName ?? "-"}';
      final arrivalStr = '${item.eta ?? "-"} (${item.arrivalStatus})';
      final demurrageStr = item.accumulatedDemurrageFx > 0
          ? '${l.demurrageIncurredBadge}: \$${item.accumulatedDemurrageFx.toStringAsFixed(0)}'
          : (item.freeDaysRemaining != null ? l.freeDaysRemainingBadge(item.freeDaysRemaining) : '-');

      sb.writeln([
        shipmentName,
        '${item.importFileCode} (${item.shipmentMode ?? "-"}|${item.incotermCode ?? "-"})',
        carrierVessel,
        blRoute,
        arrivalStr,
        demurrageStr,
        item.sampleTestStatus,
        '${item.docReadinessPercent.toStringAsFixed(0)}%',
      ].join('\t'));
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: 'Logistics_Radar_$dateStr.tsv',
      dialogTitle: l.radarExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports the Live Radar table to unmerged CSV/Excel with UTF-8 BOM.
  static Future<void> exportRadarToExcel({
    required BuildContext context,
    required List<LiveLogisticsTrackingItemModel> items,
    List<ImportFileModel>? allImportFiles,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;
    final sb = StringBuffer();

    String escapeCsv(String text) {
      if (text.contains(',') || text.contains('"') || text.contains('\n')) {
        return '"${text.replaceAll('"', '""')}"';
      }
      return text;
    }

    sb.writeln([
      escapeCsv(l.operationalTsvHeaderShipmentName),
      escapeCsv(l.radarTsvHeaderFileCode),
      escapeCsv(l.radarTsvHeaderCarrierVessel),
      escapeCsv(l.radarTsvHeaderBlRoute),
      escapeCsv(l.radarTsvHeaderArrivalStatus),
      escapeCsv(l.radarTsvHeaderDemurrageRisk),
      escapeCsv(l.radarTsvHeaderTestingStatus),
      escapeCsv(l.radarTsvHeaderDocReadiness),
    ].join(','));

    for (final item in items) {
      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
        item.importFileCode,
        shipments: allImportFiles,
        isArabic: isAr,
      );
      final carrierVessel = '${item.carrierName ?? l.colCarrierUnderPrep} (${item.vesselName ?? "-"})';
      final blRoute = '${item.blNumber ?? l.colCarrierUnderPrep} | ${item.polName ?? "-"} -> ${item.podName ?? "-"}';
      final arrivalStr = '${item.eta ?? "-"} (${item.arrivalStatus})';
      final demurrageStr = item.accumulatedDemurrageFx > 0
          ? '${l.demurrageIncurredBadge}: \$${item.accumulatedDemurrageFx.toStringAsFixed(0)}'
          : (item.freeDaysRemaining != null ? l.freeDaysRemainingBadge(item.freeDaysRemaining) : '-');

      sb.writeln([
        escapeCsv(shipmentName),
        escapeCsv('${item.importFileCode} (${item.shipmentMode ?? "-"}|${item.incotermCode ?? "-"})'),
        escapeCsv(carrierVessel),
        escapeCsv(blRoute),
        escapeCsv(arrivalStr),
        escapeCsv(demurrageStr),
        escapeCsv(item.sampleTestStatus),
        escapeCsv('${item.docReadinessPercent.toStringAsFixed(0)}%'),
      ].join(','));
    }

    final dateStr = DateTime.now().toIso8601String().split('T').first;
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: 'Logistics_Radar_$dateStr.csv',
      dialogTitle: l.radarExportExcelDialogTitle,
      allowedExtensions: ['csv', 'xlsx'],
      addUtf8Bom: true,
    );
  }

  /// Generates vector A4 landscape Cairo PDF for Live Logistics Tracking Radar.
  static Future<void> printOrSaveRadarPdf({
    required BuildContext context,
    required List<LiveLogisticsTrackingItemModel> items,
    List<ImportFileModel>? allImportFiles,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;

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
                            l.radarDossierHeader,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text(
                            'Sorour Logistics Live Logistics Tracking Radar',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E67E22'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          l.shipmentsCountFormatted(items.length),
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Radar Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.6), // Shipment Name & Code
                    1: const pw.FlexColumnWidth(1.8), // Carrier & Vessel
                    2: const pw.FlexColumnWidth(2.0), // B/L & Route
                    3: const pw.FlexColumnWidth(1.6), // Arrival
                    4: const pw.FlexColumnWidth(1.8), // Demurrage
                    5: const pw.FlexColumnWidth(1.4), // Testing
                    6: const pw.FlexColumnWidth(1.0), // Readiness
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#ECF0F1')),
                      children: [
                        _pdfHeaderCell(l.operationalTsvHeaderShipmentName),
                        _pdfHeaderCell(l.radarTsvHeaderCarrierVessel),
                        _pdfHeaderCell(l.radarTsvHeaderBlRoute),
                        _pdfHeaderCell(l.radarTsvHeaderArrivalStatus),
                        _pdfHeaderCell(l.radarTsvHeaderDemurrageRisk),
                        _pdfHeaderCell(l.radarTsvHeaderTestingStatus),
                        _pdfHeaderCell(l.radarTsvHeaderDocReadiness),
                      ],
                    ),
                    // Data Rows
                    ...items.map((item) {
                      final shipmentName = DisplayNameResolver.resolveShipmentNameByCode(
                        item.importFileCode,
                        shipments: allImportFiles,
                        isArabic: isAr,
                      );
                      final carrierVessel = '${item.carrierName ?? l.colCarrierUnderPrep} (${item.vesselName ?? "-"})';
                      final blRoute = '${item.blNumber ?? l.colCarrierUnderPrep}\n${item.polName ?? "-"} -> ${item.podName ?? "-"}';
                      final arrivalStr = '${l.colEtaPrefix}: ${item.eta ?? "-"}\n${item.arrivalStatus}';
                      final demurrageStr = item.accumulatedDemurrageFx > 0
                          ? '${l.demurrageIncurredBadge}\n\$${item.accumulatedDemurrageFx.toStringAsFixed(0)}'
                          : (item.freeDaysRemaining != null ? l.freeDaysRemainingBadge(item.freeDaysRemaining) : '-');

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  shipmentName,
                                  style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#2C3E50'),
                                  ),
                                ),
                                pw.Text(
                                  '${item.importFileCode} (${item.shipmentMode}|${item.incotermCode})',
                                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                                ),
                                pw.Text(
                                  item.companyName,
                                  style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                                ),
                              ],
                            ),
                          ),
                          _pdfDataCell(carrierVessel),
                          _pdfDataCell(blRoute),
                          _pdfDataCell(arrivalStr),
                          _pdfDataCell(demurrageStr, isAlert: item.accumulatedDemurrageFx > 0),
                          _pdfDataCell(item.sampleTestStatus),
                          _pdfDataCell('${item.docReadinessPercent.toStringAsFixed(0)}%', isAlert: item.docReadinessPercent < 80),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Sign-off footer
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
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Logistics_Radar_$dateStr.pdf',
    );
  }

  // --- Helpers for PDF cells ---

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

  static pw.Widget _pdfDataCell(String text, {bool isBold = false, bool isAlert = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isAlert ? PdfColor.fromHex('#C0392B') : PdfColor.fromHex('#2C3E50'),
        ),
      ),
    );
  }
}

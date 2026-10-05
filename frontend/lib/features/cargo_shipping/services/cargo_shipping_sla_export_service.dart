import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../import_files/models/import_file_model.dart';
import '../models/cargo_shipping_model.dart';

/// Dedicated export service for Cargo Shipping 48h SLA Tracking (Screen 52).
/// Supports TSV export, clean Excel (CSV) export, vector A4 landscape Cairo PDF, and clipboard dossier copy.
class CargoShippingSlaExportService {
  final BuildContext context;
  final ImportFileModel? importFile;
  final String shipmentType; // 'FCL' or 'LCL'
  final List<ContainerLoadingModel> containers;
  final LclLoadingTrackingModel? lclTracking;
  final String cfsWarehouse;
  final int totalCount;
  final int inProgressCount;
  final int gatedInCount;
  final int breachedCount;

  CargoShippingSlaExportService({
    required this.context,
    required this.importFile,
    required this.shipmentType,
    required this.containers,
    required this.lclTracking,
    required this.cfsWarehouse,
    required this.totalCount,
    required this.inProgressCount,
    required this.gatedInCount,
    required this.breachedCount,
  });

  AppLocalizations get _l10n => context.l10n;

  String get fileCode => importFile?.primaryNameWithCode ?? 'N/A';
  String get importer => importFile?.companyName ?? 'N/A';
  String get supplier => importFile?.supplierName ?? 'N/A';
  String get acid => importFile?.acidNumber ?? 'N/A';
  String get pol => importFile?.portOfLoading ?? 'N/A';
  String get pod => importFile?.portOfDischarge ?? 'Alexandria';

  String _cleanTsv(String val) => val.replaceAll('\t', ' ').replaceAll('\n', ' ').replaceAll('\r', '').trim();

  String _csvQuote(String val) {
    final clean = val.replaceAll('\r', '');
    if (clean.contains(',') || clean.contains('"') || clean.contains('\n')) {
      return '"${clean.replaceAll('"', '""')}"';
    }
    return clean;
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final date = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return "$date $hour:$minute";
  }

  /// Builds a plain-text structured dossier summary.
  String buildDossierText() {
    final l10n = _l10n;
    final buf = StringBuffer();

    buf.writeln('════════════════════════════════════════════════════════════════');
    buf.writeln('  ${l10n.cargoShippingSlaDossierHeader}');
    buf.writeln('════════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('${l10n.cargoShippingLinkedFileBannerPrefix} $fileCode');
    buf.writeln('${l10n.cargoShippingSupplierLabel} $supplier');
    buf.writeln('${l10n.cargoShippingAcidPrefix}: $acid');
    buf.writeln('${l10n.shippingRouteLabel}: $pol ➔ $pod');
    buf.writeln('${l10n.cargoShippingShipmentTypeLabel}: $shipmentType');
    buf.writeln('');

    buf.writeln('── ${l10n.cargoShippingSlaSummaryHeader} ──');
    buf.writeln('• ${l10n.cargoShippingMetricTotalContainers}: $totalCount');
    buf.writeln('• ${l10n.cargoShippingMetricInProgress}: $inProgressCount');
    buf.writeln('• ${l10n.cargoShippingMetricGatedIn}: $gatedInCount');
    buf.writeln('• ${l10n.cargoShippingMetricSlaBreached}: $breachedCount');
    buf.writeln('');

    if (shipmentType == 'FCL') {
      buf.writeln('── ${l10n.cargoShippingContainersHeader} ──');
      for (int i = 0; i < containers.length; i++) {
        final c = containers[i];
        final slaLabel = c.isSlaBreached ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime;
        buf.writeln('[$i + 1] ${l10n.cargoShippingColContainerNo}: ${c.containerNo} (${c.containerType}) | ${l10n.cargoShippingColSealNo}: ${c.sealNo}');
        buf.writeln('    - ${l10n.cargoShippingMilestone1Title}: ${_formatDateTime(c.containerAssignmentDate)}');
        buf.writeln('    - ${l10n.cargoShippingMilestone2Title}: ${_formatDateTime(c.arrivalAtSupplierAt)}');
        buf.writeln('    - ${l10n.cargoShippingMilestone3Title}: ${_formatDateTime(c.loadingStartAt)}');
        buf.writeln('    - ${l10n.cargoShippingMilestone4Title}: ${_formatDateTime(c.loadingEndAt)}');
        buf.writeln('    - ${l10n.cargoShippingMilestone5Title}: ${_formatDateTime(c.portGateInAt)}');
        buf.writeln('    - ${l10n.cargoShippingColTrackingStatus}: ${c.getLocalizedStatus(l10n)} | $slaLabel');
        if (c.milestoneNotes.isNotEmpty) {
          buf.writeln('    - ${l10n.cargoShippingSlaTsvHeaderNotes}: ${c.milestoneNotes.entries.map((e) => "${e.key}: ${e.value}").join(" | ")}');
        }
        buf.writeln('');
      }
    } else {
      final lcl = lclTracking;
      buf.writeln('── ${l10n.cargoShippingCfsHeader} ──');
      buf.writeln('${l10n.cargoShippingCfsWarehouseLabel}: $cfsWarehouse');
      if (lcl != null) {
        final slaLabel = lcl.isSlaBreached ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime;
        buf.writeln('• ${l10n.cargoShippingLclMilestone1}: ${_formatDateTime(lcl.consolidationScheduledDate)}');
        buf.writeln('• ${l10n.cargoShippingLclMilestone2}: ${_formatDateTime(lcl.arrivalAtCfsAt)}');
        buf.writeln('• ${l10n.cargoShippingLclMilestone3}: ${_formatDateTime(lcl.stuffingStartAt)}');
        buf.writeln('• ${l10n.cargoShippingLclMilestone4}: ${_formatDateTime(lcl.stuffingEndAt)}');
        buf.writeln('• ${l10n.cargoShippingLclMilestone5}: ${_formatDateTime(lcl.portGateInAt)}');
        buf.writeln('• ${l10n.cargoShippingColTrackingStatus}: ${lcl.getLocalizedStatus(l10n)} | $slaLabel');
      }
    }

    return buf.toString().trim();
  }

  /// Copies the generated dossier to the clipboard and shows feedback.
  Future<void> copyDossierToClipboard() async {
    final text = buildDossierText();
    CopyHelper.copy(context, text, customMessage: _l10n.cargoShippingSlaCopyDossierSuccess);
  }

  /// Exports 48h SLA tracking log as TSV with UTF-8 BOM.
  Future<void> exportToTsv() async {
    final l10n = _l10n;
    final buffer = StringBuffer();

    // Header Row
    buffer.writeln([
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderUnit),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderContainerNo),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderContainerType),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderSealNo),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderAssignmentDate),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderArrivalDate),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderLoadingStartDate),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderLoadingEndDate),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderPortGateInDate),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderSlaStatus),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderTrackingStatus),
      _cleanTsv(l10n.cargoShippingSlaTsvHeaderNotes),
    ].join('\t'));

    if (shipmentType == 'FCL') {
      for (int i = 0; i < containers.length; i++) {
        final c = containers[i];
        final slaStatus = c.isSlaBreached ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime;
        final notes = c.milestoneNotes.entries.map((e) => '[${e.key}]: ${e.value}').join(' ; ');

        buffer.writeln([
          (i + 1).toString(),
          _cleanTsv(c.containerNo),
          _cleanTsv(c.containerType),
          _cleanTsv(c.sealNo),
          _cleanTsv(_formatDateTime(c.containerAssignmentDate)),
          _cleanTsv(_formatDateTime(c.arrivalAtSupplierAt)),
          _cleanTsv(_formatDateTime(c.loadingStartAt)),
          _cleanTsv(_formatDateTime(c.loadingEndAt)),
          _cleanTsv(_formatDateTime(c.portGateInAt)),
          _cleanTsv(slaStatus),
          _cleanTsv(c.getLocalizedStatus(l10n)),
          _cleanTsv(notes),
        ].join('\t'));
      }
    } else {
      final lcl = lclTracking;
      final slaStatus = (lcl?.isSlaBreached ?? false) ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime;
      buffer.writeln([
        '1',
        _cleanTsv('LCL - CFS'),
        _cleanTsv('LCL'),
        '-',
        _cleanTsv(_formatDateTime(lcl?.consolidationScheduledDate)),
        _cleanTsv(_formatDateTime(lcl?.arrivalAtCfsAt)),
        _cleanTsv(_formatDateTime(lcl?.stuffingStartAt)),
        _cleanTsv(_formatDateTime(lcl?.stuffingEndAt)),
        _cleanTsv(_formatDateTime(lcl?.portGateInAt)),
        _cleanTsv(slaStatus),
        _cleanTsv(lcl?.getLocalizedStatus(l10n) ?? l10n.cargoShippingStatusAssigned),
        _cleanTsv(cfsWarehouse),
      ].join('\t'));
    }

    final safeCode = (importFile?.importFileCode ?? 'SLA').replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'Cargo_Shipping_SLA_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.tsv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l10n.cargoShippingSlaExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Exports 48h SLA tracking log as clean unmerged CSV/Excel with UTF-8 BOM.
  Future<void> exportToExcel() async {
    final l10n = _l10n;
    final buffer = StringBuffer();

    // CSV Header Row
    buffer.writeln([
      _csvQuote(l10n.cargoShippingSlaTsvHeaderUnit),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderContainerNo),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderContainerType),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderSealNo),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderAssignmentDate),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderArrivalDate),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderLoadingStartDate),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderLoadingEndDate),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderPortGateInDate),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderSlaStatus),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderTrackingStatus),
      _csvQuote(l10n.cargoShippingSlaTsvHeaderNotes),
    ].join(','));

    if (shipmentType == 'FCL') {
      for (int i = 0; i < containers.length; i++) {
        final c = containers[i];
        final slaStatus = c.isSlaBreached ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime;
        final notes = c.milestoneNotes.entries.map((e) => '[${e.key}]: ${e.value}').join(' ; ');

        buffer.writeln([
          (i + 1).toString(),
          _csvQuote(c.containerNo),
          _csvQuote(c.containerType),
          _csvQuote(c.sealNo),
          _csvQuote(_formatDateTime(c.containerAssignmentDate)),
          _csvQuote(_formatDateTime(c.arrivalAtSupplierAt)),
          _csvQuote(_formatDateTime(c.loadingStartAt)),
          _csvQuote(_formatDateTime(c.loadingEndAt)),
          _csvQuote(_formatDateTime(c.portGateInAt)),
          _csvQuote(slaStatus),
          _csvQuote(c.getLocalizedStatus(l10n)),
          _csvQuote(notes),
        ].join(','));
      }
    } else {
      final lcl = lclTracking;
      final slaStatus = (lcl?.isSlaBreached ?? false) ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime;
      buffer.writeln([
        '1',
        _csvQuote('LCL - CFS'),
        _csvQuote('LCL'),
        '-',
        _csvQuote(_formatDateTime(lcl?.consolidationScheduledDate)),
        _csvQuote(_formatDateTime(lcl?.arrivalAtCfsAt)),
        _csvQuote(_formatDateTime(lcl?.stuffingStartAt)),
        _csvQuote(_formatDateTime(lcl?.stuffingEndAt)),
        _csvQuote(_formatDateTime(lcl?.portGateInAt)),
        _csvQuote(slaStatus),
        _csvQuote(lcl?.getLocalizedStatus(l10n) ?? l10n.cargoShippingStatusAssigned),
        _csvQuote(cfsWarehouse),
      ].join(','));
    }

    final safeCode = (importFile?.importFileCode ?? 'SLA').replaceAll(RegExp(r'[^\w\-]'), '_');
    final filename = 'Cargo_Shipping_SLA_${safeCode}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await FileSaveHelper.saveText(
      context: context,
      textContent: buffer.toString(),
      defaultFileName: filename,
      dialogTitle: l10n.cargoShippingSlaExportExcelDialogTitle,
      allowedExtensions: ['csv', 'txt'],
      addUtf8Bom: true,
    );
  }

  /// Generates vector A4 Landscape PDF with Cairo typography and executive summary.
  Future<void> printOrSavePdf({bool save = false}) async {
    final l10n = _l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final textDir = isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        textDirection: textDir,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context ctx) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'IMPORTFLOW ERP — SOROUR LOGISTICS',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      l10n.cargoShippingSlaDossierHeader,
                      style: pw.TextStyle(color: PdfColors.amber300, fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: isAr ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      fileCode,
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'ACID: $acid',
                      style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Shipment Summary Row
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${l10n.importerCompanyLabel}: $importer', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${l10n.cargoShippingSupplierLabel} $supplier', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${l10n.shippingRouteLabel}: $pol ➔ $pod', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('${l10n.cargoShippingShipmentTypeLabel}: $shipmentType', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue800)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // 4 Metric Highlight Boxes
          pw.Row(
            children: [
              _buildPdfMetricBox(l10n.cargoShippingMetricTotalContainers, totalCount.toString(), PdfColors.blue800),
              pw.SizedBox(width: 8),
              _buildPdfMetricBox(l10n.cargoShippingMetricInProgress, inProgressCount.toString(), PdfColors.orange800),
              pw.SizedBox(width: 8),
              _buildPdfMetricBox(l10n.cargoShippingMetricGatedIn, gatedInCount.toString(), PdfColors.green800),
              pw.SizedBox(width: 8),
              _buildPdfMetricBox(l10n.cargoShippingMetricSlaBreached, breachedCount.toString(), breachedCount > 0 ? PdfColors.red800 : PdfColors.grey700),
            ],
          ),
          pw.SizedBox(height: 16),

          // Milestone Tracking Table
          pw.Text(
            l10n.cargoShippingContainersHeader,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),

          pw.TableHelper.fromTextArray(
            headers: [
              l10n.cargoShippingSlaTsvHeaderUnit,
              l10n.cargoShippingSlaTsvHeaderContainerNo,
              l10n.cargoShippingSlaTsvHeaderContainerType,
              l10n.cargoShippingSlaTsvHeaderSealNo,
              l10n.cargoShippingSlaTsvHeaderAssignmentDate,
              l10n.cargoShippingSlaTsvHeaderArrivalDate,
              l10n.cargoShippingSlaTsvHeaderLoadingStartDate,
              l10n.cargoShippingSlaTsvHeaderLoadingEndDate,
              l10n.cargoShippingSlaTsvHeaderPortGateInDate,
              l10n.cargoShippingSlaTsvHeaderSlaStatus,
              l10n.cargoShippingSlaTsvHeaderTrackingStatus,
            ],
            data: shipmentType == 'FCL'
                ? containers.asMap().entries.map((e) {
                    final i = e.key;
                    final c = e.value;
                    return [
                      (i + 1).toString(),
                      c.containerNo,
                      c.containerType,
                      c.sealNo,
                      _formatDateTime(c.containerAssignmentDate),
                      _formatDateTime(c.arrivalAtSupplierAt),
                      _formatDateTime(c.loadingStartAt),
                      _formatDateTime(c.loadingEndAt),
                      _formatDateTime(c.portGateInAt),
                      c.isSlaBreached ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime,
                      c.getLocalizedStatus(l10n),
                    ];
                  }).toList()
                : [
                    [
                      '1',
                      'LCL - CFS',
                      'LCL',
                      '-',
                      _formatDateTime(lclTracking?.consolidationScheduledDate),
                      _formatDateTime(lclTracking?.arrivalAtCfsAt),
                      _formatDateTime(lclTracking?.stuffingStartAt),
                      _formatDateTime(lclTracking?.stuffingEndAt),
                      _formatDateTime(lclTracking?.portGateInAt),
                      (lclTracking?.isSlaBreached ?? false) ? l10n.cargoShippingSlaBreached : l10n.cargoShippingSlaOnTime,
                      lclTracking?.getLocalizedStatus(l10n) ?? l10n.cargoShippingStatusAssigned,
                    ]
                  ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: isAr ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
      ),
    );

    if (save) {
      final bytes = await pdf.save();
      if (!context.mounted) return;
      await FileSaveHelper.exportAndSaveFile(
        context: context,
        bytes: bytes,
        stageName: l10n.cargoShippingSlaStageTitle,
        importFileNameOrCode: importFile?.importFileCode ?? 'SLA',
        extension: 'pdf',
      );
      return;
    }
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cargo_Shipping_SLA_${importFile?.importFileCode ?? "SLA"}.pdf',
    );
  }

  pw.Widget _buildPdfMetricBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: color, width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

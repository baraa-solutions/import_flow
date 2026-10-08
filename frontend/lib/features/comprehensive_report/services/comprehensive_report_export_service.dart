import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/services/file_save_helper.dart';
import '../../../core/services/display_name_resolver.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import '../../customs_clearance/widgets/customs_ui.dart';
import '../../import_files/models/import_file_model.dart';
import '../../shipment_updates/models/shipment_update_model.dart';
import '../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../models/comprehensive_dossier_model.dart';
import '../../purchase_orders/utils/po_packing_matcher.dart';

/// Central export and dossier generation service for the Comprehensive Import File Report (Screen 47).
/// Provides TSV, unmerged Excel (CSV with UTF-8 BOM), vector A4 Cairo PDF, and plain text clipboard dossier.
class ComprehensiveReportExportService {
  /// Builds a formatted plain text summary of the entire shipment file dossier for quick copying.
  static String buildDossierText({
    required BuildContext context,
    required ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) {
    final l = context.l10n;
    final sb = StringBuffer();

    sb.writeln('================================================================');
    sb.writeln(l.compReportDossierHeader);
    sb.writeln('================================================================');
    sb.writeln('${l.compReportColFileCode}: ${file.importFileCode}');
    if (file.customFileNumber != null && file.customFileNumber!.isNotEmpty) {
      sb.writeln('${l.compReportColCustomsFileNo}: ${file.customFileNumber}');
    }
    sb.writeln('${l.compReportColImportCompany}: ${file.companyName}');
    sb.writeln('${l.compReportColSupplier}: ${file.supplierName}');
    if (file.brokerName != null && file.brokerName!.isNotEmpty) {
      sb.writeln('${l.compReportColBroker}: ${file.brokerName}');
    }
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final stageName = DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isArabic);
    final moduleName =
        file.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: isArabic);
    final nextAction = file.displayNextAction(l, forExport: true);

    sb.writeln('${l.compReportStatusLabel}: ${file.status}');
    sb.writeln('${l.compReportCurrentStageLabel}: $stageName');
    sb.writeln('${l.compReportCurrentModuleLabel}: $moduleName');
    sb.writeln('${l.compReportNextActionLabel}: $nextAction');
    sb.writeln('${l.compReportTotalProgressLabel} ${file.progressPercent.toStringAsFixed(0)}%');
    sb.writeln();

    // Section: Basic Info
    sb.writeln('--- ${l.compReportSecBasicInfo} ---');
    if (file.poNumber != null) sb.writeln('${l.compReportColPoNumber}: ${file.poNumber}');
    if (file.piNumber != null) sb.writeln('${l.compReportColPiNumber}: ${file.piNumber}');
    sb.writeln('${l.compReportColShipmentMode}: ${file.shipmentMode}');
    sb.writeln('${l.compReportColIncoterm}: ${file.incotermCode}');
    sb.writeln('${l.compReportColCategory}: ${file.shipmentCategory}');
    if (file.selectedScenario != null) sb.writeln('${l.compReportColScenario}: ${file.selectedScenario}');
    if (file.requiredEta != null) sb.writeln('${l.compReportColRequiredEta}: ${file.requiredEta}');
    sb.writeln('${l.compReportColOwner}: ${file.owner}');
    sb.writeln('${l.compReportColCreatedAt}: ${file.createdAt.split('T').first}');
    sb.writeln('${l.compReportColUpdatedAt}: ${file.updatedAt.split('T').first}');
    sb.writeln();

    // Section: Documents
    sb.writeln('--- ${l.compReportSecDocs} ---');
    sb.writeln('${l.compReportAcidNumber}: ${file.acidNumber ?? '—'}');
    sb.writeln('${l.compReportBankForm4}: ${file.form4No ?? '—'}');
    sb.writeln('${l.compReportSwiftNumber}: ${file.swiftNo ?? '—'}');
    sb.writeln('${l.compReportForm46Number}: ${file.form46No ?? '—'}');
    sb.writeln();

    // Section: Invoices
    sb.writeln('--- ${l.compReportSecInvoices(file.invoicesData.length)} ---');
    if (file.invoicesData.isEmpty) {
      sb.writeln(l.compReportNoInvoices);
    } else {
      for (final inv in file.invoicesData) {
        sb.writeln('• ${inv.invoiceNo} | ${inv.invoiceType} | ${inv.amount.toStringAsFixed(2)} ${inv.currency}${inv.date != null ? ' | ${inv.date}' : ''}');
      }
    }
    sb.writeln();

    // Section: Packing Lists
    sb.writeln('--- ${l.compReportSecPackingLists(file.packingListsData.length)} ---');
    if (file.packingListsData.isEmpty) {
      sb.writeln(l.compReportNoPackingLists);
    } else {
      double totalCbm = file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
      double totalWeight = file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
      int totalPkgs = file.packingListsData.fold(0, (s, p) => s + p.totalPackages);
      sb.writeln('${l.compReportTotalPackages}: $totalPkgs | ${l.compReportTotalWeight}: ${PoPackingMatcher.formatWeight(totalWeight)} KG | ${l.compReportTotalCbm}: ${totalCbm.toStringAsFixed(2)} m³');
      for (final pl in file.packingListsData) {
        sb.writeln('• ${pl.plNo} | ${pl.totalPackages} pkgs | ${PoPackingMatcher.formatWeight(pl.grossWeightKg)} KG | ${pl.cbm.toStringAsFixed(2)} CBM');
      }
    }
    sb.writeln();

    // Section: Financials
    double totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    sb.writeln('--- ${l.compReportSecFinancial} ---');
    sb.writeln('${l.compReportTotalInvoicesVal}: ${totalInvoicesValue.toStringAsFixed(2)} USD');
    sb.writeln('${l.compReportEstimatedCostVal}: ${file.estimatedCost.toStringAsFixed(2)} USD');
    sb.writeln('${l.compReportEstimatedVariance}: ${(file.estimatedCost - totalInvoicesValue).toStringAsFixed(2)} USD');
    sb.writeln();

    // Section: Actual Landed Cost & Settlement (CLO-01 & CLO-02)
    final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
    if (actualLanded > 0) {
      final markup = dossier != null ? dossier.actualLandedCostMarkupFactor : (file.actualLandedCostMarkupFactor > 0 ? file.actualLandedCostMarkupFactor : null);
      final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
      final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;

      sb.writeln('--- تكلفة الوصول الفعلية والتسوية المالية الشاملة (CLO-01 & CLO-02) ---');
      sb.writeln('إجمالي تكلفة الوصول الفعلية: ${actualLanded.toStringAsFixed(2)} EGP');
      sb.writeln('معامل زيادة التكلفة (Markup Factor): ${markup != null ? "${markup.toStringAsFixed(3)}x" : "—"}');
      sb.writeln('انحراف التكلفة الفعلية عن التقديرية: ${varianceEgp.toStringAsFixed(2)} EGP (${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(2)}%)');
      sb.writeln('حالة التسوية المالية: ${file.financialSettlementStatus ?? "COST_ALLOCATED"}');
      sb.writeln();
    }

    // Section: Customs Clearance
    if (clearance != null) {
      sb.writeln('--- ${l.compReportSecClearance} ---');
      if (clearance.declaration46No != null) sb.writeln(l.compReportDeclarationChip(clearance.declaration46No!));
      sb.writeln('Channel: ${clearance.channelType} | Office: ${clearance.customsOfficeName}');
      if (clearance.releasePermitNo != null) sb.writeln(l.compReportReleasePermitChip(clearance.releasePermitNo!));
      sb.writeln('${l.compReportDutyImport}: ${CcFormat.fixed(clearance.importDutyAmount)} | ${l.compReportDutyVat}: ${CcFormat.fixed(clearance.vatAmount)} | ${l.compReportDutyTotal}: ${CcFormat.fixed(clearance.totalDutyPayable)}');
      sb.writeln();
    }

    // Section: Warehouse
    if (warehouse != null) {
      sb.writeln('--- ${l.compReportSecWarehouse} ---');
      sb.writeln('${l.compReportGrnChip(warehouse.grnCode)} | ${warehouse.warehouseName}');
      sb.writeln('${l.compReportArrivalDatetime(warehouse.arrivalDatetime)} | ${l.compReportInspectorPrefix(warehouse.inspectorName)}');
      sb.writeln('${l.compReportQtyInvoiced}: ${warehouse.totalInvoicedQty} | ${l.compReportQtyAccepted}: ${warehouse.totalAcceptedQty} | ${l.compReportQtyShortage}: ${warehouse.totalShortageQty} | ${l.compReportQtyDamaged}: ${warehouse.totalDamagedQty}');
      sb.writeln();
    }

    // Section: Empty Container Return EIR
    final eirNumbers = dossier?.emptyContainersEirNumbers ?? file.emptyContainersEirNumbers;
    if (eirNumbers != null && eirNumbers.isNotEmpty) {
      sb.writeln('--- إعادة الحاويات الفارغة وإيصالات EIR (TR-05) ---');
      sb.writeln('أرقام إيصالات EIR: $eirNumbers');
      if (file.emptyContainersReturnedAt != null) {
        sb.writeln('تاريخ الإعادة: ${file.emptyContainersReturnedAt}');
      }
      sb.writeln();
    }

    // Section: Timeline Logs
    if (logs != null && logs.isNotEmpty) {
      sb.writeln('--- ${l.compReportSecTimeline(logs.length)} ---');
      for (final log in logs) {
        sb.writeln('[${log.logDate}] ${log.updateCategory} - ${log.targetPhase}: ${log.note} (${l.compReportByPrefix(log.assignedUser)})');
      }
      sb.writeln();
    }

    if (file.notes != null && file.notes!.isNotEmpty) {
      sb.writeln('--- ${l.compReportSecNotes} ---');
      sb.writeln(file.notes!);
    }

    return sb.toString();
  }

  /// Exports the comprehensive shipment report to TSV format with UTF-8 BOM.
  static Future<void> exportToTsv({
    required BuildContext context,
    required ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) async {
    final l = context.l10n;
    final rows = _buildDossierRows(context, file, dossier: dossier, logs: logs, clearance: clearance, warehouse: warehouse);

    final sb = StringBuffer();
    sb.writeln('# ${l.compReportDossierHeader} - ${file.importFileCode} - ${DateTime.now().toIso8601String()}');
    sb.writeln('${l.compReportTsvColSection}\t${l.compReportTsvColField}\t${l.compReportTsvColValue}\t${l.compReportTsvColDetails}');

    for (final r in rows) {
      final sec = r[0].replaceAll('\t', ' ').replaceAll('\n', ' ');
      final fld = r[1].replaceAll('\t', ' ').replaceAll('\n', ' ');
      final val = r[2].replaceAll('\t', ' ').replaceAll('\n', ' ');
      final det = r[3].replaceAll('\t', ' ').replaceAll('\n', ' ');
      sb.writeln('$sec\t$fld\t$val\t$det');
    }

    final filename = 'Comprehensive Dossier - ${file.primaryNameWithCode}.tsv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: filename,
      dialogTitle: l.compReportExportTsvDialogTitle,
      allowedExtensions: ['tsv', 'txt'],
    );
  }

  /// Exports the comprehensive shipment report to Excel compatible CSV format with UTF-8 BOM.
  static Future<void> exportToExcel({
    required BuildContext context,
    required ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) async {
    final l = context.l10n;
    final rows = _buildDossierRows(context, file, dossier: dossier, logs: logs, clearance: clearance, warehouse: warehouse);

    final sb = StringBuffer();
    sb.writeln('# ${l.compReportDossierHeader} - ${file.importFileCode} - ${DateTime.now().toIso8601String()}');
    sb.writeln('"${l.compReportTsvColSection}","${l.compReportTsvColField}","${l.compReportTsvColValue}","${l.compReportTsvColDetails}"');

    for (final r in rows) {
      final sec = r[0].replaceAll('"', '""').replaceAll('\n', ' ');
      final fld = r[1].replaceAll('"', '""').replaceAll('\n', ' ');
      final val = r[2].replaceAll('"', '""').replaceAll('\n', ' ');
      final det = r[3].replaceAll('"', '""').replaceAll('\n', ' ');
      sb.writeln('"$sec","$fld","$val","$det"');
    }

    final filename = 'Comprehensive Dossier - ${file.primaryNameWithCode}.csv';
    await FileSaveHelper.saveText(
      context: context,
      textContent: sb.toString(),
      defaultFileName: filename,
      dialogTitle: l.compReportExportExcelDialogTitle,
      allowedExtensions: ['csv', 'xlsx'],
    );
  }

  /// Generates vector A4 PDF using Cairo typography and opens printing / saving dialogue.
  static Future<void> printOrSavePdf({
    required BuildContext context,
    required ImportFileModel file,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    final pdf = pw.Document();
    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();

    final totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    final totalCbm = file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    final totalWeight = file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    final totalPkgs = file.packingListsData.fold(0, (s, p) => s + p.totalPackages);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (pw.Context pdfContext) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
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
                            l.compReportDossierHeader,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${file.displayName}  |  ${file.supplierName}  |  ${file.companyName}',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: file.status.toLowerCase() == 'closed' ? PdfColors.grey600 : PdfColor.fromHex('#27AE60'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          file.status,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Section 1: Basic Information Table
                pw.Text(l.compReportSecBasicInfo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportColFileCode, file.importFileCode, l.compReportColCustomsFileNo, file.customFileNumber ?? '—'),
                    _pdfTableRow(l.compReportColImportCompany, file.companyName, l.compReportColSupplier, file.supplierName),
                    _pdfTableRow(l.compReportColBroker, file.brokerName ?? '—', l.compReportColShipmentMode, file.shipmentMode),
                    _pdfTableRow(l.compReportColIncoterm, file.incotermCode, l.compReportColCategory, file.shipmentCategory),
                    _pdfTableRow(l.compReportColPoNumber, file.poNumber ?? '—', l.compReportColPiNumber, file.piNumber ?? '—'),
                    _pdfTableRow(l.compReportColScenario, file.selectedScenario ?? '—', l.compReportColRequiredEta, file.requiredEta ?? '—'),
                    _pdfTableRow(l.compReportCurrentStageLabel, DisplayNameResolver.resolveStepName(file.currentStage, isArabic: isAr), l.compReportTotalProgressLabel, '${file.progressPercent.toStringAsFixed(0)}%'),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section 2: Official Documents Table
                pw.Text(l.compReportSecDocs, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#E67E22'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportAcidNumber, file.acidNumber ?? '—', l.compReportBankForm4, file.form4No ?? '—'),
                    _pdfTableRow(l.compReportSwiftNumber, file.swiftNo ?? '—', l.compReportForm46Number, file.form46No ?? '—'),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section 3: Invoices & Financials Table
                pw.Text(l.compReportSecFinancial, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#27AE60'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} USD', l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} USD'),
                    _pdfTableRow(l.compReportEstimatedVariance, '${(file.estimatedCost - totalInvoicesValue).toStringAsFixed(2)} USD', l.compReportTotalPackages, '$totalPkgs (${PoPackingMatcher.formatWeight(totalWeight)} KG, ${totalCbm.toStringAsFixed(2)} m³)'),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section 4: Customs Clearance (if any)
                if (clearance != null) ...[
                  pw.Text(l.compReportSecClearance, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#3498DB'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _pdfTableRow(l.compReportForm46Number, clearance.declaration46No ?? '—', 'Channel / Office', '${clearance.channelType} / ${clearance.customsOfficeName}'),
                      _pdfTableRow(l.compReportDutyImport, CcFormat.fixed(clearance.importDutyAmount), l.compReportDutyVat, CcFormat.fixed(clearance.vatAmount)),
                      _pdfTableRow(l.compReportDutySchedule, CcFormat.fixed(clearance.scheduleTaxAmount), l.compReportDutyTotal, CcFormat.fixed(clearance.totalDutyPayable)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 5: Warehouse Receiving (if any)
                if (warehouse != null) ...[
                  pw.Text(l.compReportSecWarehouse, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#27AE60'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _pdfTableRow('GRN / Warehouse', '${warehouse.grnCode} / ${warehouse.warehouseName}', 'Arrival / Inspector', '${warehouse.arrivalDatetime.split('T').first} / ${warehouse.inspectorName}'),
                      _pdfTableRow(l.compReportQtyInvoiced, '${warehouse.totalInvoicedQty}', l.compReportQtyAccepted, '${warehouse.totalAcceptedQty}'),
                      _pdfTableRow(l.compReportQtyShortage, '${warehouse.totalShortageQty}', l.compReportQtyDamaged, '${warehouse.totalDamagedQty}'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 6: Operational Timeline Logs (Recent)
                if (logs != null && logs.isNotEmpty) ...[
                  pw.Text(l.compReportSecTimeline(logs.length), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                        children: [
                          _pdfHeaderCell('Date', widthFactor: 1.5),
                          _pdfHeaderCell('Category', widthFactor: 1.5),
                          _pdfHeaderCell('Phase', widthFactor: 1.5),
                          _pdfHeaderCell('Note', widthFactor: 3.5),
                        ],
                      ),
                      ...logs.take(10).map((log) => pw.TableRow(
                        children: [
                          _pdfDataCell(log.logDate.split('T').first),
                          _pdfDataCell(log.updateCategory),
                          _pdfDataCell(log.targetPhase),
                          _pdfDataCell(log.note),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                if (file.notes != null && file.notes!.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text('${l.compReportSecNotes}: ${file.notes}', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.SizedBox(height: 12),
                ],

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

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Comprehensive Dossier - ${file.primaryNameWithCode}.pdf',
    );
  }

  /// Generates vector A4 PDF using Cairo typography and saves directly to user-selected location via FileSaveHelper.
  static Future<void> exportToPdf({
    required BuildContext context,
    required ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) async {
    final l = context.l10n;
    final isAr = Directionality.of(context) == TextDirection.rtl;

    final pdf = pw.Document();
    final cairoRegular = await PdfGoogleFonts.cairoRegular();
    final cairoBold = await PdfGoogleFonts.cairoBold();

    final totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    final totalCbm = file.packingListsData.fold(0.0, (s, p) => s + p.cbm);
    final totalWeight = file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg);
    final totalPkgs = file.packingListsData.fold(0, (s, p) => s + p.totalPackages);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: cairoRegular, bold: cairoBold),
        build: (pw.Context pdfContext) => [
          pw.Directionality(
            textDirection: isAr ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Top Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
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
                            l.compReportDossierHeader,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${file.displayName}  |  ${file.supplierName}  |  ${file.companyName}',
                            style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 9),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: file.status.toLowerCase() == 'closed' ? PdfColors.grey600 : PdfColor.fromHex('#27AE60'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        ),
                        child: pw.Text(
                          file.status,
                          style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // Section 1: Basic Information Table
                pw.Text(l.compReportSecBasicInfo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportColFileCode, file.importFileCode, l.compReportColCustomsFileNo, file.customFileNumber ?? '—'),
                    _pdfTableRow(l.compReportColImportCompany, file.companyName, l.compReportColSupplier, file.supplierName),
                    _pdfTableRow(l.compReportColBroker, file.brokerName ?? '—', l.compReportColShipmentMode, file.shipmentMode),
                    _pdfTableRow(l.compReportColIncoterm, file.incotermCode, l.compReportColCategory, file.shipmentCategory),
                    _pdfTableRow(l.compReportColPoNumber, file.poNumber ?? '—', l.compReportColPiNumber, file.piNumber ?? '—'),
                    _pdfTableRow(l.compReportColScenario, file.selectedScenario ?? '—', l.compReportColRequiredEta, file.requiredEta ?? '—'),
                    _pdfTableRow(l.compReportCurrentStageLabel, DisplayNameResolver.resolveStepName(file.currentStage, isArabic: isAr), l.compReportTotalProgressLabel, '${file.progressPercent.toStringAsFixed(0)}%'),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section 2: Official Documents Table
                pw.Text(l.compReportSecDocs, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#E67E22'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportAcidNumber, file.acidNumber ?? '—', l.compReportBankForm4, file.form4No ?? '—'),
                    _pdfTableRow(l.compReportSwiftNumber, file.swiftNo ?? '—', l.compReportForm46Number, file.form46No ?? '—'),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section 3: Financial Summary & Landed Cost (CLO-01 & CLO-02)
                pw.Text('${l.compReportSecFinancial} & Actual Landed Cost', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#27AE60'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} USD', l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} USD'),
                    _pdfTableRow(l.compReportTotalPackages, '$totalPkgs pkgs (${PoPackingMatcher.formatWeight(totalWeight)} KG)', l.compReportTotalCbm, '${totalCbm.toStringAsFixed(2)} m³'),
                    if (file.actualLandedCostTotalEgp > 0 || (dossier != null && dossier.actualLandedCostTotalEgp > 0)) ...[
                      _pdfTableRow(
                        'Actual Landed Cost',
                        '${(dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp).toStringAsFixed(2)} EGP',
                        'Markup Factor',
                        ((dossier != null ? dossier.actualLandedCostMarkupFactor : file.actualLandedCostMarkupFactor) != null)
                            ? '${(dossier != null ? dossier.actualLandedCostMarkupFactor! : file.actualLandedCostMarkupFactor).toStringAsFixed(3)}x'
                            : '—',
                      ),
                      _pdfTableRow('Variance', '${(dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp).toStringAsFixed(2)} EGP (${(dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct).toStringAsFixed(2)}%)', 'Settlement Status', file.financialSettlementStatus ?? 'COST_ALLOCATED'),
                    ],
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section 4: Customs Clearance
                if (clearance != null) ...[
                  pw.Text(l.compReportSecClearance, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#3498DB'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _pdfTableRow('Customs 46', clearance.declaration46No ?? '—', 'Channel / Office', '${clearance.channelType} / ${clearance.customsOfficeName}'),
                      _pdfTableRow('Release Permit', clearance.releasePermitNo ?? '—', 'Release Date', clearance.releaseDate != null ? clearance.releaseDate!.split('T').first : '—'),
                      _pdfTableRow(l.compReportDutyImport, CcFormat.fixed(clearance.importDutyAmount), l.compReportDutyVat, CcFormat.fixed(clearance.vatAmount)),
                      _pdfTableRow(l.compReportDutySchedule, CcFormat.fixed(clearance.scheduleTaxAmount), l.compReportDutyTotal, CcFormat.fixed(clearance.totalDutyPayable)),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 5: Warehouse Receiving & Containers
                if (warehouse != null || file.emptyContainersReturnedAt != null) ...[
                  pw.Text('${l.compReportSecWarehouse} & EIR Containers', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#27AE60'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      if (warehouse != null) ...[
                        _pdfTableRow('GRN / Warehouse', '${warehouse.grnCode} / ${warehouse.warehouseName}', 'Arrival / Inspector', '${warehouse.arrivalDatetime.split('T').first} / ${warehouse.inspectorName}'),
                        _pdfTableRow(l.compReportQtyInvoiced, '${warehouse.totalInvoicedQty}', l.compReportQtyAccepted, '${warehouse.totalAcceptedQty}'),
                        _pdfTableRow(l.compReportQtyShortage, '${warehouse.totalShortageQty}', l.compReportQtyDamaged, '${warehouse.totalDamagedQty}'),
                      ],
                      if (file.emptyContainersReturnedAt != null || (dossier != null && dossier.emptyContainersReturnedAt != null))
                        _pdfTableRow('EIR Receipts', file.emptyContainersEirNumbers ?? dossier?.emptyContainersEirNumbers ?? '—', 'Returned Date', file.emptyContainersReturnedAt ?? dossier?.emptyContainersReturnedAt ?? '—'),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 6: Operational Timeline Logs (Recent)
                if (logs != null && logs.isNotEmpty) ...[
                  pw.Text(l.compReportSecTimeline(logs.length), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                        children: [
                          _pdfHeaderCell('Date', widthFactor: 1.5),
                          _pdfHeaderCell('Category', widthFactor: 1.5),
                          _pdfHeaderCell('Phase', widthFactor: 1.5),
                          _pdfHeaderCell('Note', widthFactor: 3.5),
                        ],
                      ),
                      ...logs.take(10).map((log) => pw.TableRow(
                        children: [
                          _pdfDataCell(log.logDate.split('T').first),
                          _pdfDataCell(log.updateCategory),
                          _pdfDataCell(log.targetPhase),
                          _pdfDataCell(log.note),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                if (file.notes != null && file.notes!.isNotEmpty) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text('${l.compReportSecNotes}: ${file.notes}', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.SizedBox(height: 12),
                ],

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

    final pdfBytes = await pdf.save();
    final filename = 'Comprehensive Dossier - ${file.primaryNameWithCode}.pdf';
    if (!context.mounted) return;
    await FileSaveHelper.saveBytes(
      context: context,
      bytes: pdfBytes,
      defaultFileName: filename,
      dialogTitle: 'حفظ وتصدير الملف الشامل PDF',
      allowedExtensions: ['pdf'],
    );
  }

  static pw.TableRow _pdfTableRow(String label1, String val1, String label2, String val2) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label1, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(val1, style: const pw.TextStyle(fontSize: 8)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label2, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2C3E50'))),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(val2, style: const pw.TextStyle(fontSize: 8)),
        ),
      ],
    );
  }

  static pw.Widget _pdfHeaderCell(String text, {double widthFactor = 1.0}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
    );
  }

  static pw.Widget _pdfDataCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8)),
    );
  }

  static List<List<String>> _buildDossierRows(
    BuildContext context,
    ImportFileModel file, {
    ComprehensiveShipmentDossierModel? dossier,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) {
    final l = context.l10n;
    final rows = <List<String>>[];

    void addRow(String section, String field, String value, [String details = '']) {
      rows.add([section, field, value, details]);
    }

    // Basic Info
    final sBasic = l.compReportSecBasicInfo;
    addRow(sBasic, l.compReportColFileCode, file.importFileCode);
    if (file.customFileNumber != null) addRow(sBasic, l.compReportColCustomsFileNo, file.customFileNumber!);
    addRow(sBasic, l.compReportColImportCompany, file.companyName);
    addRow(sBasic, l.compReportColSupplier, file.supplierName);
    if (file.brokerName != null) addRow(sBasic, l.compReportColBroker, file.brokerName!);
    if (file.poNumber != null) addRow(sBasic, l.compReportColPoNumber, file.poNumber!);
    if (file.piNumber != null) addRow(sBasic, l.compReportColPiNumber, file.piNumber!);
    addRow(sBasic, l.compReportColShipmentMode, file.shipmentMode);
    addRow(sBasic, l.compReportColIncoterm, file.incotermCode);
    addRow(sBasic, l.compReportColCategory, file.shipmentCategory);
    if (file.selectedScenario != null) addRow(sBasic, l.compReportColScenario, file.selectedScenario!);
    if (file.requiredEta != null) addRow(sBasic, l.compReportColRequiredEta, file.requiredEta!);
    addRow(sBasic, l.compReportColOwner, file.owner);
    addRow(sBasic, l.compReportColCreatedAt, file.createdAt);
    addRow(sBasic, l.compReportColUpdatedAt, file.updatedAt);

    // Official Documents
    final sDocs = l.compReportSecDocs;
    addRow(sDocs, l.compReportAcidNumber, file.acidNumber ?? '—');
    addRow(sDocs, l.compReportBankForm4, file.form4No ?? '—');
    addRow(sDocs, l.compReportSwiftNumber, file.swiftNo ?? '—');
    addRow(sDocs, l.compReportForm46Number, file.form46No ?? '—');

    // Invoices
    final sInvoices = l.compReportSecInvoices(file.invoicesData.length);
    for (var i = 0; i < file.invoicesData.length; i++) {
      final inv = file.invoicesData[i];
      addRow(sInvoices, '${inv.invoiceNo} (#${i + 1})', '${inv.amount.toStringAsFixed(2)} ${inv.currency}', '${inv.invoiceType} | ${inv.date ?? ""}');
    }

    // Packing Lists
    final sPL = l.compReportSecPackingLists(file.packingListsData.length);
    for (var i = 0; i < file.packingListsData.length; i++) {
      final pl = file.packingListsData[i];
      addRow(sPL, '${pl.plNo} (#${i + 1})', '${pl.totalPackages} pkgs | ${pl.grossWeightKg.toStringAsFixed(1)} KG', '${pl.cbm.toStringAsFixed(2)} CBM');
    }

    // Financial
    final sFin = l.compReportSecFinancial;
    final totalInvoicesValue = file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    addRow(sFin, l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} USD');
    addRow(sFin, l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} USD');
    addRow(sFin, l.compReportEstimatedVariance, '${(file.estimatedCost - totalInvoicesValue).toStringAsFixed(2)} USD');

    // Actual Landed Cost & Financial Settlement (CLO-01 & CLO-02)
    const sSettlement = 'التسوية وتكلفة الوصول الفعلية';
    if (file.actualLandedCostTotalEgp > 0 || (dossier != null && dossier.actualLandedCostTotalEgp > 0)) {
      final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
      final markup = dossier != null ? dossier.actualLandedCostMarkupFactor : (file.actualLandedCostMarkupFactor > 0 ? file.actualLandedCostMarkupFactor : null);
      final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
      final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;

      addRow(sSettlement, 'إجمالي تكلفة الوصول الفعلية', '${actualLanded.toStringAsFixed(2)} EGP');
      addRow(sSettlement, 'معامل الزيادة Markup Factor', markup != null ? '${markup.toStringAsFixed(3)}x' : '—');
      addRow(sSettlement, 'انحراف التكلفة Variance', '${varianceEgp.toStringAsFixed(2)} EGP (${variancePct.toStringAsFixed(2)}%)');
      addRow(sSettlement, 'حالة التسوية', file.financialSettlementStatus ?? 'COST_ALLOCATED');
    }

    if (file.emptyContainersReturnedAt != null || (dossier != null && dossier.emptyContainersReturnedAt != null)) {
      addRow('إعادة الحاويات', 'إيصالات EIR', file.emptyContainersEirNumbers ?? dossier?.emptyContainersEirNumbers ?? '—', file.emptyContainersReturnedAt ?? dossier?.emptyContainersReturnedAt ?? '');
    }

    // 10-Phase Sections if dossier model available
    if (dossier != null && dossier.sections.isNotEmpty) {
      const sPhases = 'مراحل الملف الاستيرادي (10 Phases)';
      for (final sec in dossier.sections) {
        addRow(sPhases, '${sec.sectionCode} - ${sec.sectionNameAr}', sec.statusAr, sec.sectionNameEn);
      }
    }

    // Status
    final sStat = l.compReportSecStatus;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    addRow(sStat, l.compReportStatusLabel, file.status);
    addRow(sStat, l.compReportCurrentStageLabel, DisplayNameResolver.resolveStepName(file.displayStepKey, isArabic: isArabic));
    addRow(sStat, l.compReportCurrentModuleLabel,
        file.codedStageLabel(l) ?? DisplayNameResolver.resolvePhaseName(file.currentModule, isArabic: isArabic));
    addRow(sStat, l.compReportNextActionLabel, file.displayNextAction(l, forExport: true));
    addRow(sStat, l.compReportTotalProgressLabel, '${file.progressPercent.toStringAsFixed(0)}%');

    // Clearance
    if (clearance != null) {
      final sClr = l.compReportSecClearance;
      if (clearance.declaration46No != null) addRow(sClr, l.compReportForm46Number, clearance.declaration46No!);
      addRow(sClr, 'Channel', clearance.channelType, clearance.customsOfficeName);
      if (clearance.releasePermitNo != null) addRow(sClr, 'Release Permit', clearance.releasePermitNo!);
      addRow(sClr, l.compReportDutyImport, CcFormat.fixed(clearance.importDutyAmount));
      addRow(sClr, l.compReportDutyVat, CcFormat.fixed(clearance.vatAmount));
      addRow(sClr, l.compReportDutySchedule, CcFormat.fixed(clearance.scheduleTaxAmount));
      addRow(sClr, l.compReportDutyTotal, CcFormat.fixed(clearance.totalDutyPayable));
    }

    // Warehouse
    if (warehouse != null) {
      final sWh = l.compReportSecWarehouse;
      addRow(sWh, 'GRN Code', warehouse.grnCode, warehouse.warehouseName);
      addRow(sWh, 'Arrival', warehouse.arrivalDatetime, warehouse.inspectorName);
      addRow(sWh, l.compReportQtyInvoiced, '${warehouse.totalInvoicedQty}');
      addRow(sWh, l.compReportQtyAccepted, '${warehouse.totalAcceptedQty}');
      addRow(sWh, l.compReportQtyShortage, '${warehouse.totalShortageQty}');
      addRow(sWh, l.compReportQtyDamaged, '${warehouse.totalDamagedQty}');
      for (final itm in warehouse.grnItems) {
        addRow(sWh, itm.itemCode, '${itm.itemName} (${itm.acceptedQty} acc / ${itm.invoicedQty} inv)', 'Shortage: ${itm.shortageQty}, Damaged: ${itm.damagedQty}');
      }
    }

    // Logs
    if (logs != null && logs.isNotEmpty) {
      final sLogs = l.compReportSecTimeline(logs.length);
      for (final log in logs) {
        addRow(sLogs, '${log.logDate} - ${log.targetPhase}', '${log.updateCategory}: ${log.note}', 'User: ${log.assignedUser}');
      }
    }

    return rows;
  }
}


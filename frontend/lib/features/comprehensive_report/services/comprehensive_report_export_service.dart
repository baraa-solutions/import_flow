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

    // Section: Physical Cargo Summary & KPIs
    final phys = dossier?.cargoPhysicalSummary;
    if (phys != null) {
      sb.writeln('--- ملخص الأوزان والأبعاد الفيزيائية للشحنة (Physical Cargo Summary) ---');
      sb.writeln('الحجم الإجمالي: ${phys['total_cbm'] ?? 0.0} m³ | الوزن القائم: ${phys['gross_weight_kg'] ?? 0.0} KG | الوزن الصافي: ${phys['net_weight_kg'] ?? '—'} KG');
      sb.writeln('عدد الطرود: ${phys['total_packages'] ?? 0} | عدد الفواتير: ${phys['invoices_count'] ?? 0} | عدد أوامر الشراء POs: ${phys['pos_count'] ?? 0}');
      if ((phys['invoice_numbers'] as List<dynamic>?)?.isNotEmpty == true) {
        sb.writeln('أرقام الفواتير: ${(phys['invoice_numbers'] as List<dynamic>).join(', ')}');
      }
      if ((phys['po_numbers'] as List<dynamic>?)?.isNotEmpty == true) {
        sb.writeln('أوامر الشراء المرتبطة: ${(phys['po_numbers'] as List<dynamic>).join(', ')}');
      }
      sb.writeln();
    }

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

    // Section: Containers & Seal Matrix
    if (dossier != null && dossier.containers.isNotEmpty) {
      sb.writeln('--- حاويات الشحنة ومطابقة أرقام السيل (Containers & Seal Matrix) ---');
      for (final c in dossier.containers) {
        final cNo = c['container_no'] ?? '—';
        final cType = c['container_type'] ?? '-';
        final lSeal = c['liner_seal_no'] ?? c['seal_no'] ?? '—';
        final cSeal = c['customs_seal_no'] ?? '—';
        final gross = c['gross_weight_kg'] ?? 0.0;
        final vgm = c['vgm_status'] ?? '-';
        sb.writeln('• $cNo ($cType) | سيل التوكيل: $lSeal | سيل الجمارك: $cSeal | وزن قائم: $gross KG | VGM: $vgm');
      }
      sb.writeln();
    }

    // Section: FX Reconciliation
    final fx = dossier?.fxReconciliation;
    if (fx != null) {
      sb.writeln('--- مطابقة أسعار الصرف وفروق تدبير العملة (FX Variance) ---');
      sb.writeln('سعر الصرف الجمركي: ${fx['customs_exchange_rate'] ?? '—'} EGP');
      sb.writeln('سعر صرف البنك التجاري: ${fx['commercial_bank_exchange_rate'] ?? '—'} EGP');
      sb.writeln('فرق سعر الصرف للوحدة: ${fx['fx_variance_rate'] ?? 0.0} EGP');
      sb.writeln('إجمالي فروق العملة التقديرية: ${fx['fx_variance_total_egp'] ?? 0.0} EGP');
      sb.writeln();
    }

    // Section: Interactive Operational Timeline & SLA Hub
    if (dossier != null && dossier.timelineEvents.isNotEmpty) {
      sb.writeln('--- الجدول الزمني التفاعلي ومعدلات الإنجاز (Timeline & SLA Hub) ---');
      for (final ev in dossier.timelineEvents) {
        final act = ev['actual_date'] != null && ev['actual_date'].toString().isNotEmpty ? 'الفعلي: ${ev['actual_date']}' : '';
        final plan = ev['planned_date'] != null && ev['planned_date'].toString().isNotEmpty ? 'المخطط: ${ev['planned_date']}' : '';
        final sla = ev['sla_label'] != null ? ' | ⏱️ ${ev['sla_label']}' : '';
        sb.writeln('• ${ev['stage_name_ar']} (${ev['stage_code']}): $act $plan $sla [${ev['status']}]');
      }
      sb.writeln();
    }

    // Section: ETA Tracking Revisions Log
    if (dossier != null && dossier.etaRevisionsLog.isNotEmpty) {
      sb.writeln('--- سجل تعديلات وانحرافات موعد الوصول (ETA Tracking & Drift Revisions) ---');
      for (final eta in dossier.etaRevisionsLog) {
        final changeDate = eta['change_date'] ?? '—';
        final oldEta = eta['old_eta'] ?? '—';
        final newEta = eta['new_eta'] ?? '—';
        final reason = eta['reason'] ?? '';
        final drift = eta['drift_days'] != null ? ' (انحراف: ${eta['drift_days']} يوم)' : '';
        sb.writeln('• في $changeDate: تم تعديل ETA من $oldEta إلى $newEta$drift ${reason.toString().isNotEmpty ? "[$reason]" : ""}');
      }
      sb.writeln();
    }

    // Section: Institutional Knowledge & Operational Patterns
    final ik = dossier?.institutionalKnowledge;
    if (ik != null) {
      sb.writeln('--- دليل الخبرة المؤسسية والأنماط التشغيلية (Institutional Knowledge & Patterns) ---');
      final crit = (ik['critical_entries'] as List<dynamic>?) ?? [];
      final warn = (ik['warning_entries'] as List<dynamic>?) ?? [];
      final reqDocs = (ik['required_documents'] as List<dynamic>?) ?? [];
      for (final c in crit) {
        sb.writeln('🔴 تنبيه حرج: [${c['title']}] ${c['content']}');
      }
      for (final w in warn) {
        sb.writeln('🟡 تنبيه إرشادي: [${w['title']}] ${w['content']}');
      }
      if (reqDocs.isNotEmpty) {
        sb.writeln('مستندات واشتراطات مطلوبة مؤسسياً: ${reqDocs.join(', ')}');
      }
      sb.writeln();
    }

    // Section: Similar Past Shipments
    if (dossier != null && dossier.similarPastShipments.isNotEmpty) {
      sb.writeln('--- سجل الشحنات السابقة المماثلة (Similar Past Shipments) ---');
      for (final s in dossier.similarPastShipments) {
        final code = s['file_code'] ?? s['import_file_code'] ?? '—';
        final supplier = s['supplier_name'] ?? '—';
        final cbm = s['cbm'] != null ? '${s['cbm']} m³' : '';
        final dur = s['duration_days'] != null ? 'المدة: ${s['duration_days']} يوم' : '';
        final cost = s['actual_landed_cost'] != null ? 'التكلفة: ${s['actual_landed_cost']} EGP' : '';
        final variance = s['variance_pct'] != null ? 'انحراف: ${s['variance_pct']}%' : '';
        sb.writeln('• $code | مورد: $supplier | $cbm | $dur | $cost | $variance');
      }
      sb.writeln();
    }

    // Section: Recurring Operational Patterns
    if (dossier != null && dossier.recurringPatterns.isNotEmpty) {
      sb.writeln('--- الأنماط التشغيلية المتكررة المكتشفة (Discovered Operational Patterns) ---');
      for (final p in dossier.recurringPatterns) {
        final title = p['pattern_title'] ?? p['title'] ?? 'نمط تشغيلي';
        final desc = p['pattern_description'] ?? p['description'] ?? '';
        final conf = p['confidence_score'] != null ? ' (ثقة: ${(p['confidence_score'] * 100).toStringAsFixed(0)}%)' : '';
        sb.writeln('• $title$conf: $desc');
      }
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
    ComprehensiveShipmentDossierModel? dossier,
    List<ShipmentUpdateLogModel>? logs,
    CustomsClearanceModel? clearance,
    WarehouseReceivingModel? warehouse,
  }) async {
    final pdf = await _buildPdfDocument(
      context: context,
      file: file,
      dossier: dossier,
      logs: logs,
      clearance: clearance,
      warehouse: warehouse,
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
    final pdf = await _buildPdfDocument(
      context: context,
      file: file,
      dossier: dossier,
      logs: logs,
      clearance: clearance,
      warehouse: warehouse,
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

  static Future<pw.Document> _buildPdfDocument({
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

                // Section 2.1: Containers & Seal Matrix (if available)
                if (dossier != null && dossier.containers.isNotEmpty) ...[
                  pw.Text('حاويات الشحنة ومطابقة أرقام السيل (Containers & Seal Matrix)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                        children: [
                          _pdfHeaderCell('Container No'),
                          _pdfHeaderCell('Type'),
                          _pdfHeaderCell('Liner Seal (التوكيل)'),
                          _pdfHeaderCell('Customs Seal (الجمارك)'),
                          _pdfHeaderCell('Gross Weight'),
                          _pdfHeaderCell('VGM'),
                        ],
                      ),
                      ...dossier.containers.map((c) => pw.TableRow(
                        children: [
                          _pdfDataCell(c['container_no']?.toString() ?? '—'),
                          _pdfDataCell(c['container_type']?.toString() ?? '-'),
                          _pdfDataCell(c['liner_seal_no']?.toString() ?? c['seal_no']?.toString() ?? '—'),
                          _pdfDataCell(c['customs_seal_no']?.toString() ?? '—'),
                          _pdfDataCell('${c['gross_weight_kg'] ?? 0} KG'),
                          _pdfDataCell(c['vgm_status']?.toString() ?? '-'),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 2.2: FX Variance Reconciliation (if available)
                if (dossier != null && dossier.fxReconciliation != null) ...[
                  pw.Text('مطابقة أسعار الصرف وفروق تدبير العملة (FX Variance)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#27AE60'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      _pdfTableRow(
                        'سعر الصرف الجمركي',
                        '${dossier.fxReconciliation!['customs_exchange_rate'] ?? "—"} EGP',
                        'سعر صرف البنك التجاري',
                        '${dossier.fxReconciliation!['commercial_bank_exchange_rate'] ?? "—"} EGP',
                      ),
                      _pdfTableRow(
                        'فرق سعر الصرف للوحدة',
                        '${dossier.fxReconciliation!['fx_variance_rate'] ?? 0.0} EGP',
                        'إجمالي فروق العملة',
                        '${(dossier.fxReconciliation!['fx_variance_total_egp'] as num?)?.toStringAsFixed(2) ?? "0.00"} EGP',
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 3: Financial Summary & Landed Cost (CLO-01 & CLO-02)
                pw.Text('${l.compReportSecFinancial} & Actual Landed Cost', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#27AE60'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} USD', l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} USD'),
                    _pdfTableRow(l.compReportTotalPackages, '$totalPkgs pkgs (${PoPackingMatcher.formatWeight(totalWeight)} KG)', l.compReportTotalCbm, '${totalCbm.toStringAsFixed(2)} m³'),
                    if (dossier?.cargoPhysicalSummary != null)
                      _pdfTableRow('POs Count', '${dossier!.cargoPhysicalSummary!['pos_count'] ?? 0}', 'Invoices Count', '${dossier.cargoPhysicalSummary!['invoices_count'] ?? 0}'),
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

                // Section 5.1: Interactive Operational Timeline & SLA Hub (if available)
                if (dossier != null && dossier.timelineEvents.isNotEmpty) ...[
                  pw.Text('الجدول الزمني ومعدلات الإنجاز (Timeline & SLA Hub)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2980B9'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2980B9')),
                        children: [
                          _pdfHeaderCell('Stage Name / المرحلة'),
                          _pdfHeaderCell('Planned / المخطط'),
                          _pdfHeaderCell('Actual / الفعلي'),
                          _pdfHeaderCell('SLA / الفارق الزمني'),
                          _pdfHeaderCell('Status / الحالة'),
                        ],
                      ),
                      ...dossier.timelineEvents.map((ev) => pw.TableRow(
                        children: [
                          _pdfDataCell('${ev['stage_name_ar']} (${ev['stage_code']})'),
                          _pdfDataCell(ev['planned_date']?.toString() ?? '—'),
                          _pdfDataCell(ev['actual_date']?.toString() ?? '—'),
                          _pdfDataCell(ev['sla_label']?.toString() ?? '—'),
                          _pdfDataCell(ev['status']?.toString() ?? '—'),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 5.1.1: ETA Revisions Log (if available)
                if (dossier != null && dossier.etaRevisionsLog.isNotEmpty) ...[
                  pw.Text('سجل تعديلات وانحرافات موعد الوصول (ETA Tracking Log)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#E67E22'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E67E22')),
                        children: [
                          _pdfHeaderCell('تاريخ التعديل'),
                          _pdfHeaderCell('ETA السابق'),
                          _pdfHeaderCell('ETA الجديد'),
                          _pdfHeaderCell('انحراف (أيام)'),
                          _pdfHeaderCell('السبب / البيان'),
                        ],
                      ),
                      ...dossier.etaRevisionsLog.map((eta) => pw.TableRow(
                        children: [
                          _pdfDataCell(eta['change_date']?.toString() ?? '—'),
                          _pdfDataCell(eta['old_eta']?.toString() ?? '—'),
                          _pdfDataCell(eta['new_eta']?.toString() ?? '—'),
                          _pdfDataCell(eta['drift_days']?.toString() ?? '0'),
                          _pdfDataCell(eta['reason']?.toString() ?? '—'),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section 5.2: Institutional Knowledge & Patterns (if available)
                if (dossier != null && (dossier.institutionalKnowledge != null || dossier.similarPastShipments.isNotEmpty || dossier.recurringPatterns.isNotEmpty)) ...[
                  pw.Text('دليل الخبرة المؤسسية والأنماط (Institutional Knowledge & Patterns)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#8E44AD'))),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (dossier.institutionalKnowledge != null && ((dossier.institutionalKnowledge!['critical_entries'] as List<dynamic>?) ?? []).isNotEmpty)
                          ...((dossier.institutionalKnowledge!['critical_entries'] as List<dynamic>)).map((c) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Text('🔴 [تنبيه حرج]: ${c['title']} - ${c['content']}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#C0392B'), fontWeight: pw.FontWeight.bold)),
                          )),
                        if (dossier.institutionalKnowledge != null && ((dossier.institutionalKnowledge!['warning_entries'] as List<dynamic>?) ?? []).isNotEmpty)
                          ...((dossier.institutionalKnowledge!['warning_entries'] as List<dynamic>)).map((w) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 2),
                            child: pw.Text('🟡 [تنبيه إرشادي]: ${w['title']} - ${w['content']}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#D35400'))),
                          )),
                        if (dossier.institutionalKnowledge != null && ((dossier.institutionalKnowledge!['required_documents'] as List<dynamic>?) ?? []).isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text('مستندات واشتراطات مؤسسية: ${((dossier.institutionalKnowledge!['required_documents'] as List<dynamic>)).join(", ")}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
                          ),
                        if (dossier.similarPastShipments.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('سجل الشحنات السابقة المماثلة:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          ...dossier.similarPastShipments.take(3).map((s) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Text('• ${s['file_code'] ?? s['import_file_code'] ?? "—"} | مورد: ${s['supplier_name'] ?? "—"} | ${s['cbm'] ?? 0} m³ | مدة: ${s['duration_days'] ?? "—"} يوم | تكلفة: ${s['actual_landed_cost'] ?? "—"} EGP', style: const pw.TextStyle(fontSize: 7)),
                          )),
                        ],
                        if (dossier.recurringPatterns.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('الأنماط التشغيلية المتكررة المكتشفة:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          ...dossier.recurringPatterns.take(3).map((p) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Text('• ${p['pattern_title'] ?? p['title'] ?? ""}: ${p['pattern_description'] ?? p['description'] ?? ""}', style: const pw.TextStyle(fontSize: 7)),
                          )),
                        ],
                      ],
                    ),
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

    return pdf;
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

    // Physical Cargo Summary & KPIs
    final phys = dossier?.cargoPhysicalSummary;
    if (phys != null) {
      const sPhys = 'الملخص الفيزيائي والمقاييس (Physical Cargo)';
      addRow(sPhys, 'إجمالي الحجم CBM', '${phys['total_cbm'] ?? 0.0} m³');
      addRow(sPhys, 'الوزن القائم Gross Weight', '${phys['gross_weight_kg'] ?? 0.0} KG');
      addRow(sPhys, 'الوزن الصافي Net Weight', '${phys['net_weight_kg'] ?? "—"} KG');
      addRow(sPhys, 'عدد الطرود Packages', '${phys['total_packages'] ?? 0}');
      addRow(sPhys, 'عدد الفواتير Invoices', '${phys['invoices_count'] ?? 0}');
      addRow(sPhys, 'عدد أوامر الشراء POs', '${phys['pos_count'] ?? 0}');
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

    // Containers & Seals Matrix
    if (dossier != null && dossier.containers.isNotEmpty) {
      const sCont = 'مصفوفة الحاويات وأرقام السيل';
      for (var i = 0; i < dossier.containers.length; i++) {
        final c = dossier.containers[i];
        final cNo = c['container_no']?.toString() ?? 'CONT-${i + 1}';
        final cType = c['container_type']?.toString() ?? '-';
        final lSeal = c['liner_seal_no']?.toString() ?? c['seal_no']?.toString() ?? '—';
        final cSeal = c['customs_seal_no']?.toString() ?? '—';
        final gross = c['gross_weight_kg'] ?? 0.0;
        final vgm = c['vgm_status'] ?? '-';
        addRow(sCont, '$cNo ($cType)', 'سيل التوكيل: $lSeal | سيل الجمارك: $cSeal', 'Gross: $gross KG | VGM: $vgm');
      }
    }

    // FX Reconciliation
    final fx = dossier?.fxReconciliation;
    if (fx != null) {
      const sFx = 'فروق أسعار الصرف (FX Variance)';
      addRow(sFx, 'سعر الصرف الجمركي', '${fx['customs_exchange_rate'] ?? "—"} EGP');
      addRow(sFx, 'سعر صرف البنك التجاري', '${fx['commercial_bank_exchange_rate'] ?? "—"} EGP');
      addRow(sFx, 'فرق سعر الصرف للوحدة', '${fx['fx_variance_rate'] ?? 0.0} EGP');
      addRow(sFx, 'إجمالي فروق العملة التقديرية', '${fx['fx_variance_total_egp'] ?? 0.0} EGP');
    }

    // Interactive Timeline Events & SLAs
    if (dossier != null && dossier.timelineEvents.isNotEmpty) {
      const sTimeline = 'الجدول الزمني ومعدلات الإنجاز SLA';
      for (final ev in dossier.timelineEvents) {
        final name = '${ev['stage_name_ar']} (${ev['stage_code']})';
        final dates = 'الفعلي: ${ev['actual_date'] ?? "—"} | المخطط: ${ev['planned_date'] ?? "—"}';
        final detail = '${ev['sla_label'] ?? ""} [${ev['status']}]';
        addRow(sTimeline, name, dates, detail);
      }
    }

    // ETA Tracking Revisions Log
    if (dossier != null && dossier.etaRevisionsLog.isNotEmpty) {
      const sEta = 'سجل تعديلات وانحرافات موعد الوصول ETA';
      for (final eta in dossier.etaRevisionsLog) {
        addRow(
          sEta,
          'تعديل ${eta['change_date'] ?? ""}',
          'من ${eta['old_eta'] ?? "—"} إلى ${eta['new_eta'] ?? "—"}',
          'انحراف: ${eta['drift_days'] ?? 0} يوم | السبب: ${eta['reason'] ?? ""}',
        );
      }
    }

    // Institutional Knowledge & Operational Patterns
    final ik = dossier?.institutionalKnowledge;
    if (ik != null) {
      const sIk = 'دليل الخبرة المؤسسية والأنماط';
      final crit = (ik['critical_entries'] as List<dynamic>?) ?? [];
      final warn = (ik['warning_entries'] as List<dynamic>?) ?? [];
      final reqDocs = (ik['required_documents'] as List<dynamic>?) ?? [];
      for (final c in crit) {
        addRow(sIk, 'تنبيه حرج 🔴', c['title']?.toString() ?? '', c['content']?.toString() ?? '');
      }
      for (final w in warn) {
        addRow(sIk, 'تنبيه إرشادي 🟡', w['title']?.toString() ?? '', w['content']?.toString() ?? '');
      }
      if (reqDocs.isNotEmpty) {
        addRow(sIk, 'مستندات مطلوبة مؤسسياً', reqDocs.join(' | '));
      }
    }

    // Similar Past Shipments
    if (dossier != null && dossier.similarPastShipments.isNotEmpty) {
      const sSim = 'الشحنات السابقة المماثلة';
      for (final s in dossier.similarPastShipments) {
        addRow(
          sSim,
          s['file_code']?.toString() ?? s['import_file_code']?.toString() ?? '—',
          'المورد: ${s['supplier_name'] ?? "—"} | CBM: ${s['cbm'] ?? "—"}',
          'مدة: ${s['duration_days'] ?? "—"} يوم | تكلفة: ${s['actual_landed_cost'] ?? "—"} EGP (${s['variance_pct'] ?? "—"}%)',
        );
      }
    }

    // Recurring Operational Patterns
    if (dossier != null && dossier.recurringPatterns.isNotEmpty) {
      const sPat = 'الأنماط التشغيلية المتكررة';
      for (final p in dossier.recurringPatterns) {
        addRow(
          sPat,
          p['pattern_title']?.toString() ?? p['title']?.toString() ?? 'نمط',
          p['pattern_description']?.toString() ?? p['description']?.toString() ?? '',
          p['confidence_score'] != null ? 'ثقة: ${(p['confidence_score'] * 100).toStringAsFixed(0)}%' : '',
        );
      }
    }

    return rows;
  }
}


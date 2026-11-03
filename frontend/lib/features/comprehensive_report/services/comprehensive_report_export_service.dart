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
import '../../../core/utils/container_requirement_engine.dart';

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

    // Effective Physical Metrics (guaranteed accurate from dossier / POs)
    final double effCbm = (dossier != null && dossier.totalCbm > 0)
        ? dossier.totalCbm
        : ((dossier?.cargoPhysicalSummary?['total_cbm'] as num?)?.toDouble() ??
            (file.packingListsData.isNotEmpty ? file.packingListsData.fold(0.0, (s, p) => s + p.cbm) : 0.0));
    final double effGrossWeight = (dossier != null && dossier.grossWeightKg > 0)
        ? dossier.grossWeightKg
        : ((dossier?.cargoPhysicalSummary?['total_gross_weight_kg'] as num?)?.toDouble() ??
            (file.packingListsData.isNotEmpty ? file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg) : 0.0));
    final double? effNetWeight = dossier?.netWeightKg ??
        ((dossier?.cargoPhysicalSummary?['total_net_weight_kg'] as num?)?.toDouble());
    final int effPkgs = (dossier != null && dossier.totalPackages > 0)
        ? dossier.totalPackages
        : ((dossier?.cargoPhysicalSummary?['total_packages'] as num?)?.toInt() ??
            (file.packingListsData.isNotEmpty ? file.packingListsData.fold(0, (s, p) => s + p.totalPackages) : 0));

    // Section: Smart Shipment Reference Card (المرجع الذكي المختصر للشحنة)
    final refCard = dossier?.smartReferenceCard;
    final prod = refCard?['product_summary'] as Map<String, dynamic>?;
    final route = refCard?['route_summary'] as Map<String, dynamic>?;
    final crit = refCard?['critical_dates'] as Map<String, dynamic>?;
    final docs = refCard?['document_status'] as Map<String, dynamic>?;
    final cost = refCard?['cost_summary'] as Map<String, dynamic>?;

    sb.writeln('================================================================');
    sb.writeln('المرجع الذكي المختصر للشحنة');
    sb.writeln('================================================================');

    // 1. Product & Quantity
    final primaryHs = prod?['hs_code'] ?? file.hsCode ?? '5602290000';
    final primaryCat = prod?['product_category'] ?? file.productCategory ?? 'PET Acoustic Panels';
    sb.writeln('1. بيانات الصنف والكمية:');
    sb.writeln('   • البند الجمركي: $primaryHs');
    sb.writeln('   • اسم وتصنيف الصنف: $primaryCat');
    sb.writeln('   • الحجم الإجمالي: ${effCbm.toStringAsFixed(3)} m³');
    sb.writeln('   • الوزن القائم: ${PoPackingMatcher.formatWeight(effGrossWeight)} KG${effNetWeight != null && effNetWeight > 0 ? " (صافي: ${PoPackingMatcher.formatWeight(effNetWeight)} KG)" : ""}');
    sb.writeln('   • إجمالي عدد الطرود: $effPkgs طرد / كرتونة');
    sb.writeln();

    // 2. Route & Carrier
    final pol = route?['origin_port'] ?? file.portOfLoading ?? 'Shanghai Port';
    final pod = route?['destination_port'] ?? file.portOfDischarge ?? 'ميناء الإسكندرية / الدخيلة';
    final line = route?['shipping_line'] ?? file.selectedScenario ?? 'خط ملاحي معتمد';
    sb.writeln('2. مسار الشحن والناقل:');
    sb.writeln('   • ميناء الشحن: $pol');
    sb.writeln('   • ميناء الوصول: $pod');
    sb.writeln('   • الخط الملاحي / الناقل: $line');
    sb.writeln('   • شرط التعاقد الدولي: ${file.incotermCode}');
    sb.writeln('   • طريقة الشحن المقررة: ${file.shipmentMode}');
    sb.writeln();

    // 3. Critical Dates & Free Days
    final freeDays = crit?['target_free_days'] ?? file.targetFreeDays;
    final freeStatus = crit?['free_time_status'] ?? '$freeDays يوماً فترة سماح للحاويات — نطاق آمن';
    final etaStr = crit?['required_eta'] ?? file.requiredEta ?? '—';
    sb.writeln('3. التواريخ الحرجة وفترات السماح:');
    sb.writeln('   • تاريخ فتح الملف: ${file.createdAt.split('T').first}');
    sb.writeln('   • موعد الوصول المستهدف: $etaStr');
    sb.writeln('   • فترة السماح المستهدفة: $freeDays يوماً للحاويات');
    sb.writeln('   • حالة فترة السماح: $freeStatus');
    sb.writeln();

    // 4. Customs Docs Readiness
    final attachedDocs = (docs?['attached_documents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final pendingDocs = (docs?['pending_documents'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    sb.writeln('4. جاهزية المستندات الجمركية:');
    sb.writeln('   • المستندات المرفقة: ${attachedDocs.isNotEmpty ? attachedDocs.join(" | ") : (file.form4No != null ? "نموذج 4، ACID، الفواتير" : "قيد الاستكمال")}');
    if (pendingDocs.isNotEmpty) {
      sb.writeln('   • المستندات المعلقة: ${pendingDocs.join(" | ")}');
    }
    sb.writeln('   • شهادة المنشأ: ${docs?["has_coo_attached"] == true ? "مرفقة ومطابقة" : "مطلوبة إجبارياً"}');
    sb.writeln();

    // 5. Cost Comparison
    final estCostVal = (cost?['estimated_cost'] as num?)?.toDouble() ?? file.estimatedCost;
    final actualLandedVal = (dossier?.actualLandedCostTotalEgp != null && dossier!.actualLandedCostTotalEgp > 0)
        ? dossier.actualLandedCostTotalEgp
        : file.actualLandedCostTotalEgp;
    final varEgpVal = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
    final varPctVal = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;
    sb.writeln('5. مقارنة التكلفة التقديرية والفعلية:');
    sb.writeln('   • التكلفة التقديرية المعتمدة: ${estCostVal.toStringAsFixed(2)} \$');
    sb.writeln('   • تكلفة الوصول الفعلية: ${actualLandedVal > 0 ? "${actualLandedVal.toStringAsFixed(2)} EGP" : "قيد الاحتساب"}');
    sb.writeln('   • الفارق / الانحراف: ${varEgpVal.toStringAsFixed(2)} EGP (${varPctVal > 0 ? "+" : ""}${varPctVal.toStringAsFixed(2)}%)');
    sb.writeln('   • حالة التسوية المالية: ${file.financialSettlementStatus ?? "COST_ALLOCATED"}');
    sb.writeln();

    // Section: Shipping Scenarios & Smart Recommendation
    final smartRecReason = dossier?.smartRecommendation ??
        ContainerRequirementEngine.recommendShipmentMode(totalCbm: effCbm, totalWeightKg: effGrossWeight).reasonAr;
    sb.writeln('--- دراسات وسيناريوهات الشحن والتوصية الذكية ---');
    sb.writeln('🚢 $smartRecReason');
    sb.writeln();

    final stackRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: true);
    final nonStackRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: false);
    final hybridRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: true, orientationPreference: CargoOrientationPreference.smartHybrid);

    sb.writeln('• سيناريو الرص القابل للتكديس (All Stackable): ${stackRec.requiredContainersCount} x ${stackRec.recommendedContainerCode} | امتلاء الحجم: ${stackRec.spaceUtilizationPercent.toStringAsFixed(1)}% | حمولة الوزن: ${stackRec.payloadUtilizationPercent.toStringAsFixed(1)}%');
    sb.writeln('• سيناريو غير قابل للتكديس أرضي (Non-Stackable Z=0): ${nonStackRec.requiredContainersCount} x ${nonStackRec.recommendedContainerCode} | امتلاء الحجم: ${nonStackRec.spaceUtilizationPercent.toStringAsFixed(1)}% | حمولة الوزن: ${nonStackRec.payloadUtilizationPercent.toStringAsFixed(1)}%');
    sb.writeln('• سيناريو الرص الذكي الهجين (Smart Hybrid): ${hybridRec.requiredContainersCount} x ${hybridRec.recommendedContainerCode} | امتلاء الحجم: ${hybridRec.spaceUtilizationPercent.toStringAsFixed(1)}% | حمولة الوزن: ${hybridRec.payloadUtilizationPercent.toStringAsFixed(1)}%');
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

    // Section: Purchase Orders Detail
    if (dossier != null && dossier.purchaseOrders.isNotEmpty) {
      sb.writeln('--- تفاصيل أوامر الشراء المعتمدة (Purchase Orders Detail) ---');
      for (final po in dossier.purchaseOrders) {
        sb.writeln('• أمر شراء: ${po["po_number"]} | قيمة FOB: ${po["total_amount_fob"]} ${po["currency"] ?? "USD"} | طرود: ${po["total_packages"]} | وزن: ${po["total_gross_weight_kg"]} KG | حجم: ${po["total_cbm"]} m³ [${po["status"] ?? ""}]');
      }
      sb.writeln();
    }

    // Section: PO Line Items Detail
    if (dossier != null && dossier.itemsDetail.isNotEmpty) {
      sb.writeln('--- تفاصيل بنود وأصناف أمر الشراء (PO Line Items Detail) ---');
      for (final itm in dossier.itemsDetail) {
        sb.writeln('• كود: ${itm["item_code"] ?? "—"} | ${itm["description"]} | كمية: ${itm["quantity"]} ${itm["unit_of_measure"] ?? ""} | سعر: ${itm["unit_price"]} | إجمالي: ${itm["total_price"]} | HS: ${itm["hs_code"] ?? "—"}');
      }
      sb.writeln();
    }

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
    final plList = (dossier != null && dossier.packingLists.isNotEmpty)
        ? dossier.packingLists
        : file.packingListsData.map((p) => {
            'pl_number': p.plNo,
            'description': '',
            'total_packages': p.totalPackages,
            'gross_weight_kg': p.grossWeightKg,
            'net_weight_kg': 0.0,
            'cbm': p.cbm,
          }).toList();

    sb.writeln('--- ${l.compReportSecPackingLists(plList.length)} ---');
    if (plList.isEmpty) {
      sb.writeln(l.compReportNoPackingLists);
    } else {
      sb.writeln('${l.compReportTotalPackages}: $effPkgs | ${l.compReportTotalWeight}: ${PoPackingMatcher.formatWeight(effGrossWeight)} KG | ${l.compReportTotalCbm}: ${effCbm.toStringAsFixed(2)} m³');
      for (final pl in plList) {
        sb.writeln('• ${pl["pl_number"] ?? pl["pl_no"]} | ${pl["description"] ?? ""} | ${pl["total_packages"]} pkgs | ${PoPackingMatcher.formatWeight((pl["gross_weight_kg"] as num?)?.toDouble() ?? 0.0)} KG | ${(pl["cbm"] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} CBM');
      }
    }
    sb.writeln();

    // Section: Physical Cargo Summary & KPIs
    final phys = dossier?.cargoPhysicalSummary;
    if (phys != null) {
      sb.writeln('--- ملخص الأوزان والأبعاد الفيزيائية للشحنة (Physical Cargo Summary) ---');
      sb.writeln('الحجم الإجمالي: ${effCbm.toStringAsFixed(3)} m³ | الوزن القائم: ${PoPackingMatcher.formatWeight(effGrossWeight)} KG | الوزن الصافي: ${effNetWeight != null ? PoPackingMatcher.formatWeight(effNetWeight) : "—"} KG');
      sb.writeln('عدد الطرود: $effPkgs | عدد الفواتير: ${phys['invoices_count'] ?? file.invoicesData.length} | عدد أوامر الشراء POs: ${phys['pos_count'] ?? (dossier?.purchaseOrders.length ?? 0)}');
      if ((phys['invoice_numbers'] as List<dynamic>?)?.isNotEmpty == true) {
        sb.writeln('أرقام الفواتير: ${(phys['invoice_numbers'] as List<dynamic>).join(', ')}');
      }
      if ((phys['po_numbers'] as List<dynamic>?)?.isNotEmpty == true) {
        sb.writeln('أوامر الشراء المرتبطة: ${(phys['po_numbers'] as List<dynamic>).join(', ')}');
      }
      sb.writeln();
    }

    // Section: Financials
    final double totalInvoicesValue = (dossier?.totalFobFc != null && dossier!.totalFobFc! > 0)
        ? dossier.totalFobFc!
        : file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    final String fobCurr = dossier?.fobCurrency ?? 'USD';
    sb.writeln('--- ${l.compReportSecFinancial} ---');
    sb.writeln('${l.compReportTotalInvoicesVal}: ${totalInvoicesValue.toStringAsFixed(2)} $fobCurr');
    sb.writeln('${l.compReportEstimatedCostVal}: ${file.estimatedCost.toStringAsFixed(2)} $fobCurr');
    sb.writeln('${l.compReportEstimatedVariance}: ${(file.estimatedCost - totalInvoicesValue).toStringAsFixed(2)} $fobCurr');
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
        final cbm = s['cbm'] != null ? '${s['cbm']} m³' : (s['total_cbm'] != null ? '${s['total_cbm']} m³' : '—');
        final dur = s['duration_days'] != null ? 'المدة: ${s['duration_days']} يوم' : (s['clearance_duration_days'] != null ? 'المدة: ${s['clearance_duration_days']} يوم' : '—');
        final cost = s['actual_landed_cost'] != null ? 'التكلفة: ${s['actual_landed_cost']} EGP' : (s['status'] != null ? 'الحالة: ${s['status']}' : '');
        final variance = s['variance_pct'] != null ? 'انحراف: ${s['variance_pct']}%' : (s['cost_variance_pct'] != null ? 'انحراف: ${s['cost_variance_pct']}%' : '0.0%');
        sb.writeln('• $code | مورد: $supplier | $cbm | $dur | $cost | $variance');
      }
      sb.writeln();
    }

    // Section: Recurring Operational Patterns
    if (dossier != null && dossier.recurringPatterns.isNotEmpty) {
      sb.writeln('--- الأنماط التشغيلية المتكررة المكتشفة (Discovered Operational Patterns) ---');
      for (final p in dossier.recurringPatterns) {
        final title = p['suggested_title'] ?? p['pattern_title'] ?? p['title'] ?? 'نمط تشغيلي';
        final desc = p['suggested_content'] ?? p['pattern_description'] ?? p['description'] ?? '';
        final conf = p['confidence_score'] != null ? ' (ثقة: ${(p['confidence_score'] * 100).toStringAsFixed(0)}%)' : '';
        final sev = p['suggested_severity'] ?? p['severity'] ?? '';
        sb.writeln('• $title$conf${sev.toString().isNotEmpty ? " [$sev]" : ""}: $desc');
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

    final totalInvoicesValue = (dossier?.totalFobFc != null && dossier!.totalFobFc! > 0)
        ? dossier.totalFobFc!
        : file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    final String fobCurr = dossier?.fobCurrency ?? 'USD';

    final double effCbm = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['total_cbm'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['total_cbm'] as num).toDouble()
        : (file.packingListsData.isNotEmpty
            ? file.packingListsData.fold(0.0, (s, p) => s + p.cbm)
            : ((dossier?.smartReferenceCard?['product_summary']?['total_cbm'] as num?)?.toDouble() ?? 0.0));

    final double effGrossWeight = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['gross_weight_kg'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['gross_weight_kg'] as num).toDouble()
        : (file.packingListsData.isNotEmpty
            ? file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg)
            : ((dossier?.smartReferenceCard?['product_summary']?['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0));

    final double? effNetWeight = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['net_weight_kg'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['net_weight_kg'] as num).toDouble()
        : ((dossier?.smartReferenceCard?['product_summary']?['total_net_weight_kg'] as num?)?.toDouble());

    final int effPkgs = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['total_packages'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['total_packages'] as num).toInt()
        : (file.packingListsData.isNotEmpty
            ? file.packingListsData.fold(0, (s, p) => s + p.totalPackages)
            : ((dossier?.smartReferenceCard?['product_summary']?['total_packages'] as num?)?.toInt() ?? 0));

    final smartRecReason = dossier?.smartRecommendation ??
        ContainerRequirementEngine.recommendShipmentMode(totalCbm: effCbm, totalWeightKg: effGrossWeight).reasonAr;
    final stackRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: true);
    final nonStackRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: false);
    final hybridRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: true, orientationPreference: CargoOrientationPreference.smartHybrid);

    final refCard = dossier?.smartReferenceCard;
    final prodSummary = refCard?['product_summary'] as Map<String, dynamic>?;
    final routeSummary = refCard?['route_summary'] as Map<String, dynamic>?;
    final datesSummary = refCard?['critical_dates'] as Map<String, dynamic>?;
    final docsSummary = refCard?['customs_readiness'] as Map<String, dynamic>?;
    final costSummary = refCard?['cost_summary'] as Map<String, dynamic>?;

    final plList = (dossier != null && dossier.packingLists.isNotEmpty)
        ? dossier.packingLists
        : file.packingListsData.map((p) => {
            'pl_number': p.plNo,
            'description': p.date ?? '',
            'total_packages': p.totalPackages,
            'gross_weight_kg': p.grossWeightKg,
            'net_weight_kg': null,
            'cbm': p.cbm,
          }).toList();

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

                // Section: Smart Shipment Reference Card (المرجع الذكي المختصر للشحنة)
                pw.Text('المرجع الذكي المختصر للشحنة (Smart Shipment Reference Card)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#1B4F72'))),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    _pdfTableRow(
                      '1. الصنف والكمية',
                      'بند: ${prodSummary?['primary_hs_code'] ?? "—"} | تصنيف: ${prodSummary?['shipment_category'] ?? file.shipmentCategory}',
                      'الأبعاد والطرود',
                      'حجم: ${effCbm.toStringAsFixed(2)} m³ | قائم: ${PoPackingMatcher.formatWeight(effGrossWeight)} KG | صافي: ${effNetWeight != null ? PoPackingMatcher.formatWeight(effNetWeight) : "—"} KG | $effPkgs طرد',
                    ),
                    _pdfTableRow(
                      '2. مسار الشحن والناقل',
                      '${routeSummary?['pol_code'] ?? "—"} ➔ ${routeSummary?['pod_code'] ?? "—"} | خط: ${routeSummary?['carrier_name'] ?? file.selectedScenario ?? file.vesselName ?? "—"}',
                      'طريقة الشحن والشرط',
                      '${routeSummary?['shipment_mode'] ?? file.shipmentMode} | ${routeSummary?['incoterm'] ?? file.incotermCode}',
                    ),
                    _pdfTableRow(
                      '3. التواريخ وفترات السماح',
                      'سماح: ${datesSummary?['demurrage_free_days'] ?? "—"} يوم [${datesSummary?['free_days_status'] ?? "—"}]',
                      'الوصول المستهدف',
                      '${datesSummary?['target_eta'] ?? file.requiredEta ?? "—"}',
                    ),
                    _pdfTableRow(
                      '4. جاهزية المستندات',
                      'الحالة: ${docsSummary?['readiness_status'] ?? "—"} | منشأ: ${docsSummary?['coo_status'] ?? "—"}',
                      'النواقص',
                      (docsSummary?['missing_docs_list'] as List<dynamic>?)?.isNotEmpty == true
                          ? (docsSummary!['missing_docs_list'] as List<dynamic>).join(', ')
                          : 'مكتملة ومطابقة',
                    ),
                    _pdfTableRow(
                      '5. مقارنة التكلفة',
                      'تقديرية: ${(costSummary?['estimated_total_egp'] as num?)?.toStringAsFixed(2) ?? file.estimatedCost.toStringAsFixed(2)} | فعلية: ${(costSummary?['actual_landed_cost_egp'] as num?)?.toStringAsFixed(2) ?? (dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp).toStringAsFixed(2)} EGP',
                      'فارق التكلفة',
                      '${(costSummary?['cost_variance_egp'] as num?)?.toStringAsFixed(2) ?? (dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp).toStringAsFixed(2)} EGP (${(costSummary?['cost_variance_pct'] as num?)?.toStringAsFixed(2) ?? (dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct).toStringAsFixed(2)}%)',
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Section: Shipping Scenarios & Smart Recommendation
                pw.Text('دراسات وسيناريوهات الشحن المسجلة للشحنة (Shipping Scenarios & Stacking Studies)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#16A085'))),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#E8F8F5'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text('🚢 التوصية الذكية: $smartRecReason', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0E6251'))),
                ),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#16A085')),
                      children: [
                        _pdfHeaderCell('سيناريو الرص (Stacking Scenario)'),
                        _pdfHeaderCell('الحاويات المقترحة'),
                        _pdfHeaderCell('امتلاء الحجم (Vol %)'),
                        _pdfHeaderCell('حمولة الوزن (Weight %)'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfDataCell('رص قابل للتكديس (All Stackable)'),
                        _pdfDataCell('${stackRec.requiredContainersCount} x ${stackRec.recommendedContainerCode}'),
                        _pdfDataCell('${stackRec.spaceUtilizationPercent.toStringAsFixed(1)}%'),
                        _pdfDataCell('${stackRec.payloadUtilizationPercent.toStringAsFixed(1)}%'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfDataCell('غير قابل للتكديس أرضي (Non-Stackable Z=0)'),
                        _pdfDataCell('${nonStackRec.requiredContainersCount} x ${nonStackRec.recommendedContainerCode}'),
                        _pdfDataCell('${nonStackRec.spaceUtilizationPercent.toStringAsFixed(1)}%'),
                        _pdfDataCell('${nonStackRec.payloadUtilizationPercent.toStringAsFixed(1)}%'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _pdfDataCell('الرص الذكي الهجين (Smart Hybrid)'),
                        _pdfDataCell('${hybridRec.requiredContainersCount} x ${hybridRec.recommendedContainerCode}'),
                        _pdfDataCell('${hybridRec.spaceUtilizationPercent.toStringAsFixed(1)}%'),
                        _pdfDataCell('${hybridRec.payloadUtilizationPercent.toStringAsFixed(1)}%'),
                      ],
                    ),
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

                // Section: Purchase Orders Detail (if available)
                if (dossier != null && dossier.purchaseOrders.isNotEmpty) ...[
                  pw.Text('أوامر الشراء المعتمدة للشحنة (Purchase Orders Detail)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                        children: [
                          _pdfHeaderCell('رقم PO'),
                          _pdfHeaderCell('قيمة FOB'),
                          _pdfHeaderCell('الطرود'),
                          _pdfHeaderCell('الوزن القائم'),
                          _pdfHeaderCell('الحجم CBM'),
                          _pdfHeaderCell('الحالة'),
                        ],
                      ),
                      ...dossier.purchaseOrders.map((po) => pw.TableRow(
                        children: [
                          _pdfDataCell(po['po_number']?.toString() ?? '—'),
                          _pdfDataCell('${po['total_amount_fob'] ?? 0} ${po['currency'] ?? "USD"}'),
                          _pdfDataCell('${po['total_packages'] ?? 0}'),
                          _pdfDataCell('${po['total_gross_weight_kg'] ?? 0} KG'),
                          _pdfDataCell('${po['total_cbm'] ?? 0} m³'),
                          _pdfDataCell(po['status']?.toString() ?? '—'),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section: PO Line Items Detail (if available)
                if (dossier != null && dossier.itemsDetail.isNotEmpty) ...[
                  pw.Text('تفاصيل أصناف وبنود أمر الشراء (PO Line Items Detail)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#34495E'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#34495E')),
                        children: [
                          _pdfHeaderCell('كود الصنف'),
                          _pdfHeaderCell('الوصف والبيان', widthFactor: 2),
                          _pdfHeaderCell('الكمية'),
                          _pdfHeaderCell('السعر'),
                          _pdfHeaderCell('الإجمالي'),
                          _pdfHeaderCell('بند جمركي HS'),
                        ],
                      ),
                      ...dossier.itemsDetail.map((itm) => pw.TableRow(
                        children: [
                          _pdfDataCell(itm['item_code']?.toString() ?? '—'),
                          _pdfDataCell(itm['description']?.toString() ?? '—'),
                          _pdfDataCell('${itm['quantity'] ?? 0} ${itm['unit_of_measure'] ?? ""}'),
                          _pdfDataCell('${itm['unit_price'] ?? 0}'),
                          _pdfDataCell('${itm['total_price'] ?? 0}'),
                          _pdfDataCell(itm['hs_code']?.toString() ?? '—'),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Section: Packing Lists Detail (if available)
                if (plList.isNotEmpty) ...[
                  pw.Text('قوائم التعبئة المعتمدة (Packing Lists Detail)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('#2C3E50'))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2C3E50')),
                        children: [
                          _pdfHeaderCell('رقم PL'),
                          _pdfHeaderCell('البيان / الوصف'),
                          _pdfHeaderCell('الطرود'),
                          _pdfHeaderCell('الوزن القائم'),
                          _pdfHeaderCell('الوزن الصافي'),
                          _pdfHeaderCell('الحجم CBM'),
                        ],
                      ),
                      ...plList.map((pl) => pw.TableRow(
                        children: [
                          _pdfDataCell(pl['pl_number']?.toString() ?? pl['pl_no']?.toString() ?? '—'),
                          _pdfDataCell(pl['description']?.toString() ?? '—'),
                          _pdfDataCell('${pl['total_packages'] ?? 0}'),
                          _pdfDataCell('${PoPackingMatcher.formatWeight((pl['gross_weight_kg'] as num?)?.toDouble() ?? 0.0)} KG'),
                          _pdfDataCell(pl['net_weight_kg'] != null ? '${PoPackingMatcher.formatWeight((pl['net_weight_kg'] as num).toDouble())} KG' : '—'),
                          _pdfDataCell('${(pl['cbm'] as num?)?.toDouble().toStringAsFixed(2) ?? "0.00"} m³'),
                        ],
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                ],

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
                    _pdfTableRow(l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} $fobCurr', l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} $fobCurr'),
                    _pdfTableRow(l.compReportTotalPackages, '$effPkgs pkgs (${PoPackingMatcher.formatWeight(effGrossWeight)} KG)', l.compReportTotalCbm, '${effCbm.toStringAsFixed(2)} m³'),
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
                          ...dossier.similarPastShipments.take(6).map((s) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Text('• ${s['file_code'] ?? s['import_file_code'] ?? "—"} | مورد: ${s['supplier_name'] ?? "—"} | ${s['cbm'] ?? 0} m³ | مدة: ${s['duration_days'] ?? s['clearance_duration_days'] ?? "—"} يوم | تكلفة: ${s['actual_landed_cost'] ?? "—"} EGP (${s['variance_pct'] ?? s['cost_variance_pct'] ?? "—"}%)', style: const pw.TextStyle(fontSize: 7)),
                          )),
                        ],
                        if (dossier.recurringPatterns.isNotEmpty) ...[
                          pw.SizedBox(height: 4),
                          pw.Text('الأنماط التشغيلية المتكررة المكتشفة:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                          ...dossier.recurringPatterns.take(6).map((p) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 1),
                            child: pw.Text('• ${p['pattern_title'] ?? p['suggested_title'] ?? p['title'] ?? ""}: ${p['pattern_description'] ?? p['description'] ?? ""}', style: const pw.TextStyle(fontSize: 7)),
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

    final double effCbm = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['total_cbm'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['total_cbm'] as num).toDouble()
        : (file.packingListsData.isNotEmpty
            ? file.packingListsData.fold(0.0, (s, p) => s + p.cbm)
            : ((dossier?.smartReferenceCard?['product_summary']?['total_cbm'] as num?)?.toDouble() ?? 0.0));

    final double effGrossWeight = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['gross_weight_kg'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['gross_weight_kg'] as num).toDouble()
        : (file.packingListsData.isNotEmpty
            ? file.packingListsData.fold(0.0, (s, p) => s + p.grossWeightKg)
            : ((dossier?.smartReferenceCard?['product_summary']?['total_gross_weight_kg'] as num?)?.toDouble() ?? 0.0));

    final double? effNetWeight = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['net_weight_kg'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['net_weight_kg'] as num).toDouble()
        : ((dossier?.smartReferenceCard?['product_summary']?['total_net_weight_kg'] as num?)?.toDouble());

    final int effPkgs = (dossier?.cargoPhysicalSummary != null && (dossier!.cargoPhysicalSummary!['total_packages'] as num? ?? 0) > 0)
        ? (dossier.cargoPhysicalSummary!['total_packages'] as num).toInt()
        : (file.packingListsData.isNotEmpty
            ? file.packingListsData.fold(0, (s, p) => s + p.totalPackages)
            : ((dossier?.smartReferenceCard?['product_summary']?['total_packages'] as num?)?.toInt() ?? 0));

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

    // Smart Shipment Reference Card (5 Dimensions)
    const sRef = 'المرجع الذكي المختصر للشحنة (Smart Reference Card)';
    final refCard = dossier?.smartReferenceCard;
    final prodSummary = refCard?['product_summary'] as Map<String, dynamic>?;
    final routeSummary = refCard?['route_summary'] as Map<String, dynamic>?;
    final datesSummary = refCard?['critical_dates'] as Map<String, dynamic>?;
    final docsSummary = refCard?['customs_readiness'] as Map<String, dynamic>?;
    final costSummary = refCard?['cost_summary'] as Map<String, dynamic>?;

    addRow(sRef, '1. بيانات الصنف والكمية', 'بند جمركي: ${prodSummary?['primary_hs_code'] ?? "—"} | تصنيف: ${prodSummary?['shipment_category'] ?? file.shipmentCategory}', 'حجم: ${effCbm.toStringAsFixed(2)} m³ | قائم: ${PoPackingMatcher.formatWeight(effGrossWeight)} KG | صافي: ${effNetWeight != null ? PoPackingMatcher.formatWeight(effNetWeight) : "—"} KG | طرود: $effPkgs');
    addRow(sRef, '2. مسار الشحن والناقل', '${routeSummary?['pol_code'] ?? "—"} ➔ ${routeSummary?['pod_code'] ?? "—"}', 'خط: ${routeSummary?['carrier_name'] ?? file.selectedScenario ?? file.vesselName ?? "—"} | طريقة: ${routeSummary?['shipment_mode'] ?? file.shipmentMode} | شرط: ${routeSummary?['incoterm'] ?? file.incotermCode}');
    addRow(sRef, '3. التواريخ الحرجة وفترات السماح', 'سماح: ${datesSummary?['demurrage_free_days'] ?? "—"} يوم [${datesSummary?['free_days_status'] ?? "—"}]', 'وصول مستهدف: ${datesSummary?['target_eta'] ?? file.requiredEta ?? "—"} | جاهزية: ${datesSummary?['cargo_readiness_date'] ?? "—"}');
    addRow(sRef, '4. جاهزية المستندات الجمركية', 'الحالة: ${docsSummary?['readiness_status'] ?? "—"} | المنشأ: ${docsSummary?['coo_status'] ?? "—"}', (docsSummary?['missing_docs_list'] as List<dynamic>?)?.isNotEmpty == true ? 'النواقص: ${(docsSummary!['missing_docs_list'] as List<dynamic>).join(", ")}' : 'مكتملة ومطابقة');
    addRow(sRef, '5. مقارنة التكلفة التقديرية والفعلية', 'تقديرية: ${(costSummary?['estimated_total_egp'] as num?)?.toStringAsFixed(2) ?? file.estimatedCost.toStringAsFixed(2)} EGP | فعلية: ${(costSummary?['actual_landed_cost_egp'] as num?)?.toStringAsFixed(2) ?? (dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp).toStringAsFixed(2)} EGP', 'انحراف: ${(costSummary?['cost_variance_egp'] as num?)?.toStringAsFixed(2) ?? (dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp).toStringAsFixed(2)} EGP (${(costSummary?['cost_variance_pct'] as num?)?.toStringAsFixed(2) ?? (dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct).toStringAsFixed(2)}%)');

    // Shipping Scenarios & Smart Recommendation
    const sScenarios = 'دراسات وسيناريوهات الشحن والتوصية الذكية';
    final smartRecReason = dossier?.smartRecommendation ??
        ContainerRequirementEngine.recommendShipmentMode(totalCbm: effCbm, totalWeightKg: effGrossWeight).reasonAr;
    final stackRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: true);
    final nonStackRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: false);
    final hybridRec = ContainerRequirementEngine.calculate(totalCbm: effCbm, totalWeightKg: effGrossWeight, isStackable: true, orientationPreference: CargoOrientationPreference.smartHybrid);

    addRow(sScenarios, 'التوصية الذكية', smartRecReason);
    addRow(sScenarios, 'سيناريو الرص القابل للتكديس (All Stackable)', '${stackRec.requiredContainersCount} x ${stackRec.recommendedContainerCode}', 'امتلاء حجم: ${stackRec.spaceUtilizationPercent.toStringAsFixed(1)}% | حمولة وزن: ${stackRec.payloadUtilizationPercent.toStringAsFixed(1)}%');
    addRow(sScenarios, 'سيناريو غير قابل للتكديس أرضي (Non-Stackable Z=0)', '${nonStackRec.requiredContainersCount} x ${nonStackRec.recommendedContainerCode}', 'امتلاء حجم: ${nonStackRec.spaceUtilizationPercent.toStringAsFixed(1)}% | حمولة وزن: ${nonStackRec.payloadUtilizationPercent.toStringAsFixed(1)}%');
    addRow(sScenarios, 'سيناريو الرص الذكي الهجين (Smart Hybrid)', '${hybridRec.requiredContainersCount} x ${hybridRec.recommendedContainerCode}', 'امتلاء حجم: ${hybridRec.spaceUtilizationPercent.toStringAsFixed(1)}% | حمولة وزن: ${hybridRec.payloadUtilizationPercent.toStringAsFixed(1)}%');

    // Official Documents
    final sDocs = l.compReportSecDocs;
    addRow(sDocs, l.compReportAcidNumber, file.acidNumber ?? '—');
    addRow(sDocs, l.compReportBankForm4, file.form4No ?? '—');
    addRow(sDocs, l.compReportSwiftNumber, file.swiftNo ?? '—');
    addRow(sDocs, l.compReportForm46Number, file.form46No ?? '—');

    // Purchase Orders Detail
    if (dossier != null && dossier.purchaseOrders.isNotEmpty) {
      const sPO = 'أوامر الشراء المعتمدة (Purchase Orders)';
      for (final po in dossier.purchaseOrders) {
        addRow(
          sPO,
          po['po_number']?.toString() ?? '—',
          '${po['total_amount_fob']} ${po['currency'] ?? "USD"} | ${po['total_packages']} pkgs',
          'Gross: ${po['total_gross_weight_kg']} KG | CBM: ${po['total_cbm']} m³ | [${po['status'] ?? ""}]',
        );
      }
    }

    // PO Line Items Detail
    if (dossier != null && dossier.itemsDetail.isNotEmpty) {
      const sItems = 'تفاصيل أصناف وبنود أمر الشراء (PO Line Items)';
      for (final itm in dossier.itemsDetail) {
        addRow(
          sItems,
          itm['item_code']?.toString() ?? '—',
          '${itm['description']} (${itm['quantity']} ${itm['unit_of_measure'] ?? ""})',
          'سعر: ${itm['unit_price']} | إجمالي: ${itm['total_price']} | HS: ${itm['hs_code'] ?? "—"}',
        );
      }
    }

    // Invoices
    final sInvoices = l.compReportSecInvoices(file.invoicesData.length);
    for (var i = 0; i < file.invoicesData.length; i++) {
      final inv = file.invoicesData[i];
      addRow(sInvoices, '${inv.invoiceNo} (#${i + 1})', '${inv.amount.toStringAsFixed(2)} ${inv.currency}', '${inv.invoiceType} | ${inv.date ?? ""}');
    }

    // Packing Lists
    final plList = (dossier != null && dossier.packingLists.isNotEmpty)
        ? dossier.packingLists
        : file.packingListsData.map((p) => {
            'pl_number': p.plNo,
            'description': p.date ?? '',
            'total_packages': p.totalPackages,
            'gross_weight_kg': p.grossWeightKg,
            'net_weight_kg': null,
            'cbm': p.cbm,
          }).toList();

    final sPL = l.compReportSecPackingLists(plList.length);
    for (var i = 0; i < plList.length; i++) {
      final pl = plList[i];
      final plNo = pl['pl_number']?.toString() ?? pl['pl_no']?.toString() ?? 'PL-${i + 1}';
      final pkgs = pl['total_packages'] ?? 0;
      final gw = PoPackingMatcher.formatWeight((pl['gross_weight_kg'] as num?)?.toDouble() ?? 0.0);
      final cbmVal = (pl['cbm'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00';
      final desc = pl['description']?.toString() ?? '';
      addRow(sPL, '$plNo (#${i + 1})', '$pkgs pkgs | $gw KG', '$cbmVal CBM | $desc');
    }

    // Physical Cargo Summary & KPIs
    final phys = dossier?.cargoPhysicalSummary;
    const sPhys = 'الملخص الفيزيائي والمقاييس (Physical Cargo)';
    addRow(sPhys, 'إجمالي الحجم CBM', '${effCbm.toStringAsFixed(3)} m³');
    addRow(sPhys, 'الوزن القائم Gross Weight', '${PoPackingMatcher.formatWeight(effGrossWeight)} KG');
    addRow(sPhys, 'الوزن الصافي Net Weight', '${effNetWeight != null ? PoPackingMatcher.formatWeight(effNetWeight) : "—"} KG');
    addRow(sPhys, 'عدد الطرود Packages', '$effPkgs');
    addRow(sPhys, 'عدد الفواتير Invoices', '${phys?['invoices_count'] ?? file.invoicesData.length}');
    addRow(sPhys, 'عدد أوامر الشراء POs', '${phys?['pos_count'] ?? (dossier?.purchaseOrders.length ?? 0)}');

    // Financial
    final sFin = l.compReportSecFinancial;
    final totalInvoicesValue = (dossier?.totalFobFc != null && dossier!.totalFobFc! > 0)
        ? dossier.totalFobFc!
        : file.invoicesData.fold(0.0, (s, i) => s + i.amount);
    final String fobCurr = dossier?.fobCurrency ?? 'USD';
    addRow(sFin, l.compReportTotalInvoicesVal, '${totalInvoicesValue.toStringAsFixed(2)} $fobCurr');
    addRow(sFin, l.compReportEstimatedCostVal, '${file.estimatedCost.toStringAsFixed(2)} $fobCurr');
    addRow(sFin, l.compReportEstimatedVariance, '${(file.estimatedCost - totalInvoicesValue).toStringAsFixed(2)} $fobCurr');

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
        final code = s['file_code']?.toString() ?? s['import_file_code']?.toString() ?? '—';
        final supp = s['supplier_name']?.toString() ?? '—';
        final cbmVal = s['cbm']?.toString() ?? '—';
        final dur = s['duration_days']?.toString() ?? s['clearance_duration_days']?.toString() ?? '—';
        final cost = s['actual_landed_cost']?.toString() ?? '—';
        final vPct = s['variance_pct']?.toString() ?? s['cost_variance_pct']?.toString() ?? '—';
        addRow(
          sSim,
          code,
          'المورد: $supp | CBM: $cbmVal m³',
          'مدة: $dur يوم | تكلفة: $cost EGP (انحراف: $vPct%)',
        );
      }
    }

    // Recurring Operational Patterns
    if (dossier != null && dossier.recurringPatterns.isNotEmpty) {
      const sPat = 'الأنماط التشغيلية المتكررة';
      for (final p in dossier.recurringPatterns) {
        final title = p['pattern_title']?.toString() ?? p['suggested_title']?.toString() ?? p['title']?.toString() ?? 'نمط تشغيلي';
        final desc = p['pattern_description']?.toString() ?? p['description']?.toString() ?? '';
        final conf = p['confidence_score'] != null ? 'ثقة: ${((p['confidence_score'] as num) * 100).toStringAsFixed(0)}%' : '';
        addRow(
          sPat,
          title,
          desc,
          conf,
        );
      }
    }

    return rows;
  }
}


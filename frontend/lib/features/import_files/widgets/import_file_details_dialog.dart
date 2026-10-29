// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/utils/import_file_po_linker.dart';
import '../../purchase_orders/providers/purchase_orders_provider.dart';
import '../../purchase_orders/models/purchase_order_model.dart' hide PackingListItemModel;
import '../../purchase_orders/utils/po_packing_matcher.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../models/import_file_model.dart';
import '../../shipping_scenarios/providers/shipping_scenarios_provider.dart';
import '../widgets/close_shipment_dialog.dart';
import '../widgets/freight_rfq_dialog.dart';
import '../../experience_guide/models/guide_entry_model.dart';
import '../../experience_guide/providers/experience_guide_provider.dart';
import '../../experience_guide/widgets/experience_guide_alert_banner.dart';
import '../../experience_guide/widgets/similar_shipments_card.dart';
import '../../experience_guide/widgets/detected_patterns_card.dart';
import '../../experience_guide/widgets/smart_shipment_reference_card.dart';
import '../../experience_guide/widgets/add_guide_entry_dialog.dart';
import '../../smart_checklists/widgets/smart_checklist_dialog.dart';
import '../../customs_tariff/models/customs_tariff_model.dart';
import '../../customs_tariff/providers/customs_tariff_provider.dart';
import '../../customs_tariff/widgets/duty_calculator_dialog.dart';
import '../../customs_tariff/widgets/hs_code_compliance_insight_card.dart';
import '../../financial_settlement/widgets/estimated_landed_cost_dialog.dart';
import '../../financial_approval/widgets/supplier_advance_payment_dialog.dart';
import '../../import_documentation/screens/nafeza_acid_screen.dart';
import '../../import_documentation/screens/bank_form4_screen.dart';
import '../../import_documentation/screens/shipment_draft_docs_screen.dart';
import '../../freight_booking/screens/freight_booking_screen.dart';
import '../../freight_booking/models/freight_booking_model.dart';
import '../../freight_booking/providers/freight_booking_provider.dart';
import '../../freight_booking/widgets/departure_confirmation_dialog.dart';
import '../../demurrage_detention/widgets/free_days_agreement_dialog.dart';
import 'visual_container_load_planner_dialog.dart';
import '../../import_documentation/widgets/draft_bl_review_dialog.dart';
import '../../cargox/widgets/cargox_hub_dialog.dart';
import '../../import_documentation/widgets/original_documents_collection_dialog.dart';
import '../../customs_clearance/widgets/customs_broker_authorization_dialog.dart';
import '../../customs_clearance/widgets/delivery_order_payment_dialog.dart';
import '../../customs_clearance/widgets/customs_declaration_46_dialog.dart';
import '../../customs_clearance/widgets/customs_inspection_sampling_dialog.dart';
import '../../customs_clearance/widgets/final_duty_assessment_dialog.dart';
import '../../customs_clearance/widgets/customs_duty_payment_dialog.dart';
import '../../customs_clearance/widgets/customs_final_release_dialog.dart';
import '../../customs_clearance/widgets/clearance_expenses_dialog.dart';
import '../../inland_transport/widgets/inland_transport_dialog.dart';
import '../../demurrage_detention/screens/demurrage_detention_screen.dart';
import '../../warehouse_receiving/screens/warehouse_receiving_screen.dart';
import '../../warehouse_receiving/widgets/warehouse_inspection_dialog.dart';
import '../../warehouse_receiving/models/warehouse_receiving_model.dart';
import '../../warehouse_receiving/providers/warehouse_receiving_provider.dart';
import '../../demurrage_detention/widgets/empty_container_return_dialog.dart';
import '../../financial_settlement/widgets/final_settlement_invoices_dialog.dart';
import '../../financial_settlement/widgets/actual_landed_cost_dialog.dart';
import '../../comprehensive_report/widgets/comprehensive_dossier_export_dialog.dart';
import '../../comprehensive_report/widgets/shipment_audit_timeline_dialog.dart';
import '../../file_closure/widgets/official_file_closure_dialog.dart';
import 'create_partial_batch_dialog.dart';
import 'logistics_shipment_expenses_summary_card.dart';
import '../../logistics_invoices/screens/logistics_invoices_screen.dart';
import 'shipment_milestone_tracker.dart';
import '../../comprehensive_report/services/comprehensive_dossier_service.dart';
import '../../comprehensive_report/models/comprehensive_dossier_model.dart';
import '../../shipment_updates/providers/shipment_updates_provider.dart';
import '../../customs_clearance/providers/customs_clearance_provider.dart';
import '../../customs_clearance/models/customs_clearance_model.dart';
import '../../../core/widgets/copyable_data_helper.dart';
import '../../../core/widgets/unified_dossier_export_menu.dart';

import 'package:frontend/core/widgets/ltr_text.dart';
class ImportFileDetailsDialog extends ConsumerStatefulWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final Set<String> invoiceNumbers;
  final double totalPackingListCbm;
  final double totalPackingListWeight;
  final int totalPackingListsCount;
  final VoidCallback? onEditPressed;

  const ImportFileDetailsDialog({super.key, 
    required this.file,
    required this.linkedPOs,
    required this.invoiceNumbers,
    required this.totalPackingListCbm,
    required this.totalPackingListWeight,
    required this.totalPackingListsCount,
    this.onEditPressed,
  });

  @override
  ConsumerState<ImportFileDetailsDialog> createState() => ImportFileDetailsDialogState();
}

class ImportFileDetailsDialogState extends ConsumerState<ImportFileDetailsDialog> {
  GuideMatchResultModel? _guideMatchResult;

  @override
  void initState() {
    super.initState();
    // listen: false — resolving `ref` here would register an inherited dependency
    // during initState, which Flutter asserts against.
    final container = ProviderScope.containerOf(context, listen: false);
    container.invalidate(smartReferenceCardProvider(widget.file.importFileId));
    container.invalidate(similarShipmentsProvider(widget.file.importFileId));
    container.invalidate(detectedPatternsProvider);
    _loadExperienceGuide();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final poState = ref.read(purchaseOrdersProvider);
      if (poState.purchaseOrders.isEmpty && !poState.isLoading) {
        await ref.read(purchaseOrdersProvider.notifier).fetchPurchaseOrders();
        if (mounted) {
          _loadExperienceGuide();
        }
      }
    });
  }

  Future<void> _loadExperienceGuide() async {
    try {
      final allHsCodes = <String>{};
      final allCategories = <String>{};
      final allPOs = ref.read(purchaseOrdersProvider).purchaseOrders;
      final livePOs = ImportFilePoLinker.getLinkedPOs(file: widget.file, allPOs: allPOs);
      final effectivePOs = livePOs.isNotEmpty ? livePOs : widget.linkedPOs;

      for (final po in effectivePOs) {
        for (final pli in po.packingListItems) {
          if (pli.hsCode.trim().isNotEmpty) allHsCodes.add(pli.hsCode.trim());
          if (pli.description != null && pli.description!.trim().isNotEmpty) {
            allCategories.add(pli.description!.trim());
          }
        }
        for (final it in po.items) {
          if (it.hsCode != null && it.hsCode!.trim().isNotEmpty) {
            allHsCodes.add(it.hsCode!.trim());
          }
          if (it.mainDescription != null && it.mainDescription!.trim().isNotEmpty) {
            allCategories.add(it.mainDescription!.trim());
          }
        }
      }
      if (widget.file.hsCode != null && widget.file.hsCode!.trim().isNotEmpty) {
        allHsCodes.add(widget.file.hsCode!.trim());
      }
      if (widget.file.productCategory != null && widget.file.productCategory!.trim().isNotEmpty) {
        allCategories.add(widget.file.productCategory!.trim());
      }

      final res = await ref.read(experienceGuideProvider.notifier).matchShipment(
        supplier: widget.file.supplierName,
        hsCode: allHsCodes.isNotEmpty ? allHsCodes.first : widget.file.hsCode,
        productCategory: allCategories.isNotEmpty ? allCategories.first : widget.file.productCategory,
        portOfDischarge: widget.file.portOfDischarge,
        incoterm: widget.file.incotermCode,
        importFileReference: widget.file.importFileCode,
      );
      if (mounted) {
        setState(() {
          _guideMatchResult = res;
        });
      }
    } catch (_) {}
  }

  void _showVisualLoadPlanDialog(BuildContext context, List<PurchaseOrderModel> pos) {
    showDialog(
      context: context,
      builder: (context) => VisualContainerLoadPlannerDialog(
        file: widget.file,
        linkedPOs: pos,
        fallbackCbm: widget.totalPackingListCbm,
        fallbackWeight: widget.totalPackingListWeight,
      ),
    );
  }

  static Widget _buildFileMetricPill(String label, String value, Color color, {bool isDark = false}) {
    Color effectiveColor = color;
    if (isDark) {
      if (color == AppTheme.charcoal) {
        effectiveColor = AppTheme.darkTextPrimary;
      } else if (color == Colors.orange.shade900) {
        effectiveColor = Colors.orange.shade300;
      } else if (color == Colors.green.shade800) {
        effectiveColor = Colors.green.shade300;
      } else if (color == Colors.red.shade800) {
        effectiveColor = Colors.red.shade300;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? effectiveColor.withOpacity(0.18) : effectiveColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? effectiveColor.withOpacity(0.5) : effectiveColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: effectiveColor, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 10, color: isDark ? Colors.white : effectiveColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showContainerComparisonDialog(BuildContext context, ContainerDualRecommendationResult dualRec, double totalCbm, double totalWeightKg) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = AppTheme.isDark(context);
        final l = context.l10n;
        return DefaultTabController(
          length: 3,
          child: AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.inventory_2, color: AppTheme.cobalt),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.containerOptionsAnalysisTitle,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : null),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${l.totalShipmentSummary}: ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SelectionArea(
              child: SizedBox(
                width: 820,
                height: 500,
                child: Column(
                  children: [
                    Container(
                      color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                      child: TabBar(
                        indicatorColor: AppTheme.cobalt,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(icon: const Icon(Icons.layers), text: l.containerStackableTab),
                          Tab(icon: const Icon(Icons.view_array), text: l.containerNonStackableTab),
                          Tab(icon: const Icon(Icons.shuffle), text: l.containerMixedTab),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildComparisonTable(dualRec.stackableResult, isDark: isDark),
                          _buildComparisonTable(dualRec.nonStackableResult, isDark: isDark),
                          _buildComparisonTable(dualRec.stackableResult, isDark: isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l.closeDiagramBtn)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonTable(ContainerRecommendationResult rec, {bool isDark = false}) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable
                  ? (isDark ? Colors.green.shade900.withOpacity(0.3) : AppTheme.emerald.withOpacity(0.1))
                  : (isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: rec.isStackable
                    ? (isDark ? Colors.green.shade700 : AppTheme.emerald)
                    : (isDark ? Colors.orange.shade700 : Colors.orange.shade800),
              ),
            ),
            child: Text(
              '${l.approvedRecommendationPrefix}: ${rec.recommendationSummary}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rec.isStackable
                    ? (isDark ? Colors.green.shade300 : AppTheme.emerald)
                    : (isDark ? Colors.orange.shade300 : Colors.orange.shade900),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.containerSpecType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.requiredCount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.effectiveCapacityCbm, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.spaceUtilizationPercent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  Padding(padding: const EdgeInsets.all(8), child: Text(context.l10n.weightUtilizationPercent, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
              ...rec.comparisonDetails.map((detail) {
                final spec = detail['spec'] as ContainerSpec;
                final reqCount = detail['reqCount'] as int;
                final effVol = detail['effectiveVolumeCbm'] as double;
                final spaceUtil = detail['spaceUtil'] as double;
                final payloadUtil = detail['payloadUtil'] as double;
                final isBest = spec.code == rec.recommendedContainerCode;

                return TableRow(
                  decoration: BoxDecoration(color: isBest ? (isDark ? Colors.blue.shade900.withOpacity(0.2) : AppTheme.cobalt.withOpacity(0.08)) : null),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          if (isBest) const Icon(Icons.star, color: Colors.amber, size: 16),
                          if (isBest) const SizedBox(width: 4),
                          Text(
                            '${spec.code} (${spec.name})',
                            style: TextStyle(
                              fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                              color: isBest
                                  ? (isDark ? Colors.lightBlueAccent : AppTheme.cobalt)
                                  : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '$reqCount',
                        style: TextStyle(fontWeight: isBest ? FontWeight.bold : FontWeight.normal, color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${effVol.toStringAsFixed(1)} m³',
                        style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${spaceUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: spaceUtil > 80 ? (isDark ? Colors.green.shade300 : Colors.green) : (isDark ? AppTheme.darkTextPrimary : Colors.black),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${payloadUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: payloadUtil > 80 ? (isDark ? Colors.green.shade300 : Colors.green) : (isDark ? AppTheme.darkTextPrimary : Colors.black),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isDark = AppTheme.isDark(context);
    final file = widget.file;
    final allPOs = ref.watch(purchaseOrdersProvider).purchaseOrders;
    final liveLinkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final linkedPOs = liveLinkedPOs.isNotEmpty ? liveLinkedPOs : widget.linkedPOs;
    final isAr = ref.watch(localeProvider).languageCode == 'ar' || Localizations.localeOf(context).languageCode == 'ar';
    final shipmentHsCodes = <String>{};
    final shipmentCategories = <String>{};
    for (final po in linkedPOs) {
      for (final pli in po.packingListItems) {
        if (pli.hsCode.trim().isNotEmpty) shipmentHsCodes.add(pli.hsCode.trim());
        if (pli.description != null && pli.description!.trim().isNotEmpty) {
          shipmentCategories.add(pli.description!.trim());
        }
      }
      for (final it in po.items) {
        if (it.hsCode != null && it.hsCode!.trim().isNotEmpty) {
          shipmentHsCodes.add(it.hsCode!.trim());
        }
        if (it.mainDescription != null && it.mainDescription!.trim().isNotEmpty) {
          shipmentCategories.add(it.mainDescription!.trim());
        }
      }
    }
    if (file.hsCode != null && file.hsCode!.trim().isNotEmpty) {
      shipmentHsCodes.add(file.hsCode!.trim());
    }
    if (file.productCategory != null && file.productCategory!.trim().isNotEmpty) {
      shipmentCategories.add(file.productCategory!.trim());
    }

    final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
    final totalPackingListCbm = metrics.cbm > 0 ? metrics.cbm : widget.totalPackingListCbm;
    final totalPackingListWeight = metrics.weightKg > 0 ? metrics.weightKg : widget.totalPackingListWeight;
    final totalPackingListsCount = metrics.plCount > 0 ? metrics.plCount : widget.totalPackingListsCount;
    final rawInvoices = metrics.invoices.isNotEmpty ? metrics.invoices : widget.invoiceNumbers;
    final poNumbersToExclude = <String>{
      if (file.poNumber != null && file.poNumber!.trim().toUpperCase().startsWith('PO-')) file.poNumber!.trim(),
      for (final po in linkedPOs)
        if (po.poNumber.trim().toUpperCase().startsWith('PO-')) po.poNumber.trim(),
    };
    final invoiceNumbers = rawInvoices.where((inv) =>
      !poNumbersToExclude.contains(inv) &&
      !(inv.toUpperCase().startsWith('PO-') && !inv.toUpperCase().contains('INV') && !inv.toUpperCase().contains('PI'))
    ).toSet();

    final dossierAsync = ref.watch(comprehensiveDossierProvider(file.importFileId));
    final dossier = dossierAsync.valueOrNull;
    final updatesState = ref.watch(shipmentUpdatesProvider);
    final clearanceState = ref.watch(customsClearanceProvider);
    final warehouseState = ref.watch(warehouseReceivingProvider);

    final dualRec = ContainerRequirementEngine.calculateBoth(
      totalCbm: totalPackingListCbm,
      totalWeightKg: totalPackingListWeight,
    );
    final modeRec = dualRec.modeRecommendation;

    final baseCargoItems = ImportFilePoLinker.buildCargoItems(
      pos: linkedPOs,
      file: file,
      fallbackCbm: totalPackingListCbm,
      fallbackWeight: totalPackingListWeight,
    );

    // Run the 3 plans
    final planStackable = ContainerRequirementEngine.planShipment(baseCargoItems, forceStackable: true);
    final planNonStackable = ContainerRequirementEngine.planShipment(baseCargoItems, forceStackable: false);
    final planMixed = ContainerRequirementEngine.planShipment(baseCargoItems, forceStackable: null);

    // Helpers to compute fleet string and metrics
    String getFleetText(List<ContainerPackingResult> pList) {
      final Map<String, int> counts = {};
      for (final p in pList) {
        if (p.containerCode != 'FAILED') {
          counts[p.containerCode] = (counts[p.containerCode] ?? 0) + 1;
        }
      }
      return counts.isEmpty ? '1 x 40HC' : counts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');
    }

    final stackableFleet = getFleetText(planStackable);
    final nonStackableFleet = getFleetText(planNonStackable);
    final mixedFleet = getFleetText(planMixed);

    final stackableTotalCapVol = planStackable.fold(0.0, (s, p) => s + p.spec.internalVolumeCbm);
    final stackableTotalCapPay = planStackable.fold(0.0, (s, p) => s + p.spec.maxPayloadKg);
    final stackableSpaceUtil = stackableTotalCapVol > 0 ? (planStackable.fold(0.0, (s, p) => s + p.totalVolume) / stackableTotalCapVol * 100) : 0.0;
    final stackablePayloadUtil = stackableTotalCapPay > 0 ? (planStackable.fold(0.0, (s, p) => s + p.totalWeight) / stackableTotalCapPay * 100) : 0.0;

    final nonStackableTotalCapVol = planNonStackable.fold(0.0, (s, p) => s + p.spec.internalVolumeCbm);
    final nonStackableTotalCapPay = planNonStackable.fold(0.0, (s, p) => s + p.spec.maxPayloadKg);
    final nonStackableSpaceUtil = nonStackableTotalCapVol > 0 ? (planNonStackable.fold(0.0, (s, p) => s + p.totalVolume) / nonStackableTotalCapVol * 100) : 0.0;
    final nonStackablePayloadUtil = nonStackableTotalCapPay > 0 ? (planNonStackable.fold(0.0, (s, p) => s + p.totalWeight) / nonStackableTotalCapPay * 100) : 0.0;

    final mixedTotalCapVol = planMixed.fold(0.0, (s, p) => s + p.spec.internalVolumeCbm);
    final mixedTotalCapPay = planMixed.fold(0.0, (s, p) => s + p.spec.maxPayloadKg);
    final mixedSpaceUtil = mixedTotalCapVol > 0 ? (planMixed.fold(0.0, (s, p) => s + p.totalVolume) / mixedTotalCapVol * 100) : 0.0;
    final mixedPayloadUtil = mixedTotalCapPay > 0 ? (planMixed.fold(0.0, (s, p) => s + p.totalWeight) / mixedTotalCapPay * 100) : 0.0;

    final mixedStackCount = baseCargoItems.where((i) => i.isStackable).length;
    final mixedNonStackCount = baseCargoItems.where((i) => !i.isStackable).length;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.folder_special, color: AppTheme.cobalt, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${file.displayName} (${file.companyName})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${l.importFileIdLabel}: ${file.importFileCode}${file.poNumber != null && file.poNumber!.isNotEmpty ? " | PO: ${file.poNumber!}" : ""}${file.piNumber != null && file.piNumber!.isNotEmpty ? " | PI: ${file.piNumber!}" : ""} | ${l.foreignSupplier}: ${file.supplierName} | ${l.status}: ${file.status}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (file.isChildPartial && file.parentFileCode != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade700, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_split_rounded, size: 14, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                        const SizedBox(width: 6),
                        Text(
                          'دفعة شحن جزئية تابعة للملف الأساسي: ${file.parentFileCode}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (file.isParentPartial)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade700, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.call_split_rounded, size: 14, color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900),
                        const SizedBox(width: 6),
                        Text(
                          'ملف شحنة مجزأة رئيسية (تم تفريغ دفعات جزئية منه)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.lightBlueAccent : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── 2.2 Dossier Bridge Action ─────────────────────────────────────
          ElevatedButton.icon(
            key: const Key('openMasterReportScreenBtn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.cobalt,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(
              isAr ? 'عرض التقرير والبطاقة الفنية الشاملة ↗' : 'View Master Dossier ↗',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(selectedComprehensiveReportFileIdProvider.notifier).state = file.importFileId;
              selectNavigationIndex(ref, 47, tabTitle: 'تقرير الشحنة الشامل المدمج');
            },
          ),
          const SizedBox(width: 8),

          // ── 2.1 Dropdown: [نماذج ومحاكاة ▾] ────────────────────────────────
          _buildModelsAndSimulationsMenu(context, file, isAr: isAr, isDark: isDark),
          const SizedBox(width: 8),

          // ── 2.1 Dropdown: [مستندات الشحنة ▾] ───────────────────────────────
          _buildShipmentDocumentsMenu(context, file, isAr: isAr, isDark: isDark),
          const SizedBox(width: 8),

          // Close Button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: isAr ? 'إغلاق' : 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SelectionArea(
        child: SizedBox(
          width: 920,
          height: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // 1. 10-Phase Milestone Journey Tracker (Operational Cockpit)
              ShipmentMilestoneTracker(
                importFile: file,
                totalCbm: widget.totalPackingListCbm > 0 ? widget.totalPackingListCbm : (dossier?.totalCbm ?? 66.39),
                grossWeightKg: widget.totalPackingListWeight > 0 ? widget.totalPackingListWeight : (dossier?.grossWeightKg ?? 10510.0),
                shippingLine: file.selectedScenario ?? 'Wan Hai',
                hasAcousticAlert: (_guideMatchResult?.matchedEntries.any((e) => e.isCritical) == true) ||
                    (file.productCategory?.toLowerCase().contains('acoustic') == true ||
                     file.customFileNumber?.toLowerCase().contains('pet') == true ||
                     file.importFileCode == 'IMP-2026-0004'),
              ),
              const SizedBox(height: 12),

              // 2. Quick Export & Dossier Actions Toolbar
              _buildQuickExportToolbar(
                context,
                file,
                dossier,
                updatesState,
                clearanceState,
                warehouseState,
                isDark: isDark,
                isAr: isAr,
              ),
              const SizedBox(height: 14),

              // Smart Shipment Experience Guide Alert Banner (Institutional Memory)
              if (_guideMatchResult != null && _guideMatchResult!.matchedEntries.isNotEmpty)
                ExperienceGuideAlertBanner(
                  matchResult: _guideMatchResult!,
                  supplier: file.supplierName,
                  hsCode: file.hsCode,
                  productCategory: file.productCategory,
                  portOfDischarge: file.portOfDischarge,
                  incoterm: file.incotermCode,
                  importFileReference: file.importFileCode,
                ),

              // Historical Similar Shipments Card
              SimilarShipmentsCard(importFileId: file.importFileId),

              // Systemic Detected Patterns Card
              const DetectedPatternsCard(),
              const SizedBox(height: 12),

              // Logistics Service Invoices & Advance Custody Summary Card
              LogisticsShipmentExpensesSummaryCard(file: file),
              const SizedBox(height: 12),

              // FX Reconciliation Card
              _buildFxReconciliationCard(context, dossier, file, isDark: isDark),
              const SizedBox(height: 12),

              // Top Executive Metric Summary Cards (5 Key Physical & Financial Metrics)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cobalt.withOpacity(isDark ? 0.14 : 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cobalt.withOpacity(isDark ? 0.4 : 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 مؤشرات الشحنة التنفيذية والمطابقة الفعلية:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    ),
                    const SizedBox(height: 10),
                    () {
                      final netWeight = dossier?.netWeightKg;
                    final displayNet = (netWeight != null && netWeight > 0)
                        ? 'صافي: ${PoPackingMatcher.formatWeight(netWeight)} kg'
                        : l.grossWeightSumDescription;

                    final actualLanded = dossier?.actualLandedCostTotalEgp ?? file.actualLandedCostTotalEgp;
                    final variancePct = dossier?.actualLandedCostVariancePct ?? file.actualLandedCostVariancePct;
                    final varianceEgp = dossier?.actualLandedCostVarianceEgp ?? file.actualLandedCostVarianceEgp;
                    final hasVariance = actualLanded > 0 && varianceEgp != 0;

                    int driftDays = 0;
                    if (dossier != null && dossier.etaRevisionsLog.isNotEmpty) {
                      final lastLog = dossier.etaRevisionsLog.last;
                      driftDays = (lastLog['drift_days'] as num?)?.toInt() ?? 0;
                    }
                    final isDrifted = driftDays > 0;

                    return Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            l.totalCbmFromPackingList,
                            '${totalPackingListCbm.toStringAsFixed(3)} m³',
                            subtitle: '$totalPackingListsCount ${l.packingListsUnit}',
                            icon: Icons.view_in_ar,
                            color: Colors.orange,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            l.totalGrossWeightFromPl,
                            '${PoPackingMatcher.formatWeight(totalPackingListWeight)} kg',
                            subtitle: displayNet,
                            icon: Icons.fitness_center,
                            color: AppTheme.emerald,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'الفواتير وأوامر الشراء',
                            '${invoiceNumbers.length} فاتورة • ${linkedPOs.length} PO',
                            subtitle: '${dossier?.itemsCount ?? 0} صنف تفصيلي',
                            icon: Icons.receipt_long,
                            color: AppTheme.cobalt,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            actualLanded > 0 ? 'تكلفة الوصول والتسوية' : 'التكلفة التقديرية',
                            actualLanded > 0
                                ? '${actualLanded.toStringAsFixed(0)} ج.م'
                                : (file.estimatedCost > 0 ? '${file.estimatedCost.toStringAsFixed(0)} \$' : '—'),
                            subtitle: hasVariance
                                ? 'تباين: ${variancePct > 0 ? "+" : ""}${variancePct.toStringAsFixed(1)}%'
                                : (file.estimatedCost > 0 ? 'تقديري مبدئي' : 'بانتظار التسوية'),
                            icon: Icons.account_balance_wallet,
                            color: hasVariance ? (variancePct.abs() > 5 ? AppTheme.crimson : const Color(0xFFD97706)) : const Color(0xFF0D9488),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildMetricTile(
                            'الجدول الزمني والانحراف',
                            file.requiredEta ?? '—',
                            subtitle: isDrifted
                                ? '⚠️ تأخير +$driftDays يوم'
                                : (driftDays < 0 ? 'تبكير $driftDays يوم' : 'منتظم بالجدول'),
                            icon: Icons.access_time,
                            color: isDrifted ? Colors.orange.shade800 : AppTheme.cobalt,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  }(),
                  ],
                ),
              ),
              const SizedBox(height: 16),


              // ACID & Expiry Tracking Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: file.isCustomsReleased
                      ? (isDark ? Colors.green.shade900.withOpacity(0.25) : Colors.green.shade50.withOpacity(0.5))
                      : (file.acidNumber != null
                          ? (isDark ? Colors.blue.shade900.withOpacity(0.25) : Colors.blue.shade50.withOpacity(0.5))
                          : (isDark ? AppTheme.darkSurface : Colors.grey.shade50)),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: file.isCustomsReleased
                        ? (isDark ? Colors.green.shade700 : Colors.green.shade300)
                        : (file.acidNumber != null
                            ? (isDark ? Colors.blue.shade700 : Colors.blue.shade300)
                            : (isDark ? AppTheme.darkBorder : Colors.grey.shade300)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: file.isCustomsReleased
                          ? AppTheme.emerald.withOpacity(0.15)
                          : (file.acidNumber != null ? AppTheme.cobalt.withOpacity(0.15) : Colors.grey.shade200),
                      child: Icon(
                        file.isCustomsReleased
                            ? Icons.verified_user
                            : (file.acidNumber != null ? Icons.hourglass_top : Icons.pending_actions),
                        color: file.isCustomsReleased
                            ? AppTheme.emerald
                            : (file.acidNumber != null ? AppTheme.cobalt : Colors.grey),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '📌 ${l.acidStatusTitle}:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: file.isCustomsReleased
                                      ? AppTheme.emerald
                                      : (file.acidNumber != null ? (isDark ? Colors.lightBlueAccent : AppTheme.cobalt) : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                ),
                              ),
                              if (file.isCustomsReleased)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '✅ ${l.customsReleasedBadge}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else if (file.acidNumber != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade800,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '⏳ ${l.underClearanceBadge}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (file.acidNumber != null && file.acidNumber!.isNotEmpty) ...[
                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('ACID: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                    SelectableText(
                                      file.acidNumber!,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.lightBlueAccent : AppTheme.charcoal),
                                    ),
                                  ],
                                ),
                                if (file.acidRequestDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(file.acidRequestDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                                    ],
                                  ),
                                if (file.acidIssueDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(file.acidIssueDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                                    ],
                                  ),
                                if (file.acidExpiryDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${l.targetEta}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(
                                        file.acidExpiryDate!,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.red.shade300 : AppTheme.crimson),
                                      ),
                                    ],
                                  ),
                                if (file.acidExecutionDays != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? Colors.green.shade700 : Colors.green.shade300, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.timer_outlined, size: 12, color: isDark ? Colors.green.shade300 : AppTheme.emerald),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${file.acidExecutionDays} d',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : AppTheme.emerald),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              l.noImportFilesFound,
                              style: TextStyle(fontSize: 12, color: isDark ? AppTheme.darkTextMuted : Colors.grey),
                            ),
                          ],
                          if (file.form4No != null && file.form4No!.isNotEmpty) ...[
                            Divider(height: 16, color: isDark ? AppTheme.darkBorder : null),
                            Wrap(
                              spacing: 16,
                              runSpacing: 6,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Form 4: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                    SelectableText(file.form4No!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                                  ],
                                ),
                                if (file.form4RequestDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(file.form4RequestDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                                    ],
                                  ),
                                if (file.form4ReceivedDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${l.date}: ', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                      Text(file.form4ReceivedDate!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.green.shade300 : AppTheme.emerald)),
                                    ],
                                  ),
                                if (file.form4ExecutionDays != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: isDark ? Colors.blue.shade700 : Colors.blue.shade300, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.speed, size: 12, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${file.form4ExecutionDays} d',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Containers & Seal Matrix Card (Operational Seal Tracker)
              _buildContainersCard(context, dossier, file, isDark: isDark),
              const SizedBox(height: 16),

              // ── Smart Shipment Experience Guide Card ───────────────────────
              SmartShipmentReferenceCard(
                importFileId: file.importFileId,
                dossier: dossier,
                initialHsCode: shipmentHsCodes.isNotEmpty ? shipmentHsCodes.first : file.hsCode,
                initialCategory: shipmentCategories.isNotEmpty ? shipmentCategories.first : file.productCategory,
                initialPod: file.portOfDischarge,
                initialSupplier: file.supplierName,
                initialCarrier: file.selectedScenario,
                linkedPOs: linkedPOs,
                file: file,
                onGuidelineAdded: () {
                  showDialog(
                    context: context,
                    builder: (_) => AddGuideEntryDialog(
                      initialHsCode: shipmentHsCodes.isNotEmpty ? shipmentHsCodes.first : file.hsCode,
                      initialCategory: shipmentCategories.isNotEmpty ? shipmentCategories.first : file.productCategory,
                      initialDestinationPort: file.portOfDischarge,
                      initialSupplier: file.supplierName,
                      initialShippingLine: file.selectedScenario,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Linked Purchase Orders Table
              Text(
                '🛒 ${l.linkedPurchaseOrdersTitle}:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
              ),
              const SizedBox(height: 10),
              linkedPOs.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Text(l.noLinkedPosForFile, style: TextStyle(color: isDark ? AppTheme.darkTextSecondary : null)),
                    )
                  : Table(
                      border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      columnWidths: const {
                        0: FlexColumnWidth(1.4),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.8),
                        3: FlexColumnWidth(1.6),
                        4: FlexColumnWidth(1.4),
                        5: FlexColumnWidth(1.0),
                        6: FlexColumnWidth(1.5),
                        7: FlexColumnWidth(1.0),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
                          children: [
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.purchaseOrder, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.poInvoiceLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.foreignSupplier, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.paymentTermsLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.totalCostMetric, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.packingListItemsCol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.weightCbmCol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: const EdgeInsets.all(8), child: Text(l.status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ...linkedPOs.map((po) {
                          final double poPalletCbm = po.palletPlanItems.isNotEmpty
                              ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.calculatedCbm > 0 ? p.calculatedCbm : (p.lengthCm * p.widthCm * p.heightCm / 1000000.0) * p.palletCount))
                              : (po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0
                                  ? (po.palletLengthCm * po.palletWidthCm * po.palletHeightCm / 1000000.0) * po.palletCount
                                  : 0.0);
                          final double poPalletGross = po.palletPlanItems.isNotEmpty
                              ? po.palletPlanItems.fold<double>(0.0, (s, p) => s + (p.grossWeightPerPalletKg * p.palletCount))
                              : (po.palletCount > 0 && po.totalGrossWeightKg > 0 ? po.totalGrossWeightKg : 0.0);
                          final int poPalletCount = po.palletPlanItems.isNotEmpty
                              ? po.palletPlanItems.fold<int>(0, (s, p) => s + p.palletCount)
                              : po.palletCount;

                          final poPlCbm = poPalletCbm > 0
                              ? poPalletCbm
                              : (po.totalCbm > 0 && po.packingListItems.isEmpty
                                  ? po.totalCbm
                                  : (po.packingListItems.isNotEmpty
                                      ? po.packingListItems.fold(0.0, (s, pl) => s + (pl.totalCbm > 0 ? pl.totalCbm : pl.calculatedCbm))
                                      : po.totalCbm));

                          final poPlWeight = poPalletGross > 0
                              ? poPalletGross
                              : (po.totalGrossWeightKg > 0 && po.packingListItems.isEmpty
                                  ? po.totalGrossWeightKg
                                  : (po.packingListItems.isNotEmpty
                                      ? po.packingListItems.fold(0.0, (s, pl) => s + (pl.totalGrossWeightKg > 0 ? pl.totalGrossWeightKg : (pl.grossWeightUnitKg * pl.qtyPkg)))
                                      : po.totalGrossWeightKg));

                          final plText = poPalletCount > 0
                              ? '$poPalletCount ${l.palletsShippingPlan}'
                              : '${po.packingListItems.length} ${l.packingItemsCount}';

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(po.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                                    if (po.displayName != po.poNumber)
                                      LtrText(po.poNumber, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                                  ],
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(8), child: Text(po.proformaInvoiceNumber ?? '-', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(po.supplierName ?? '-', style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade200),
                                  ),
                                  child: Text(
                                    po.paymentTerms ?? '-',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.amber.shade200 : Colors.brown.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${po.currencyCode ?? "USD"} ${po.totalAmountFob.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : Colors.green),
                                ),
                              ),
                              Padding(padding: const EdgeInsets.all(8), child: Text(plText, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null))),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  '${poPlCbm.toStringAsFixed(3)} m³ / ${PoPackingMatcher.formatWeight(poPlWeight)} kg',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  po.statusLabel(context.l10n),
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
              const SizedBox(height: 18),

              // ── Product & Quantity Summary Section ──────────────────────────
              _buildProductQuantitySummary(context, linkedPOs, isAr: isAr, isDark: isDark),

              const SizedBox(height: 18),

              // CARGO STACKING & CONTAINER REQUIREMENT WIDGET (MD-019.1)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF261D33) : Colors.purple.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.purple.shade700.withOpacity(0.5) : Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '🚚 ${l.cargoStackingScenariosTitle}:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cobalt,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.table_chart, size: 14, color: Colors.white),
                              label: Text(
                                l.scenariosMatrixButton,
                                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _showContainerComparisonDialog(
                                context,
                                dualRec,
                                totalPackingListCbm,
                                totalPackingListWeight,
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.cobalt,
                                side: const BorderSide(color: AppTheme.cobalt),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.view_in_ar, size: 14, color: AppTheme.cobalt),
                              label: Text(
                                l.containerLoadPlanButton,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _showVisualLoadPlanDialog(context, linkedPOs),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3 Scenarios stacked under each other:
                    // 1. All Stackable
                    _buildScenarioResultCard(
                      context,
                      title: '📦 ${l.scenarioAllStackableTitle}',
                      fleet: stackableFleet,
                      description: l.multiLayerStacking,
                      badgeColor: isDark ? Colors.green.shade400 : AppTheme.emerald,
                      containerCount: planStackable.length,
                      spaceUtil: stackableSpaceUtil,
                      payloadUtil: stackablePayloadUtil,
                      detailsText: stackableFleet,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),

                    // 2. All Non-Stackable
                    _buildScenarioResultCard(
                      context,
                      title: '🚫 ${l.scenarioAllNonStackableTitle}',
                      fleet: nonStackableFleet,
                      description: l.floorPlacementZ0,
                      badgeColor: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                      containerCount: planNonStackable.length,
                      spaceUtil: nonStackableSpaceUtil,
                      payloadUtil: nonStackablePayloadUtil,
                      detailsText: nonStackableFleet,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),

                    // 3. Mixed Stacking (Actual cargo composition)
                    _buildScenarioResultCard(
                      context,
                      title: '🔀 ${l.scenarioMixedStackingTitle}',
                      fleet: mixedFleet,
                      description: l.mixedStackingCargoDesc(mixedNonStackCount, mixedStackCount),
                      badgeColor: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                      containerCount: planMixed.length,
                      spaceUtil: mixedSpaceUtil,
                      payloadUtil: mixedPayloadUtil,
                      detailsText: mixedFleet,
                      isHighlighted: true,
                      isDark: isDark,
                    ),

                    // SECTION: Saved Shipping Scenarios Evaluation Studies
                    const SizedBox(height: 14),
                    Consumer(
                      builder: (context, ref, child) {
                        final shippingState = ref.watch(shippingScenariosProvider);
                        final linkedStudies = shippingState.sessions.where((s) => s.importFileId == widget.file.importFileId).toList();

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2430) : Colors.blue.shade50.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? AppTheme.cobalt.withOpacity(0.4) : Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.directions_boat, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '🚢 ${l.savedShippingStudiesTitle}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (linkedStudies.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(
                                    '-',
                                    style: TextStyle(color: isDark ? AppTheme.darkTextMuted : Colors.grey, fontStyle: FontStyle.italic, fontSize: 11.5),
                                  ),
                                )
                              else
                                Column(
                                  children: linkedStudies.map((s) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkCardBackground : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blue.shade300),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(s.sessionCode, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt, fontSize: 12)),
                                              const SizedBox(width: 10),
                                              Expanded(child: Text(s.title ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : null), overflow: TextOverflow.ellipsis)),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.green.shade900.withOpacity(0.3) : AppTheme.emerald.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: isDark ? Colors.green.shade700 : AppTheme.emerald.withOpacity(0.3)),
                                                ),
                                                child: Text(
                                                  s.recommendedScenarioProvider ?? "-",
                                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.green.shade300 : AppTheme.emerald, fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Mini report summary card for files
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade200),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(l.targetEta, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                                          Text(s.avgExpectedWarehouseArrivalDate ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null)),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(l.date, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                                          Text('${s.items.isNotEmpty ? s.items.first.readyForShippingDays : 0} d', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Divider(height: 12, color: isDark ? AppTheme.darkBorder : null),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('⚡ Earliest', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                                          Text(s.earliestArrivalScenarioProvider ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                                                          Text(s.earliestArrivalDate ?? "", style: TextStyle(fontSize: 9, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('🐢 Latest', style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey)),
                                                          Text(s.latestArrivalScenarioProvider ?? '-', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade300 : Colors.amber.shade800)),
                                                          Text(s.latestArrivalDate ?? "", style: TextStyle(fontSize: 9, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'CRD: ${s.cargoReadyDate} | ${s.pickUpAddress ?? "-"} | Transit: ${s.avgExpectedTransitDays} d',
                                            style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.black87),
                                          ),
                                          if (s.items.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: s.items.map((opt) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: opt.isRecommended
                                                        ? (isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
                                                        : (isDark ? AppTheme.darkSurface : Colors.grey.shade50),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                      color: opt.isRecommended
                                                          ? (isDark ? Colors.green.shade700 : Colors.green)
                                                          : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '${opt.providerName} (${opt.vesselName}) | POL: ${opt.polName ?? "-"} ➔ POD: ${opt.podName ?? "-"} | ${opt.sailingDate} ➔ ${opt.expectedWarehouseArrivalDate}',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: opt.isRecommended ? FontWeight.bold : FontWeight.normal,
                                                      color: opt.isRecommended
                                                          ? (isDark ? Colors.green.shade300 : AppTheme.charcoal)
                                                          : (isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Smart Recommendation Banner Box
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardBackground : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            modeRec.isAirSuggested
                                ? Icons.airplanemode_active
                                : (modeRec.isLclSuggested ? Icons.inventory : Icons.directions_boat),
                            color: modeRec.isAirSuggested
                                ? (isDark ? Colors.purple.shade300 : Colors.purple)
                                : (modeRec.isLclSuggested
                                    ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                                    : (isDark ? Colors.lightBlueAccent : AppTheme.cobalt)),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAr ? '🚢 ${modeRec.reasonAr}' : '🚢 ${modeRec.reasonEn}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: modeRec.isAirSuggested
                                        ? (isDark ? Colors.purple.shade200 : Colors.purple.shade900)
                                        : (modeRec.isLclSuggested
                                            ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                                            : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$mixedFleet (${Localizations.localeOf(context).languageCode == 'ar' ? modeRec.recommendedModeAr : modeRec.recommendedMode})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.cobalt,
            side: const BorderSide(color: AppTheme.cobalt),
          ),
          icon: const Icon(Icons.mark_email_unread_outlined, color: AppTheme.cobalt, size: 16),
          label: Text(l.freightRfqTooltip, style: const TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () {
            FreightRfqDialog.show(
              context,
              importFileId: file.importFileId,
              importFileCode: file.importFileCode,
              customFileNumber: file.customFileNumber,
            );
          },
        ),
        if (file.status != 'Closed' && widget.onEditPressed != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.cobalt, foregroundColor: Colors.white),
            icon: const Icon(Icons.edit, color: Colors.white, size: 16),
            label: Text(l.editImportFile, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context);
              widget.onEditPressed!();
            },
          ),
        if (file.status != 'Closed')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.pause_circle_outline, color: Colors.white, size: 16),
            label: Text(l.stopShipmentAtThisStageBtn, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (c) => CloseShipmentDialog(
                  importFileId: file.importFileId,
                  importFileCode: file.customFileNumber ?? file.importFileCode,
                  currentPhaseName: file.currentStage,
                ),
              );
            },
          ),
        if (file.status != 'Closed')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.call_split_rounded, color: Colors.white, size: 16),
            label: const Text('إنشاء دفعة جزئية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final created = await showDialog<ImportFileModel>(
                context: context,
                builder: (c) => CreatePartialBatchDialog(parentFile: file),
              );
              if (created != null && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),

      ],
    );
  }


  /// ── Product & Quantity Summary ─────────────────────────────────────────────
  /// Aggregates po.items from all linkedPOs.
  /// If there are multiple distinct HS Codes → renders sub-tabs (one per HS Code + "All").
  Widget _buildProductQuantitySummary(
    BuildContext context,
    List<PurchaseOrderModel> linkedPOs, {
    bool isAr = false,
    bool isDark = false,
  }) {
    // Gather all items from all linked POs
    final allItems = <({
      String description,
      String hsCode,
      double quantity,
      String uom,
      double unitPrice,
      String currency,
      String poNumber,
    })>[];

    for (final po in linkedPOs) {
      if (po.items.isNotEmpty) {
        for (final item in po.items) {
          String resolvedHs = item.hsCode?.trim() ?? '';
          if (resolvedHs.isEmpty && po.packingListItems.isNotEmpty) {
            for (final pl in po.packingListItems) {
              if (pl.hsCode.trim().isNotEmpty) {
                resolvedHs = pl.hsCode.trim();
                break;
              }
            }
          }
          if (resolvedHs.isEmpty && widget.file.hsCode != null) {
            resolvedHs = widget.file.hsCode!.trim();
          }
          allItems.add((
            description: item.itemDescription.trim().isNotEmpty
                ? item.itemDescription.trim()
                : (isAr ? 'منتج غير محدد' : 'Unnamed Product'),
            hsCode: resolvedHs,
            quantity: item.quantity,
            uom: item.unitOfMeasure,
            unitPrice: item.unitPrice,
            currency: po.currencyCode ?? 'USD',
            poNumber: po.poNumber,
          ));
        }
      } else if (po.packingListItems.isNotEmpty) {
        for (final pl in po.packingListItems) {
          allItems.add((
            description: pl.mainDescription?.trim().isNotEmpty == true
                ? pl.mainDescription!.trim()
                : (pl.description?.trim().isNotEmpty == true
                    ? pl.description!.trim()
                    : (isAr ? 'منتج غير محدد' : 'Unnamed Product')),
            hsCode: pl.hsCode.trim(),
            quantity: pl.qtyPcs > 0 ? pl.qtyPcs : pl.qtyPkg,
            uom: pl.packageType.trim().isNotEmpty ? pl.packageType.trim() : 'CTN',
            unitPrice: 0.0,
            currency: po.currencyCode ?? 'USD',
            poNumber: po.poNumber,
          ));
        }
      }
    }

    if (allItems.isEmpty && widget.file.packingListsData.isNotEmpty) {
      for (final pl in widget.file.packingListsData) {
        allItems.add((
          description: widget.file.productCategory ?? (isAr ? 'قائمة تعبئة (${pl.plNo})' : 'Packing List (${pl.plNo})'),
          hsCode: widget.file.hsCode ?? '',
          quantity: pl.totalPackages.toDouble(),
          uom: 'PKG',
          unitPrice: 0.0,
          currency: 'USD',
          poNumber: widget.file.poNumber ?? widget.file.importFileCode,
        ));
      }
    }

    if (allItems.isEmpty) return const SizedBox.shrink();

    // Collect distinct HS Codes (non-empty)
    final distinctHsCodes = <String>{};
    for (final item in allItems) {
      if (item.hsCode.isNotEmpty) distinctHsCodes.add(item.hsCode);
    }
    final hsCodes = distinctHsCodes.toList()..sort();

    const headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );

    // Build a table for a given list of items
    Widget buildTable(List<dynamic> items) {
      return Table(
        border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
        columnWidths: const {
          0: FlexColumnWidth(3.0),
          1: FlexColumnWidth(1.4),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.0),
          4: FlexColumnWidth(1.2),
          5: FlexColumnWidth(1.4),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal),
            children: [
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'المنتج / البيان' : 'Product / Description', style: headerStyle)),
              const Padding(padding: EdgeInsets.all(7), child: Text('HS Code', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'الكمية' : 'Qty', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'الوحدة' : 'UOM', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'سعر الوحدة' : 'Unit Price', style: headerStyle)),
              Padding(padding: const EdgeInsets.all(7), child: Text(isAr ? 'أمر التوريد' : 'PO No.', style: headerStyle)),
            ],
          ),
          ...items.map((rawItem) {
            final item = rawItem as ({
              String description,
              String hsCode,
              double quantity,
              String uom,
              double unitPrice,
              String currency,
              String poNumber,
            });
            final evenRow = items.indexOf(rawItem).isEven;
            return TableRow(
              decoration: BoxDecoration(
                color: evenRow
                    ? (isDark ? AppTheme.darkSurface : null)
                    : (isDark ? AppTheme.darkCardBackground : Colors.grey.shade50),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    item.description,
                    style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: item.hsCode.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.cobalt.withOpacity(isDark ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: AppTheme.cobalt.withOpacity(0.3)),
                          ),
                          child: LtrText(
                            item.hsCode,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt,
                            ),
                          ),
                        )
                      : Text(isAr ? '—' : '—', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextMuted : Colors.grey)),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(2),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(item.uom, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    item.unitPrice > 0 ? '${item.currency} ${item.unitPrice.toStringAsFixed(2)}' : '—',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.green.shade300 : Colors.green.shade700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: LtrText(
                    item.poNumber,
                    style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextMuted : Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withOpacity(0.5) : AppTheme.emerald.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.emerald.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: isDark ? Colors.green.shade300 : AppTheme.emerald, size: 18),
              const SizedBox(width: 8),
              Text(
                isAr ? '📦 ملخص المنتجات والكميات' : '📦 Product & Quantity Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.green.shade900 : AppTheme.emerald).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? Colors.green.shade700 : AppTheme.emerald.withOpacity(0.4)),
                ),
                child: Text(
                  '${allItems.length} ${isAr ? 'بند' : 'items'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.green.shade300 : AppTheme.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // If multiple HS Codes → tabs per HS Code + "All" tab
          if (hsCodes.length > 1) ...[
            DefaultTabController(
              length: hsCodes.length + 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal,
                    child: TabBar(
                      isScrollable: true,
                      indicatorColor: AppTheme.emerald,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(
                          child: Text(
                            isAr ? 'الكل (${allItems.length})' : 'All (${allItems.length})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...hsCodes.map((hs) {
                          final count = allItems.where((i) => i.hsCode == hs).length;
                          return Tab(
                            child: Text(
                              '$hs ($count)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: (allItems.length.clamp(1, 8) * 36.0) + 40,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: buildTable(allItems)),
                        ...hsCodes.map((hs) {
                          final filtered = allItems.where((i) => i.hsCode == hs).toList();
                          return SingleChildScrollView(child: buildTable(filtered));
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Single HS Code or no HS Code — just the table
            buildTable(allItems),
          ],
          if (distinctHsCodes.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              isAr
                  ? '📊 ملخص بنود أوامر التوريد حسب البند الجمركي (PO Line Items Summary By HS Code)'
                  : '📊 PO Line Items Summary By HS Code',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
              columnWidths: const {
                0: FlexColumnWidth(1.6),
                1: FlexColumnWidth(1.8),
                2: FlexColumnWidth(0.9),
                3: FlexColumnWidth(1.1),
                4: FlexColumnWidth(1.3),
                5: FlexColumnWidth(1.3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: isDark ? AppTheme.darkElevatedSurface : AppTheme.cloudWhite),
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'بند التعريفة' : 'HS Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'أوامر التوريد' : 'Linked POs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'الأصناف' : 'Items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'إجمالي الكمية' : 'Total Qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'إجمالي القيمة' : 'Total Value', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: const EdgeInsets.all(6), child: Text(isAr ? 'نسب الرسوم' : 'Duty / VAT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                ),
                ...hsCodes.map((hs) {
                  final matchingItems = allItems.where((i) => i.hsCode == hs).toList();
                  final totalQty = matchingItems.fold<double>(0.0, (sum, i) => sum + i.quantity);
                  final totalAmount = matchingItems.fold<double>(0.0, (sum, i) => sum + (i.quantity * i.unitPrice));
                  final poNumbers = matchingItems.map((i) => i.poNumber).toSet().toList().join(', ');
                  final currency = matchingItems.isNotEmpty ? matchingItems.first.currency : 'USD';
                  final cleanHs = hs.trim();
                  final registeredTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
                  final tariff = registeredTariffs.cast<CustomsTariffModel?>().firstWhere(
                    (t) => t != null && (t.hsCode == cleanHs || t.hsCode.replaceAll('.', '') == cleanHs.replaceAll('.', '')),
                    orElse: () => null,
                  );
                  final dutyRate = tariff?.customsDutyRate ?? 0.0;
                  final vatRate = tariff?.vatRate ?? 14.0;

                  return TableRow(
                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : null),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(hs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(poNumbers, style: TextStyle(fontSize: 10.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade800)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('${matchingItems.length}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(totalQty % 1 == 0 ? totalQty.toInt().toString() : totalQty.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('$currency ${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text('$dutyRate% / $vatRate%', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              isAr
                  ? '🛡️ شروط الاستيراد الرقابية وقواعد الإعفاء لكل بند جمركي (Compliance & Trade Agreements):'
                  : '🛡️ Regulatory Import Conditions & Trade Agreements per HS Code:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            ...hsCodes.map((hs) {
              final cleanHs = hs.trim();
              final registeredTariffs = ref.watch(customsTariffProvider).valueOrNull ?? [];
              final tariff = registeredTariffs.cast<CustomsTariffModel?>().firstWhere(
                (t) => t != null && (t.hsCode == cleanHs || t.hsCode.replaceAll('.', '') == cleanHs.replaceAll('.', '')),
                orElse: () => null,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: HsCodeComplianceInsightCard(
                  hsCode: hs,
                  tariff: tariff,
                  countryOfOrigin: linkedPOs.firstOrNull?.countryOfOrigin,
                  isDark: isDark,
                  isArabic: isAr,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildScenarioResultCard(
    BuildContext context, {
    required String title,
    required String fleet,
    required String description,
    required Color badgeColor,
    required int containerCount,
    required double spaceUtil,
    required double payloadUtil,
    required String detailsText,
    bool isHighlighted = false,
    bool isDark = false,
  }) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? (isDark ? badgeColor.withOpacity(0.18) : badgeColor.withOpacity(0.06))
            : (isDark ? AppTheme.darkSurface : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? badgeColor : (isDark ? AppTheme.darkBorder : Colors.grey.shade300),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: badgeColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? badgeColor.withOpacity(0.25) : badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(
                  fleet,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: badgeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildFileMetricPill(l.containerCountPill, l.containerCountUnit(containerCount), badgeColor, isDark: isDark),
              _buildFileMetricPill(l.spaceAndVolumeUtilPill, '${spaceUtil.toStringAsFixed(1)}%', isDark ? Colors.orange.shade300 : Colors.orange.shade900, isDark: isDark),
              _buildFileMetricPill(l.weightUtilPill, '${payloadUtil.toStringAsFixed(1)}%', isDark ? Colors.tealAccent.shade200 : AppTheme.charcoal, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String value, {required String subtitle, required IconData icon, required Color color, bool isDark = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(isDark ? 0.5 : 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: isDark ? AppTheme.darkTextSecondary : Colors.grey), overflow: TextOverflow.ellipsis, maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildContainersCard(
    BuildContext context,
    ComprehensiveShipmentDossierModel? dossier,
    ImportFileModel file, {
    bool isDark = false,
  }) {
    final containers = dossier?.containers ?? [];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_boat_filled_outlined, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 8),
              Text(
                'حاويات الشحنة ومطابقة أرقام السيل (Containers & Seal Matrix)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
              const Spacer(),
              if (containers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.cobalt.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${containers.length} حاويات مسجلة',
                    style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (containers.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.amber.shade700 : Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: isDark ? Colors.amber.shade300 : Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لم يتم تسجيل الحاويات وأرقام السيل بعد. يتم تأكيدها فور رص الحاويات في مرحلة الشحن الدولي (Phase 5).',
                      style: TextStyle(color: isDark ? Colors.amber.shade300 : Colors.amber.shade900, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: containers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final c = containers[idx];
                final cNo = c['container_no']?.toString() ?? 'CONT-${idx + 1}';
                final cType = c['container_type']?.toString() ?? '-';
                final lSeal = c['liner_seal_no']?.toString() ?? c['seal_no']?.toString() ?? '—';
                final cSeal = c['customs_seal_no']?.toString() ?? '—';
                final tare = c['tare_weight_kg'] ?? 0.0;
                final gross = c['gross_weight_kg'] ?? 0.0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inventory_2, color: AppTheme.cobalt, size: 16),
                          const SizedBox(width: 8),
                          SelectableText(
                            cNo,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildCopyBadge(context, cNo, tooltip: 'نسخ رقم الحاوية'),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              cType,
                              style: const TextStyle(color: AppTheme.cobalt, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 14, color: isDark ? AppTheme.darkBorder : null),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('سيل التوكيل / الخط الملاحي:', style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                            const SizedBox(width: 8),
                            SelectableText(
                              lSeal,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                            ),
                            if (lSeal != '—') ...[
                              const SizedBox(width: 4),
                              _buildCopyBadge(context, lSeal, tooltip: 'نسخ رقم سيل الخط'),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Text('سيل الجمارك / الترصيص الجمركي:', style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade700)),
                            const SizedBox(width: 8),
                            SelectableText(
                              cSeal,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: cSeal != '—' ? AppTheme.emerald : (isDark ? AppTheme.darkTextMuted : Colors.grey.shade600),
                              ),
                            ),
                            if (cSeal != '—') ...[
                              const SizedBox(width: 4),
                              _buildCopyBadge(context, cSeal, tooltip: 'نسخ رقم سيل الجمارك'),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('وزن فارغ: $tare كجم', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                          const SizedBox(width: 14),
                          Text('وزن قائم: $gross كجم', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextSecondary : Colors.grey.shade600)),
                          const Spacer(),
                          Text('VGM: ${c['vgm_status'] ?? "-"}', style: const TextStyle(fontSize: 11, color: AppTheme.emerald, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFxReconciliationCard(
    BuildContext context,
    ComprehensiveShipmentDossierModel? dossier,
    ImportFileModel file, {
    bool isDark = false,
  }) {
    final fx = dossier?.fxReconciliation;
    final customsRate = fx?['customs_exchange_rate'];
    final bankRate = fx?['commercial_bank_exchange_rate'];
    final varianceRate = fx?['fx_variance_rate'] ?? 0.0;
    final varianceTotal = fx?['fx_variance_total_egp'] ?? 0.0;
    final hasVariance = fx?['has_variance'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_exchange_outlined, color: AppTheme.emerald, size: 20),
              const SizedBox(width: 8),
              Text(
                'مطابقة أسعار الصرف وفروق تدبير العملة (FX Variance)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'سعر الصرف الجمركي: ${customsRate != null ? "$customsRate ج.م" : "—"}',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
              ),
              Expanded(
                child: Text(
                  'سعر صرف البنك: ${bankRate != null ? "$bankRate ج.م" : "—"}',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'فرق السعر لكل وحدة عملة: $varianceRate ج.م',
                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.charcoal),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Text('إجمالي الفروق: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal)),
                    Text(
                      '${varianceTotal.toStringAsFixed(2)} ج.م',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: hasVariance ? AppTheme.crimson : AppTheme.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: hasVariance
                  ? (isDark ? Colors.red.shade900.withOpacity(0.3) : AppTheme.crimson.withOpacity(0.08))
                  : (isDark ? Colors.green.shade900.withOpacity(0.3) : AppTheme.emerald.withOpacity(0.08)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  hasVariance ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 14,
                  color: hasVariance ? (isDark ? Colors.red.shade300 : AppTheme.crimson) : (isDark ? Colors.green.shade300 : AppTheme.emerald),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasVariance
                        ? 'يوجد فروق أسعار صرف بين تقييم الجمارك والتحويل البنكي الفعلي تؤثر على تكلفة الوصول.'
                        : 'أسعار الصرف مطابقة تماماً أو لم يتم تسجيل تسويات بنكية بالعملة الأجنبية بعد.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: hasVariance ? (isDark ? Colors.red.shade300 : AppTheme.crimson) : (isDark ? Colors.green.shade300 : AppTheme.emerald),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickExportToolbar(
    BuildContext context,
    ImportFileModel file,
    ComprehensiveShipmentDossierModel? dossier,
    ShipmentUpdatesState updatesState,
    AsyncValue<List<CustomsClearanceModel>> clearanceState,
    AsyncValue<List<WarehouseReceivingModel>> warehouseState, {
    bool isDark = false,
    bool isAr = false,
  }) {
    final clr = clearanceState.valueOrNull?.firstOrNull;
    final wh = warehouseState.valueOrNull?.firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.output_rounded, size: 16, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
          const SizedBox(width: 6),
          Text(
            isAr ? 'أدوات التصدير والمشاركة السريعة:' : 'Quick Export Tools:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
            ),
          ),
          const Spacer(),
          UnifiedDossierExportMenu.row(
            file: file,
            dossier: dossier,
            logs: updatesState.logs,
            clearance: clr,
            warehouse: wh,
          ),
        ],
      ),
    );
  }

  Widget _buildCopyBadge(
    BuildContext context,
    String text, {
    String? tooltip,
    String? customMessage,
    Color? color,
    Color? textColor,
    Color? borderColor,
  }) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final tip = tooltip ?? (isAr ? 'نسخ: $text' : 'Copy: $text');

    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => CopyHelper.copy(context, text, customMessage: customMessage),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color ?? Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor ?? Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? AppTheme.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 11,
                color: textColor ?? Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2.1 Models & Simulations Menu ─────────────────────────────────────────
  Widget _buildModelsAndSimulationsMenu(
    BuildContext context,
    ImportFileModel file, {
    required bool isAr,
    required bool isDark,
  }) {
    return PopupMenuButton<String>(
      tooltip: isAr ? 'نماذج ومحاكاة الشحنة' : 'Models & Simulations',
      position: PopupMenuPosition.under,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 16, color: isDark ? Colors.lightBlueAccent : AppTheme.cobalt),
            const SizedBox(width: 6),
            Text(
              isAr ? 'نماذج ومحاكاة ▾' : 'Models & Sim ▾',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
      onSelected: (action) => _handleSimulationAction(context, file, action),
      itemBuilder: (ctx) => [
        _buildMenuItem(
          value: 'customs_sim',
          icon: Icons.calculate_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'المحاكاة الجمركية' : 'Customs Simulation',
          subtitle: isAr ? 'حساب الرسوم والضرائب التقديرية' : 'Estimated duties & taxes',
        ),
        _buildMenuItem(
          value: 'landed_cost_sim',
          icon: Icons.analytics_outlined,
          iconColor: const Color(0xFF0F766E),
          title: isAr ? 'محاكاة تكلفة الوصول (Landed Cost)' : 'Landed Cost Simulation',
          subtitle: isAr ? 'تقدير تكلفة الوحدة والمصاريف' : 'Unit cost estimation',
        ),
        _buildMenuItem(
          value: 'fn01_advance',
          icon: Icons.payments_outlined,
          iconColor: const Color(0xFFD97706),
          title: isAr ? 'طلب دفعة المورد (FN-01)' : 'Supplier Advance (FN-01)',
          subtitle: isAr ? 'إجراءات الاعتماد البنكي والدفعة' : 'Advance payment workflow',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'cs02_delivery_order',
          icon: Icons.directions_boat_filled_rounded,
          iconColor: const Color(0xFF0284C7),
          title: isAr ? 'سداد إذن التسليم (CS-02)' : 'Delivery Order Payment (CS-02)',
          subtitle: isAr ? 'تسوية رسوم ومصاريف التوكيل الملاحي' : 'Shipping line fees',
        ),
        _buildMenuItem(
          value: 'cl02_duty_assessment',
          icon: Icons.calculate_outlined,
          iconColor: const Color(0xFF7C3AED),
          title: isAr ? 'احتساب الرسوم (CL-02)' : 'Duty Assessment (CL-02)',
          subtitle: isAr ? 'تقييم التعريفة الجمركية والقيمة' : 'Tariff & tax valuation',
        ),
        _buildMenuItem(
          value: 'cl03_duty_payment',
          icon: Icons.receipt_long_rounded,
          iconColor: AppTheme.emerald,
          title: isAr ? 'سداد الرسوم الجمركية (CL-03)' : 'Customs Duty Payment (CL-03)',
          subtitle: isAr ? 'سداد فواتير الجمارك والضرائب' : 'Customs tax payment',
        ),
        _buildMenuItem(
          value: 'cl05_clearance_invoices',
          icon: Icons.receipt_long_outlined,
          iconColor: const Color(0xFF0284C7),
          title: isAr ? 'فواتير التخليص (CL-05)' : 'Clearance Invoices (CL-05)',
          subtitle: isAr ? 'مصاريف المخلص والجهات الرقابية' : 'Brokerage expenses',
        ),
        _buildMenuItem(
          value: 'lsi_partner_invoices',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFF1E3A8A),
          title: isAr ? 'فواتير الشركاء اللوجستيين (LSI)' : 'Logistics Invoices (LSI)',
          subtitle: isAr ? 'مركز فواتير ومطالبات الشركاء' : 'Partner billing hub',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'clo01_settlement',
          icon: Icons.fact_check_outlined,
          iconColor: const Color(0xFF0D9488),
          title: isAr ? 'تسوية الفواتير (CLO-01)' : 'Invoice Settlement (CLO-01)',
          subtitle: isAr ? 'المطابقة النهائية والتسوية المحاسبية' : 'Final matching & settlement',
        ),
        _buildMenuItem(
          value: 'clo02_actual_landed',
          icon: Icons.account_balance_outlined,
          iconColor: const Color(0xFF1E3A8A),
          title: isAr ? 'التكلفة الفعلية (CLO-02)' : 'Actual Landed Cost (CLO-02)',
          subtitle: isAr ? 'حساب تكلفة الوصول النهائية الفردية' : 'Realized landed cost per unit',
        ),
        _buildMenuItem(
          value: 'audit_timeline_radar',
          icon: Icons.history_toggle_off_rounded,
          iconColor: const Color(0xFF0F766E),
          title: isAr ? 'رادار ومحضر التتبع الزمني (36 محطة)' : 'Audit Timeline Radar (36)',
          subtitle: isAr ? 'سجل المحطات والمدد التشغيلية' : 'Full timeline stations SLA',
        ),
      ],
    );
  }

  // ── 2.1 Shipment Documents Menu ───────────────────────────────────────────
  Widget _buildShipmentDocumentsMenu(
    BuildContext context,
    ImportFileModel file, {
    required bool isAr,
    required bool isDark,
  }) {
    return PopupMenuButton<String>(
      tooltip: isAr ? 'مستندات وإجراءات الشحنة' : 'Shipment Documents',
      position: PopupMenuPosition.under,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.grey.shade300),
      ),
      color: isDark ? AppTheme.darkElevatedSurface : Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_shared_outlined, size: 16, color: isDark ? Colors.tealAccent : const Color(0xFF0D9488)),
            const SizedBox(width: 6),
            Text(
              isAr ? 'مستندات الشحنة ▾' : 'Shipment Docs ▾',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
      onSelected: (action) => _handleDocumentAction(context, file, action),
      itemBuilder: (ctx) => [
        _buildMenuItem(
          value: 'dc01_acid',
          icon: Icons.verified_outlined,
          iconColor: const Color(0xFF1E40AF),
          title: isAr ? 'نافذة ورقم ACID (DC-01)' : 'Nafeza & ACID (DC-01)',
          subtitle: isAr ? 'إصدار وتتبع أرقام القيد الجمركي' : 'ACID issuance & tracking',
        ),
        _buildMenuItem(
          value: 'dc03_bank',
          icon: Icons.account_balance_outlined,
          iconColor: const Color(0xFF0D9488),
          title: isAr ? 'المستندات البنكية ونموذج 4 (DC-03)' : 'Bank Documents (DC-03)',
          subtitle: isAr ? 'نموذج 4 البنكي والتحويلات' : 'Form 4 & SWIFT bank docs',
        ),
        _buildMenuItem(
          value: 'dc04_matrix',
          icon: Icons.fact_check_outlined,
          iconColor: const Color(0xFF6366F1),
          title: isAr ? 'مصفوفة المستندات (DC-04)' : 'Document Matrix (DC-04)',
          subtitle: isAr ? 'مسودات الفواتير والباكينج ليست' : 'Drafts & document audit',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'bk01_booking',
          icon: Icons.directions_boat_outlined,
          iconColor: const Color(0xFF0284C7),
          title: isAr ? 'حجز الشحن الملاحي (BK-01)' : 'Freight Booking (BK-01)',
          subtitle: isAr ? 'تأكيد الحجز وتخصيص الحاويات' : 'Booking & container allocation',
        ),
        _buildMenuItem(
          value: 'bk02_free_days',
          icon: Icons.verified_user_outlined,
          iconColor: const Color(0xFF059669),
          title: isAr ? 'فترات السماح (BK-02)' : 'Free Days Agreement (BK-02)',
          subtitle: isAr ? 'أيام السماح وفترات غرامات التأخير' : 'Demurrage free time agreements',
        ),
        _buildMenuItem(
          value: 'sh01_sailing',
          icon: Icons.sailing_rounded,
          iconColor: const Color(0xFF2563EB),
          title: isAr ? 'تأكيد الإبحار (SH-01)' : 'Sailing Confirmation (SH-01)',
          subtitle: isAr ? 'تسجيل تاريخ الإبحار الفعلي والـ ETA' : 'Departure & ETA updates',
        ),
        _buildMenuItem(
          value: 'sh02_draft_bl',
          icon: Icons.fact_check_rounded,
          iconColor: const Color(0xFF059669),
          title: isAr ? 'مراجعة مسودة البوليصة (SH-02)' : 'Draft B/L Review (SH-02)',
          subtitle: isAr ? 'مطابقة بيانات البوليصة قبل الإصدار' : 'B/L data verification',
        ),
        _buildMenuItem(
          value: 'sh03_cargox',
          icon: Icons.cloud_upload_rounded,
          iconColor: const Color(0xFF0284C7),
          title: isAr ? 'مستندات CargoX (SH-03)' : 'CargoX Documents (SH-03)',
          subtitle: isAr ? 'الرفع الرقمي عبر البلوكشين' : 'Blockchain document transfer',
        ),
        _buildMenuItem(
          value: 'sh04_original_docs',
          icon: Icons.markunread_mailbox_rounded,
          iconColor: const Color(0xFFD97706),
          title: isAr ? 'تتبع أصول المستندات (SH-04)' : 'Original Docs Tracking (SH-04)',
          subtitle: isAr ? 'استلام ومتابعة البريد السريع' : 'Courier & original doc tracking',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'cs01_broker_auth',
          icon: Icons.assignment_ind_rounded,
          iconColor: const Color(0xFF7C3AED),
          title: isAr ? 'تفويض المخلص الجمركي (CS-01)' : 'Broker Authorization (CS-01)',
          subtitle: isAr ? 'خطاب تفويض ووكالة التخليص' : 'Broker delegation & power of attorney',
        ),
        _buildMenuItem(
          value: 'cs03_declaration_46',
          icon: Icons.description_rounded,
          iconColor: const Color(0xFFD97706),
          title: isAr ? 'قيد إقرار 46 جمرك (CS-03)' : 'Customs Declaration 46 (CS-03)',
          subtitle: isAr ? 'رقم الشهادة الجمركية وقيد البيان' : 'Customs entry number',
        ),
        _buildMenuItem(
          value: 'cl01_inspection',
          icon: Icons.biotech_rounded,
          iconColor: const Color(0xFF0D9488),
          title: isAr ? 'الكشف والمعاينة وسحب العينات (CL-01)' : 'Inspection & Sampling (CL-01)',
          subtitle: isAr ? 'محاضر الفحص ومعامل الرقابة' : 'Physical inspection records',
        ),
        _buildMenuItem(
          value: 'cl04_final_release',
          icon: Icons.verified_outlined,
          iconColor: AppTheme.emerald,
          title: isAr ? 'إذن الإفراج الجمركي (CL-04)' : 'Customs Final Release (CL-04)',
          subtitle: isAr ? 'الإفراج النهائي وخروج الحاويات' : 'Customs out-of-charge release',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'tr01_inland_transport',
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFF0D9488),
          title: isAr ? 'النقل الداخلي (TR-01)' : 'Inland Transport (TR-01)',
          subtitle: isAr ? 'أوامر التحميل وحركة الشاحنات' : 'Trucking & gate dispatch',
        ),
        _buildMenuItem(
          value: 'tr02_demurrage_radar',
          icon: Icons.radar_rounded,
          iconColor: const Color(0xFFC0392B),
          title: isAr ? 'رادار غرامات الحاويات (TR-02)' : 'Demurrage & Detention Radar',
          subtitle: isAr ? 'تتبع فترات السماح وتفادي الغرامات' : 'Container free-time tracking',
        ),
        _buildMenuItem(
          value: 'tr03_warehouse_receiving',
          icon: Icons.warehouse_rounded,
          iconColor: const Color(0xFF27AE60),
          title: isAr ? 'استلام المخازن (TR-03)' : 'Warehouse Receiving (TR-03)',
          subtitle: isAr ? 'وصول الشحنة وإذن الاستلام' : 'GRN receiving & check-in',
        ),
        _buildMenuItem(
          value: 'tr04_warehouse_inspection',
          icon: Icons.fact_check_rounded,
          iconColor: const Color(0xFFD97706),
          title: isAr ? 'محضر الفحص المخزني (TR-04)' : 'Warehouse Inspection (TR-04)',
          subtitle: isAr ? 'فحص الجودة والمطابقة والكميات' : 'QC & shortage inspection report',
        ),
        _buildMenuItem(
          value: 'tr05_empty_return',
          icon: Icons.assignment_turned_in_rounded,
          iconColor: const Color(0xFF475569),
          title: isAr ? 'إرجاع الحاويات الفارغة (TR-05)' : 'Empty Container Return (TR-05)',
          subtitle: isAr ? 'إيصالات EIR وساحات الإرجاع' : 'EIR slips & depot return',
        ),
        const PopupMenuDivider(),
        _buildMenuItem(
          value: 'clo03_dossier',
          icon: Icons.assignment_turned_in_rounded,
          iconColor: const Color(0xFF7C3AED),
          title: isAr ? 'الملف الشامل (CLO-03)' : 'Comprehensive Dossier (CLO-03)',
          subtitle: isAr ? 'تصدير وأرشفة ملف الشحنة' : 'Full export archive',
        ),
        _buildMenuItem(
          value: 'clo04_official_closure',
          icon: Icons.verified_rounded,
          iconColor: AppTheme.flatEmerald,
          title: isAr ? 'الإغلاق الرسمي للملف (CLO-04)' : 'Official Closure (CLO-04)',
          subtitle: isAr ? 'الأرشفة النهائية وإغلاق الملف' : 'Final archival & closure',
        ),
        _buildMenuItem(
          value: 'smart_checklist',
          icon: Icons.playlist_add_check_circle,
          iconColor: AppTheme.cobalt,
          title: isAr ? 'قائمة التحقق الذكية' : 'Smart Checklist',
          subtitle: isAr ? 'مراجعة متطلبات ومستندات الملف' : 'Interactive readiness check',
        ),
        _buildMenuItem(
          value: 'add_kb_note',
          icon: Icons.psychology_outlined,
          iconColor: const Color(0xFF4F46E5),
          title: isAr ? 'توثيق درس مستفاد (KB Note)' : 'Add Knowledge Note',
          subtitle: isAr ? 'تسجيل ملاحظة في بنك المعرفة' : 'Document institutional learning',
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleSimulationAction(BuildContext context, ImportFileModel file, String action) {
    switch (action) {
      case 'customs_sim':
        showDutyCalculatorDialog(context, ref, initialImportFileId: file.importFileId);
        break;
      case 'fn01_advance':
        showSupplierAdvancePaymentDialog(
          context,
          ref,
          importFileId: file.importFileId,
          importFileCode: file.importFileCode,
          fileTitle: file.displayName,
          supplierId: file.supplierId,
          supplierName: file.supplierName,
          projectId: file.projectIds.isNotEmpty ? file.projectIds.first : null,
          totalAmountForeign: file.estimatedCost > 0 ? file.estimatedCost : null,
          currency: file.estimatedCostCurrency.isNotEmpty ? file.estimatedCostCurrency : 'USD',
        );
        break;
      case 'landed_cost_sim':
        showEstimatedLandedCostDialog(context, ref, importFileId: file.importFileId);
        break;
      case 'cs02_delivery_order':
        DeliveryOrderPaymentDialog.show(context, file);
        break;
      case 'cl02_duty_assessment':
        FinalDutyAssessmentDialog.show(context, file);
        break;
      case 'cl03_duty_payment':
        CustomsDutyPaymentDialog.show(context, file);
        break;
      case 'cl05_clearance_invoices':
        ClearanceExpensesDialog.show(context, file);
        break;
      case 'lsi_partner_invoices':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => LogisticsInvoicesScreen(
              initialShipmentId: file.importFileId,
              initialBlNumber: null,
            ),
          ),
        );
        break;
      case 'clo01_settlement':
        FinalSettlementInvoicesDialog.show(
          context,
          importFileId: file.importFileId,
          importFileCode: file.importFileCode,
        );
        break;
      case 'clo02_actual_landed':
        ActualLandedCostDialog.show(
          context,
          importFileId: file.importFileId,
          importFileCode: file.importFileCode,
        );
        break;
      case 'audit_timeline_radar':
        showShipmentAuditTimelineDialog(context, importFileId: file.importFileId);
        break;
    }
  }

  void _handleDocumentAction(BuildContext context, ImportFileModel file, String action) {
    switch (action) {
      case 'dc01_acid':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NafezaAcidScreen(
              initialImportFileId: file.importFileId,
              initialSubTab: (file.acidNumber != null && file.acidNumber!.isNotEmpty && file.acidNumber != 'PENDING') ? 3 : 0,
            ),
          ),
        );
        break;
      case 'dc03_bank':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BankForm4Screen(
              initialImportFileId: file.importFileId,
              initialSubTab: (file.form4No != null && file.form4No!.isNotEmpty && file.form4No != 'PENDING') ? 1 : 0,
            ),
          ),
        );
        break;
      case 'dc04_matrix':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShipmentDraftDocsScreen(
              initialImportFileId: file.importFileId,
              initialSubTab: 0,
            ),
          ),
        );
        break;
      case 'bk01_booking':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FreightBookingScreen(
              initialImportFileId: file.importFileId,
            ),
          ),
        );
        break;
      case 'bk02_free_days':
        FreeDaysAgreementDialog.show(
          context,
          initialImportFileId: file.importFileId,
          initialDemurrageDays: file.targetFreeDays,
        );
        break;
      case 'sh01_sailing':
        final bookings = ref.read(freightBookingProvider).value ?? [];
        final linkedBooking = bookings.firstWhere(
          (b) => b.importFileId == file.importFileId,
          orElse: () => ShipmentBookingModel(
            bookingId: 0,
            bookingCode: 'NEW-BKG',
            importFileId: file.importFileId,
            importFileCode: file.importFileCode,
            createdAt: '',
            updatedAt: '',
          ),
        );
        if (linkedBooking.bookingId > 0) {
          DepartureConfirmationDialog.show(context, linkedBooking);
        } else {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.snackBar(
              context,
              isAr ? 'يرجى إنشاء وتأكيد حجز الشحن (BK-01) أولاً من شاشة حجز الشحن لتسجيل الإبحار' : 'Please create and confirm freight booking (BK-01) first to record departure',
              severity: AppSeverity.warning,
            ),
          );
        }
        break;
      case 'sh02_draft_bl':
        DraftBLReviewDialog.show(context, file);
        break;
      case 'sh03_cargox':
        CargoXHubDialog.show(context, file);
        break;
      case 'sh04_original_docs':
        OriginalDocumentsCollectionDialog.show(context, file);
        break;
      case 'cs01_broker_auth':
        CustomsBrokerAuthorizationDialog.show(context, file);
        break;
      case 'cs03_declaration_46':
        CustomsDeclaration46Dialog.show(context, file);
        break;
      case 'cl01_inspection':
        CustomsInspectionSamplingDialog.show(context, file);
        break;
      case 'cl04_final_release':
        CustomsFinalReleaseDialog.show(context, file);
        break;
      case 'tr01_inland_transport':
        InlandTransportDialog.show(context, file);
        break;
      case 'tr02_demurrage_radar':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => const DemurrageDetentionScreen(),
          ),
        );
        break;
      case 'tr03_warehouse_receiving':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => const WarehouseReceivingScreen(),
          ),
        );
        break;
      case 'tr04_warehouse_inspection':
        final recs = ref.read(warehouseReceivingProvider).valueOrNull ?? [];
        final matching = recs.where((r) => r.importFileId == file.importFileId).toList();
        final calculatedQty = file.packingListsData.isNotEmpty
            ? file.packingListsData.fold<int>(0, (sum, pl) => sum + pl.totalPackages)
            : 100;
        final targetRec = matching.isNotEmpty
            ? matching.first
            : WarehouseReceivingModel(
                receivingId: file.importFileId,
                grnCode: 'GRN-',
                importFileId: file.importFileId,
                warehouseName: 'Main Warehouse - Cairo',
                arrivalDatetime: DateTime.now().toIso8601String(),
                totalInvoicedQty: calculatedQty > 0 ? calculatedQty : 100,
                totalAcceptedQty: calculatedQty > 0 ? calculatedQty : 100,
                totalShortageQty: 0,
                totalDamagedQty: 0,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
              );
        WarehouseInspectionDialog.show(context, record: targetRec, importFileCode: file.importFileCode);
        break;
      case 'tr05_empty_return':
        EmptyContainerReturnDialog.show(
          context,
          initialImportFileId: file.importFileId,
          initialEirNumber: file.emptyContainersEirNumbers,
          initialDepotName: file.emptyContainersDepotName,
        );
        break;
      case 'clo03_dossier':
        ComprehensiveDossierExportDialog.show(
          context,
          file: file,
        );
        break;
      case 'clo04_official_closure':
        OfficialFileClosureDialog.show(
          context,
          file: file,
        );
        break;
      case 'smart_checklist':
        SmartChecklistDialog.show(context, file);
        break;
      case 'add_kb_note':
        showDialog(
          context: context,
          builder: (ctx) => AddGuideEntryDialog(
            initialSupplier: file.supplierName,
            initialHsCode: file.hsCode,
            initialCategory: file.productCategory,
            initialDestinationPort: file.portOfDischarge,
            initialIncoterm: file.incotermCode,
            initialImportFileReference: file.importFileCode,
            onSuccess: () => _loadExperienceGuide(),
          ),
        );
        break;
    }
  }
}

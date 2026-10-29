import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../import_files/models/import_file_model.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../import_files/widgets/visual_container_load_planner_dialog.dart';
import '../../purchase_orders/models/purchase_order_model.dart';
import '../models/comprehensive_dossier_model.dart';
import 'report_card_container.dart';

/// Cargo stacking, 3D container requirement planning, and packing scenarios section.
class ReportCargoStackingSection extends StatelessWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> allPOs;
  final ComprehensiveShipmentDossierModel? dossier;

  const ReportCargoStackingSection({
    super.key,
    required this.file,
    this.allPOs = const [],
    this.dossier,
  });

  static void showVisualLoadPlanDialog(
    BuildContext context,
    ImportFileModel file,
    List<PurchaseOrderModel> pos,
    double fallbackCbm,
    double fallbackWeight,
  ) {
    showDialog(
      context: context,
      builder: (context) => VisualContainerLoadPlannerDialog(
        file: file,
        linkedPOs: pos,
        fallbackCbm: fallbackCbm,
        fallbackWeight: fallbackWeight,
      ),
    );
  }

  static void showContainerComparisonDialog(
    BuildContext context,
    ContainerDualRecommendationResult dualRec,
    double totalCbm,
    double totalWeightKg,
  ) {
    showDialog(
      context: context,
      builder: (context) {
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${l.totalShipmentSummary}: ${totalCbm.toStringAsFixed(2)} m³ | ${totalWeightKg.toStringAsFixed(0)} kg',
                        style: const TextStyle(fontSize: 12, color: AppTheme.cobalt, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 820,
              height: 500,
              child: Column(
                children: [
                  Container(
                    color: AppTheme.charcoal,
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
                        buildComparisonTable(context, dualRec.stackableResult),
                        buildComparisonTable(context, dualRec.nonStackableResult),
                        buildComparisonTable(context, dualRec.stackableResult),
                      ],
                    ),
                  ),
                ],
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

  static Widget buildComparisonTable(BuildContext context, ContainerRecommendationResult rec) {
    final l = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: rec.isStackable ? AppTheme.emerald.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: rec.isStackable ? AppTheme.emerald : Colors.orange.shade800,
              ),
            ),
            child: Text(
              '${l.approvedRecommendationPrefix}: ${rec.recommendationSummary}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rec.isStackable ? AppTheme.emerald : Colors.orange.shade900,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2.0),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppTheme.charcoal),
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
                  decoration: BoxDecoration(color: isBest ? AppTheme.cobalt.withValues(alpha: 0.08) : null),
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
                              color: isBest ? AppTheme.cobalt : AppTheme.charcoal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '$reqCount',
                        style: TextStyle(fontWeight: isBest ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${effVol.toStringAsFixed(1)} m³',
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${spaceUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: spaceUtil > 80 ? Colors.green : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        '${payloadUtil.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: payloadUtil > 80 ? Colors.green : Colors.black,
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
    final linkedPOs = ImportFilePoLinker.getLinkedPOs(file: file, allPOs: allPOs);
    final metrics = ImportFilePoLinker.computeMetrics(file: file, linkedPOs: linkedPOs);
    final totalPackingListCbm = metrics.cbm > 0 ? metrics.cbm : (dossier?.totalCbm ?? 0.0);
    final totalPackingListWeight = metrics.weightKg > 0 ? metrics.weightKg : (dossier?.grossWeightKg ?? 0.0);

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

    final planStackable = ContainerRequirementEngine.planShipment(baseCargoItems, forceStackable: true);
    final planNonStackable = ContainerRequirementEngine.planShipment(baseCargoItems, forceStackable: false);
    final planMixed = ContainerRequirementEngine.planShipment(baseCargoItems, forceStackable: null);

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

    return ReportCardContainer(
      title: 'دراسة رص وتوزيع البضائع واحتياج الحاويات (Cargo Stacking & Containers)',
      icon: Icons.inventory_2_outlined,
      iconColor: Colors.purple.shade700,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'سيناريوهات التحميل واحتياج أسطول الشحن:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.charcoal),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.cobalt,
                      side: const BorderSide(color: AppTheme.cobalt),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.table_chart_outlined, size: 14),
                    label: Text(l.scenariosMatrixButton, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => showContainerComparisonDialog(
                      context,
                      dualRec,
                      totalPackingListCbm,
                      totalPackingListWeight,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: const Icon(Icons.view_in_ar, size: 14),
                    label: Text(l.containerLoadPlanButton, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => showVisualLoadPlanDialog(
                      context,
                      file,
                      linkedPOs,
                      totalPackingListCbm,
                      totalPackingListWeight,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3 Side-by-Side Scenarios
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 720;
              final stackableCard = buildScenarioResultCard(
                context,
                title: l.containerStackableTab,
                fleet: stackableFleet,
                description: 'رص رأسي مزدوج (أعلى كفاءة حجمية)',
                badgeColor: AppTheme.emerald,
                containerCount: planStackable.length,
                spaceUtil: stackableSpaceUtil,
                payloadUtil: stackablePayloadUtil,
                detailsText: '${planStackable.length} حاويات | استغلال ${stackableSpaceUtil.toStringAsFixed(1)}%',
                isHighlighted: modeRec.recommendedMode == 'FCL',
              );
              final nonStackableCard = buildScenarioResultCard(
                context,
                title: l.containerNonStackableTab,
                fleet: nonStackableFleet,
                description: 'رص أرضي مفرد (للبضائع الحساسة والهشة)',
                badgeColor: Colors.orange.shade800,
                containerCount: planNonStackable.length,
                spaceUtil: nonStackableSpaceUtil,
                payloadUtil: nonStackablePayloadUtil,
                detailsText: '${planNonStackable.length} حاويات | استغلال ${nonStackableSpaceUtil.toStringAsFixed(1)}%',
              );
              final mixedCard = buildScenarioResultCard(
                context,
                title: l.containerMixedTab,
                fleet: mixedFleet,
                description: 'واقعي ($mixedStackCount قابل للرص + $mixedNonStackCount غير قابل)',
                badgeColor: Colors.purple.shade700,
                containerCount: planMixed.length,
                spaceUtil: mixedSpaceUtil,
                payloadUtil: mixedPayloadUtil,
                detailsText: '${planMixed.length} حاويات | استغلال ${mixedSpaceUtil.toStringAsFixed(1)}%',
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: stackableCard),
                    const SizedBox(width: 8),
                    Expanded(child: nonStackableCard),
                    const SizedBox(width: 8),
                    Expanded(child: mixedCard),
                  ],
                );
              }
              return Column(
                children: [
                  stackableCard,
                  const SizedBox(height: 8),
                  nonStackableCard,
                  const SizedBox(height: 8),
                  mixedCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Widget buildScenarioResultCard(
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
  }) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHighlighted ? badgeColor.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? badgeColor : Colors.grey.shade300,
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
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  fleet,
                  style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  '${l.spaceUtilizationPercent}: ${spaceUtil.toStringAsFixed(1)}% | ${l.weightUtilizationPercent}: ${payloadUtil.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.charcoal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

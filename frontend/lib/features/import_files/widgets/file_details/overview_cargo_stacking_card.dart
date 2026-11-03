// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../../../core/utils/import_file_po_linker.dart';
import '../../../purchase_orders/models/purchase_order_model.dart';
import '../../models/import_file_model.dart';
import '../visual_container_load_planner_dialog.dart';
import 'container_comparison_dialog.dart';
import 'overview_saved_shipping_studies_card.dart';

/// 🚚 Cargo Stacking & Container Requirements Card for Overview Tab
class OverviewCargoStackingCard extends ConsumerWidget {
  final ImportFileModel file;
  final List<PurchaseOrderModel> linkedPOs;
  final double totalPackingListCbm;
  final double totalPackingListWeight;
  final bool isDark;
  final bool isAr;

  const OverviewCargoStackingCard({
    super.key,
    required this.file,
    required this.linkedPOs,
    required this.totalPackingListCbm,
    required this.totalPackingListWeight,
    required this.isDark,
    required this.isAr,
  });

  void _showVisualLoadPlanDialog(BuildContext context, List<PurchaseOrderModel> pos) {
    showDialog(
      context: context,
      builder: (context) => VisualContainerLoadPlannerDialog(
        file: file,
        linkedPOs: pos,
        fallbackCbm: totalPackingListCbm,
        fallbackWeight: totalPackingListWeight,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

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

    return SelectionArea(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevatedSurface : Colors.purple.shade50.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? Colors.purple.shade700.withValues(alpha: 0.5) : Colors.purple.shade200),
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
                    AppButton(
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.primary,
                      icon: Icons.table_chart,
                      label: l.scenariosMatrixButton,
                      onPressed: () => ContainerComparisonDialog.show(
                        context,
                        dualRec,
                        totalPackingListCbm,
                        totalPackingListWeight,
                      ),
                    ),
                    AppButton(
                      size: AppButtonSize.small,
                      variant: AppButtonVariant.secondary,
                      icon: Icons.view_in_ar,
                      label: l.containerLoadPlanButton,
                      onPressed: () => _showVisualLoadPlanDialog(context, linkedPOs),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

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

            _buildScenarioResultCard(
              context,
              title: '🚫 ${l.scenarioAllNonStackableTitle}',
              fleet: nonStackableFleet,
              description: l.floorPlacementZ0,
              badgeColor: isDark ? Colors.orange.shade300 : AppTheme.orange,
              containerCount: planNonStackable.length,
              spaceUtil: nonStackableSpaceUtil,
              payloadUtil: nonStackablePayloadUtil,
              detailsText: nonStackableFleet,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

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

            // SECTION: Saved Shipping Scenarios Studies
            const SizedBox(height: 14),
            OverviewSavedShippingStudiesCard(
              importFileId: file.importFileId,
              isDark: isDark,
              isAr: isAr,
            ),

            // Smart Mode Recommendation Banner
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
                            ? (isDark ? Colors.amber.shade300 : AppTheme.orange)
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
                          '$mixedFleet (${isAr ? modeRec.recommendedModeAr : modeRec.recommendedMode})',
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
            ? badgeColor.withValues(alpha: isDark ? 0.18 : 0.06)
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
                  color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
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
              _buildFileMetricPill(l.spaceAndVolumeUtilPill, '${spaceUtil.toStringAsFixed(1)}%', isDark ? Colors.orange.shade300 : AppTheme.orange, isDark: isDark),
              _buildFileMetricPill(l.weightUtilPill, '${payloadUtil.toStringAsFixed(1)}%', isDark ? Colors.tealAccent.shade200 : AppTheme.charcoal, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileMetricPill(String label, String value, Color color, {bool isDark = false}) {
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
        color: effectiveColor.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: effectiveColor.withValues(alpha: isDark ? 0.5 : 0.3)),
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
}

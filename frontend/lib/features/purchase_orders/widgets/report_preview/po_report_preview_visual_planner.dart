import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/services/container_load_plan_export_service.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/container_requirement_engine.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import 'po_report_preview_helpers.dart';
import 'po_visual_load_plan_card.dart';

/// Interactive 3D/2D visual container load simulation dialog for PO preview.
class POVisualLoadPlannerDialog {
  static void show({
    required BuildContext context,
    required String poNumber,
    required String companyName,
    required String supplierName,
    required List<PackingListItemModel> packingItems,
    required List<PalletPlanItemModel> palletItems,
    required bool isDirectVolumeMode,
  }) {
    final l = context.l10n;
    if (packingItems.isEmpty && palletItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.enterPackingOrPalletsNotice));
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final cargoItems = generateSimulationCargoItems(
      packingItems: packingItems,
      palletItems: palletItems,
      isDirectVolumeMode: isDirectVolumeMode,
      isArabic: isArabic,
    );

    if (cargoItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(AppTheme.snackBar(context, l.enterPackingOrPalletsNotice));
      return;
    }

    final GlobalKey previewPlannerRepaintKey = GlobalKey();
    final displayName = 'PO $poNumber';
    bool isTopView = true;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final plan = ContainerRequirementEngine.planShipment(
              cargoItems,
              forceStackable: activeStackingMode,
              forceOrientation: activeOrientationMode,
            );

            final totalPkgs = cargoItems.length;
            final stackableInActive = activeStackingMode == true
                ? totalPkgs
                : (activeStackingMode == false ? 0 : cargoItems.where((c) => c.isStackable).length);
            final nonStackableInActive = totalPkgs - stackableInActive;
            final totalPlanWeight = plan.fold(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold(0.0, (s, p) => s + p.totalVolume);

            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }

            final fleetSummary = containerCounts.isEmpty
                ? (isArabic ? 'لا توجد حاويات مناسبة' : 'No suitable containers')
                : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return SelectionArea(
              child: Dialog(
                insetPadding: const EdgeInsets.all(16),
                child: Container(
                  width: 1180,
                  height: 780,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(
                        context: context,
                        dialogCtx: dialogCtx,
                        l: l,
                        displayName: displayName,
                        poNumber: poNumber,
                        companyName: companyName,
                        supplierName: supplierName,
                        previewPlannerRepaintKey: previewPlannerRepaintKey,
                        isArabic: isArabic,
                        plan: plan,
                        fleetSummary: fleetSummary,
                        totalPlanWeight: totalPlanWeight,
                        totalPlanVolume: totalPlanVolume,
                        totalPkgs: totalPkgs,
                      ),
                      const SizedBox(height: 10),
                      _buildControlBar(
                        l: l,
                        activeStackingMode: activeStackingMode,
                        activeOrientationMode: activeOrientationMode,
                        isTopView: isTopView,
                        onStackingChanged: (stacking, orientation) {
                          setDialogState(() {
                            activeStackingMode = stacking;
                            activeOrientationMode = orientation;
                          });
                        },
                        onProjectionChanged: (topView) => setDialogState(() => isTopView = topView),
                      ),
                      const SizedBox(height: 10),
                      _buildSummaryBar(
                        l: l,
                        fleetSummary: fleetSummary,
                        totalPkgs: totalPkgs,
                        stackableInActive: stackableInActive,
                        nonStackableInActive: nonStackableInActive,
                        totalPlanWeight: totalPlanWeight,
                        totalPlanVolume: totalPlanVolume,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: RepaintBoundary(
                          key: previewPlannerRepaintKey,
                          child: ListView.builder(
                            itemCount: plan.length,
                            itemBuilder: (ctx, pIdx) {
                              final res = plan[pIdx];
                              if (res.containerCode == 'FAILED') return _buildFailedCard(res, l);
                              return POContainerLoadPlanCard(index: pIdx, plan: res, isTopView: isTopView);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildHeader({
    required BuildContext context,
    required BuildContext dialogCtx,
    required AppLocalizations l,
    required String displayName,
    required String poNumber,
    required String companyName,
    required String supplierName,
    required GlobalKey previewPlannerRepaintKey,
    required bool isArabic,
    required List<ContainerPackingResult> plan,
    required String fleetSummary,
    required double totalPlanWeight,
    required double totalPlanVolume,
    required int totalPkgs,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 26),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.containerLoadPlan3dTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal)),
                Text(l.containerLoadPlan3dSubtitle, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.image_outlined, color: AppTheme.cobalt),
              tooltip: context.l10n.poDownloadSimulationImagePNG,
              onPressed: () async {
                await ContainerLoadPlanExportService.exportSimulationImage(
                  context: dialogCtx,
                  repaintKey: previewPlannerRepaintKey,
                  displayName: '$displayName - 3D Simulation',
                  isArabic: isArabic,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.crimson),
              tooltip: context.l10n.poDownloadLoadingPlanPDF,
              onPressed: () async {
                await ContainerLoadPlanExportService.exportLoadingPlanPdf(
                  context: dialogCtx,
                  repaintKey: previewPlannerRepaintKey,
                  displayName: displayName,
                  poNumber: poNumber,
                  companyName: companyName,
                  supplierName: supplierName,
                  plan: plan,
                  fleetSummary: fleetSummary,
                  totalPlanWeight: totalPlanWeight,
                  totalPlanVolume: totalPlanVolume,
                  totalPkgs: totalPkgs,
                  isArabic: isArabic,
                );
              },
            ),
            const SizedBox(width: 4),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(dialogCtx)),
          ],
        ),
      ],
    );
  }

  static Widget _buildControlBar({
    required AppLocalizations l,
    required bool? activeStackingMode,
    required CargoOrientationPreference activeOrientationMode,
    required bool isTopView,
    required void Function(bool? stacking, CargoOrientationPreference orientation) onStackingChanged,
    required void Function(bool topView) onProjectionChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.charcoalSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cloudWhite),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(l.stackingSimulationModeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal)),
            const SizedBox(width: 10),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l.smartHybridOption)),
                ButtonSegment(value: 1, label: Text(l.flatOnlyOption)),
                ButtonSegment(value: 2, label: Text(l.simulationModeFloorOnly)),
                ButtonSegment(value: 3, label: Text(l.simulationModeActualMixed)),
              ],
              selected: {
                activeStackingMode == false
                    ? 2
                    : (activeStackingMode == null
                        ? 3
                        : (activeOrientationMode == CargoOrientationPreference.smartHybrid ? 0 : 1))
              },
              onSelectionChanged: (val) {
                final sel = val.first;
                if (sel == 0) {
                  onStackingChanged(true, CargoOrientationPreference.smartHybrid);
                } else if (sel == 1) {
                  onStackingChanged(true, CargoOrientationPreference.flatOnly);
                } else if (sel == 2) {
                  onStackingChanged(false, activeOrientationMode);
                } else if (sel == 3) {
                  onStackingChanged(null, activeOrientationMode);
                }
              },
            ),
            const SizedBox(width: 20),
            Text(l.projectionLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.charcoal)),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l.topViewProjection)),
                ButtonSegment(value: false, label: Text(l.sideViewProjection)),
              ],
              selected: {isTopView},
              onSelectionChanged: (val) => onProjectionChanged(val.first),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSummaryBar({
    required AppLocalizations l,
    required String fleetSummary,
    required int totalPkgs,
    required int stackableInActive,
    required int nonStackableInActive,
    required double totalPlanWeight,
    required double totalPlanVolume,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.charcoal.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
              const SizedBox(width: 6),
              Text(l.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, color: AppTheme.charcoal, size: 18),
              const SizedBox(width: 6),
              Text(l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
              const SizedBox(width: 6),
              Text(l.totalWeightSummary(formatPOWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
              const SizedBox(width: 6),
              Text(l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildFailedCard(ContainerPackingResult res, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.crimsonLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.crimsonBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.crimson, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              res.failureReason ?? l.packingFailureTitle,
              style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

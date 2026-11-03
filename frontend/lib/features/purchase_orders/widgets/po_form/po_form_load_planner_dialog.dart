import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/container_load_plan_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/container_requirement_engine.dart';
import '../../models/purchase_order_model.dart';
import 'planner/po_load_planner_cargo_builder.dart';
import 'planner/po_load_planner_container_card.dart';
import 'planner/po_load_planner_controls_bar.dart';
import 'planner/po_load_planner_kpi_banner.dart';

/// 3D Container Load Planner modal dialog for PO Packing & Pallet plan items.
class PoFormLoadPlannerDialog {
  static void show(
    BuildContext context, {
    required List<PackingListItemModel> packingItems,
    required List<PalletPlanItemModel> palletPlanItems,
    required bool isDirectVolumeMode,
    String? poNumber,
    String? companyName,
    String? supplierName,
  }) {
    final cargoItems = PoLoadPlannerCargoBuilder.buildCargoItems(
      context: context,
      packingItems: packingItems,
      palletPlanItems: palletPlanItems,
      isDirectVolumeMode: isDirectVolumeMode,
    );

    if (cargoItems.isEmpty) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.snackBar(
          context,
          isAr
              ? 'يرجى إدخال أصناف قائمة التعبئة أو البالتات أولاً للمحاكاة'
              : 'Please enter packing items or pallets first to simulate load plan',
          severity: AppSeverity.warning,
        ),
      );
      return;
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final GlobalKey formPlannerRepaintKey = GlobalKey();
    final effectivePoNumber = (poNumber != null && poNumber.trim().isNotEmpty) ? poNumber.trim() : 'Draft';
    final displayName = 'PO $effectivePoNumber';
    String viewProjection = 'both';
    bool showDetailedCoordinates = false;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;

    showDialog(
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
                      // Header Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 26),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.containerLoadPlan3dTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.charcoal),
                                  ),
                                  Text(
                                    context.l10n.containerLoadPlan3dSubtitle,
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
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
                                    repaintKey: formPlannerRepaintKey,
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
                                    repaintKey: formPlannerRepaintKey,
                                    displayName: displayName,
                                    poNumber: effectivePoNumber,
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
                      ),
                      const SizedBox(height: 10),

                      // Controls & Stacking Filter Row
                      PoLoadPlannerControlsBar(
                        activeOrientationMode: activeOrientationMode,
                        activeStackingMode: activeStackingMode,
                        viewProjection: viewProjection,
                        isArabic: isArabic,
                        onModeChanged: (orientation, stacking) {
                          setDialogState(() {
                            activeOrientationMode = orientation;
                            activeStackingMode = stacking;
                          });
                        },
                        onProjectionChanged: (proj) {
                          setDialogState(() => viewProjection = proj);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Fleet KPI Summary Banner
                      PoLoadPlannerKpiBanner(
                        fleetSummary: fleetSummary,
                        totalPkgs: totalPkgs,
                        stackableInActive: stackableInActive,
                        nonStackableInActive: nonStackableInActive,
                        totalPlanWeight: totalPlanWeight,
                        totalPlanVolume: totalPlanVolume,
                      ),
                      const SizedBox(height: 10),

                      // Plan Containers List
                      Expanded(
                        child: RepaintBoundary(
                          key: formPlannerRepaintKey,
                          child: ListView.builder(
                            itemCount: plan.length,
                            itemBuilder: (ctx, pIdx) {
                              final res = plan[pIdx];
                              return PoLoadPlannerContainerCard(
                                index: pIdx,
                                res: res,
                                viewProjection: viewProjection,
                                showDetailedCoordinates: showDetailedCoordinates,
                                isArabic: isArabic,
                                onToggleDetailedCoordinates: () {
                                  setDialogState(() => showDetailedCoordinates = !showDetailedCoordinates);
                                },
                              );
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
}

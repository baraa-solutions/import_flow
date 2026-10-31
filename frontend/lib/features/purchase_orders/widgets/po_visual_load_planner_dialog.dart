import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/container_requirement_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/services/container_load_plan_export_service.dart';
import '../models/purchase_order_model.dart';
import '../utils/po_packing_matcher.dart';
import 'po_table_cells.dart';
import 'po_details_dialog.dart';

class PoVisualLoadPlannerDialog {
  static void show(BuildContext context, PurchaseOrderModel po) {
    final cargoItems = PoDetailsDialog.extractCargoItems(po);

    if (cargoItems.isEmpty) {
      final l = context.l10n;
      AppTheme.snackBar(
        context,
        l.noCargoOrPalletToSimulate,
        severity: AppSeverity.warning,
      );
      return;
    }

    String viewProjection = 'both';
    bool showDetailedCoordinates = false;
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;
    final GlobalKey dialogRepaintKey = GlobalKey();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final l = dialogCtx.l10n;
        final isArabic = Localizations.localeOf(dialogCtx).languageCode == 'ar';
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
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
                ? l.noSuitableContainers
                : containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');

            return SelectionArea(
              child: Dialog(
                backgroundColor: isDark ? AppTheme.darkSurface : null,
                insetPadding: const EdgeInsets.all(16),
                child: Container(
                  width: math.min(1180.0, MediaQuery.of(dialogCtx).size.width - 32),
                  height: math.min(780.0, MediaQuery.of(dialogCtx).size.height - 48),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Bar
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.cobalt.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.view_in_ar_rounded, color: AppTheme.cobalt, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.containerLoadPlanTitle(po.displayName, po.poNumber),
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                                Text(
                                  l.containerLoadPlanMetrics(totalPlanVolume.toStringAsFixed(3), PoPackingMatcher.formatWeight(totalPlanWeight), fleetSummary),
                                  style: TextStyle(fontSize: 11.5, color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.image_outlined, color: AppTheme.cobalt),
                            tooltip: context.l10n.poDownloadSimulationImagePNG,
                            onPressed: () async {
                              await ContainerLoadPlanExportService.exportSimulationImage(
                                context: dialogCtx,
                                repaintKey: dialogRepaintKey,
                                displayName: '${po.displayName} - 3D Simulation',
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
                                repaintKey: dialogRepaintKey,
                                displayName: po.displayName,
                                poNumber: po.poNumber,
                                companyName: po.companyName,
                                supplierName: po.supplierName,
                                plan: plan,
                                fleetSummary: fleetSummary,
                                totalPlanWeight: totalPlanWeight,
                                totalPlanVolume: totalPlanVolume,
                                totalPkgs: totalPkgs,
                                isArabic: isArabic,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Controls & Stacking Filter Row (Responsive Wrap)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCardBackground : AppTheme.charcoalSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                        ),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '🔄 ${l.stackingSimulationModeLabel}:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                                ChoiceChip(
                                  label: Text('✨ ${l.smartHybridOption}'),
                                  selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true,
                                  selectedColor: AppTheme.emerald,
                                  labelStyle: TextStyle(
                                    color: (activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode == true) ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      setDialogState(() {
                                        activeOrientationMode = CargoOrientationPreference.smartHybrid;
                                        activeStackingMode = true;
                                      });
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: Text('📐 ${l.flatOnlyOption}'),
                                  selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true,
                                  selectedColor: AppTheme.cobalt,
                                  labelStyle: TextStyle(
                                    color: (activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode == true) ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      setDialogState(() {
                                        activeOrientationMode = CargoOrientationPreference.flatOnly;
                                        activeStackingMode = true;
                                      });
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: Text('🚫 ${l.simulationModeFloorOnly}'),
                                  selected: activeStackingMode == false,
                                  selectedColor: AppTheme.wcagOrange,
                                  labelStyle: TextStyle(
                                    color: activeStackingMode == false ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      setDialogState(() {
                                        activeStackingMode = false;
                                      });
                                    }
                                  },
                                ),
                                ChoiceChip(
                                  label: Text('🔀 ${l.simulationModeActualMixed}'),
                                  selected: activeStackingMode == null,
                                  selectedColor: AppTheme.charcoal,
                                  labelStyle: TextStyle(
                                    color: activeStackingMode == null ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) {
                                      setDialogState(() {
                                        activeStackingMode = null;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '👁️ ${l.projectionLabel}:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                ),
                                ChoiceChip(
                                  label: Text(context.l10n.poBothViews),
                                  selected: viewProjection == 'both',
                                  selectedColor: AppTheme.cobalt,
                                  labelStyle: TextStyle(
                                    color: viewProjection == 'both' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) setDialogState(() => viewProjection = 'both');
                                  },
                                ),
                                ChoiceChip(
                                  label: Text('📐 ${l.sideViewProjection}'),
                                  selected: viewProjection == 'side',
                                  selectedColor: AppTheme.cobalt,
                                  labelStyle: TextStyle(
                                    color: viewProjection == 'side' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) setDialogState(() => viewProjection = 'side');
                                  },
                                ),
                                ChoiceChip(
                                  label: Text('🔝 ${l.topViewProjection}'),
                                  selected: viewProjection == 'top',
                                  selectedColor: AppTheme.cobalt,
                                  labelStyle: TextStyle(
                                    color: viewProjection == 'top' ? AppTheme.white : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) setDialogState(() => viewProjection = 'top');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Fleet KPI Summary Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : AppTheme.charcoal.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.charcoal.withValues(alpha: 0.12)),
                        ),
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceAround,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_boat_rounded, color: AppTheme.cobalt, size: 20),
                                const SizedBox(width: 6),
                                Text(l.requiredContainersSummary(fleetSummary), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal, size: 18),
                                const SizedBox(width: 6),
                                Text(l.totalPackagesSummary(totalPkgs, stackableInActive, nonStackableInActive), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppTheme.darkTextPrimary : null)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.scale_outlined, color: AppTheme.emerald, size: 18),
                                const SizedBox(width: 6),
                                Text(l.totalWeightSummary(PoPackingMatcher.formatWeight(totalPlanWeight)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.view_in_ar, color: AppTheme.orange, size: 18),
                                const SizedBox(width: 6),
                                Text(l.totalVolumeSummary(totalPlanVolume.toStringAsFixed(3)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.orange)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Plan Containers List (Wrapped in RepaintBoundary for PNG/PDF Export)
                      Expanded(
                        child: RepaintBoundary(
                          key: dialogRepaintKey,
                          child: ListView.builder(
                            itemCount: plan.length,
                            itemBuilder: (ctx, pIdx) {
                              final res = plan[pIdx];
                              if (res.containerCode == 'FAILED') {
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.crimsonLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? AppTheme.crimson : AppTheme.crimsonBorder),
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

                              final spacePct = (res.totalVolume / res.spec.internalVolumeCbm * 100);
                              final weightPct = (res.totalWeight / res.spec.maxPayloadKg * 100);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              l.containerCardHeader(pIdx + 1, res.spec.code, res.placedItems.length, spacePct.toStringAsFixed(1), weightPct.toStringAsFixed(1)),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.cobalt),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.cobalt.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              l.internalDimensionsLabel(res.spec.internalLength.toStringAsFixed(0), res.spec.internalWidth.toStringAsFixed(0), res.spec.internalHeight.toStringAsFixed(0)),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (viewProjection == 'both') ...[
                                        // Side View (Left Wall Removed)
                                        Container(
                                          height: 190,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppTheme.charcoal,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: CustomPaint(
                                            painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        // Top View (Roof Removed)
                                        Container(
                                          height: 150,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppTheme.charcoal,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: CustomPaint(
                                            painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          height: 320,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: AppTheme.charcoal,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: CustomPaint(
                                            painter: ContainerLoadPlanPainter(plan: res, isTopView: viewProjection == 'top'),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),

                                      // Placed Items Details Table (Aggregated by Item Rule)
                                      Theme(
                                        data: Theme.of(dialogCtx).copyWith(dividerColor: Colors.transparent),
                                        child: ExpansionTile(
                                          initiallyExpanded: true,
                                          tilePadding: EdgeInsets.zero,
                                          title: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                showDetailedCoordinates
                                                    ? (context.l10n.poDetailedPlacementCoordinatesPkgs(res.placedItems.length))
                                                    : (context.l10n.poGroupedItemsItemsTotalPkgs(res.groupedItems.length, res.placedItems.length)),
                                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                              ),
                                              AppButton(
                                                label: showDetailedCoordinates ? (context.l10n.poGroupByItems) : (context.l10n.poDetailedCoordinates),
                                                icon: showDetailedCoordinates ? Icons.table_chart_outlined : Icons.format_list_numbered,
                                                variant: AppButtonVariant.secondary,
                                                size: AppButtonSize.small,
                                                onPressed: () => setDialogState(() => showDetailedCoordinates = !showDetailedCoordinates),
                                              ),
                                            ],
                                          ),
                                          children: [
                                            if (!showDetailedCoordinates)
                                              Table(
                                                border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                                columnWidths: const {
                                                  0: FlexColumnWidth(0.6),
                                                  1: FlexColumnWidth(2.5),
                                                  2: FlexColumnWidth(1.2),
                                                  3: FlexColumnWidth(1.6),
                                                  4: FlexColumnWidth(1.2),
                                                  5: FlexColumnWidth(1.8),
                                                  6: FlexColumnWidth(1.2),
                                                  7: FlexColumnWidth(1.2),
                                                },
                                                children: [
                                                  TableRow(
                                                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                                    children: [
                                                      const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      PoHeaderCell(context.l10n.poItemCode, fontSize: 11),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poPkgType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poDimsCm, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.qtyCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poGrossWt2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poCBM2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.poStack, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                    ],
                                                  ),
                                                  ...res.groupedItems.asMap().entries.map((entry) {
                                                    final idx = entry.key + 1;
                                                    final g = entry.value;
                                                    return TableRow(
                                                      children: [
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text(g.itemCodeOrDesc, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text(g.packageType, style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('${g.length.toStringAsFixed(0)} × ${g.width.toStringAsFixed(0)} × ${g.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(
                                                          padding: const EdgeInsets.all(6),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: AppTheme.cobalt.withValues(alpha: 0.12),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text('${g.count}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt), textAlign: TextAlign.center),
                                                          ),
                                                        ),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('${PoPackingMatcher.formatWeight(g.totalWeight)} kg', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('${g.volumeM3.toStringAsFixed(3)} m³', style: const TextStyle(fontSize: 11, color: AppTheme.orange, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text(g.isStackable ? (context.l10n.poYes) : (context.l10n.poFloor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              )
                                            else
                                              Table(
                                                border: TableBorder.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                                                columnWidths: const {
                                                  0: FlexColumnWidth(0.8),
                                                  1: FlexColumnWidth(2.2),
                                                  2: FlexColumnWidth(1.8),
                                                  3: FlexColumnWidth(1.2),
                                                  4: FlexColumnWidth(2.0),
                                                  5: FlexColumnWidth(1.2),
                                                },
                                                children: [
                                                  TableRow(
                                                    decoration: BoxDecoration(color: isDark ? AppTheme.darkSurface : AppTheme.cloudWhite),
                                                    children: [
                                                      const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      PoHeaderCell(l.thPackageCode, fontSize: 11),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                      Padding(padding: const EdgeInsets.all(6), child: Text(l.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                                                    ],
                                                  ),
                                                  ...res.placedItems.asMap().entries.map((entry) {
                                                    final idx = entry.key + 1;
                                                    final item = entry.value;
                                                    return TableRow(
                                                      children: [
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppTheme.darkTextPrimary : null))),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text(PoPackingMatcher.formatWeight(item.item.weight), style: TextStyle(fontSize: 11, color: isDark ? AppTheme.darkTextPrimary : null), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                                                        Padding(padding: const EdgeInsets.all(6), child: Text(item.item.isStackable ? (context.l10n.poYes) : (context.l10n.poFloor), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson), textAlign: TextAlign.center)),
                                                      ],
                                                    );
                                                  }),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

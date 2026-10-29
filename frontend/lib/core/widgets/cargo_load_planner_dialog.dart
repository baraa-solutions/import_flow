import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../features/cbm_calculator/models/cbm_calculator_model.dart';
import '../../features/purchase_orders/models/purchase_order_model.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';
import '../utils/container_requirement_engine.dart';
import 'buttons/app_button.dart';
import 'container_load_plan_painter.dart';
import 'copyable_data_helper.dart';

/// 🚢 Unified 3D Container Load Planner Dialog — ImportFlow ERP
///
/// Single Source of Truth for visual container load simulation and 3D packing.
/// Complies with:
/// - SelectionArea universal drag-selection.
/// - Pure localization via `context.l10n`.
/// - CopyHelper for sanitized Bidi clipboard copying.
/// - Responsive dialog constraints on 1366x768.
class CargoLoadPlannerDialog {
  CargoLoadPlannerDialog._();

  /// Primary display method using raw [CargoItem]s.
  static void show(
    BuildContext context, {
    required List<CargoItem> cargoItems,
    String? title,
  }) {
    final l = context.l10n;
    if (cargoItems.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => SelectionArea(
          child: AlertDialog(
            title: Text(title ?? l.cbmCalculatorTitle),
            content: Text(l.noDataFound),
            actions: [
              AppButton(
                label: l.ok,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Default active view mode: null = Actual/Mixed, true = All Stackable, false = All Non-Stackable
    bool? activeStackingMode = cargoItems.any((i) => !i.isStackable) ? null : true;
    CargoOrientationPreference activeOrientationMode = CargoOrientationPreference.smartHybrid;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
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

            final totalPlanWeight = plan.fold<double>(0.0, (s, p) => s + p.totalWeight);
            final totalPlanVolume = plan.fold<double>(0.0, (s, p) => s + p.totalVolume);

            final Map<String, int> containerCounts = {};
            for (final p in plan) {
              if (p.containerCode != 'FAILED') {
                containerCounts[p.containerCode] = (containerCounts[p.containerCode] ?? 0) + 1;
              }
            }
            final fleetSummaryText = containerCounts.entries.map((e) => '${e.value} x ${e.key}').join(' + ');
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return SelectionArea(
              child: AlertDialog(
                backgroundColor: isDark ? AppTheme.darkCardBackground : AppTheme.white,
                title: Row(
                  children: [
                    const Icon(Icons.view_in_ar, color: AppTheme.cobalt, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title ?? l.visualLoadPlanSimulator,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cobalt.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cobalt),
                      ),
                      child: Text(
                        '${l.requiredFleet}: ${fleetSummaryText.isEmpty ? '-' : fleetSummaryText} (${plan.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: math.min(1050.0, MediaQuery.of(context).size.width * 0.95),
                  height: math.min(680.0, MediaQuery.of(context).size.height * 0.85),
                  child: Column(
                    children: [
                      // 1. Scenario & Orientation Mode Switcher
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoalSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text(
                              l.chooseStackingScenario,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                ChoiceChip(
                                  label: Text(l.smartHybridOption),
                                  selected: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode != false,
                                  selectedColor: AppTheme.emerald,
                                  labelStyle: TextStyle(
                                    color: activeOrientationMode == CargoOrientationPreference.smartHybrid && activeStackingMode != false
                                        ? AppTheme.white
                                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  label: Text(l.flatOnlyOption),
                                  selected: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode != false,
                                  selectedColor: AppTheme.wcagCobalt,
                                  labelStyle: TextStyle(
                                    color: activeOrientationMode == CargoOrientationPreference.flatOnly && activeStackingMode != false
                                        ? AppTheme.white
                                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  label: Text(l.allNonStackableOption),
                                  selected: activeStackingMode == false,
                                  selectedColor: AppTheme.wcagOrange,
                                  labelStyle: TextStyle(
                                    color: activeStackingMode == false
                                        ? AppTheme.white
                                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
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
                                  label: Text(l.mixedStackingOption),
                                  selected: activeStackingMode == null,
                                  selectedColor: AppTheme.cobalt,
                                  labelStyle: TextStyle(
                                    color: activeStackingMode == null
                                        ? AppTheme.white
                                        : (isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  onSelected: (val) {
                                    if (val) setDialogState(() => activeStackingMode = null);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 2. Metrics Strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkElevatedSurface : AppTheme.charcoal.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.cloudWhite),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildMetricPill(l.qtyCol, '$totalPkgs', AppTheme.cobalt),
                                const SizedBox(width: 8),
                                _buildMetricPill(l.grossWeightMetric, '${totalPlanWeight.toStringAsFixed(0)} kg', isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal),
                                const SizedBox(width: 8),
                                _buildMetricPill(l.totalCbmVolumeMetric, '${totalPlanVolume.toStringAsFixed(3)} m³', AppTheme.wcagOrange),
                              ],
                            ),
                            Row(
                              children: [
                                _buildMetricPill(l.stackableOption, '$stackableInActive', AppTheme.wcagEmerald),
                                const SizedBox(width: 8),
                                _buildMetricPill(l.nonStackableOption, '$nonStackableInActive', AppTheme.crimson),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 3. Table summary of container loads
                      Table(
                        border: TableBorder.all(color: AppTheme.cloudWhite),
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1.8),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(2.4),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: AppTheme.charcoal.withValues(alpha: 0.08)),
                            children: [
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.containerSpecCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.packageTypeCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.grossWeightMetric, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.spaceUtilizationCol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(l.cargoStackingInstructions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                            ],
                          ),
                          ...plan.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final res = entry.value;
                            final placedIds = res.placedItems.map((p) => p.item.itemId).join(', ');
                            final totalPlacedCount = res.placedItems.length;

                            final double volSpaceUtil = res.spec.internalVolumeCbm > 0 ? (res.totalVolume / res.spec.internalVolumeCbm) * 100 : 0.0;
                            final double floorAreaM2 = res.placedItems.fold(0.0, (s, p) => s + p.item.floorAreaM2);
                            final double specFloorAreaM2 = (res.spec.internalLength * res.spec.internalWidth) / 10000;
                            final double floorUtil = specFloorAreaM2 > 0 ? (floorAreaM2 / specFloorAreaM2) * 100 : 0.0;

                            final bool hasNonStackable = res.placedItems.any((p) => !p.item.isStackable);
                            final double displaySpaceUtil = hasNonStackable ? math.max(volSpaceUtil, floorUtil) : volSpaceUtil;

                            String statusText = '';
                            if (res.containerCode == 'FAILED' || !res.fits) {
                              statusText = res.failureReason ?? l.operationFailed;
                            } else {
                              final nonStackInThis = res.placedItems.where((p) => !p.item.isStackable).length;
                              if (nonStackInThis > 0) {
                                statusText = '${l.nonStackableOption} ($nonStackInThis) - ${floorUtil.toStringAsFixed(1)}%';
                              } else {
                                statusText = '${l.stackableOption} ($totalPlacedCount)';
                              }
                            }

                            final containerLabel = res.containerCode == 'FAILED' ? l.operationFailed : '$idx: ${res.spec.code}';
                            final pkgsLabel = placedIds.isEmpty ? '-' : '$placedIds ($totalPlacedCount)';
                            final wtLabel = res.containerCode == 'FAILED' ? '-' : '${res.totalWeight.toStringAsFixed(0)} kg';
                            final rowSummary = '$containerLabel | $pkgsLabel | $wtLabel | ${displaySpaceUtil.toStringAsFixed(1)}% | $statusText';

                            return TableRow(
                              children: [
                                CopyableTableCell(
                                  value: containerLabel,
                                  rowSummary: rowSummary,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(
                                      containerLabel,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.cobalt, fontSize: 11),
                                    ),
                                  ),
                                ),
                                CopyableTableCell(
                                  value: pkgsLabel,
                                  rowSummary: rowSummary,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(pkgsLabel, style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                                CopyableTableCell(
                                  value: wtLabel,
                                  rowSummary: rowSummary,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(wtLabel, style: const TextStyle(fontSize: 11)),
                                  ),
                                ),
                                CopyableTableCell(
                                  value: '${displaySpaceUtil.toStringAsFixed(1)}%',
                                  rowSummary: rowSummary,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(
                                      '${displaySpaceUtil.toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.orange),
                                    ),
                                  ),
                                ),
                                CopyableTableCell(
                                  value: statusText,
                                  rowSummary: rowSummary,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: statusText.contains(l.operationFailed)
                                            ? AppTheme.crimson
                                            : AppTheme.wcagEmerald,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 4. Visual container load diagrams
                      Expanded(
                        child: ListView.builder(
                          itemCount: plan.length,
                          itemBuilder: (ctx, pIdx) {
                            final res = plan[pIdx];
                            if (res.containerCode == 'FAILED') {
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
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            res.failureReason ?? 'FAILED',
                                            style: const TextStyle(color: AppTheme.crimson, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          if (res.unplacedItems.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '# ${res.unplacedItems.map((u) => u.itemId).join(', ')}',
                                              style: const TextStyle(color: AppTheme.crimson, fontSize: 11),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${l.containerPlanTitle} #${pIdx + 1}: ${res.spec.name} (${res.spec.code})',
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppTheme.cobaltLight, borderRadius: BorderRadius.circular(4)),
                                          child: Text(
                                            '${l.internalDimensions}: ${res.spec.internalLength.toStringAsFixed(0)} x ${res.spec.internalWidth.toStringAsFixed(0)} x ${res.spec.internalHeight.toStringAsFixed(0)} cm',
                                            style: const TextStyle(fontSize: 10, color: AppTheme.cobalt),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Side View
                                    Container(
                                      height: 190,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppTheme.charcoal,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: CustomPaint(
                                        painter: ContainerLoadPlanPainter(plan: res, isTopView: false),
                                        child: Container(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Top View
                                    Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppTheme.charcoal,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: CustomPaint(
                                        painter: ContainerLoadPlanPainter(plan: res, isTopView: true),
                                        child: Container(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  AppButton(
                    label: l.closePlan,
                    icon: Icons.close,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Adapter for converting [CBMItemModel] list directly.
  static void showFromCbmItems(
    BuildContext context, {
    required List<CBMItemModel> items,
    String? title,
  }) {
    final List<CargoItem> cargoItems = [];
    int itemCounter = 1;

    for (final item in items) {
      for (int q = 0; q < item.quantity; q++) {
        double lCm = item.length;
        double wCm = item.width;
        double hCm = item.height;
        if (item.unit == 'mm') {
          lCm /= 10;
          wCm /= 10;
          hCm /= 10;
        } else if (item.unit == 'm') {
          lCm *= 100;
          wCm *= 100;
          hCm *= 100;
        }

        cargoItems.add(CargoItem(
          itemId: '$itemCounter',
          length: lCm,
          width: wCm,
          height: hCm,
          weight: item.grossWeightPerUnitKg,
          rotate: true,
          isStackable: item.isStackable,
          packageType: item.packageType,
        ));
        itemCounter++;
      }
    }

    show(context, cargoItems: cargoItems, title: title);
  }

  /// Adapter for converting [PurchaseOrderModel] list directly.
  static void showFromPurchaseOrders(
    BuildContext context, {
    required List<PurchaseOrderModel> pos,
    double totalCbm = 0.0,
    double totalWeight = 0.0,
    String? title,
  }) {
    final List<CargoItem> baseCargoItems = [];
    int itemCounter = 1;

    for (final po in pos) {
      final hasPalletPlan = po.palletPlanItems.isNotEmpty && po.palletPlanItems.any((p) => p.palletCount > 0);
      final hasSinglePallet = po.palletCount > 0 && po.palletLengthCm > 0 && po.palletWidthCm > 0 && po.palletHeightCm > 0;

      if (hasPalletPlan) {
        final double totalGross = po.packingListItems.fold<double>(
          0.0,
          (sum, p) => sum + (p.totalGrossWeightKg > 0 ? p.totalGrossWeightKg : (p.qtyPkg * p.grossWeightUnitKg)),
        );
        final int totalPallets = po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
        final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

        for (final pLine in po.palletPlanItems) {
          final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
          final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
          final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
          final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

          for (int i = 0; i < pLine.palletCount; i++) {
            baseCargoItems.add(CargoItem(
              itemId: 'PLT-$itemCounter',
              length: pL,
              width: pW,
              height: pH,
              weight: pWt,
              isStackable: pLine.isStackable,
              rotate: true,
              packageType: pLine.palletType,
              description: 'Pallet #$itemCounter (${pLine.palletType})',
            ));
            itemCounter++;
          }
        }
      } else if (hasSinglePallet) {
        final double pWt = po.totalGrossWeightKg > 0 ? (po.totalGrossWeightKg / po.palletCount) : 137.5;
        for (int i = 0; i < po.palletCount; i++) {
          baseCargoItems.add(CargoItem(
            itemId: 'PLT-$itemCounter',
            length: po.palletLengthCm,
            width: po.palletWidthCm,
            height: po.palletHeightCm,
            weight: pWt,
            isStackable: po.isPalletStackable,
            rotate: true,
            packageType: po.palletType,
            description: 'Pallet #$itemCounter (${po.palletType})',
          ));
          itemCounter++;
        }
      } else if (po.packingListItems.isNotEmpty) {
        for (final pl in po.packingListItems) {
          for (int q = 0; q < pl.qtyPkg.toInt(); q++) {
            double lCm = pl.lengthCm;
            double wCm = pl.widthCm;
            double hCm = pl.heightCm;
            if (pl.unit == 'mm') {
              lCm /= 10;
              wCm /= 10;
              hCm /= 10;
            } else if (pl.unit == 'm') {
              lCm *= 100;
              wCm *= 100;
              hCm *= 100;
            }

            baseCargoItems.add(CargoItem(
              itemId: '$itemCounter',
              length: lCm > 0 ? lCm : 100.0,
              width: wCm > 0 ? wCm : 80.0,
              height: hCm > 0 ? hCm : 60.0,
              weight: pl.grossWeightUnitKg > 0 ? pl.grossWeightUnitKg : (pl.totalGrossWeightKg / (pl.qtyPkg > 0 ? pl.qtyPkg : 1)),
              rotate: true,
              isStackable: pl.isStackable,
              packageType: pl.packageType,
            ));
            itemCounter++;
          }
        }
      }
    }

    if (baseCargoItems.isEmpty && totalCbm > 0) {
      final double targetCbm = totalCbm;
      final double targetWeight = totalWeight > 0 ? totalWeight : 1000.0;
      final int numPallets = (targetCbm / 2.0).ceil().clamp(1, 50);
      final double perPalletCbm = targetCbm / numPallets;
      final double perPalletWeight = targetWeight / numPallets;

      for (int i = 0; i < numPallets; i++) {
        baseCargoItems.add(CargoItem(
          itemId: 'PLT-$itemCounter',
          length: 120.0,
          width: 80.0,
          height: math.min(220.0, (perPalletCbm / (1.2 * 0.8)) * 100),
          weight: perPalletWeight,
          isStackable: true,
          rotate: true,
          packageType: 'Auto-Simulated Pallet',
          description: 'Auto Pallet #$itemCounter (${perPalletCbm.toStringAsFixed(2)} CBM)',
        ));
        itemCounter++;
      }
    }

    show(context, cargoItems: baseCargoItems, title: title);
  }

  static Widget _buildMetricPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

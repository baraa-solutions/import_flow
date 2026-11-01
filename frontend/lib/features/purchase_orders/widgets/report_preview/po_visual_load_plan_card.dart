import 'package:flutter/material.dart';
import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/container_requirement_engine.dart';
import 'package:frontend/core/widgets/container_load_plan_painter.dart';
import 'package:frontend/features/purchase_orders/models/purchase_order_model.dart';
import '../po_table_cells.dart';
import 'po_report_preview_helpers.dart';

/// Container load card displaying 3D/2D painted projection and placed packages table.
class POContainerLoadPlanCard extends StatelessWidget {
  final int index;
  final ContainerPackingResult plan;
  final bool isTopView;

  const POContainerLoadPlanCard({
    super.key,
    required this.index,
    required this.plan,
    required this.isTopView,
  });

  @override
  Widget build(BuildContext context) {
    final spacePct = (plan.totalVolume / plan.spec.internalVolumeCbm * 100);
    final weightPct = (plan.totalWeight / plan.spec.maxPayloadKg * 100);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    context.l10n.containerCardHeader(
                      index + 1,
                      plan.spec.code,
                      plan.placedItems.length,
                      spacePct.toStringAsFixed(1),
                      weightPct.toStringAsFixed(1),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppTheme.cobalt),
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
                    context.l10n.internalDimensionsLabel(
                      plan.spec.internalLength.toStringAsFixed(0),
                      plan.spec.internalWidth.toStringAsFixed(0),
                      plan.spec.internalHeight.toStringAsFixed(0),
                    ),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.cobalt),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 380,
              child: CustomPaint(
                size: const Size(double.infinity, 380),
                painter: ContainerLoadPlanPainter(plan: plan, isTopView: isTopView),
              ),
            ),
            const SizedBox(height: 10),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.placedPackagesTableTitle(plan.placedItems.length),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.charcoal),
                ),
                children: [
                  Table(
                    border: TableBorder.all(color: AppTheme.cloudWhite),
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
                        decoration: const BoxDecoration(color: AppTheme.cloudWhite),
                        children: [
                          const Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          PoHeaderCell(context.l10n.thPackageCode, fontSize: 11),
                          Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thDimensions, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thWeight, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thCoordinates, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                          Padding(padding: const EdgeInsets.all(6), child: Text(context.l10n.thStacking, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                        ],
                      ),
                      ...plan.placedItems.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(item.item.description ?? item.item.itemId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${item.length.toStringAsFixed(0)} × ${item.width.toStringAsFixed(0)} × ${item.height.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(formatPOWeight(item.item.weight), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text('X: ${item.x.toStringAsFixed(0)} | Y: ${item.y.toStringAsFixed(0)} | Z: ${item.z.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'), textAlign: TextAlign.center)),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.item.isStackable ? context.l10n.stackableOption : context.l10n.nonStackableOption,
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: item.item.isStackable ? AppTheme.emerald : AppTheme.crimson),
                                textAlign: TextAlign.center,
                              ),
                            ),
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
  }
}

/// Helper for constructing CargoItems for visual simulation.
List<CargoItem> generateSimulationCargoItems({
  required List<PackingListItemModel> packingItems,
  required List<PalletPlanItemModel> palletItems,
  required bool isDirectVolumeMode,
  required bool isArabic,
}) {
  final hasPallets = palletItems.isNotEmpty && palletItems.any((p) => p.palletCount > 0);
  final List<CargoItem> cargoItems = [];

  if (isDirectVolumeMode || hasPallets) {
    final double totalGross = packingItems.fold<double>(0.0, (sum, p) => sum + p.computedTotalGrossWeightKg);
    final int totalPallets = palletItems.fold<int>(0, (sum, p) => sum + p.palletCount);
    final double defaultPalletWeight = totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

    int globalIdx = 1;
    for (final pLine in palletItems) {
      final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
      final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
      final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
      final pWt = pLine.grossWeightPerPalletKg > 0 ? pLine.grossWeightPerPalletKg : defaultPalletWeight;

      for (int i = 0; i < pLine.palletCount; i++) {
        final floorOnlyText = isArabic ? ' [أرضية فقط]' : ' [Floor Only]';
        cargoItems.add(CargoItem(
          itemId: 'PLT-$globalIdx',
          length: pL,
          width: pW,
          height: pH,
          weight: pWt,
          isStackable: pLine.isStackable,
          rotate: true,
          packageType: pLine.palletType,
          description: isArabic
              ? 'بالتة #$globalIdx (${pLine.palletType})${pLine.isStackable ? "" : floorOnlyText}'
              : 'Pallet #$globalIdx (${pLine.palletType})${pLine.isStackable ? "" : floorOnlyText}',
        ));
        globalIdx++;
      }
    }
  } else {
    int globalIdx = 1;
    for (final p in packingItems) {
      final lCm = p.unit == 'mm' ? p.lengthCm / 10.0 : (p.unit == 'm' ? p.lengthCm * 100.0 : p.lengthCm);
      final wCm = p.unit == 'mm' ? p.widthCm / 10.0 : (p.unit == 'm' ? p.widthCm * 100.0 : p.widthCm);
      final hCm = p.unit == 'mm' ? p.heightCm / 10.0 : (p.unit == 'm' ? p.heightCm * 100.0 : p.heightCm);
      final int count = p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1;
      final double unitGrossWt = p.grossWeightUnitKg > 0
          ? p.grossWeightUnitKg
          : (p.totalGrossWeightKg > 0 ? (p.totalGrossWeightKg / count) : 10.0);

      for (int i = 0; i < count; i++) {
        final pkgLabel = isArabic ? 'طرد ${i + 1}/$count' : 'Pkg ${i + 1}/$count';
        cargoItems.add(CargoItem(
          itemId: '$globalIdx',
          length: lCm > 0 ? lCm : 100.0,
          width: wCm > 0 ? wCm : 80.0,
          height: hCm > 0 ? hCm : 60.0,
          weight: unitGrossWt,
          isStackable: p.isStackable,
          rotate: true,
          packageType: p.packageType,
          description: count > 1 ? '${p.itemCode} ($pkgLabel)' : p.itemCode,
        ));
        globalIdx++;
      }
    }
  }
  return cargoItems;
}

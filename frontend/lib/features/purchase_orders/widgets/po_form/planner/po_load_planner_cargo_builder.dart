import 'package:flutter/material.dart';
import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../models/purchase_order_model.dart';

class PoLoadPlannerCargoBuilder {
  static List<CargoItem> buildCargoItems({
    required BuildContext context,
    required List<PackingListItemModel> packingItems,
    required List<PalletPlanItemModel> palletPlanItems,
    required bool isDirectVolumeMode,
  }) {
    final hasPallets = isDirectVolumeMode &&
        palletPlanItems.isNotEmpty &&
        palletPlanItems.any((p) => p.palletCount > 0);
    final List<CargoItem> cargoItems = [];

    if (hasPallets) {
      final double totalGross = packingItems.fold<double>(
        0.0,
        (sum, p) => sum + p.computedTotalGrossWeightKg,
      );
      final int totalPallets = palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
      final double defaultPalletWeight =
          totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

      int globalIdx = 1;
      for (final pLine in palletPlanItems) {
        final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
        final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
        final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
        final pWt = pLine.grossWeightPerPalletKg > 0
            ? pLine.grossWeightPerPalletKg
            : defaultPalletWeight;

        for (int i = 0; i < pLine.palletCount; i++) {
          final isAr = Localizations.localeOf(context).languageCode == 'ar';
          final palletDesc = isAr
              ? 'بالتة #$globalIdx - ${pLine.palletType}${pLine.isStackable ? "" : " [أرضي]"}'
              : 'Pallet #$globalIdx - ${pLine.palletType}${pLine.isStackable ? "" : " [Floor Only]"}';

          cargoItems.add(CargoItem(
            itemId: 'PLT-$globalIdx',
            length: pL,
            width: pW,
            height: pH,
            weight: pWt,
            isStackable: pLine.isStackable,
            rotate: true,
            packageType: pLine.palletType,
            description: palletDesc,
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

        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        for (int i = 0; i < count; i++) {
          final pkgDesc = count > 1
              ? (isAr ? '${p.itemCode} (طرد ${i + 1}/$count)' : '${p.itemCode} (Pkg ${i + 1}/$count)')
              : p.itemCode;

          cargoItems.add(CargoItem(
            itemId: '$globalIdx',
            length: lCm > 0 ? lCm : 100.0,
            width: wCm > 0 ? wCm : 80.0,
            height: hCm > 0 ? hCm : 60.0,
            weight: unitGrossWt,
            isStackable: p.isStackable,
            rotate: true,
            packageType: p.packageType,
            description: pkgDesc,
          ));
          globalIdx++;
        }
      }
    }

    return cargoItems;
  }
}

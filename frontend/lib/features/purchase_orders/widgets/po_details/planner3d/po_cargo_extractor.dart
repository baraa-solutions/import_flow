import '../../../../../core/utils/container_requirement_engine.dart';
import '../../../models/purchase_order_model.dart';

class PoCargoExtractor {
  /// Extracts cargo items from a purchase order's pallet plan or packing list.
  static List<CargoItem> extract(PurchaseOrderModel po) {
    final hasPalletPlan = po.palletPlanItems.isNotEmpty &&
        po.palletPlanItems.any((p) => p.palletCount > 0);
    final hasSinglePallet = po.palletCount > 0 &&
        po.palletLengthCm > 0 &&
        po.palletWidthCm > 0 &&
        po.palletHeightCm > 0;
    List<CargoItem> cargoItems = [];

    if (hasPalletPlan) {
      final double totalGross = po.packingListItems.fold<double>(
        0.0,
        (sum, p) =>
            sum +
            (p.totalGrossWeightKg > 0
                ? p.totalGrossWeightKg
                : (p.qtyPkg * p.grossWeightUnitKg)),
      );
      final int totalPallets =
          po.palletPlanItems.fold<int>(0, (sum, p) => sum + p.palletCount);
      final double defaultPalletWeight =
          totalPallets > 0 && totalGross > 0 ? (totalGross / totalPallets) : 137.5;

      int globalIdx = 1;
      for (final pLine in po.palletPlanItems) {
        final pL = pLine.lengthCm > 0 ? pLine.lengthCm : 120.0;
        final pW = pLine.widthCm > 0 ? pLine.widthCm : 80.0;
        final pH = pLine.heightCm > 0 ? pLine.heightCm : 150.0;
        final pWt = pLine.grossWeightPerPalletKg > 0
            ? pLine.grossWeightPerPalletKg
            : defaultPalletWeight;

        for (int i = 0; i < pLine.palletCount; i++) {
          cargoItems.add(CargoItem(
            itemId: 'PLT-$globalIdx',
            length: pL,
            width: pW,
            height: pH,
            weight: pWt,
            isStackable: pLine.isStackable,
            rotate: true,
            packageType: pLine.palletType,
            description:
                '${pLine.palletType} #$globalIdx${pLine.isStackable ? "" : " [Floor Only]"}',
          ));
          globalIdx++;
        }
      }
    } else if (hasSinglePallet) {
      final double pWt = po.totalGrossWeightKg > 0
          ? (po.totalGrossWeightKg / po.palletCount)
          : 137.5;
      for (int i = 0; i < po.palletCount; i++) {
        cargoItems.add(CargoItem(
          itemId: 'PLT-${i + 1}',
          length: po.palletLengthCm,
          width: po.palletWidthCm,
          height: po.palletHeightCm,
          weight: pWt,
          isStackable: po.isPalletStackable,
          rotate: true,
          packageType: po.palletType,
          description:
              '${po.palletType} #${i + 1}${po.isPalletStackable ? "" : " [Floor Only]"}',
        ));
      }
    } else if (po.packingListItems.isNotEmpty) {
      int globalIdx = 1;
      for (final p in po.packingListItems) {
        final lCm = p.unit == 'mm'
            ? p.lengthCm / 10.0
            : (p.unit == 'm' ? p.lengthCm * 100.0 : p.lengthCm);
        final wCm = p.unit == 'mm'
            ? p.widthCm / 10.0
            : (p.unit == 'm' ? p.widthCm * 100.0 : p.widthCm);
        final hCm = p.unit == 'mm'
            ? p.heightCm / 10.0
            : (p.unit == 'm' ? p.heightCm * 100.0 : p.heightCm);
        final int count = p.qtyPkg > 0 ? p.qtyPkg.toInt() : 1;
        final double unitGrossWt = p.grossWeightUnitKg > 0
            ? p.grossWeightUnitKg
            : (p.totalGrossWeightKg > 0
                ? (p.totalGrossWeightKg / count)
                : 10.0);

        for (int i = 0; i < count; i++) {
          cargoItems.add(CargoItem(
            itemId: '$globalIdx',
            length: lCm > 0 ? lCm : 100.0,
            width: wCm > 0 ? wCm : 80.0,
            height: hCm > 0 ? hCm : 60.0,
            weight: unitGrossWt,
            isStackable: p.isStackable,
            rotate: true,
            packageType: p.packageType,
            description: count > 1 ? '${p.itemCode} ($count / ${i + 1})' : p.itemCode,
          ));
          globalIdx++;
        }
      }
    }
    return cargoItems;
  }
}

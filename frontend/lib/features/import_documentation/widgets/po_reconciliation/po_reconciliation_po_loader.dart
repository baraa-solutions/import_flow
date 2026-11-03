import '../../../purchase_orders/models/purchase_order_model.dart' as po_models;
import '../../models/import_documentation_model.dart';

class PoReconciliationLoadedItems {
  final List<POReconciliationItemModel> invoiceItems;
  final List<POReconciliationItemModel> packingItems;

  const PoReconciliationLoadedItems({
    required this.invoiceItems,
    required this.packingItems,
  });
}

/// Helper for loading and transforming Purchase Order lines and packing items into reconciliation items.
class PoReconciliationPoLoader {
  static PoReconciliationLoadedItems loadPOItems(List<po_models.PurchaseOrderModel> linkedPOs) {
    List<POReconciliationItemModel> invList = [];
    List<POReconciliationItemModel> plList = [];

    for (var po in linkedPOs) {
      final pkgMap = <String, po_models.PackingListItemModel>{};
      for (var plItm in po.packingListItems) {
        final code = plItm.itemCode.trim().toLowerCase();
        if (code.isNotEmpty) pkgMap[code] = plItm;
      }

      for (var itm in po.items) {
        final itmCode = itm.itemCode ?? 'ITEM-${itm.itemId ?? 0}';
        final itmDesc = itm.descriptionAr.isNotEmpty ? itm.descriptionAr : (itm.descriptionEn ?? 'PO Line Item');

        final matchedPl = pkgMap[itmCode.trim().toLowerCase()];
        final double pkgCountFromPl = (matchedPl != null && matchedPl.qtyPkg > 0) ? matchedPl.qtyPkg.toDouble() : 0.0;

        invList.add(POReconciliationItemModel(
          poItemId: itm.itemId,
          itemCode: itmCode,
          description: itmDesc,
          hsCode: itm.hsCode,
          initialQuantity: itm.quantity,
          finalQuantity: itm.quantity,
          initialUnitPrice: itm.unitPrice,
          unitPrice: itm.unitPrice,
          finalUnitPrice: itm.unitPrice,
          initialPackagesCount: pkgCountFromPl,
          finalPackagesCount: pkgCountFromPl,
          initialGrossWeightKg: itm.grossWeightKg,
          finalGrossWeightKg: itm.grossWeightKg,
          initialNetWeightKg: itm.netWeightKg,
          finalNetWeightKg: itm.netWeightKg,
          initialCbm: itm.totalCbm,
          finalCbm: itm.totalCbm,
        ));
      }

      for (var plItm in po.packingListItems) {
        final itmCode = plItm.itemCode.isNotEmpty ? plItm.itemCode : 'ITEM-${plItm.packingItemId ?? 0}';
        final matchingPoItem = po.items.where((i) => i.itemCode?.trim().toLowerCase() == itmCode.trim().toLowerCase()).firstOrNull;
        final itmDesc = (plItm.description?.isNotEmpty == true)
            ? plItm.description!
            : (matchingPoItem?.descriptionAr.isNotEmpty == true ? matchingPoItem!.descriptionAr : (matchingPoItem?.descriptionEn ?? itmCode));
        final double poPkgQty = plItm.qtyPkg > 0 ? plItm.qtyPkg : 1.0;

        plList.add(POReconciliationItemModel(
          poItemId: matchingPoItem?.itemId,
          packingItemId: plItm.packingItemId,
          itemCode: itmCode,
          description: itmDesc,
          hsCode: plItm.hsCode.isNotEmpty ? plItm.hsCode : matchingPoItem?.hsCode,
          packageType: plItm.packageType.isNotEmpty ? plItm.packageType : 'Carton',
          initialQuantity: plItm.qtyPcs > 0 ? plItm.qtyPcs : (matchingPoItem?.quantity ?? 0.0),
          finalQuantity: plItm.qtyPcs > 0 ? plItm.qtyPcs : (matchingPoItem?.quantity ?? 0.0),
          initialUnitPrice: matchingPoItem?.unitPrice ?? 0.0,
          unitPrice: matchingPoItem?.unitPrice ?? 0.0,
          finalUnitPrice: matchingPoItem?.unitPrice ?? 0.0,
          initialPackagesCount: poPkgQty,
          finalPackagesCount: poPkgQty,
          initialGrossWeightKg: plItm.totalGrossWeightKg > 0 ? plItm.totalGrossWeightKg : (matchingPoItem?.grossWeightKg ?? 0.0),
          finalGrossWeightKg: plItm.totalGrossWeightKg > 0 ? plItm.totalGrossWeightKg : (matchingPoItem?.grossWeightKg ?? 0.0),
          initialNetWeightKg: plItm.totalNetWeightKg > 0 ? plItm.totalNetWeightKg : (matchingPoItem?.netWeightKg ?? 0.0),
          finalNetWeightKg: plItm.totalNetWeightKg > 0 ? plItm.totalNetWeightKg : (matchingPoItem?.netWeightKg ?? 0.0),
          initialCbm: (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm) > 0 ? (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm) : (matchingPoItem?.totalCbm ?? 0.0),
          finalCbm: (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm) > 0 ? (plItm.calculatedCbm > 0 ? plItm.calculatedCbm : plItm.totalCbm) : (matchingPoItem?.totalCbm ?? 0.0),
        ));
      }
    }

    return PoReconciliationLoadedItems(
      invoiceItems: invList,
      packingItems: plList,
    );
  }
}

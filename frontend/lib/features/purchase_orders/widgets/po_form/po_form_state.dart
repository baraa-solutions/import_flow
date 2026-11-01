import '../../models/purchase_order_model.dart';
import '../../utils/po_payment_terms.dart';
import 'po_form_extractor.dart';

/// Pre-computes initial values for the PO form controllers and lists.
class PoFormInitialState {
  final DateTime orderDate;
  final String piNumber;
  final String poReference;
  final String rate;
  final String notes;
  final String status;
  final String? paymentTerms;
  final String? countryOfOrigin;
  final int? companyId;
  final int? supplierId;
  final int? projectId;
  final int? importFileId;
  final int? incotermId;
  final int? currencyId;
  final List<PalletPlanItemModel> palletItems;
  final bool isDirectVolumeMode;
  final List<POLineItemModel> items;
  final List<PackingListItemModel> packingItems;

  const PoFormInitialState({
    required this.orderDate,
    required this.piNumber,
    required this.poReference,
    required this.rate,
    required this.notes,
    required this.status,
    required this.paymentTerms,
    required this.countryOfOrigin,
    required this.companyId,
    required this.supplierId,
    required this.projectId,
    required this.importFileId,
    required this.incotermId,
    required this.currencyId,
    required this.palletItems,
    required this.isDirectVolumeMode,
    required this.items,
    required this.packingItems,
  });

  factory PoFormInitialState.create({
    required PurchaseOrderModel? po,
    required PurchaseOrderModel? cloneFromPo,
    required Map<String, dynamic>? ext,
    required int? defaultCompanyId,
    required int? defaultSupplierId,
  }) {
    final effectivePo = po ?? cloneFromPo;
    final isClone = cloneFromPo != null && po == null;

    final orderDate = effectivePo?.orderDate ??
        (ext != null ? PoFormExtractor.parseFlexDate((ext['order_date'] ?? ext['po_date'] ?? ext['date'])?.toString()) : DateTime.now());
    final piNumber = effectivePo?.proformaInvoiceNumber ??
        (ext != null ? (ext['po_number'] ?? ext['pi_number'] ?? ext['invoice_number'])?.toString() : null) ?? '';
    final poReference = effectivePo?.poReference ??
        (ext != null ? (ext['po_reference'] ?? ext['reference'] ?? ext['order_title'])?.toString() : null) ?? '';
    final rate = effectivePo?.exchangeRate?.toString() ?? '';
    final notes = effectivePo?.notes ?? '';
    final status = effectivePo?.status ?? 'DRAFT';

    final pCount = effectivePo?.palletCount ?? (ext != null ? PoFormExtractor.numToInt(ext['pallet_count']) : 0);
    final pType = effectivePo?.palletType ?? (ext != null ? ext['pallet_type']?.toString() : null) ?? 'Euro Pallet (120x80)';
    final pStack = effectivePo?.isPalletStackable ?? (ext != null ? (ext['is_pallet_stackable'] as bool? ?? false) : false);

    List<PalletPlanItemModel> palletItems;
    bool isDirectVolumeMode;
    if (effectivePo != null && effectivePo.palletPlanItems.isNotEmpty) {
      palletItems = List.from(effectivePo.palletPlanItems);
      isDirectVolumeMode = true;
    } else if (pCount > 0) {
      palletItems = [
        PalletPlanItemModel(
          palletType: pType,
          palletCount: pCount,
          lengthCm: effectivePo?.palletLengthCm ?? 120,
          widthCm: effectivePo?.palletWidthCm ?? 80,
          heightCm: effectivePo?.palletHeightCm ?? 150,
          isStackable: pStack,
        )
      ];
      isDirectVolumeMode = true;
    } else {
      palletItems = [];
      isDirectVolumeMode = false;
    }

    final paymentTerms = effectivePo != null
        ? (PoPaymentTerms.fromText(effectivePo.paymentTerms) ?? effectivePo.paymentTerms)
        : (ext != null ? PoPaymentTerms.fromText(ext['payment_terms']?.toString()) : null);

    List<POLineItemModel> items;
    if (effectivePo != null && effectivePo.items.isNotEmpty) {
      items = effectivePo.items.map((i) => i.copyWith(clearId: isClone)).toList();
    } else {
      items = [POLineItemModel(descriptionAr: 'بند استيرادي رئيسي 1', quantity: 100, unitPrice: 10, cbmPerUnit: 0.1)];
    }

    List<PackingListItemModel> packingItems;
    if (effectivePo != null && effectivePo.packingListItems.isNotEmpty) {
      packingItems = effectivePo.packingListItems.map((p) => p.copyWith(clearId: isClone)).toList();
    } else {
      packingItems = items.asMap().entries.map((e) => PackingListItemModel(
        hsCode: e.value.hsCode ?? '',
        itemCode: (e.value.itemCode != null && e.value.itemCode!.trim().isNotEmpty) ? e.value.itemCode!.trim() : 'ITEM-${(e.key + 1).toString().padLeft(3, "0")}',
        mainDescription: e.value.mainDescription,
        description: e.value.descriptionAr.isNotEmpty ? e.value.descriptionAr : e.value.descriptionEn,
        qtyPcs: e.value.quantity,
        qtyPkg: (e.value.quantity > 0 ? (e.value.quantity / 10).ceilToDouble() : 10.0),
        packageType: 'Carton',
        lengthCm: 50.0,
        widthCm: 40.0,
        heightCm: 30.0,
        netWeightUnitKg: e.value.netWeightKg > 0 ? e.value.netWeightKg : 5.0,
        grossWeightUnitKg: e.value.grossWeightKg > 0 ? e.value.grossWeightKg : 6.0,
      )).toList();
    }

    return PoFormInitialState(
      orderDate: orderDate,
      piNumber: piNumber,
      poReference: poReference,
      rate: rate,
      notes: notes,
      status: status,
      paymentTerms: paymentTerms,
      countryOfOrigin: PoFormExtractor.normalizeCountryName(effectivePo?.countryOfOrigin),
      companyId: effectivePo?.companyId ?? defaultCompanyId,
      supplierId: effectivePo?.supplierId ?? defaultSupplierId,
      projectId: effectivePo?.projectId,
      importFileId: effectivePo?.importFileId,
      incotermId: effectivePo?.incotermId,
      currencyId: effectivePo?.currencyId,
      palletItems: palletItems,
      isDirectVolumeMode: isDirectVolumeMode,
      items: items,
      packingItems: packingItems,
    );
  }
}

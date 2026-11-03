import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';

const List<Map<String, String>> kMasterPackageTypes = [
  {'code': 'CT', 'name': 'CT - Carton (كرتونة)'},
  {'code': 'BX', 'name': 'BX - Box (صندوق)'},
  {'code': 'PK', 'name': 'PK - Package (طرد / عبوة)'},
  {'code': 'PLT', 'name': 'PLT - Pallet (بالتة)'},
  {'code': 'BG', 'name': 'BG - Bag (كيس / شوال)'},
  {'code': 'CR', 'name': 'CR - Crate (قفص خشبي)'},
  {'code': 'DR', 'name': 'DR - Drum (برميل)'},
  {'code': 'RO', 'name': 'RO - Roll (رول / لفة)'},
  {'code': 'CL', 'name': 'CL - Coil (لفافة / كويل)'},
  {'code': 'BE', 'name': 'BE - Bundle (حزمة)'},
  {'code': 'BL', 'name': 'BL - Bale, compressed (بالة مضغوطة)'},
  {'code': 'BD', 'name': 'BD - Board (لوح)'},
  {'code': 'B4', 'name': 'B4 - Belt (حزام / سير)'},
  {'code': 'BK', 'name': 'BK - Basket (سلة)'},
  {'code': 'CA', 'name': 'CA - Can, rectangular (صفيحة مستطيلة)'},
  {'code': 'CH', 'name': 'CH - Chest (صندوق خشب كبير)'},
  {'code': 'PF', 'name': 'PF - Pen (قلم / حاوية خاصة)'},
  {'code': 'PG', 'name': 'PG - Plate (صفيحة / لوح مسطح)'},
  {'code': 'PL', 'name': 'PL - Pail (سطل / جردل)'},
  {'code': 'PR', 'name': 'PR - Receptacle, plastic (وعاء بلاستيكي)'},
  {'code': 'RL', 'name': 'RL - Reel (بكرة)'},
  {'code': 'TN', 'name': 'TN - Tin (علبة صفيح)'},
  {'code': 'VQ', 'name': 'VQ - Bulk, liquefied gas (صب / غاز مسال)'},
  {'code': 'IBC', 'name': 'IBC - IBC Tank (خزان سوائل)'},
];

const List<Map<String, String>> kMasterUnitsOfMeasure = [
  {'code': 'PCS', 'name': 'PCS - Piece (قطعة)'},
  {'code': 'KGM', 'name': 'KGM - Kilogram (كيلوجرام)'},
  {'code': 'GRM', 'name': 'GRM - Gram (جرام)'},
  {'code': 'SET', 'name': 'SET - Set (طقم / مجموعة)'},
  {'code': 'STN', 'name': 'STN - Ton (US / Short ton)'},
  {'code': 'TON', 'name': 'TON - Metric Ton (طن متري)'},
  {'code': 'CTN', 'name': 'CTN - Carton (كرتونة)'},
  {'code': 'BOX', 'name': 'BOX - Box (صندوق)'},
  {'code': 'PKG', 'name': 'PKG - Package (طرد)'},
  {'code': 'MTR', 'name': 'MTR - Meter (متر)'},
  {'code': 'LTR', 'name': 'LTR - Liter (لتر)'},
  {'code': 'LOT', 'name': 'LOT - Lot (دفعة)'},
];

double _numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

double? _numToNullableDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

int _numToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

class POLineItemModel {
  final int? itemId;
  final int? poId;
  final String? itemCode;
  final String? mainDescription;
  final String descriptionAr;
  final String? descriptionEn;
  final String? countryOfOrigin;
  final int? tariffId;
  final double quantity;
  final String unitOfMeasure;
  final double unitPrice;
  final double totalPrice;
  final double cbmPerUnit;
  final double totalCbm;
  final double grossWeightKg;
  final double netWeightKg;
  final String? hsCode;
  final double? dutyRate;
  final double? vatRate;

  POLineItemModel({
    this.itemId,
    this.poId,
    this.itemCode,
    this.mainDescription,
    required this.descriptionAr,
    this.descriptionEn,
    this.countryOfOrigin,
    this.tariffId,
    this.quantity = 1.0,
    this.unitOfMeasure = 'PCS',
    this.unitPrice = 0.0,
    double? totalPrice,
    this.cbmPerUnit = 0.0,
    this.totalCbm = 0.0,
    this.grossWeightKg = 0.0,
    this.netWeightKg = 0.0,
    this.hsCode,
    this.dutyRate,
    this.vatRate,
  }) : totalPrice = (totalPrice != null && totalPrice > 0)
            ? totalPrice
            : (quantity * unitPrice);

  String get itemDescription => mainDescription?.isNotEmpty == true
      ? mainDescription!
      : (descriptionAr.isNotEmpty ? descriptionAr : (descriptionEn ?? ''));

  factory POLineItemModel.fromJson(Map<String, dynamic> json) {
    final q = _numToDouble(json['quantity'], 1.0);
    final p = _numToDouble(json['unit_price']);
    final rawTotal = _numToDouble(json['total_price']);
    final tot = rawTotal > 0 ? rawTotal : (q * p);
    return POLineItemModel(
      itemId: json['item_id'] != null ? _numToInt(json['item_id']) : null,
      poId: _numToInt(json['po_id']),
      itemCode: json['item_code'] as String?,
      mainDescription: json['main_description'] as String?,
      descriptionAr: json['description_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      countryOfOrigin: json['country_of_origin'] as String?,
      tariffId: json['tariff_id'] != null ? _numToInt(json['tariff_id']) : null,
      quantity: q,
      unitOfMeasure: json['unit_of_measure'] as String? ?? 'PCS',
      unitPrice: p,
      totalPrice: tot,
      cbmPerUnit: _numToDouble(json['cbm_per_unit']),
      totalCbm: _numToDouble(json['total_cbm']),
      grossWeightKg: _numToDouble(json['gross_weight_kg']),
      netWeightKg: _numToDouble(json['net_weight_kg']),
      hsCode: json['hs_code'] as String?,
      dutyRate: _numToNullableDouble(json['duty_rate']),
      vatRate: _numToNullableDouble(json['vat_rate']),
    );
  }

  /// [clearId] drops the id (a duplicated row is a NEW row: the backend would update the original in place otherwise).
  POLineItemModel copyWith({
    bool clearId = false,
    int? itemId,
    int? poId,
    String? itemCode,
    String? mainDescription,
    String? descriptionAr,
    String? descriptionEn,
    String? countryOfOrigin,
    int? tariffId,
    double? quantity,
    String? unitOfMeasure,
    double? unitPrice,
    double? totalPrice,
    double? cbmPerUnit,
    double? totalCbm,
    double? grossWeightKg,
    double? netWeightKg,
    String? hsCode,
    double? dutyRate,
    double? vatRate,
  }) {
    final newQty = quantity ?? this.quantity;
    final newPrice = unitPrice ?? this.unitPrice;
    return POLineItemModel(
      itemId: clearId ? null : (itemId ?? this.itemId),
      poId: poId ?? this.poId,
      itemCode: itemCode ?? this.itemCode,
      mainDescription: mainDescription ?? this.mainDescription,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      tariffId: tariffId ?? this.tariffId,
      quantity: newQty,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      unitPrice: newPrice,
      totalPrice: totalPrice ?? (newQty * newPrice),
      cbmPerUnit: cbmPerUnit ?? this.cbmPerUnit,
      totalCbm: totalCbm ?? this.totalCbm,
      grossWeightKg: grossWeightKg ?? this.grossWeightKg,
      netWeightKg: netWeightKg ?? this.netWeightKg,
      hsCode: hsCode ?? this.hsCode,
      dutyRate: dutyRate ?? this.dutyRate,
      vatRate: vatRate ?? this.vatRate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (itemId != null) 'item_id': itemId,
      if (poId != null) 'po_id': poId,
      if (itemCode != null) 'item_code': itemCode,
      if (mainDescription != null) 'main_description': mainDescription,
      'description_ar': descriptionAr,
      if (descriptionEn != null) 'description_en': descriptionEn,
      if (countryOfOrigin != null) 'country_of_origin': countryOfOrigin,
      if (tariffId != null) 'tariff_id': tariffId,
      'quantity': quantity,
      'unit_of_measure': unitOfMeasure,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'cbm_per_unit': cbmPerUnit,
      'gross_weight_kg': grossWeightKg,
      'net_weight_kg': netWeightKg,
    };
  }
}

class PackingListItemModel {
  /// Lengths are sent in one of these units (the backend answers 422 for anything else).
  static const List<String> lengthUnits = ['mm', 'cm', 'm'];

  /// Declared weight UOM codes (MEASURE_UNIT). A label only: every weight value is kilograms.
  static const List<String> weightUnits = ['KG', 'GRM', 'STN', 'SET'];

  /// A valid length unit; blank / unknown (e.g. an AI-extracted "PCS") becomes cm.
  static String normalizeLengthUnit(String? value) {
    final u = (value ?? '').trim().toLowerCase();
    return lengthUnits.contains(u) ? u : 'cm';
  }

  /// A valid weight-unit code; aliases (KGM, KGS, TON ...) are mapped, anything else is KG.
  static String normalizeWeightUnit(String? value) {
    final code = DomainEnums.legacyToCode(DomainEnumType.measureUnit, value);
    return code != null && weightUnits.contains(code) ? code : 'KG';
  }

  final int? packingItemId;
  final int? poId;
  final String hsCode;
  final String itemCode;
  final String? mainDescription;
  final String? description;
  final double qtyPcs;
  final double qtyPkg;
  final String packageType;
  final String unit; // 'cm', 'mm', 'm'
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final String weightUnit;
  final double netWeightUnitKg;
  final double grossWeightUnitKg;
  final double totalNetWeightKg;
  final double totalGrossWeightKg;
  final double totalCbm;
  final double chargeableWeightKg;
  final bool isStackable;

  PackingListItemModel({
    this.packingItemId,
    this.poId,
    required this.hsCode,
    required this.itemCode,
    this.mainDescription,
    this.description,
    this.qtyPcs = 1.0,
    this.qtyPkg = 1.0,
    this.packageType = 'Carton',
    this.unit = 'cm',
    this.lengthCm = 0.0,
    this.widthCm = 0.0,
    this.heightCm = 0.0,
    this.weightUnit = 'KG',
    this.netWeightUnitKg = 0.0,
    this.grossWeightUnitKg = 0.0,
    this.totalNetWeightKg = 0.0,
    this.totalGrossWeightKg = 0.0,
    this.totalCbm = 0.0,
    this.chargeableWeightKg = 0.0,
    this.isStackable = true,
  });

  double get lengthM => unit == 'mm' ? lengthCm / 1000.0 : (unit == 'm' ? lengthCm : lengthCm / 100.0);
  double get widthM => unit == 'mm' ? widthCm / 1000.0 : (unit == 'm' ? widthCm : widthCm / 100.0);
  double get heightM => unit == 'mm' ? heightCm / 1000.0 : (unit == 'm' ? heightCm : heightCm / 100.0);

  double get calculatedCbm {
    if (lengthM > 0 && widthM > 0 && heightM > 0) {
      return qtyPkg * (lengthM * widthM * heightM);
    }
    return totalCbm;
  }

  /// Row gross weight from the CURRENT values (qty_pkg x unit weight, full precision) — what the
  /// backend stores (cargo_math.packing_row_totals). The stored [totalGrossWeightKg] is stale as
  /// soon as the user edits the quantity or unit weight, so displays must use this.
  double get computedTotalGrossWeightKg => qtyPkg * grossWeightUnitKg;

  /// Row net weight: qty_pkg x unit net weight (see [computedTotalGrossWeightKg]).
  double get computedTotalNetWeightKg => qtyPkg * netWeightUnitKg;

  /// [clearId] drops the id (a duplicated row is a NEW row).
  PackingListItemModel copyWith({
    bool clearId = false,
    int? packingItemId,
    int? poId,
    String? hsCode,
    String? itemCode,
    String? mainDescription,
    String? description,
    double? qtyPcs,
    double? qtyPkg,
    String? packageType,
    String? unit,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    String? weightUnit,
    double? netWeightUnitKg,
    double? grossWeightUnitKg,
    double? totalNetWeightKg,
    double? totalGrossWeightKg,
    double? totalCbm,
    double? chargeableWeightKg,
    bool? isStackable,
  }) {
    return PackingListItemModel(
      packingItemId: clearId ? null : (packingItemId ?? this.packingItemId),
      poId: poId ?? this.poId,
      hsCode: hsCode ?? this.hsCode,
      itemCode: itemCode ?? this.itemCode,
      mainDescription: mainDescription ?? this.mainDescription,
      description: description ?? this.description,
      qtyPcs: qtyPcs ?? this.qtyPcs,
      qtyPkg: qtyPkg ?? this.qtyPkg,
      packageType: packageType ?? this.packageType,
      unit: unit ?? this.unit,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      weightUnit: weightUnit ?? this.weightUnit,
      netWeightUnitKg: netWeightUnitKg ?? this.netWeightUnitKg,
      grossWeightUnitKg: grossWeightUnitKg ?? this.grossWeightUnitKg,
      totalNetWeightKg: totalNetWeightKg ?? this.totalNetWeightKg,
      totalGrossWeightKg: totalGrossWeightKg ?? this.totalGrossWeightKg,
      totalCbm: totalCbm ?? this.totalCbm,
      chargeableWeightKg: chargeableWeightKg ?? this.chargeableWeightKg,
      isStackable: isStackable ?? this.isStackable,
    );
  }

  factory PackingListItemModel.fromJson(Map<String, dynamic> json) {
    return PackingListItemModel(
      packingItemId: json['packing_item_id'] != null ? _numToInt(json['packing_item_id']) : null,
      poId: _numToInt(json['po_id']),
      hsCode: json['hs_code'] as String? ?? '',
      itemCode: json['item_code'] as String? ?? '',
      mainDescription: json['main_description'] as String?,
      description: json['description'] as String?,
      qtyPcs: _numToDouble(json['qty_pcs'], 1.0),
      qtyPkg: _numToDouble(json['qty_pkg'], 1.0),
      packageType: json['package_type'] as String? ?? 'Carton',
      unit: PackingListItemModel.normalizeLengthUnit(json['unit'] as String?),
      lengthCm: _numToDouble(json['length_cm']),
      widthCm: _numToDouble(json['width_cm']),
      heightCm: _numToDouble(json['height_cm']),
      weightUnit: PackingListItemModel.normalizeWeightUnit(json['weight_unit'] as String?),
      netWeightUnitKg: _numToDouble(json['net_weight_unit_kg']),
      grossWeightUnitKg: _numToDouble(json['gross_weight_unit_kg']),
      totalNetWeightKg: _numToDouble(json['total_net_weight_kg']),
      totalGrossWeightKg: _numToDouble(json['total_gross_weight_kg']),
      totalCbm: _numToDouble(json['total_cbm']),
      chargeableWeightKg: _numToDouble(json['chargeable_weight_kg']),
      isStackable: json['is_stackable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (packingItemId != null) 'packing_item_id': packingItemId,
      if (poId != null) 'po_id': poId,
      'hs_code': hsCode,
      'item_code': itemCode,
      if (mainDescription != null) 'main_description': mainDescription,
      if (description != null) 'description': description,
      'qty_pcs': qtyPcs,
      'qty_pkg': qtyPkg,
      'package_type': packageType,
      'unit': unit,
      'length_cm': lengthCm,
      'width_cm': widthCm,
      'height_cm': heightCm,
      'weight_unit': weightUnit,
      'net_weight_unit_kg': netWeightUnitKg,
      'gross_weight_unit_kg': grossWeightUnitKg,
      'total_cbm': totalCbm,
      'is_stackable': isStackable,
    };
  }
}

class PalletPlanItemModel {
  final String palletType;
  final int palletCount;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double grossWeightPerPalletKg;
  final bool isStackable;
  final String? notes;

  PalletPlanItemModel({
    this.palletType = 'Euro Pallet (120x80)',
    this.palletCount = 1,
    this.lengthCm = 120.0,
    this.widthCm = 80.0,
    this.heightCm = 150.0,
    this.grossWeightPerPalletKg = 0.0,
    this.isStackable = false,
    this.notes,
  });

  double get calculatedCbm => (lengthCm * widthCm * heightCm / 1000000.0) * palletCount;
  double get totalWeightKg => grossWeightPerPalletKg * palletCount;

  factory PalletPlanItemModel.fromJson(Map<String, dynamic> json) {
    return PalletPlanItemModel(
      palletType: json['pallet_type'] as String? ?? 'Euro Pallet (120x80)',
      palletCount: _numToInt(json['pallet_count'], 1),
      lengthCm: _numToDouble(json['length_cm'], 120.0),
      widthCm: _numToDouble(json['width_cm'], 80.0),
      heightCm: _numToDouble(json['height_cm'], 150.0),
      grossWeightPerPalletKg: _numToDouble(json['gross_weight_per_pallet_kg']),
      isStackable: json['is_stackable'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pallet_type': palletType,
      'pallet_count': palletCount,
      'length_cm': lengthCm,
      'width_cm': widthCm,
      'height_cm': heightCm,
      'gross_weight_per_pallet_kg': grossWeightPerPalletKg,
      'is_stackable': isStackable,
      if (notes != null) 'notes': notes,
    };
  }

  PalletPlanItemModel copyWith({
    String? palletType,
    int? palletCount,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    double? grossWeightPerPalletKg,
    bool? isStackable,
    String? notes,
  }) {
    return PalletPlanItemModel(
      palletType: palletType ?? this.palletType,
      palletCount: palletCount ?? this.palletCount,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      grossWeightPerPalletKg: grossWeightPerPalletKg ?? this.grossWeightPerPalletKg,
      isStackable: isStackable ?? this.isStackable,
      notes: notes ?? this.notes,
    );
  }
}

class PurchaseOrderModel {
  final int? poId;
  final String poNumber;
  final String? poReference;
  final String? proformaInvoiceNumber;
  final String? countryOfOrigin;
  final int? importFileId;
  final int projectId;
  final int companyId;
  final int supplierId;
  final int incotermId;
  final int currencyId;
  final DateTime? orderDate;
  final DateTime? expectedDeliveryDate;
  final double? exchangeRate;
  final String? paymentTerms;
  final double totalAmountFob;
  final double totalCbm;
  final double totalGrossWeightKg;
  final double totalNetWeightKg;
  final int totalPackagesCount;
  final int palletCount;
  final String palletType;
  final bool isPalletStackable;
  final double palletLengthCm;
  final double palletWidthCm;
  final double palletHeightCm;
  /// PO_STATUS code (DRAFT, APPROVED, PARTIALLY_SHIPPED, FULLY_SHIPPED, CLOSED, CANCELLED).
  final String status;
  final String? createdBy;
  final String? updatedBy;
  final String? notes;
  final int version;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? importFileCode;
  final String? projectName;
  final String? companyName;
  final String? supplierName;
  final String? incotermCode;
  final String? currencyCode;
  final List<POLineItemModel> items;
  List<POLineItemModel> get lineItems => items;
  final List<PackingListItemModel> packingListItems;
  final List<PalletPlanItemModel> palletPlanItems;
  final double totalShippedQuantity;
  final double totalReceivedQuantity;
  final double remainingBalanceQuantity;
  final String fulfillmentStatus;

  double get effectiveContractedQuantity =>
      items.isNotEmpty ? items.fold<double>(0.0, (s, it) => s + it.quantity) : (totalShippedQuantity + remainingBalanceQuantity);
  double get fulfillmentRate => effectiveContractedQuantity > 0
      ? ((totalShippedQuantity / effectiveContractedQuantity) * 100.0).clamp(0.0, 100.0)
      : 0.0;

  String get displayName => (poReference != null && poReference!.trim().isNotEmpty)
      ? poReference!.trim()
      : poNumber;

  PurchaseOrderModel({
    this.poId,
    required this.poNumber,
    this.poReference,
    this.proformaInvoiceNumber,
    this.countryOfOrigin,
    this.importFileId,
    required this.projectId,
    required this.companyId,
    required this.supplierId,
    required this.incotermId,
    required this.currencyId,
    this.orderDate,
    this.expectedDeliveryDate,
    this.exchangeRate,
    this.paymentTerms = 'LC at Sight / اعتماد مستندي',
    this.totalAmountFob = 0.0,
    this.totalCbm = 0.0,
    this.totalGrossWeightKg = 0.0,
    this.totalNetWeightKg = 0.0,
    this.totalPackagesCount = 0,
    this.palletCount = 0,
    this.palletType = 'Euro Pallet (120x80)',
    this.isPalletStackable = false,
    this.palletLengthCm = 120.0,
    this.palletWidthCm = 80.0,
    this.palletHeightCm = 150.0,
    this.status = 'DRAFT',
    this.createdBy,
    this.updatedBy,
    this.notes,
    this.version = 1,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.importFileCode,
    this.projectName,
    this.companyName,
    this.supplierName,
    this.incotermCode,
    this.currencyCode,
    this.items = const [],
    this.packingListItems = const [],
    this.palletPlanItems = const [],
    this.totalShippedQuantity = 0.0,
    this.totalReceivedQuantity = 0.0,
    this.remainingBalanceQuantity = 0.0,
    this.fulfillmentStatus = 'OPEN',
  });

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      poId: json['po_id'] != null ? _numToInt(json['po_id']) : null,
      poNumber: json['po_number'] as String? ?? '',
      version: _numToInt(json['version'], 1),
      poReference: json['po_reference'] as String?,
      proformaInvoiceNumber: json['proforma_invoice_number'] as String?,
      countryOfOrigin: json['country_of_origin'] as String?,
      importFileId: json['import_file_id'] != null ? _numToInt(json['import_file_id']) : null,
      projectId: _numToInt(json['project_id']),
      companyId: _numToInt(json['company_id']),
      supplierId: _numToInt(json['supplier_id']),
      incotermId: _numToInt(json['incoterm_id']),
      currencyId: _numToInt(json['currency_id']),
      orderDate: json['order_date'] != null ? DateTime.parse(json['order_date']) : null,
      expectedDeliveryDate: json['expected_delivery_date'] != null
          ? DateTime.parse(json['expected_delivery_date'])
          : null,
      exchangeRate: _numToNullableDouble(json['exchange_rate']),
      paymentTerms: json['payment_terms'] as String?,
      totalAmountFob: _numToDouble(json['total_amount_fob']),
      totalCbm: _numToDouble(json['total_cbm']),
      totalGrossWeightKg: _numToDouble(json['total_gross_weight_kg']),
      totalNetWeightKg: _numToDouble(json['total_net_weight_kg']),
      totalPackagesCount: _numToInt(json['total_packages_count']),
      palletCount: _numToInt(json['pallet_count']),
      palletType: json['pallet_type'] as String? ?? 'Euro Pallet (120x80)',
      isPalletStackable: json['is_pallet_stackable'] as bool? ?? false,
      palletLengthCm: _numToDouble(json['pallet_length_cm'], 120.0),
      palletWidthCm: _numToDouble(json['pallet_width_cm'], 80.0),
      palletHeightCm: _numToDouble(json['pallet_height_cm'], 150.0),
      status: DomainEnums.legacyToCode(DomainEnumType.poStatus, json['status'] as String?) ?? (json['status'] as String? ?? 'DRAFT'),
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      importFileCode: json['import_file_code'] as String?,
      projectName: json['project_name'] as String?,
      companyName: json['company_name'] as String?,
      supplierName: json['supplier_name'] as String?,
      incotermCode: json['incoterm_code'] as String?,
      currencyCode: json['currency_code'] as String?,
      items: json['items'] != null
          ? (json['items'] as List).map((i) => POLineItemModel.fromJson(i as Map<String, dynamic>)).toList()
          : [],
      packingListItems: json['packing_list_items'] != null
          ? (json['packing_list_items'] as List).map((i) => PackingListItemModel.fromJson(i as Map<String, dynamic>)).toList()
          : [],
      palletPlanItems: json['pallet_plan'] != null && json['pallet_plan'] is List
          ? (json['pallet_plan'] as List).map((i) => PalletPlanItemModel.fromJson(i as Map<String, dynamic>)).toList()
          : [],
      totalShippedQuantity: _numToDouble(json['total_shipped_quantity']),
      totalReceivedQuantity: _numToDouble(json['total_received_quantity']),
      remainingBalanceQuantity: _numToDouble(json['remaining_balance_quantity']),
      fulfillmentStatus: json['fulfillment_status'] as String? ?? 'OPEN',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (poId != null) 'po_id': poId,
      if (poNumber.isNotEmpty) 'po_number': poNumber,
      if (poReference != null && poReference!.isNotEmpty) 'po_reference': poReference,
      if (proformaInvoiceNumber != null) 'proforma_invoice_number': proformaInvoiceNumber,
      if (countryOfOrigin != null) 'country_of_origin': countryOfOrigin,
      if (importFileId != null) 'import_file_id': importFileId,
      'project_id': projectId,
      'company_id': companyId,
      'supplier_id': supplierId,
      'incoterm_id': incotermId,
      'currency_id': currencyId,
      if (orderDate != null) 'order_date': orderDate!.toIso8601String(),
      if (expectedDeliveryDate != null) 'expected_delivery_date': expectedDeliveryDate!.toIso8601String(),
      if (exchangeRate != null) 'exchange_rate': exchangeRate,
      if (paymentTerms != null) 'payment_terms': paymentTerms,
      'pallet_count': palletCount,
      'pallet_type': palletType,
      'is_pallet_stackable': isPalletStackable,
      'pallet_length_cm': palletLengthCm,
      'pallet_width_cm': palletWidthCm,
      'pallet_height_cm': palletHeightCm,
      'status': status,
      if (notes != null) 'notes': notes,
      'version': version,
      'is_active': isActive,
      'items': items.map((i) => i.toJson()).toList(),
      'packing_list_items': packingListItems.map((i) => i.toJson()).toList(),
      'pallet_plan': palletPlanItems.map((i) => i.toJson()).toList(),
      'total_shipped_quantity': totalShippedQuantity,
      'total_received_quantity': totalReceivedQuantity,
      'remaining_balance_quantity': remainingBalanceQuantity,
      'fulfillment_status': fulfillmentStatus,
    };
  }
}



/// Display helper: the backend sends a PO_STATUS code; never show it raw.
extension PurchaseOrderStatusLabel on PurchaseOrderModel {
  String statusLabel(AppLocalizations l10n) =>
      DomainEnums.label(l10n, DomainEnumType.poStatus, status, fallback: '-');
}


// =========================================================================
// EPIC-PO-PART: PO Shipment Allocations & Fulfillment Balance Models
// =========================================================================

class POShipmentAllocationModel {
  final int? allocationId;
  final int poId;
  final int? poLineItemId;
  final int? poItemId;
  final int? importFileId;
  final String? shipmentBatchNo;
  final String shipmentRef;
  final double allocatedQuantity;
  final double shippedQuantity;
  final double allocatedFobAmount;
  final double shippedAmountFob;
  final DateTime? shippingDate;
  final String status;
  final String? notes;
  final String? createdBy;

  POShipmentAllocationModel({
    this.allocationId,
    required this.poId,
    this.poLineItemId,
    this.poItemId,
    this.importFileId,
    this.shipmentBatchNo,
    required this.shipmentRef,
    this.allocatedQuantity = 0.0,
    this.shippedQuantity = 0.0,
    this.allocatedFobAmount = 0.0,
    this.shippedAmountFob = 0.0,
    this.shippingDate,
    this.status = 'IN_TRANSIT',
    this.notes,
    this.createdBy,
  });

  factory POShipmentAllocationModel.fromJson(Map<String, dynamic> json) {
    final lineId = json['po_line_item_id'] != null
        ? _numToInt(json['po_line_item_id'])
        : (json['po_item_id'] != null ? _numToInt(json['po_item_id']) : null);
    final ref = (json['shipment_batch_no'] ?? json['shipment_ref'] ?? '') as String;
    final qty = _numToDouble(json['allocated_quantity'] ?? json['shipped_quantity']);
    final fob = _numToDouble(json['allocated_fob_amount'] ?? json['shipped_amount_fob']);

    return POShipmentAllocationModel(
      allocationId: json['allocation_id'] != null ? _numToInt(json['allocation_id']) : null,
      poId: _numToInt(json['po_id']),
      poLineItemId: lineId,
      poItemId: lineId,
      importFileId: json['import_file_id'] != null ? _numToInt(json['import_file_id']) : null,
      shipmentBatchNo: json['shipment_batch_no'] as String? ?? ref,
      shipmentRef: ref,
      allocatedQuantity: qty,
      shippedQuantity: qty,
      allocatedFobAmount: fob,
      shippedAmountFob: fob,
      shippingDate: json['shipping_date'] != null ? DateTime.tryParse(json['shipping_date']) : null,
      status: json['status'] as String? ?? 'IN_TRANSIT',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (allocationId != null) 'allocation_id': allocationId,
      'po_id': poId,
      if (poLineItemId != null) 'po_line_item_id': poLineItemId,
      if (poItemId != null) 'po_item_id': poItemId,
      if (importFileId != null) 'import_file_id': importFileId,
      'shipment_batch_no': shipmentBatchNo ?? shipmentRef,
      'shipment_ref': shipmentRef,
      'allocated_quantity': allocatedQuantity,
      'shipped_quantity': shippedQuantity,
      'allocated_fob_amount': allocatedFobAmount,
      'shipped_amount_fob': shippedAmountFob,
      if (shippingDate != null) 'shipping_date': shippingDate!.toIso8601String(),
      'status': status,
      if (notes != null) 'notes': notes,
    };
  }
}

class POLineItemBalanceModel {
  final int itemId;
  final String? itemCode;
  final String descriptionAr;
  final double orderedQty;
  final double contractedQty;
  final double shippedQty;
  final double receivedQty;
  final double remainingQty;
  final double unitPrice;
  final double orderedAmountFob;
  final double shippedAmountFob;
  final double remainingAmountFob;
  final double fulfillmentPercent;

  POLineItemBalanceModel({
    required this.itemId,
    this.itemCode,
    required this.descriptionAr,
    this.orderedQty = 0.0,
    this.contractedQty = 0.0,
    this.shippedQty = 0.0,
    this.receivedQty = 0.0,
    this.remainingQty = 0.0,
    this.unitPrice = 0.0,
    this.orderedAmountFob = 0.0,
    this.shippedAmountFob = 0.0,
    this.remainingAmountFob = 0.0,
    this.fulfillmentPercent = 0.0,
  });

  factory POLineItemBalanceModel.fromJson(Map<String, dynamic> json) {
    final ord = _numToDouble(json['ordered_qty'] ?? json['contracted_qty']);
    return POLineItemBalanceModel(
      itemId: _numToInt(json['item_id']),
      itemCode: json['item_code'] as String?,
      descriptionAr: json['description_ar'] as String? ?? '',
      orderedQty: ord,
      contractedQty: _numToDouble(json['contracted_qty'], ord),
      shippedQty: _numToDouble(json['shipped_qty']),
      receivedQty: _numToDouble(json['received_qty']),
      remainingQty: _numToDouble(json['remaining_qty']),
      unitPrice: _numToDouble(json['unit_price']),
      orderedAmountFob: _numToDouble(json['ordered_amount_fob']),
      shippedAmountFob: _numToDouble(json['shipped_amount_fob']),
      remainingAmountFob: _numToDouble(json['remaining_amount_fob']),
      fulfillmentPercent: _numToDouble(json['fulfillment_percent']),
    );
  }
}

class POBalanceSummaryModel {
  final int poId;
  final String poNumber;
  final double totalOrderedQty;
  final double totalContractedQty;
  final double totalShippedQty;
  final double totalReceivedQty;
  final double totalRemainingQty;
  final double totalOrderedAmountFob;
  final double totalShippedAmountFob;
  final double totalRemainingAmountFob;
  final String? currencyCode;
  final double overallFulfillmentPercent;
  final String fulfillmentStatus;
  final List<POLineItemBalanceModel> lineItemsBalance;
  final List<POShipmentAllocationModel> allocations;
  final String executiveSummaryAr;

  POBalanceSummaryModel({
    required this.poId,
    required this.poNumber,
    this.totalOrderedQty = 0.0,
    this.totalContractedQty = 0.0,
    this.totalShippedQty = 0.0,
    this.totalReceivedQty = 0.0,
    this.totalRemainingQty = 0.0,
    this.totalOrderedAmountFob = 0.0,
    this.totalShippedAmountFob = 0.0,
    this.totalRemainingAmountFob = 0.0,
    this.currencyCode,
    this.overallFulfillmentPercent = 0.0,
    this.fulfillmentStatus = 'OPEN',
    this.lineItemsBalance = const [],
    this.allocations = const [],
    this.executiveSummaryAr = '',
  });

  factory POBalanceSummaryModel.fromJson(Map<String, dynamic> json) {
    final ord = _numToDouble(json['total_ordered_qty'] ?? json['total_contracted_qty']);
    return POBalanceSummaryModel(
      poId: _numToInt(json['po_id']),
      poNumber: json['po_number'] as String? ?? '',
      totalOrderedQty: ord,
      totalContractedQty: _numToDouble(json['total_contracted_qty'], ord),
      totalShippedQty: _numToDouble(json['total_shipped_qty']),
      totalReceivedQty: _numToDouble(json['total_received_qty']),
      totalRemainingQty: _numToDouble(json['total_remaining_qty']),
      totalOrderedAmountFob: _numToDouble(json['total_ordered_amount_fob']),
      totalShippedAmountFob: _numToDouble(json['total_shipped_amount_fob']),
      totalRemainingAmountFob: _numToDouble(json['total_remaining_amount_fob']),
      currencyCode: json['currency_code'] as String?,
      overallFulfillmentPercent: _numToDouble(json['overall_fulfillment_percent']),
      fulfillmentStatus: json['fulfillment_status'] as String? ?? 'OPEN',
      lineItemsBalance: (json['line_items_balance'] as List<dynamic>?)
              ?.map((e) => POLineItemBalanceModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      allocations: (json['allocations'] as List<dynamic>?)
              ?.map((e) => POShipmentAllocationModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      executiveSummaryAr: json['executive_summary_ar'] as String? ?? '',
    );
  }
}

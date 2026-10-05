import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/domain_enum_labels.dart';

// The factor lives in core so the PO form and ContainerRequirementEngine share it.
export '../../../core/constants/cargo_constants.dart';
double _numToDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val) ?? fallback;
  return fallback;
}

int _numToInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

class CBMItemModel {
  final int? itemId;
  final int? calcId;
  final String packageType;
  final int quantity;
  final double length;
  final double width;
  final double height;
  final String unit; // mm, cm, m
  final double grossWeightPerUnitKg;
  final double totalCbm;
  final double volumetricWeightKg;
  final double totalGrossWeightKg;
  final bool isStackable;

  CBMItemModel({
    this.itemId,
    this.calcId,
    this.packageType = 'Carton',
    required this.quantity,
    required this.length,
    required this.width,
    required this.height,
    this.unit = 'cm',
    required this.grossWeightPerUnitKg,
    this.totalCbm = 0.0,
    this.volumetricWeightKg = 0.0,
    this.totalGrossWeightKg = 0.0,
    this.isStackable = true,
  });

  double get lengthM => unit == 'mm' ? length / 1000.0 : (unit == 'cm' ? length / 100.0 : length);
  double get widthM => unit == 'mm' ? width / 1000.0 : (unit == 'cm' ? width / 100.0 : width);
  double get heightM => unit == 'mm' ? height / 1000.0 : (unit == 'cm' ? height / 100.0 : height);

  double get lengthCm => lengthM * 100.0;
  double get widthCm => widthM * 100.0;
  double get heightCm => heightM * 100.0;

  factory CBMItemModel.fromJson(Map<String, dynamic> json) {
    final u = json['unit']?.toString() ?? 'cm';
    final l = _numToDouble(json['length'], _numToDouble(json['length_cm'], 100.0));
    final w = _numToDouble(json['width'], _numToDouble(json['width_cm'], 80.0));
    final h = _numToDouble(json['height'], _numToDouble(json['height_cm'], 60.0));

    return CBMItemModel(
      itemId: json['item_id'] != null ? _numToInt(json['item_id']) : null,
      calcId: json['calc_id'] != null ? _numToInt(json['calc_id']) : null,
      packageType: json['package_type'] ?? 'Carton',
      quantity: _numToInt(json['quantity'], 1),
      length: l,
      width: w,
      height: h,
      unit: u,
      grossWeightPerUnitKg: _numToDouble(json['gross_weight_per_unit_kg']),
      totalCbm: _numToDouble(json['total_cbm']),
      volumetricWeightKg: _numToDouble(json['volumetric_weight_kg']),
      totalGrossWeightKg: _numToDouble(json['total_gross_weight_kg']),
      isStackable: json['is_stackable'] as bool? ?? (json['stackable'] as bool? ?? true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (itemId != null) 'item_id': itemId,
      if (calcId != null) 'calc_id': calcId,
      'package_type': packageType,
      'quantity': quantity,
      'length': length,
      'width': width,
      'height': height,
      'unit': unit,
      'length_cm': lengthCm,
      'width_cm': widthCm,
      'height_cm': heightCm,
      'gross_weight_per_unit_kg': grossWeightPerUnitKg,
      'is_stackable': isStackable,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'package_type': packageType,
      'quantity': quantity > 0 ? quantity : 1,
      'length': length > 0 ? length : 1.0,
      'width': width > 0 ? width : 1.0,
      'height': height > 0 ? height : 1.0,
      'unit': unit,
      'gross_weight_per_unit_kg': grossWeightPerUnitKg >= 0 ? grossWeightPerUnitKg : 0.0,
      'is_stackable': isStackable,
    };
  }
}

class CBMCalculationModel {
  final int? calcId;
  final String calcCode;
  final String? title;
  final int? importFileId;
  final int? projectId;
  final int? poId;
  final int totalQty;
  final double totalCbm;
  final double totalGrossWeightKg;
  final double totalVolumetricWeightKg;
  final double airChargeableWeightKg;
  /// SHIPMENT_MODE code the study was made for (AIR / SEA); null on legacy rows.
  final String? shipmentMode;
  final String? recommendedShippingMethod;
  final String? recommendedContainerType;
  final int recommendedContainerCount;
  /// "<n> x C40_HC" (CONTAINER_TYPE code) and the same counts as numbers.
  final String? smartHybridContainers;
  final String? flatOnlyContainers;
  final int? smartHybridContainersCount;
  final int? flatOnlyContainersCount;
  final String? notes;
  final bool isStackable;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final String? importFileCode;
  final String? projectName;
  final String? poNumber;
  final List<CBMItemModel> items;

  CBMCalculationModel({
    this.calcId,
    required this.calcCode,
    this.title,
    this.importFileId,
    this.projectId,
    this.poId,
    this.totalQty = 0,
    this.totalCbm = 0.0,
    this.totalGrossWeightKg = 0.0,
    this.totalVolumetricWeightKg = 0.0,
    this.airChargeableWeightKg = 0.0,
    this.shipmentMode,
    this.recommendedShippingMethod,
    this.recommendedContainerType,
    this.recommendedContainerCount = 0,
    this.smartHybridContainers,
    this.flatOnlyContainers,
    this.smartHybridContainersCount,
    this.flatOnlyContainersCount,
    this.notes,
    this.isStackable = true,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.importFileCode,
    this.projectName,
    this.poNumber,
    this.items = const [],
  });

  factory CBMCalculationModel.fromJson(Map<String, dynamic> json) {
    return CBMCalculationModel(
      calcId: json['calc_id'] != null ? _numToInt(json['calc_id']) : null,
      calcCode: json['calc_code'] ?? '',
      title: json['title'],
      importFileId: json['import_file_id'] != null ? _numToInt(json['import_file_id']) : null,
      projectId: json['project_id'] != null ? _numToInt(json['project_id']) : null,
      poId: json['po_id'] != null ? _numToInt(json['po_id']) : null,
      totalQty: _numToInt(json['total_qty']),
      totalCbm: _numToDouble(json['total_cbm']),
      totalGrossWeightKg: _numToDouble(json['total_gross_weight_kg']),
      totalVolumetricWeightKg: _numToDouble(json['total_volumetric_weight_kg']),
      airChargeableWeightKg: _numToDouble(json['air_chargeable_weight_kg']),
      shipmentMode: json['shipment_mode'] as String?,
      recommendedShippingMethod: json['recommended_shipping_method'],
      recommendedContainerType: json['recommended_container_type'],
      recommendedContainerCount: _numToInt(json['recommended_container_count']),
      smartHybridContainers: json['smart_hybrid_containers'] as String?,
      flatOnlyContainers: json['flat_only_containers'] as String?,
      smartHybridContainersCount: json['smart_hybrid_containers_count'] != null ? _numToInt(json['smart_hybrid_containers_count']) : null,
      flatOnlyContainersCount: json['flat_only_containers_count'] != null ? _numToInt(json['flat_only_containers_count']) : null,
      notes: json['notes'],
      isStackable: json['is_stackable'] as bool? ?? true,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      importFileCode: json['import_file_code'],
      projectName: json['project_name'],
      poNumber: json['po_number'],
      items: json['items'] != null
          ? (json['items'] as List).map((i) => CBMItemModel.fromJson(i)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (calcId != null) 'calc_id': calcId,
      'calc_code': calcCode,
      'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      'project_id': projectId,
      'po_id': poId,
      'notes': notes,
      'is_stackable': isStackable,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      if (importFileId != null) 'import_file_id': importFileId,
      if (projectId != null) 'project_id': projectId,
      if (poId != null) 'po_id': poId,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'is_stackable': isStackable,
      if (shipmentMode != null) 'shipment_mode': shipmentMode,
      'items': items.map((i) => i.toCreateJson()).toList(),
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'title': title,
      'import_file_id': importFileId,
      'project_id': projectId,
      'po_id': poId,
      'notes': notes,
      'is_stackable': isStackable,
      if (shipmentMode != null) 'shipment_mode': shipmentMode,
      'items': items.map((i) => i.toCreateJson()).toList(),
    };
  }
}


/// Display helpers: the backend sends CODES (SHIPPING_METHOD / CONTAINER_TYPE);
/// these render them in the user's language and never show a raw code.
extension CBMCalculationLabels on CBMCalculationModel {
  String shippingMethodLabel(AppLocalizations l10n) => DomainEnums.label(
        l10n,
        DomainEnumType.shippingMethod,
        recommendedShippingMethod,
        fallback: '-',
      );

  /// '-' for air (no container) or an unknown value.
  String containerTypeLabel(AppLocalizations l10n) => DomainEnums.label(
        l10n,
        DomainEnumType.containerType,
        recommendedContainerType,
        fallback: '-',
      );

  /// "Air Freight" / "Sea Freight"; '-' for legacy rows saved before the mode was stored.
  String shipmentModeLabel(AppLocalizations l10n) =>
      DomainEnums.label(l10n, DomainEnumType.shipmentMode, shipmentMode, fallback: '-');

  bool get isAirRecommended =>
      DomainEnums.legacyToCode(DomainEnumType.shippingMethod, recommendedShippingMethod) == 'AIR';

  /// "3 x 40FT High Cube Container (40' HC)"; '-' when there is no container.
  String recommendedContainersLabel(AppLocalizations l10n) {
    final type = containerTypeLabel(l10n);
    if (type == '-' || recommendedContainerCount <= 0) return '-';
    return '$recommendedContainerCount x $type';
  }

  String? smartHybridContainersLabel(AppLocalizations l10n) =>
      containersText(smartHybridContainers, l10n);

  String? flatOnlyContainersLabel(AppLocalizations l10n) => containersText(flatOnlyContainers, l10n);
}

final RegExp _containersTextPattern = RegExp(r'^\s*(\d+)\s*x\s*(\S+)\s*$', caseSensitive: false);

/// Renders the backend's "<n> x C40_HC" as "<n> x <container label>".
/// Text that does not match the pattern is returned unchanged; null stays null.
String? containersText(String? raw, AppLocalizations l10n) {
  if (raw == null) return null;
  final m = _containersTextPattern.firstMatch(raw);
  if (m == null) return raw;
  final label = DomainEnums.labelIfKnown(l10n, DomainEnumType.containerType, m.group(2));
  return label == null ? raw : '${m.group(1)} x $label';
}

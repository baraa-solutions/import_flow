import 'package:flutter/foundation.dart';

/// Standard Master Item Model (MD-ITEM-001)
/// Single Source of Truth for standard import items/SKUs, dimensions, and cached tariffs.
@immutable
class MasterItemModel {
  final int itemId;
  final String itemCode;
  final String descriptionAr;
  final String? descriptionEn;
  final int? tariffId;
  final String? hsCode;
  final String defaultUom;
  final String defaultPkgType;
  final double cbmPerUnit;
  final double grossWeightKg;
  final double netWeightKg;
  final double? lastCustomsDutyPct;
  final double? lastVatPct;
  final double? lastScheduleTaxPct;
  final String? productCategory;
  final String? productSubcategory;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  const MasterItemModel({
    required this.itemId,
    required this.itemCode,
    required this.descriptionAr,
    this.descriptionEn,
    this.tariffId,
    this.hsCode,
    this.defaultUom = 'PCS',
    this.defaultPkgType = 'Carton',
    this.cbmPerUnit = 0.0,
    this.grossWeightKg = 0.0,
    this.netWeightKg = 0.0,
    this.lastCustomsDutyPct,
    this.lastVatPct,
    this.lastScheduleTaxPct,
    this.productCategory,
    this.productSubcategory,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory MasterItemModel.fromJson(Map<String, dynamic> json) {
    return MasterItemModel(
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      itemCode: json['item_code']?.toString() ?? '',
      descriptionAr: json['description_ar']?.toString() ?? '',
      descriptionEn: json['description_en']?.toString(),
      tariffId: (json['tariff_id'] as num?)?.toInt(),
      hsCode: json['hs_code']?.toString(),
      defaultUom: json['default_uom']?.toString() ?? 'PCS',
      defaultPkgType: json['default_pkg_type']?.toString() ?? 'Carton',
      cbmPerUnit: (json['cbm_per_unit'] as num?)?.toDouble() ?? 0.0,
      grossWeightKg: (json['gross_weight_kg'] as num?)?.toDouble() ?? 0.0,
      netWeightKg: (json['net_weight_kg'] as num?)?.toDouble() ?? 0.0,
      lastCustomsDutyPct: (json['last_customs_duty_pct'] as num?)?.toDouble(),
      lastVatPct: (json['last_vat_pct'] as num?)?.toDouble(),
      lastScheduleTaxPct: (json['last_schedule_tax_pct'] as num?)?.toDouble(),
      productCategory: json['product_category']?.toString(),
      productSubcategory: json['product_subcategory']?.toString(),
      notes: json['notes']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      createdBy: json['created_by']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      updatedBy: json['updated_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_code': itemCode,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'tariff_id': tariffId,
      if (hsCode != null) 'hs_code': hsCode,
      'default_uom': defaultUom,
      'default_pkg_type': defaultPkgType,
      'cbm_per_unit': cbmPerUnit,
      'gross_weight_kg': grossWeightKg,
      'net_weight_kg': netWeightKg,
      'last_customs_duty_pct': lastCustomsDutyPct,
      'last_vat_pct': lastVatPct,
      'last_schedule_tax_pct': lastScheduleTaxPct,
      'product_category': productCategory,
      'product_subcategory': productSubcategory,
      'notes': notes,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (updatedBy != null) 'updated_by': updatedBy,
    };
  }

  MasterItemModel copyWith({
    int? itemId,
    String? itemCode,
    String? descriptionAr,
    String? descriptionEn,
    int? tariffId,
    String? hsCode,
    String? defaultUom,
    String? defaultPkgType,
    double? cbmPerUnit,
    double? grossWeightKg,
    double? netWeightKg,
    double? lastCustomsDutyPct,
    double? lastVatPct,
    double? lastScheduleTaxPct,
    String? productCategory,
    String? productSubcategory,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return MasterItemModel(
      itemId: itemId ?? this.itemId,
      itemCode: itemCode ?? this.itemCode,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      tariffId: tariffId ?? this.tariffId,
      hsCode: hsCode ?? this.hsCode,
      defaultUom: defaultUom ?? this.defaultUom,
      defaultPkgType: defaultPkgType ?? this.defaultPkgType,
      cbmPerUnit: cbmPerUnit ?? this.cbmPerUnit,
      grossWeightKg: grossWeightKg ?? this.grossWeightKg,
      netWeightKg: netWeightKg ?? this.netWeightKg,
      lastCustomsDutyPct: lastCustomsDutyPct ?? this.lastCustomsDutyPct,
      lastVatPct: lastVatPct ?? this.lastVatPct,
      lastScheduleTaxPct: lastScheduleTaxPct ?? this.lastScheduleTaxPct,
      productCategory: productCategory ?? this.productCategory,
      productSubcategory: productSubcategory ?? this.productSubcategory,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MasterItemModel &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          itemCode == other.itemCode;

  @override
  int get hashCode => itemId.hashCode ^ itemCode.hashCode;
}

/// Paginated / List wrapper for Master Items API response
@immutable
class MasterItemListModel {
  final int total;
  final List<MasterItemModel> items;

  const MasterItemListModel({
    required this.total,
    required this.items,
  });

  factory MasterItemListModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return MasterItemListModel(
      total: (json['total'] as num?)?.toInt() ?? rawItems.length,
      items: rawItems
          .map((item) => MasterItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

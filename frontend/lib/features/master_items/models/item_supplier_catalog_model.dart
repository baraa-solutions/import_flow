import 'package:flutter/foundation.dart';

/// Item Supplier Catalog Model (MD-ITEM-001)
/// Maps Master Items to Overseas Suppliers, with quotes and part codes.
@immutable
class ItemSupplierCatalogModel {
  final int catalogId;
  final int itemId;
  final String? itemCode;
  final int supplierId;
  final String? supplierName;
  final String? supplierItemCode;
  final String? supplierDescription;
  final double? lastConfirmedPrice;
  final String lastConfirmedCurrency;
  final String? lastConfirmedDate;
  final int? lastPoId;
  final double? minOrderQty;
  final int? leadTimeDays;
  final String? preferredIncoterm;
  final bool isPreferredSupplier;
  final String? notes;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ItemSupplierCatalogModel({
    required this.catalogId,
    required this.itemId,
    this.itemCode,
    required this.supplierId,
    this.supplierName,
    this.supplierItemCode,
    this.supplierDescription,
    this.lastConfirmedPrice,
    this.lastConfirmedCurrency = 'USD',
    this.lastConfirmedDate,
    this.lastPoId,
    this.minOrderQty,
    this.leadTimeDays,
    this.preferredIncoterm,
    this.isPreferredSupplier = false,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ItemSupplierCatalogModel.fromJson(Map<String, dynamic> json) {
    return ItemSupplierCatalogModel(
      catalogId: (json['catalog_id'] as num?)?.toInt() ?? 0,
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      itemCode: json['item_code']?.toString(),
      supplierId: (json['supplier_id'] as num?)?.toInt() ?? 0,
      supplierName: json['supplier_name']?.toString(),
      supplierItemCode: json['supplier_item_code']?.toString(),
      supplierDescription: json['supplier_description']?.toString(),
      lastConfirmedPrice: (json['last_confirmed_price'] as num?)?.toDouble(),
      lastConfirmedCurrency: json['last_confirmed_currency']?.toString() ?? 'USD',
      lastConfirmedDate: json['last_confirmed_date']?.toString(),
      lastPoId: (json['last_po_id'] as num?)?.toInt(),
      minOrderQty: (json['min_order_qty'] as num?)?.toDouble(),
      leadTimeDays: (json['lead_time_days'] as num?)?.toInt(),
      preferredIncoterm: json['preferred_incoterm']?.toString(),
      isPreferredSupplier: json['is_preferred_supplier'] as bool? ?? false,
      notes: json['notes']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'catalog_id': catalogId,
      'item_id': itemId,
      if (itemCode != null) 'item_code': itemCode,
      'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      'supplier_item_code': supplierItemCode,
      'supplier_description': supplierDescription,
      'last_confirmed_price': lastConfirmedPrice,
      'last_confirmed_currency': lastConfirmedCurrency,
      'last_confirmed_date': lastConfirmedDate,
      'last_po_id': lastPoId,
      'min_order_qty': minOrderQty,
      'lead_time_days': leadTimeDays,
      'preferred_incoterm': preferredIncoterm,
      'is_preferred_supplier': isPreferredSupplier,
      'notes': notes,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  ItemSupplierCatalogModel copyWith({
    int? catalogId,
    int? itemId,
    String? itemCode,
    int? supplierId,
    String? supplierName,
    String? supplierItemCode,
    String? supplierDescription,
    double? lastConfirmedPrice,
    String? lastConfirmedCurrency,
    String? lastConfirmedDate,
    int? lastPoId,
    double? minOrderQty,
    int? leadTimeDays,
    String? preferredIncoterm,
    bool? isPreferredSupplier,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemSupplierCatalogModel(
      catalogId: catalogId ?? this.catalogId,
      itemId: itemId ?? this.itemId,
      itemCode: itemCode ?? this.itemCode,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      supplierItemCode: supplierItemCode ?? this.supplierItemCode,
      supplierDescription: supplierDescription ?? this.supplierDescription,
      lastConfirmedPrice: lastConfirmedPrice ?? this.lastConfirmedPrice,
      lastConfirmedCurrency: lastConfirmedCurrency ?? this.lastConfirmedCurrency,
      lastConfirmedDate: lastConfirmedDate ?? this.lastConfirmedDate,
      lastPoId: lastPoId ?? this.lastPoId,
      minOrderQty: minOrderQty ?? this.minOrderQty,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      preferredIncoterm: preferredIncoterm ?? this.preferredIncoterm,
      isPreferredSupplier: isPreferredSupplier ?? this.isPreferredSupplier,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemSupplierCatalogModel &&
          runtimeType == other.runtimeType &&
          catalogId == other.catalogId;

  @override
  int get hashCode => catalogId.hashCode;
}

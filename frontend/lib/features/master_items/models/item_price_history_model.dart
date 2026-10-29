import 'package:flutter/foundation.dart';

/// Historical Item Purchase and Landed Cost Ledger Entry (MD-ITEM-001)
/// Records purchasing transactions, exchange rates, and final landed costs.
@immutable
class ItemPriceHistoryModel {
  final int historyId;
  final int itemId;
  final int? supplierId;
  final String? supplierName;
  final int? poId;
  final String? poNumber;
  final int? importFileId;
  final String? importFileCode;
  final double unitPriceFx;
  final String currency;
  final double exchangeRate;
  final double? unitPriceEgp;
  final double? landedCostEgp;
  final double? landedCostMarkup;
  final double? quantity;
  final String? poDate;
  final DateTime? recordedAt;

  const ItemPriceHistoryModel({
    required this.historyId,
    required this.itemId,
    this.supplierId,
    this.supplierName,
    this.poId,
    this.poNumber,
    this.importFileId,
    this.importFileCode,
    required this.unitPriceFx,
    required this.currency,
    this.exchangeRate = 1.0,
    this.unitPriceEgp,
    this.landedCostEgp,
    this.landedCostMarkup,
    this.quantity,
    this.poDate,
    this.recordedAt,
  });

  factory ItemPriceHistoryModel.fromJson(Map<String, dynamic> json) {
    return ItemPriceHistoryModel(
      historyId: (json['history_id'] as num?)?.toInt() ?? 0,
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      supplierId: (json['supplier_id'] as num?)?.toInt(),
      supplierName: json['supplier_name']?.toString(),
      poId: (json['po_id'] as num?)?.toInt(),
      poNumber: json['po_number']?.toString(),
      importFileId: (json['import_file_id'] as num?)?.toInt(),
      importFileCode: json['import_file_code']?.toString(),
      unitPriceFx: (json['unit_price_fx'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'USD',
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      unitPriceEgp: (json['unit_price_egp'] as num?)?.toDouble(),
      landedCostEgp: (json['landed_cost_egp'] as num?)?.toDouble(),
      landedCostMarkup: (json['landed_cost_markup'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      poDate: json['po_date']?.toString(),
      recordedAt: json['recorded_at'] != null
          ? DateTime.tryParse(json['recorded_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'history_id': historyId,
      'item_id': itemId,
      if (supplierId != null) 'supplier_id': supplierId,
      if (supplierName != null) 'supplier_name': supplierName,
      if (poId != null) 'po_id': poId,
      if (poNumber != null) 'po_number': poNumber,
      if (importFileId != null) 'import_file_id': importFileId,
      if (importFileCode != null) 'import_file_code': importFileCode,
      'unit_price_fx': unitPriceFx,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'unit_price_egp': unitPriceEgp,
      'landed_cost_egp': landedCostEgp,
      'landed_cost_markup': landedCostMarkup,
      'quantity': quantity,
      'po_date': poDate,
      if (recordedAt != null) 'recorded_at': recordedAt!.toIso8601String(),
    };
  }

  ItemPriceHistoryModel copyWith({
    int? historyId,
    int? itemId,
    int? supplierId,
    String? supplierName,
    int? poId,
    String? poNumber,
    int? importFileId,
    String? importFileCode,
    double? unitPriceFx,
    String? currency,
    double? exchangeRate,
    double? unitPriceEgp,
    double? landedCostEgp,
    double? landedCostMarkup,
    double? quantity,
    String? poDate,
    DateTime? recordedAt,
  }) {
    return ItemPriceHistoryModel(
      historyId: historyId ?? this.historyId,
      itemId: itemId ?? this.itemId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      poId: poId ?? this.poId,
      poNumber: poNumber ?? this.poNumber,
      importFileId: importFileId ?? this.importFileId,
      importFileCode: importFileCode ?? this.importFileCode,
      unitPriceFx: unitPriceFx ?? this.unitPriceFx,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      unitPriceEgp: unitPriceEgp ?? this.unitPriceEgp,
      landedCostEgp: landedCostEgp ?? this.landedCostEgp,
      landedCostMarkup: landedCostMarkup ?? this.landedCostMarkup,
      quantity: quantity ?? this.quantity,
      poDate: poDate ?? this.poDate,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemPriceHistoryModel &&
          runtimeType == other.runtimeType &&
          historyId == other.historyId;

  @override
  int get hashCode => historyId.hashCode;
}

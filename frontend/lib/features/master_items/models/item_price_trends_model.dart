import 'package:flutter/foundation.dart';
import 'item_price_history_model.dart';

/// Price Trend Analytics Model for a Master Item (MD-ITEM-001)
/// Aggregates purchase price history, min/max/average rates, and landed cost markup.
@immutable
class ItemPriceTrendsModel {
  final int itemId;
  final String itemCode;
  final String descriptionAr;
  final int totalPurchasesCount;
  final double averageUnitPriceFx;
  final double minUnitPriceFx;
  final double maxUnitPriceFx;
  final double? averageLandedCostEgp;
  final double? averageMarkupPercent;
  final List<ItemPriceHistoryModel> history;

  const ItemPriceTrendsModel({
    required this.itemId,
    required this.itemCode,
    required this.descriptionAr,
    required this.totalPurchasesCount,
    required this.averageUnitPriceFx,
    required this.minUnitPriceFx,
    required this.maxUnitPriceFx,
    this.averageLandedCostEgp,
    this.averageMarkupPercent,
    this.history = const [],
  });

  factory ItemPriceTrendsModel.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? [];
    return ItemPriceTrendsModel(
      itemId: (json['item_id'] as num?)?.toInt() ?? 0,
      itemCode: json['item_code']?.toString() ?? '',
      descriptionAr: json['description_ar']?.toString() ?? '',
      totalPurchasesCount: (json['total_purchases_count'] as num?)?.toInt() ?? 0,
      averageUnitPriceFx: (json['average_unit_price_fx'] as num?)?.toDouble() ?? 0.0,
      minUnitPriceFx: (json['min_unit_price_fx'] as num?)?.toDouble() ?? 0.0,
      maxUnitPriceFx: (json['max_unit_price_fx'] as num?)?.toDouble() ?? 0.0,
      averageLandedCostEgp: (json['average_landed_cost_egp'] as num?)?.toDouble(),
      averageMarkupPercent: (json['average_markup_percent'] as num?)?.toDouble(),
      history: rawHistory
          .map((h) => ItemPriceHistoryModel.fromJson(h as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_code': itemCode,
      'description_ar': descriptionAr,
      'total_purchases_count': totalPurchasesCount,
      'average_unit_price_fx': averageUnitPriceFx,
      'min_unit_price_fx': minUnitPriceFx,
      'max_unit_price_fx': maxUnitPriceFx,
      'average_landed_cost_egp': averageLandedCostEgp,
      'average_markup_percent': averageMarkupPercent,
      'history': history.map((h) => h.toJson()).toList(),
    };
  }

  ItemPriceTrendsModel copyWith({
    int? itemId,
    String? itemCode,
    String? descriptionAr,
    int? totalPurchasesCount,
    double? averageUnitPriceFx,
    double? minUnitPriceFx,
    double? maxUnitPriceFx,
    double? averageLandedCostEgp,
    double? averageMarkupPercent,
    List<ItemPriceHistoryModel>? history,
  }) {
    return ItemPriceTrendsModel(
      itemId: itemId ?? this.itemId,
      itemCode: itemCode ?? this.itemCode,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      totalPurchasesCount: totalPurchasesCount ?? this.totalPurchasesCount,
      averageUnitPriceFx: averageUnitPriceFx ?? this.averageUnitPriceFx,
      minUnitPriceFx: minUnitPriceFx ?? this.minUnitPriceFx,
      maxUnitPriceFx: maxUnitPriceFx ?? this.maxUnitPriceFx,
      averageLandedCostEgp: averageLandedCostEgp ?? this.averageLandedCostEgp,
      averageMarkupPercent: averageMarkupPercent ?? this.averageMarkupPercent,
      history: history ?? this.history,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemPriceTrendsModel &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;
}

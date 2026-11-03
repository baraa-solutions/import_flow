import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Data model for Split Shipment Allocation
class SplitAllocationData {
  final int id;
  final int shipmentId;
  final String parentBlNumber;
  final String splitBlNumber;
  final int? poId;
  final int? poItemId;
  final String itemSku;
  final double allocatedQuantity;
  final double totalItemQuantity;
  final double allocationRatio;
  final double proratedCustomsCost;
  final double proratedFreightCost;
  final String currency;
  final String? notes;

  SplitAllocationData({
    required this.id,
    required this.shipmentId,
    required this.parentBlNumber,
    required this.splitBlNumber,
    this.poId,
    this.poItemId,
    required this.itemSku,
    required this.allocatedQuantity,
    required this.totalItemQuantity,
    required this.allocationRatio,
    required this.proratedCustomsCost,
    required this.proratedFreightCost,
    required this.currency,
    this.notes,
  });

  factory SplitAllocationData.fromJson(Map<String, dynamic> json) {
    return SplitAllocationData(
      id: json['id'] as int? ?? 0,
      shipmentId: json['shipment_id'] as int? ?? 0,
      parentBlNumber: json['parent_bl_number'] as String? ?? '',
      splitBlNumber: json['split_bl_number'] as String? ?? '',
      poId: json['po_id'] as int?,
      poItemId: json['po_item_id'] as int?,
      itemSku: json['item_sku'] as String? ?? '',
      allocatedQuantity: (json['allocated_quantity'] as num?)?.toDouble() ?? 0.0,
      totalItemQuantity: (json['total_item_quantity'] as num?)?.toDouble() ?? 0.0,
      allocationRatio: (json['allocation_ratio'] as num?)?.toDouble() ?? 0.0,
      proratedCustomsCost: (json['prorated_customs_cost'] as num?)?.toDouble() ?? 0.0,
      proratedFreightCost: (json['prorated_freight_cost'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'EGP',
      notes: json['notes'] as String?,
    );
  }
}

/// Split Allocations List Result
class SplitAllocationsListResult {
  final List<SplitAllocationData> items;
  final int total;
  final int uniqueSplitBlCount;
  final double totalAllocatedQuantity;
  final double totalProratedCustoms;
  final double totalProratedFreight;

  SplitAllocationsListResult({
    required this.items,
    required this.total,
    required this.uniqueSplitBlCount,
    required this.totalAllocatedQuantity,
    required this.totalProratedCustoms,
    required this.totalProratedFreight,
  });

  factory SplitAllocationsListResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return SplitAllocationsListResult(
      items: list.map((i) => SplitAllocationData.fromJson(i as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? 0,
      uniqueSplitBlCount: json['unique_split_bl_count'] as int? ?? 0,
      totalAllocatedQuantity: (json['total_allocated_quantity'] as num?)?.toDouble() ?? 0.0,
      totalProratedCustoms: (json['total_prorated_customs'] as num?)?.toDouble() ?? 0.0,
      totalProratedFreight: (json['total_prorated_freight'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Unallocated PO item placeholder model
class UnallocatedPoItem {
  final int poItemId;
  final int poId;
  final String poNumber;
  final String itemSku;
  final String itemName;
  final double totalQuantity;
  final double allocatedQuantity;

  UnallocatedPoItem({
    required this.poItemId,
    required this.poId,
    required this.poNumber,
    required this.itemSku,
    required this.itemName,
    required this.totalQuantity,
    required this.allocatedQuantity,
  });

  double get remainingQuantity => totalQuantity - allocatedQuantity;
}

/// Repository
class SplitShipmentsRepository {
  final Dio dio;

  SplitShipmentsRepository(this.dio);

  Future<SplitAllocationsListResult> listAllocations(
    int shipmentId, {
    String? splitBlNumber,
  }) async {
    final params = <String, dynamic>{};
    if (splitBlNumber != null && splitBlNumber.isNotEmpty) {
      params['split_bl_number'] = splitBlNumber;
    }
    final response = await dio.get(
      '/api/v1/split-shipments/shipments/$shipmentId/allocations',
      queryParameters: params,
    );
    return SplitAllocationsListResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SplitAllocationData> createAllocation(
    int shipmentId,
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.post(
      '/api/v1/split-shipments/shipments/$shipmentId/allocations',
      data: payload,
    );
    return SplitAllocationData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> recalculateProratedCosts(
    int shipmentId, {
    required double customsPool,
    required double freightPool,
    String currency = 'EGP',
  }) async {
    await dio.post(
      '/api/v1/split-shipments/shipments/$shipmentId/calculate-prorated-costs',
      data: {
        'shipment_id': shipmentId,
        'customs_cost_pool': customsPool,
        'freight_cost_pool': freightPool,
        'currency': currency,
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final splitShipmentsRepositoryProvider = Provider<SplitShipmentsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SplitShipmentsRepository(dio);
});

final splitShipmentIdProvider = StateProvider<int>((ref) => 1);
final selectedSplitBlFilterProvider = StateProvider<String?>((ref) => null);

final splitAllocationsListProvider =
    FutureProvider.autoDispose<SplitAllocationsListResult>((ref) async {
  final repo = ref.watch(splitShipmentsRepositoryProvider);
  final shipmentId = ref.watch(splitShipmentIdProvider);
  final splitBl = ref.watch(selectedSplitBlFilterProvider);
  return repo.listAllocations(shipmentId, splitBlNumber: splitBl);
});

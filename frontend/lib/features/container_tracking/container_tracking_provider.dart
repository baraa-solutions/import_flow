import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Data model for Demurrage Charge
class ContainerDemurrageData {
  final int id;
  final int containerId;
  final int freeTimeDays;
  final DateTime? freeTimeEndDate;
  final double dailyDemurrageRate;
  final DateTime? actualReturnDate;
  final int daysOverdue;
  final double totalDemurrageAmount;
  final String currency;
  final String? notes;

  ContainerDemurrageData({
    required this.id,
    required this.containerId,
    required this.freeTimeDays,
    this.freeTimeEndDate,
    required this.dailyDemurrageRate,
    this.actualReturnDate,
    required this.daysOverdue,
    required this.totalDemurrageAmount,
    required this.currency,
    this.notes,
  });

  factory ContainerDemurrageData.fromJson(Map<String, dynamic> json) {
    return ContainerDemurrageData(
      id: json['id'] as int? ?? 0,
      containerId: json['container_id'] as int? ?? 0,
      freeTimeDays: json['free_time_days'] as int? ?? 14,
      freeTimeEndDate: json['free_time_end_date'] != null
          ? DateTime.tryParse(json['free_time_end_date'] as String)
          : null,
      dailyDemurrageRate: (json['daily_demurrage_rate'] as num?)?.toDouble() ?? 0.0,
      actualReturnDate: json['actual_return_date'] != null
          ? DateTime.tryParse(json['actual_return_date'] as String)
          : null,
      daysOverdue: json['days_overdue'] as int? ?? 0,
      totalDemurrageAmount: (json['total_demurrage_amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      notes: json['notes'] as String?,
    );
  }
}

/// Data model for Container Lifecycle Unit
class ContainerUnitData {
  final int id;
  final String containerNumber;
  final String? sealNumber;
  final String isoType;
  final double? tareWeight;
  final double? payloadWeight;
  final double? grossWeight;
  final double? vgmWeight;
  final DateTime? dischargeDate;
  final DateTime? gateOutHeldDate;
  final DateTime? emptyReturnedDate;
  final String status;
  final int shipmentId;
  final String? notes;
  final List<ContainerDemurrageData> demurrageCharges;

  ContainerUnitData({
    required this.id,
    required this.containerNumber,
    this.sealNumber,
    required this.isoType,
    this.tareWeight,
    this.payloadWeight,
    this.grossWeight,
    this.vgmWeight,
    this.dischargeDate,
    this.gateOutHeldDate,
    this.emptyReturnedDate,
    required this.status,
    required this.shipmentId,
    this.notes,
    required this.demurrageCharges,
  });

  factory ContainerUnitData.fromJson(Map<String, dynamic> json) {
    final list = json['demurrage_charges'] as List<dynamic>? ?? [];
    return ContainerUnitData(
      id: json['id'] as int? ?? 0,
      containerNumber: json['container_number'] as String? ?? '',
      sealNumber: json['seal_number'] as String?,
      isoType: json['iso_type'] as String? ?? '40HC',
      tareWeight: (json['tare_weight'] as num?)?.toDouble(),
      payloadWeight: (json['payload_weight'] as num?)?.toDouble(),
      grossWeight: (json['gross_weight'] as num?)?.toDouble(),
      vgmWeight: (json['vgm_weight'] as num?)?.toDouble(),
      dischargeDate: json['discharge_date'] != null
          ? DateTime.tryParse(json['discharge_date'] as String)
          : null,
      gateOutHeldDate: json['gate_out_held_date'] != null
          ? DateTime.tryParse(json['gate_out_held_date'] as String)
          : null,
      emptyReturnedDate: json['empty_returned_date'] != null
          ? DateTime.tryParse(json['empty_returned_date'] as String)
          : null,
      status: json['status'] as String? ?? 'ON_VESSEL',
      shipmentId: json['shipment_id'] as int? ?? 0,
      notes: json['notes'] as String?,
      demurrageCharges: list
          .map((d) => ContainerDemurrageData.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  double get latestDemurrageTotal {
    if (demurrageCharges.isEmpty) return 0.0;
    return demurrageCharges.first.totalDemurrageAmount;
  }
}

/// Container List Response Model
class ContainerListResult {
  final List<ContainerUnitData> items;
  final int total;
  final int onVesselCount;
  final int dischargedCount;
  final int gateOutHeldCount;
  final int returnedEmptyCount;
  final int damagedCount;
  final double totalDemurrageAccrued;

  ContainerListResult({
    required this.items,
    required this.total,
    required this.onVesselCount,
    required this.dischargedCount,
    required this.gateOutHeldCount,
    required this.returnedEmptyCount,
    required this.damagedCount,
    required this.totalDemurrageAccrued,
  });

  factory ContainerListResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return ContainerListResult(
      items: list.map((i) => ContainerUnitData.fromJson(i as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? 0,
      onVesselCount: json['on_vessel_count'] as int? ?? 0,
      dischargedCount: json['discharged_count'] as int? ?? 0,
      gateOutHeldCount: json['gate_out_held_count'] as int? ?? 0,
      returnedEmptyCount: json['returned_empty_count'] as int? ?? 0,
      damagedCount: json['damaged_count'] as int? ?? 0,
      totalDemurrageAccrued: (json['total_demurrage_accrued'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Repository
class ContainerTrackingRepository {
  final Dio dio;

  ContainerTrackingRepository(this.dio);

  Future<ContainerListResult> getShipmentContainers(
    int shipmentId, {
    String? status,
  }) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    final response = await dio.get(
      '/api/v1/container-tracking/shipments/$shipmentId/containers',
      queryParameters: params,
    );
    return ContainerListResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerUnitData> createContainer(
    int shipmentId,
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.post(
      '/api/v1/container-tracking/shipments/$shipmentId/containers',
      data: payload,
    );
    return ContainerUnitData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContainerUnitData> updateContainer(
    int containerId,
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.put(
      '/api/v1/container-tracking/containers/$containerId',
      data: payload,
    );
    return ContainerUnitData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> calculateDemurrage(int containerId) async {
    await dio.post(
      '/api/v1/container-tracking/containers/$containerId/calculate-demurrage',
    );
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final containerTrackingRepositoryProvider = Provider<ContainerTrackingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ContainerTrackingRepository(dio);
});

final containerShipmentIdProvider = StateProvider<int>((ref) => 1);
final containerStatusFilterProvider = StateProvider<String?>((ref) => null);
final selectedContainerForTimelineProvider = StateProvider<ContainerUnitData?>((ref) => null);

final containerTrackingListProvider =
    FutureProvider.autoDispose<ContainerListResult>((ref) async {
  final repo = ref.watch(containerTrackingRepositoryProvider);
  final shipmentId = ref.watch(containerShipmentIdProvider);
  final status = ref.watch(containerStatusFilterProvider);
  return repo.getShipmentContainers(shipmentId, status: status);
});

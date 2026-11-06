import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// Data model for Multimodal Freight Record
class MultimodalFreightRecord {
  final int id;
  final int shipmentId;
  final String transportMode;
  final String? awbNumber;
  final String? airlineCode;
  final String? flightNumber;
  final double terminalHandlingCharges;
  final double lclCbm;
  final double lclRatePerCbm;
  final double lclCfsFee;
  final String? roroVehicleType;
  final double roroDimensionsCbm;
  final String? bulkCargoType;
  final double bulkTonnage;
  final String? specialHandlingNotes;
  final double calculatedSubtotal;

  MultimodalFreightRecord({
    required this.id,
    required this.shipmentId,
    required this.transportMode,
    this.awbNumber,
    this.airlineCode,
    this.flightNumber,
    required this.terminalHandlingCharges,
    required this.lclCbm,
    required this.lclRatePerCbm,
    required this.lclCfsFee,
    this.roroVehicleType,
    required this.roroDimensionsCbm,
    this.bulkCargoType,
    required this.bulkTonnage,
    this.specialHandlingNotes,
    required this.calculatedSubtotal,
  });

  factory MultimodalFreightRecord.fromJson(Map<String, dynamic> json) {
    return MultimodalFreightRecord(
      id: json['id'] as int? ?? 0,
      shipmentId: json['shipment_id'] as int? ?? 0,
      transportMode: json['transport_mode'] as String? ?? 'AIR',
      awbNumber: json['awb_number'] as String?,
      airlineCode: json['airline_code'] as String?,
      flightNumber: json['flight_number'] as String?,
      terminalHandlingCharges: (json['terminal_handling_charges'] as num?)?.toDouble() ?? 0.0,
      lclCbm: (json['lcl_cbm'] as num?)?.toDouble() ?? 0.0,
      lclRatePerCbm: (json['lcl_rate_per_cbm'] as num?)?.toDouble() ?? 0.0,
      lclCfsFee: (json['lcl_cfs_fee'] as num?)?.toDouble() ?? 0.0,
      roroVehicleType: json['roro_vehicle_type'] as String?,
      roroDimensionsCbm: (json['roro_dimensions_cbm'] as num?)?.toDouble() ?? 0.0,
      bulkCargoType: json['bulk_cargo_type'] as String?,
      bulkTonnage: (json['bulk_tonnage'] as num?)?.toDouble() ?? 0.0,
      specialHandlingNotes: json['special_handling_notes'] as String?,
      calculatedSubtotal: (json['calculated_subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Response list model
class MultimodalFreightListResult {
  final List<MultimodalFreightRecord> items;
  final int total;
  final int airCount;
  final int lclCount;
  final int roroCount;
  final int bulkCount;
  final double totalEstimatedCharges;

  MultimodalFreightListResult({
    required this.items,
    required this.total,
    required this.airCount,
    required this.lclCount,
    required this.roroCount,
    required this.bulkCount,
    required this.totalEstimatedCharges,
  });

  factory MultimodalFreightListResult.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return MultimodalFreightListResult(
      items: list.map((i) => MultimodalFreightRecord.fromJson(i as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? 0,
      airCount: json['air_count'] as int? ?? 0,
      lclCount: json['lcl_count'] as int? ?? 0,
      roroCount: json['roro_count'] as int? ?? 0,
      bulkCount: json['bulk_count'] as int? ?? 0,
      totalEstimatedCharges: (json['total_estimated_charges'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Repository
class MultimodalFreightRepository {
  final Dio dio;

  MultimodalFreightRepository(this.dio);

  Future<MultimodalFreightListResult> listFreightDetails(
    int shipmentId, {
    String? transportMode,
  }) async {
    final params = <String, dynamic>{};
    if (transportMode != null && transportMode.isNotEmpty) {
      params['transport_mode'] = transportMode;
    }
    final response = await dio.get(
      '/api/v1/multimodal-freight/shipments/$shipmentId/freight-details',
      queryParameters: params,
    );
    return MultimodalFreightListResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MultimodalFreightRecord> createDetails(
    int shipmentId,
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.post(
      '/api/v1/multimodal-freight/shipments/$shipmentId/freight-details',
      data: payload,
    );
    return MultimodalFreightRecord.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MultimodalFreightRecord> updateDetails(
    int detailsId,
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.put(
      '/api/v1/multimodal-freight/freight-details/$detailsId',
      data: payload,
    );
    return MultimodalFreightRecord.fromJson(response.data as Map<String, dynamic>);
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final multimodalFreightRepositoryProvider = Provider<MultimodalFreightRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return MultimodalFreightRepository(dio);
});

final multimodalModeFilterProvider = StateProvider<String?>((ref) => null);

/// Keyed by the selected import file id — never fetched without a chosen file.
final multimodalFreightListProvider =
    FutureProvider.autoDispose.family<MultimodalFreightListResult, int>((ref, shipmentId) async {
  final repo = ref.watch(multimodalFreightRepositoryProvider);
  final mode = ref.watch(multimodalModeFilterProvider);
  return repo.listFreightDetails(shipmentId, transportMode: mode);
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/air_freight_models.dart';

const _base = '/api/v1/air-freight';

class AirFreightRepository {
  final Dio dio;

  AirFreightRepository(this.dio);

  Future<List<AirShipmentRecord>> listRecords(int importFileId) async {
    final res = await dio.get('$_base/records', queryParameters: {'import_file_id': importFileId});
    return (res.data as List).map((e) => AirShipmentRecord.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<AirShipmentRecord> createRecord(Map<String, dynamic> payload) async {
    final res = await dio.post('$_base/records', data: payload);
    return AirShipmentRecord.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<AirShipmentRecord> updateRecord(int id, Map<String, dynamic> payload) async {
    final res = await dio.put('$_base/records/$id', data: payload);
    return AirShipmentRecord.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteRecord(int id) => dio.delete('$_base/records/$id');

  Future<List<DraftAwbReview>> listReviews(int airRecordId) async {
    final res = await dio.get('$_base/records/$airRecordId/reviews');
    return (res.data as List).map((e) => DraftAwbReview.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<DraftAwbReview> createReview(int airRecordId, Map<String, dynamic> draft) async {
    final res = await dio.post('$_base/reviews', data: {'air_record_id': airRecordId, 'draft': draft});
    return DraftAwbReview.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<DraftAwbReview> decideReview(int reviewId, String decision, {String? notes}) async {
    final res = await dio.post('$_base/reviews/$reviewId/decision', data: {'decision': decision, 'notes': notes});
    return DraftAwbReview.fromJson((res.data as Map).cast<String, dynamic>());
  }
}

final airFreightRepositoryProvider = Provider<AirFreightRepository>((ref) {
  return AirFreightRepository(ref.watch(dioProvider));
});

/// AWB records of one import file (never fetched without a chosen file).
final airShipmentRecordsProvider = FutureProvider.autoDispose.family<List<AirShipmentRecord>, int>((
  ref,
  importFileId,
) async {
  return ref.watch(airFreightRepositoryProvider).listRecords(importFileId);
});

/// A master-data option for the searchable dropdowns (airports, airlines).
class AirMasterOption {
  final int id;
  final String label;
  final String? subtitle;

  const AirMasterOption(this.id, this.label, [this.subtitle]);
}

/// Active airports (transport_locations, location_type = Airport); reloaded whenever the panel is mounted.
final airportOptionsProvider = FutureProvider.autoDispose<List<AirMasterOption>>((ref) async {
  final res = await ref
      .watch(dioProvider)
      .get('/api/v1/transport-locations', queryParameters: {'location_type': 'Airport', 'limit': 5000});
  return (res.data as List).map((e) {
    final m = (e as Map).cast<String, dynamic>();
    return AirMasterOption(
      (m['location_id'] as num).toInt(),
      '${m['un_locode']} - ${m['location_name']}',
      '${m['city'] ?? ''}, ${m['country'] ?? ''}',
    );
  }).toList();
});

/// Active carriers usable on an AWB (any partner type; the type is shown as the subtitle).
final airlineOptionsProvider = FutureProvider.autoDispose<List<AirMasterOption>>((ref) async {
  final res = await ref.watch(dioProvider).get('/api/v1/external-service-providers');
  return (res.data as List).map((e) {
    final m = (e as Map).cast<String, dynamic>();
    return AirMasterOption(
      (m['provider_id'] as num).toInt(),
      m['partner_name'] as String? ?? '',
      m['partner_type'] as String?,
    );
  }).toList();
});

/// Review history of one AWB record, newest version first.
final draftAwbReviewsProvider = FutureProvider.autoDispose.family<List<DraftAwbReview>, int>((ref, airRecordId) async {
  return ref.watch(airFreightRepositoryProvider).listReviews(airRecordId);
});

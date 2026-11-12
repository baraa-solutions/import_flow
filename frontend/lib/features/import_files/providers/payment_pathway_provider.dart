import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/payment_pathway_status_model.dart';

/// Live payment pathway milestones of one import file. `autoDispose` so every
/// screen mount refetches from the backend; call `ref.invalidate` after any
/// financing change (LC / CAD instrument, SWIFT payment, GRN) to refresh.
final paymentPathwayStatusProvider =
    FutureProvider.autoDispose.family<PaymentPathwayStatus, int>((ref, importFileId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('${ApiConstants.importFiles}/$importFileId/payment-pathway');
  return PaymentPathwayStatus.fromJson(Map<String, dynamic>.from(response.data as Map));
});

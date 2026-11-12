import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/integration_status_model.dart';

/// Live integration modes from the backend. autoDispose: every screen that shows Nafeza / CargoX
/// status re-reads it on mount, so a changed server config is never hidden behind a stale cache.
final integrationStatusProvider = FutureProvider.autoDispose<IntegrationStatus>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('${ApiConstants.baseUrl}/integrations/status');
  return IntegrationStatus.fromJson(response.data as Map<String, dynamic>);
});

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/audit_log_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/paged_data_table/list_query.dart';
import '../../../core/widgets/paged_data_table/paged_list_notifier.dart';

// Live Server-Paged provider for high-performance virtualization
final auditLogsPagedProvider = StateNotifierProvider.autoDispose<DefaultPagedListNotifier<AuditLogModel>, PagedListState<AuditLogModel>>((ref) {
  final dio = ref.watch(dioProvider);
  final source = ServerPagedSource<AuditLogModel>(
    dio: dio,
    path: '${ApiConstants.baseUrl}/audit-logs/paginated',
    fromJson: AuditLogModel.fromJson,
  );
  final notifier = DefaultPagedListNotifier<AuditLogModel>(
    source,
    initialQuery: const ListQuery(page: 1, pageSize: 50, sort: '-created_at'),
  );
  notifier.load();
  return notifier;
});

// Fetch single row history timeline live from API
final entityAuditTimelineProvider = FutureProvider.family<List<AuditLogModel>, ({String entityType, int entityId})>((ref, arg) async {
  final dio = ref.watch(dioProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('entityAuditTimelineProvider disposed'));
  final response = await dio.get(
    '${ApiConstants.baseUrl}/audit-logs/${arg.entityType}/${arg.entityId}',
    cancelToken: cancelToken,
  );
  final List data = response.data as List;
  return data.map((json) => AuditLogModel.fromJson(json as Map<String, dynamic>)).toList();
});

// Fetch all system-wide audit logs live from API (retained for backward compatibility)
final systemAuditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  final dio = ref.watch(dioProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel('systemAuditLogsProvider disposed'));
  final response = await dio.get(
    '${ApiConstants.baseUrl}/audit-logs?limit=200',
    cancelToken: cancelToken,
  );
  final List data = response.data as List;
  return data.map((json) => AuditLogModel.fromJson(json as Map<String, dynamic>)).toList();
});

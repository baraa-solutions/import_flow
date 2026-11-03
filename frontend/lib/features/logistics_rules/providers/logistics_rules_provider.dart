import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/logistics_rule.dart';
import '../repositories/logistics_rules_repository.dart';

final logisticsRulesRepositoryProvider = Provider<LogisticsRulesRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return LogisticsRulesRepository(dio);
});

final logisticsRulesFilterScopeProvider = StateProvider<String?>((ref) => null);
final logisticsRulesFilterStatusProvider = StateProvider<String?>((ref) => null);

final logisticsRulesProvider =
    FutureProvider.autoDispose<List<LogisticsRule>>((ref) async {
  final repo = ref.watch(logisticsRulesRepositoryProvider);
  final scope = ref.watch(logisticsRulesFilterScopeProvider);
  final status = ref.watch(logisticsRulesFilterStatusProvider);

  return repo.listRules(
    scopeType: scope,
    verificationStatus: status,
    isLatest: true,
  );
});

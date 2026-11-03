import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/system_observability_provider.dart';
import 'observability_metric_strip.dart';
import 'system_health_table.dart';

class LivePulseTab extends ConsumerWidget {
  final bool isArabic;

  const LivePulseTab({
    super.key,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(systemMetricsProvider);
    final dbHealthAsync = ref.watch(databaseHealthProvider);

    return metricsAsync.when(
      data: (metrics) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ObservabilityMetricStrip(
                metrics: metrics,
                dbHealth: dbHealthAsync.valueOrNull,
                isArabic: isArabic,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 320,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'توزيع رموز الاستجابة' : 'Status Codes Distribution',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.charcoal,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildTrafficRow(isArabic ? '2xx / 3xx - طلبات ناجحة' : '2xx / 3xx - Success', metrics.status2xx, AppTheme.emerald),
                            const Divider(height: 16),
                            _buildTrafficRow(isArabic ? '4xx - أخطاء العميل' : '4xx - Client Errors', metrics.status4xx, AppTheme.orange),
                            const Divider(height: 16),
                            _buildTrafficRow(isArabic ? '5xx - أخطاء الخادم' : '5xx - Server Errors', metrics.status5xx, AppTheme.crimson),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isArabic ? 'إجمالي الأخطاء:' : 'Total Errors:', style: const TextStyle(fontSize: 11)),
                                  Text(
                                    '${metrics.totalErrors} (${metrics.totalRequests > 0 ? ((metrics.totalErrors / metrics.totalRequests) * 100).toStringAsFixed(1) : 0}%)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SystemHealthTable(
                      topEndpoints: metrics.topEndpoints,
                      isArabic: isArabic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const AppLoadingState(),
      error: (e, _) => Center(child: Text('خطأ في تحميل مؤشرات الأداء: $e')),
    );
  }

  Widget _buildTrafficRow(String label, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11.5)),
          ],
        ),
        Text(
          '$count',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
        ),
      ],
    );
  }
}

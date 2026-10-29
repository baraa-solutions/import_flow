import 'package:flutter/material.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../models/system_observability_model.dart';

/// 📊 Observability Metric Strip
///
/// Displays core system observability KPIs in a canonical, responsive strip using
/// [MetricCardStrip] and [MetricCardData].
class ObservabilityMetricStrip extends StatelessWidget {
  final SystemMetricsModel metrics;
  final DatabaseHealthModel? dbHealth;
  final bool isArabic;

  const ObservabilityMetricStrip({
    super.key,
    required this.metrics,
    this.dbHealth,
    this.isArabic = true,
  });

  @override
  Widget build(BuildContext context) {
    final dbSize = dbHealth != null
        ? '${dbHealth!.databaseSizeMb.toStringAsFixed(1)} MB'
        : (isArabic ? 'جاري التحميل...' : 'Loading...');
    final dbTooltip = dbHealth != null
        ? 'WAL: ${dbHealth!.walSizeMb.toStringAsFixed(1)} MB • Timeout: ${dbHealth!.busyTimeoutMs}ms'
        : null;

    final items = [
      MetricCardData(
        title: isArabic ? 'خادم النظام والذاكرة' : 'Server & Memory',
        shortTitle: 'Server',
        value: '${metrics.processMemoryMb.toStringAsFixed(1)} MB',
        icon: Icons.memory_rounded,
        color: AppTheme.cobalt,
        tooltip: 'Uptime: ${metrics.uptimeHuman} • Port: ${ApiConstants.serverPort}',
      ),
      MetricCardData(
        title: isArabic ? 'محرك قاعدة البيانات' : 'SQLite WAL Engine',
        shortTitle: 'SQLite WAL',
        value: dbSize,
        icon: Icons.storage_rounded,
        color: AppTheme.charcoal,
        tooltip: dbTooltip,
      ),
      MetricCardData(
        title: isArabic ? 'معدل الطلبات والتزامن' : 'Request Throughput',
        shortTitle: 'Req/s',
        value: '${metrics.requestsPerSecond.toStringAsFixed(1)} req/s',
        icon: Icons.bolt_rounded,
        color: AppTheme.emerald,
        tooltip: 'Total requests: ${metrics.totalRequests}',
      ),
      MetricCardData(
        title: isArabic ? 'أزمنة الاستجابة' : 'Response Latencies',
        shortTitle: 'Latencies',
        value: 'P50: ${metrics.p50LatencyMs.toStringAsFixed(1)} ms',
        icon: Icons.timer_outlined,
        color: AppTheme.orange,
        tooltip: 'P95: ${metrics.p95LatencyMs.toStringAsFixed(1)} ms • P99: ${metrics.p99LatencyMs.toStringAsFixed(1)} ms',
      ),
    ];

    return MetricCardStrip(metrics: items);
  }
}

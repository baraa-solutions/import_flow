import 'package:flutter/material.dart';

import 'package:frontend/core/localization/app_localizations.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/widgets.dart';

import '../../models/shipping_scenario_model.dart';

/// Computed lead time metrics and comparison summary points for evaluated scenarios.
class ScenarioEvaluatorMetrics {
  final List<Map<String, dynamic>> calculatedScenarios;
  final List<Map<String, dynamic>> validScenarios;
  final int avgTotalDays;
  final String avgArrivalDate;
  final Map<String, dynamic>? recItemMap;
  final Map<String, dynamic>? earliestItemMap;
  final Map<String, dynamic>? latestItemMap;

  const ScenarioEvaluatorMetrics({
    required this.calculatedScenarios,
    required this.validScenarios,
    required this.avgTotalDays,
    required this.avgArrivalDate,
    required this.recItemMap,
    required this.earliestItemMap,
    required this.latestItemMap,
  });

  factory ScenarioEvaluatorMetrics.calculate({
    required List<ShippingScenarioItemModel> items,
    required DateTime cargoReadyDate,
    required int avgForm4Days,
    required int avgClearanceDays,
  }) {
    final calculated = items.asMap().entries.map((entry) {
      final idx = entry.key;
      final item = entry.value;

      final sDate = DateTime.tryParse(item.sailingDate) ?? cargoReadyDate;
      final etaDate = DateTime.tryParse(item.estimatedArrivalDate) ?? sDate.add(const Duration(days: 20));

      final vesselLeadTime = etaDate.difference(sDate).inDays;
      final readyDays = sDate.difference(cargoReadyDate).inDays;
      final totalDays = vesselLeadTime + readyDays + avgForm4Days + avgClearanceDays + item.expectedLineDelayDays;
      final expectedWhDate = cargoReadyDate.add(Duration(days: totalDays)).toString().substring(0, 10);

      return {
        'index': idx,
        'item': item,
        'vesselLeadTime': vesselLeadTime,
        'readyDays': readyDays,
        'totalDays': totalDays,
        'expectedWhDate': expectedWhDate,
      };
    }).toList();

    final valid = calculated.where((c) => !(c['item'] as ShippingScenarioItemModel).isExcludedFromAverage).toList();
    final avgDays = valid.isNotEmpty
        ? (valid.fold<int>(0, (sum, c) => sum + (c['totalDays'] as int)) / valid.length).round()
        : 0;
    final avgArrival = valid.isNotEmpty
        ? cargoReadyDate.add(Duration(days: avgDays)).toString().substring(0, 10)
        : 'N/A';

    final rec = calculated.where((c) {
      final it = c['item'] as ShippingScenarioItemModel;
      return it.isRecommended && it.totalQuotationAmount != null;
    }).firstOrNull;

    final earliest = valid.isNotEmpty
        ? valid.reduce((a, b) => (a['totalDays'] as int) < (b['totalDays'] as int) ? a : b)
        : null;
    final latest = valid.isNotEmpty
        ? valid.reduce((a, b) => (a['totalDays'] as int) > (b['totalDays'] as int) ? a : b)
        : null;

    return ScenarioEvaluatorMetrics(
      calculatedScenarios: calculated,
      validScenarios: valid,
      avgTotalDays: avgDays,
      avgArrivalDate: avgArrival,
      recItemMap: rec,
      earliestItemMap: earliest,
      latestItemMap: latest,
    );
  }
}

/// Top metrics cards responsive header displaying summary statistics for evaluated scenarios.
class ScenarioEvaluatorHeader extends StatelessWidget {
  final ScenarioEvaluatorMetrics metrics;

  const ScenarioEvaluatorHeader({
    super.key,
    required this.metrics,
  });

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String val,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBackground : AppTheme.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: isDark ? AppTheme.black.withValues(alpha: 0.26) : AppTheme.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textStrong,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          CopyableText(
            val,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            CopyableText(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.charcoal,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recItem = metrics.recItemMap != null ? (metrics.recItemMap!['item'] as ShippingScenarioItemModel) : null;
    final earliest = metrics.earliestItemMap;
    final latest = metrics.latestItemMap;

    return LayoutBuilder(
      builder: (context, metricConstraints) {
        final card1 = _buildMetricCard(
          context,
          l.avgWarehouseArrivalMetric,
          metrics.avgArrivalDate,
          Icons.date_range,
          AppTheme.wcagEmerald,
          subtitle: l.avgDaysFromReadiness(metrics.avgTotalDays),
        );
        final card2 = _buildMetricCard(
          context,
          l.earliestLineMetric,
          earliest != null ? (earliest['item'] as ShippingScenarioItemModel).providerName : 'N/A',
          Icons.speed,
          AppTheme.wcagCobalt,
          subtitle: earliest != null ? '${l.estimatedArrivalDateCol}: ${earliest["expectedWhDate"]}' : null,
        );
        final card3 = _buildMetricCard(
          context,
          l.latestLineMetric,
          latest != null ? (latest['item'] as ShippingScenarioItemModel).providerName : 'N/A',
          Icons.warning_amber_rounded,
          AppTheme.wcagOrange,
          subtitle: latest != null ? '${l.estimatedArrivalDateCol}: ${latest["expectedWhDate"]}' : null,
        );
        final card4 = _buildMetricCard(
          context,
          l.recommendedLineMetric,
          recItem != null ? '${recItem.providerName} (${recItem.vesselName})' : l.unassigned,
          Icons.stars_rounded,
          AppTheme.cobalt,
          subtitle: metrics.recItemMap != null ? '${l.avgWarehouseArrivalMetric}: ${metrics.recItemMap!["expectedWhDate"]} (${metrics.recItemMap!["totalDays"]} d)' : null,
        );

        if (metricConstraints.maxWidth < 600) {
          return Column(
            children: [
              card1,
              const SizedBox(height: 8),
              card2,
              const SizedBox(height: 8),
              card3,
              const SizedBox(height: 8),
              card4,
            ],
          );
        } else if (metricConstraints.maxWidth < 1100) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 8),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 8),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 8),
              Expanded(child: card2),
              const SizedBox(width: 8),
              Expanded(child: card3),
              const SizedBox(width: 8),
              Expanded(child: card4),
            ],
          );
        }
      },
    );
  }
}

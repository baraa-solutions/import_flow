import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../models/warehouse_receiving_model.dart';
import '../grn_record_card.dart';

/// KPI metric strip for Warehouse Receiving Screen
class WarehouseReceivingMetrics extends StatelessWidget {
  final List<WarehouseReceivingModel> records;

  const WarehouseReceivingMetrics({
    super.key,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pending = records.where((r) => GrnStatusView.isDraftStatus(r.status)).length;
    final received = records.where((r) => r.status == 'Goods Received' || r.status == 'Closed').length;
    final discrepancy = records.where((r) => r.status == 'Discrepancy Reported' || r.discrepancyType != 'None').length;

    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: l.wrGrnMetricTotal,
          shortTitle: l.wrGrnMetricTotal,
          value: '${records.length}',
          icon: Icons.inventory_outlined,
          color: AppTheme.cobalt,
        ),
        MetricCardData(
          title: l.wrGrnMetricPending,
          shortTitle: l.wrGrnMetricPending,
          value: '$pending',
          icon: Icons.hourglass_top_rounded,
          color: AppTheme.orange,
        ),
        MetricCardData(
          title: l.wrGrnMetricReceived,
          shortTitle: l.wrGrnMetricReceived,
          value: '$received',
          icon: Icons.check_circle_outline,
          color: AppTheme.emerald,
        ),
        MetricCardData(
          title: l.wrGrnMetricDiscrepancy,
          shortTitle: l.wrGrnMetricDiscrepancy,
          value: '$discrepancy',
          icon: Icons.report_problem_outlined,
          color: AppTheme.crimson,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../utils/po_packing_matcher.dart';

class PoKpiCards extends StatelessWidget {
  final int totalOrders;
  final double totalFobSum;
  final double totalCbmSum;
  final double totalGrossSum;

  const PoKpiCards({
    super.key,
    required this.totalOrders,
    required this.totalFobSum,
    required this.totalCbmSum,
    required this.totalGrossSum,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return MetricCardStrip(
      metrics: [
        MetricCardData(
          title: l.totalOrdersMetric,
          shortTitle: 'POs',
          value: '$totalOrders',
          icon: Icons.receipt_long,
          color: AppTheme.wcagCobalt,
        ),
        MetricCardData(
          title: l.totalFobMetric,
          shortTitle: 'PI/PO Amt',
          value: '\$${totalFobSum.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: AppTheme.wcagEmerald,
        ),
        MetricCardData(
          title: l.totalCargoCbmMetric,
          shortTitle: 'CBM',
          value: '${totalCbmSum.toStringAsFixed(2)} m³',
          icon: Icons.view_in_ar,
          color: AppTheme.wcagOrange,
        ),
        MetricCardData(
          title: l.totalGrossWeightMetric,
          shortTitle: 'Gross Wt',
          value: '${PoPackingMatcher.formatWeight(totalGrossSum)} kg',
          icon: Icons.scale,
          color: AppTheme.cobalt,
        ),
      ],
    );
  }
}

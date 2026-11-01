import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../customs_clearance/widgets/customs_ui.dart';
import '../../providers/shipment_updates_provider.dart';

class SuMetricsStrip extends StatelessWidget {
  final AppLocalizations l10n;
  final ShipmentUpdatesState updatesState;
  final int totalPhases;

  const SuMetricsStrip({
    super.key,
    required this.l10n,
    required this.updatesState,
    this.totalPhases = 10,
  });

  @override
  Widget build(BuildContext context) {
    final logs = updatesState.logs;
    final daily = logs.where((x) => x.updateCategory == 'Daily Check-in').length;
    final costAdj = logs.where((x) => x.updateCategory == 'Phase Cost Adjustment').length;
    final completed = updatesState.inspectedPhases.where((p) => p.status == 'Completed').length;

    return CcUi.metrics([
      MetricCardData(
        title: l10n.suMetricTotalUpdates,
        value: '${logs.length}',
        icon: Icons.history_rounded,
        color: AppTheme.cobalt,
      ),
      MetricCardData(
        title: l10n.shipmentUpdateBadgeDaily,
        value: '$daily',
        icon: Icons.today,
        color: AppTheme.emerald,
      ),
      MetricCardData(
        title: l10n.shipmentUpdateBadgeCostAdj,
        value: '$costAdj',
        icon: Icons.price_change_outlined,
        color: AppTheme.orange,
      ),
      MetricCardData(
        title: l10n.suMetricCompletedPhases,
        value: '$completed/$totalPhases',
        icon: Icons.check_circle_outline,
        color: AppTheme.charcoal,
      ),
    ]);
  }
}

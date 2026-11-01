import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../models/invoices_aggregation_model.dart';
import '../settlement_ui.dart';

class FinalSettlementKpis extends StatelessWidget {
  final InvoicesAggregationResponseModel data;

  const FinalSettlementKpis({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final egp = l10n.financialSettlementCurrencyEgp;
    final hasRemaining = data.totalRemainingEgp > 0;

    return SettlementMetricStrips(
      metrics: [
        MetricCardData(
          title: l10n.settlementClo01KpiTotal,
          value: '${formatSettlementMoney(data.totalAmountEgp)} $egp',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.charcoal,
          tooltip: l10n.settlementClo01KpiTotalSub(data.totalInvoicesCount),
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiPaid,
          value: '${formatSettlementMoney(data.totalPaidEgp)} $egp',
          icon: Icons.check_circle_outline_rounded,
          color: AppTheme.emerald,
          tooltip: l10n.settlementClo01KpiPaidSub,
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiRemaining,
          value: '${formatSettlementMoney(data.totalRemainingEgp)} $egp',
          icon: Icons.pending_actions_rounded,
          color: hasRemaining ? AppTheme.crimson : AppTheme.emerald,
          tooltip: hasRemaining
              ? l10n.settlementClo01KpiRemainingSubDue
              : l10n.settlementClo01KpiRemainingSubNone,
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiWht,
          value: '${formatSettlementMoney(data.totalWithholdingTaxEgp)} $egp',
          icon: Icons.account_balance_outlined,
          color: AppTheme.orange,
          tooltip: l10n.settlementClo01KpiWhtSub,
        ),
        MetricCardData(
          title: l10n.settlementClo01KpiReady,
          value: '${data.settlementReadinessPercent.toStringAsFixed(1)}%',
          icon: Icons.speed_rounded,
          color: AppTheme.cobalt,
          tooltip: l10n.settlementClo01KpiReadySub,
        ),
      ],
    );
  }
}

class FinalSettlementWarningsCard extends StatelessWidget {
  final List<String> warnings;

  const FinalSettlementWarningsCard({
    super.key,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SettlementTokens.radius),
        border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settlementClo01WarningsTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.orange,
                  ),
                ),
                const SizedBox(height: 4),
                ...warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.orange)),
                        Expanded(
                          child: Text(w, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../models/estimated_landed_cost_model.dart';
import '../settlement_ui.dart';

/// Executive summary banner, warnings, and KPI strip for Estimated Landed Cost simulation
class EstLandedCostSummary extends StatelessWidget {
  final EstimatedLandedCostSimulationModel data;

  const EstLandedCostSummary({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = data;
    final egp = l10n.financialSettlementCurrencyEgp;
    String whole(double v) => formatSettlementWhole(v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Executive Summary Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cobalt.withValues(alpha: 0.08),
            border: Border.all(color: AppTheme.cobalt.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(SettlementTokens.radius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.cobalt, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  d.executiveSummaryAr,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.charcoal,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Optional warnings
        if (d.messages.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(SettlementTokens.radius),
              border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in d.messages)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(settlementMessageText(l10n, m), style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2. KPI strip
        SettlementMetricStrips(
          metrics: [
            MetricCardData(
              title: l10n.settlementEstKpiFob,
              value: '${whole(d.totalFobEgp)} $egp',
              tooltip: '${whole(d.totalFobFc)} ${d.currency}',
              icon: Icons.inventory_2,
              color: AppTheme.cobalt,
            ),
            MetricCardData(
              title: l10n.settlementEstKpiFreightIns,
              value: '${whole(d.totalFreightEgp + d.totalInsuranceEgp)} $egp',
              icon: Icons.sailing,
              color: AppTheme.wcagEmerald,
              tooltip: l10n.settlementEstKpiFreightSub(whole(d.totalFreightEgp)),
            ),
            MetricCardData(
              title: l10n.settlementEstKpiCustoms,
              value: '${whole(d.totalCustomsAndTaxesEgp)} $egp',
              icon: Icons.account_balance,
              color: AppTheme.orange,
              tooltip: d.totalCustomsDutyEgp > 0 || d.totalVatAndFeesEgp > 0
                  ? '${l10n.settlementEstKpiDuty}: ${whole(d.totalCustomsDutyEgp)} | ${l10n.settlementEstKpiVatFees}: ${whole(d.totalVatAndFeesEgp)}'
                  : l10n.settlementEstKpiCustomsSub,
            ),
            MetricCardData(
              title: l10n.settlementEstKpiPort,
              value: '${whole(d.totalClearanceAndPortEgp + d.totalInlandTransportEgp)} $egp',
              icon: Icons.local_shipping,
              color: AppTheme.charcoal,
              tooltip: l10n.settlementEstKpiPortSub,
            ),
            MetricCardData(
              title: l10n.settlementEstKpiLanded,
              value: '${whole(d.totalLandedCostEgp)} $egp',
              tooltip: '${whole(d.totalLandedCostFc)} ${d.currency}',
              icon: Icons.monetization_on,
              color: AppTheme.emerald,
            ),
            MetricCardData(
              title: l10n.settlementEstKpiMarkup,
              value: '×${d.averageMarkupFactor.toStringAsFixed(3)}',
              tooltip: '+${d.averageMarkupPercent.toStringAsFixed(1)}%',
              icon: Icons.trending_up,
              color: AppTheme.crimson,
            ),
          ],
        ),
      ],
    );
  }
}

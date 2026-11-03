import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../models/actual_landed_cost_model.dart';
import '../settlement_ui.dart';

/// KPI metric strip and messages banner for Actual Landed Cost calculation
class ActualLandedCostSummary extends StatelessWidget {
  final ActualLandedCostCalculationResponseModel calc;

  const ActualLandedCostSummary({
    super.key,
    required this.calc,
  });

  static Color varianceColor(String status) {
    if (status == 'NO_ESTIMATE') return AppTheme.textSecondary;
    if (status == 'UNFAVORABLE') return AppTheme.flatCrimson;
    if (status == 'MATCHED') return AppTheme.flatCobalt;
    return AppTheme.flatEmerald;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final egp = l10n.financialSettlementCurrencyEgp;
    final vColor = varianceColor(calc.varianceStatus);

    final lines = [
      ...calc.messages.map((m) => settlementMessageText(l10n, m)),
      if (calc.reconciliationDifferenceEgp != 0)
        l10n.settlementReconciliationNote(
            '${formatSettlementMoney(calc.reconciliationDifferenceEgp)} ${l10n.financialSettlementCurrencyEgp}'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 8),
          child: SettlementMetricStrips(
            metrics: [
              MetricCardData(
                title: l10n.settlementClo02KpiFob,
                value: '${formatSettlementMoney(calc.totalFobEgp)} $egp',
                icon: Icons.inventory_2_outlined,
                color: AppTheme.flatCobalt,
                tooltip: l10n.settlementClo02KpiFobSub(calc.currency ?? '', calc.fxRate.toStringAsFixed(2)),
              ),
              MetricCardData(
                title: l10n.settlementClo02KpiExpenses,
                value: '${formatSettlementMoney(calc.totalActualExpensesEgp)} $egp',
                icon: Icons.receipt_long_outlined,
                color: AppTheme.flatOrange,
                tooltip: l10n.settlementClo02KpiExpensesSub,
              ),
              MetricCardData(
                title: l10n.settlementClo02KpiLanded,
                value: '${formatSettlementMoney(calc.actualTotalLandedCostEgp)} $egp',
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.flatCharcoal,
                tooltip: calc.estimatedTotalLandedCostEgp != null
                    ? l10n.settlementClo02KpiLandedSub(
                        '${formatSettlementMoney(calc.estimatedTotalLandedCostEgp!)} $egp')
                    : '-',
              ),
              MetricCardData(
                title: l10n.settlementClo02KpiMarkup,
                value: '${calc.actualMarkupFactor.toStringAsFixed(3)}x',
                icon: Icons.trending_up,
                color: AppTheme.flatCobalt,
                tooltip: l10n.settlementClo02KpiMarkupSub,
              ),
              MetricCardData(
                title: l10n.settlementClo02KpiVariance,
                value: calc.landedVariancePct != null
                    ? formatSettlementPercent(calc.landedVariancePct!)
                    : '-',
                icon: calc.varianceStatus == 'FAVORABLE'
                    ? Icons.arrow_downward
                    : calc.varianceStatus == 'UNFAVORABLE'
                        ? Icons.arrow_upward
                        : calc.varianceStatus == 'NO_ESTIMATE'
                            ? Icons.remove
                            : Icons.check,
                color: vColor,
                tooltip: calc.landedVarianceEgp != null
                    ? l10n.settlementClo02KpiVarianceSub(
                        '${formatSettlementMoney(calc.landedVarianceEgp!)} $egp',
                        calc.varianceStatusAr)
                    : calc.varianceStatusAr,
              ),
            ],
          ),
        ),
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(SettlementTokens.radius),
                border: Border.all(color: AppTheme.orange.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in lines)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.orange),
                        const SizedBox(width: 6),
                        Expanded(child: Text(line, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
